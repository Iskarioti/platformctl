# Launches Alacritty and centers its window on whichever monitor it opens on.
#
# Alacritty's own config schema has no equivalent to Windows Terminal's
# `centerOnLaunch` boolean - its [window.position] key only sets fixed
# absolute pixel coordinates, which would be wrong the moment the window
# opens on a different monitor, resolution, or DPI scale than whatever this
# was tuned against (see shell/alacritty/architect.alacritty.toml's header).
# So instead of hardcoding a position in that shared cross-platform config
# file, this Windows-only launcher starts Alacritty normally, finds its real
# window, then repositions (never resizes) it using its own actual on-screen
# size and whichever monitor it landed on - correct regardless of monitor
# setup. Run every time Alacritty starts, via the Start Menu shortcut
# 43-configure-taskbar-appearance.ps1 manages for it.
#
# Invoked hidden (wscript.exe + run-hidden.vbs, see that file) so this
# script's own PowerShell window never flashes - only Alacritty's real
# window appears, already centered.
#
# Deliberately does NOT use [System.Diagnostics.Process]::MainWindowHandle -
# confirmed live, repeatedly, that it's unreliable here: Alacritty briefly
# has TWO visible top-level windows under the same PID (the real terminal
# window, already at its full configured size and never observed to move on
# its own; and an unrelated ~16x16 helper window at 0,0 - likely a
# drag-and-drop or DirectComposition implementation detail of winit, not
# something this repo controls). MainWindowHandle would sometimes latch onto
# the tiny helper window instead of the real one, silently centering nothing
# useful while the actual terminal sat wherever Windows' own default cascade
# placement put it. Enumerating windows directly and filtering by size finds
# the real one reliably instead.
$ErrorActionPreference = "Stop"

Add-Type -Namespace WinCenter -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
[DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);
[DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

[StructLayout(LayoutKind.Sequential)]
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

[StructLayout(LayoutKind.Sequential)]
public struct MONITORINFO {
    public uint cbSize;
    public RECT rcMonitor;
    public RECT rcWork;
    public uint dwFlags;
}
'@

$AlacrittyExe = "C:\Program Files\Alacritty\alacritty.exe"
if (-not (Test-Path -LiteralPath $AlacrittyExe -PathType Leaf)) {
    $cmd = Get-Command "alacritty.exe" -ErrorAction SilentlyContinue
    if ($cmd) { $AlacrittyExe = $cmd.Source }
}
if (-not (Test-Path -LiteralPath $AlacrittyExe -PathType Leaf)) {
    exit 1   # not installed - nothing to launch
}

$proc = Start-Process -FilePath $AlacrittyExe -PassThru
$targetPid = $proc.Id

# Real terminal window vs. winit's tiny helper window are told apart purely
# by size (>= 200x150 - comfortably above the helper's 16x16, comfortably
# below any real terminal grid) since neither window title nor class name
# reliably distinguishes them.
function Find-RealWindow([int]$TargetPid) {
    $script:candidate = [IntPtr]::Zero
    $callback = {
        param($h, $l)
        $winPid = 0
        [void][WinCenter.NativeMethods]::GetWindowThreadProcessId($h, [ref]$winPid)
        if ($winPid -eq $TargetPid -and [WinCenter.NativeMethods]::IsWindowVisible($h)) {
            $r = New-Object WinCenter.NativeMethods+RECT
            [void][WinCenter.NativeMethods]::GetWindowRect($h, [ref]$r)
            if (($r.Right - $r.Left) -ge 200 -and ($r.Bottom - $r.Top) -ge 150) {
                $script:candidate = $h
                return $false   # found it, stop enumerating
            }
        }
        return $true
    }
    [void][WinCenter.NativeMethods]::EnumWindows($callback, [IntPtr]::Zero)
    return $script:candidate
}

$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 100; $i++) {
    if ($proc.HasExited) { exit 0 }
    $hwnd = Find-RealWindow $targetPid
    if ($hwnd -ne [IntPtr]::Zero) { break }
    Start-Sleep -Milliseconds 50
}
if ($hwnd -eq [IntPtr]::Zero) {
    exit 0   # window never appeared in time - leave it wherever it lands
}

$rect = New-Object WinCenter.NativeMethods+RECT
[void][WinCenter.NativeMethods]::GetWindowRect($hwnd, [ref]$rect)
$winWidth = $rect.Right - $rect.Left
$winHeight = $rect.Bottom - $rect.Top

$MONITOR_DEFAULTTONEAREST = 2
$hMonitor = [WinCenter.NativeMethods]::MonitorFromWindow($hwnd, $MONITOR_DEFAULTTONEAREST)
$mi = New-Object WinCenter.NativeMethods+MONITORINFO
$mi.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mi)
[void][WinCenter.NativeMethods]::GetMonitorInfo($hMonitor, [ref]$mi)

$workWidth = $mi.rcWork.Right - $mi.rcWork.Left
$workHeight = $mi.rcWork.Bottom - $mi.rcWork.Top
$x = $mi.rcWork.Left + [int](($workWidth - $winWidth) / 2)
$y = $mi.rcWork.Top + [int](($workHeight - $winHeight) / 2)

$SWP_NOSIZE = 0x0001
$SWP_NOZORDER = 0x0004
[void][WinCenter.NativeMethods]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, ($SWP_NOSIZE -bor $SWP_NOZORDER))
