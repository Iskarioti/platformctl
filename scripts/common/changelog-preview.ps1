param(
    [string]$Since = ""
)

# Drafts a CHANGELOG.md section + suggested semver bump from Conventional
# Commits (feat:/fix:/type!:) since the last VERSION bump. Preview only -
# prints to stdout, never writes CHANGELOG.md or VERSION itself. This repo's
# commit history predates any enforcement of the convention, so this is
# deliberately a helper a human (or agent) reviews and pastes in, not a CI
# gate - retrofitting strict enforcement would just break the existing
# autosync/commit workflow for no benefit.

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

if (-not $Since) {
    $VersionCommits = git log --format="%H" -- VERSION
    $Since = if ($VersionCommits -and $VersionCommits.Count -ge 2) { $VersionCommits[1] } else { "" }
}

$RangeArg = if ($Since) { "$Since..HEAD" } else { "HEAD" }
$Subjects = git log $RangeArg --format="%s" --no-merges

$Groups = [ordered]@{
    "Breaking changes" = @()
    "Features"         = @()
    "Fixes"            = @()
    "Other"            = @()
}

$HasBreaking = $false
$HasFeat = $false

foreach ($Subject in $Subjects) {
    if ($Subject -match '^(?<type>\w+)(\(.+\))?(?<breaking>!)?:\s*(?<desc>.+)$') {
        $Type = $Matches['type']
        $Desc = $Matches['desc']
        $Breaking = $Matches['breaking'] -eq '!'

        if ($Breaking) {
            $HasBreaking = $true
            $Groups["Breaking changes"] += $Desc
            continue
        }

        switch ($Type) {
            "feat"  { $HasFeat = $true; $Groups["Features"] += $Desc }
            "fix"   { $Groups["Fixes"] += $Desc }
            default { $Groups["Other"] += "$Type`: $Desc" }
        }
    } else {
        $Groups["Other"] += $Subject
    }
}

$CurrentVersion = (Get-Content (Join-Path $Root "VERSION") -Raw).Trim()
$Parts = $CurrentVersion -split '\.'
[int]$Major, [int]$Minor, [int]$Patch = $Parts[0], $Parts[1], $Parts[2]

if ($HasBreaking) { $Major++; $Minor = 0; $Patch = 0 }
elseif ($HasFeat) { $Minor++; $Patch = 0 }
else { $Patch++ }

$SuggestedVersion = "$Major.$Minor.$Patch"
$ShortSince = if ($Since) { $Since.Substring(0, [Math]::Min(7, $Since.Length)) } else { "repo start" }

Write-Host "=== Changelog preview ===" -ForegroundColor Cyan
Write-Host "Current VERSION: $CurrentVersion"
Write-Host "Suggested next:  $SuggestedVersion  (Conventional Commits since $ShortSince)"
Write-Host ""
Write-Host "## $SuggestedVersion" -ForegroundColor Green
Write-Host ""

$AnyOutput = $false
foreach ($Key in $Groups.Keys) {
    if ($Groups[$Key].Count -eq 0) { continue }
    $AnyOutput = $true
    foreach ($Item in $Groups[$Key]) {
        Write-Host "- $Item"
    }
}

if (-not $AnyOutput) {
    Write-Host "(no commits since $ShortSince)"
}

Write-Host ""
Write-Host "This is a DRAFT for review - paste the parts you want into CHANGELOG.md yourself." -ForegroundColor Yellow
Write-Host "Commits that don't follow 'type: description' land under Other verbatim - not every" -ForegroundColor Yellow
Write-Host "commit in this repo's history follows Conventional Commits, and that's fine." -ForegroundColor Yellow
