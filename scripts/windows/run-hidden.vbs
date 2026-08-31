' Launches a program with zero visible window. Task Scheduler's own "Hidden"
' task setting only hides the task from Task Scheduler's UI - it does NOT
' suppress the console window a launched .exe allocates, which is why a
' scheduled pwsh.exe task still flashes a visible window every run even when
' marked Hidden. wscript.exe is a GUI-subsystem host (unlike cscript.exe) and
' never shows a window itself, so routing the real command through
' Shell.Run's hidden window-style flag (0) here is what actually keeps the
' scheduled task invisible.
'
' Usage: wscript.exe //B run-hidden.vbs <exe> [args...]
' Each argument is passed separately (not as one pre-quoted string) so paths
' containing spaces work without the caller having to hand-escape quotes.
Dim objShell, cmd, i
Set objShell = CreateObject("WScript.Shell")
cmd = """" & WScript.Arguments(0) & """"
For i = 1 To WScript.Arguments.Count - 1
    cmd = cmd & " """ & WScript.Arguments(i) & """"
Next
objShell.Run cmd, 0, False
