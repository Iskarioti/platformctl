param(
    [Parameter(Mandatory=$true)]
    [string]$GitName,

    [Parameter(Mandatory=$true)]
    [string]$GitEmail
)

$ErrorActionPreference = "Stop"

$GitDir = Join-Path $env:USERPROFILE ".config\git"
$SshDir = Join-Path $env:USERPROFILE ".ssh"

New-Item -ItemType Directory -Force -Path $GitDir | Out-Null
New-Item -ItemType Directory -Force -Path $SshDir | Out-Null

$CommonGit = @"
[user]
    name = $GitName
    email = $GitEmail

[init]
    defaultBranch = main

[pull]
    ff = only

[fetch]
    prune = true

[rerere]
    enabled = true

[diff]
    algorithm = histogram

[merge]
    conflictStyle = zdiff3

[push]
    autoSetupRemote = true

[tag]
    sort = version:refname
"@

$CommonGitPath = Join-Path $GitDir "common.gitconfig"
Set-Content -Path $CommonGitPath -Value $CommonGit -Encoding UTF8

git config --global include.path "$($CommonGitPath -replace '\\','/')"
git config --global core.autocrlf false

$CommonSsh = @"
Host *
    ServerAliveInterval 30
    ServerAliveCountMax 3
    TCPKeepAlive yes
    HashKnownHosts yes
"@

$CommonSshPath = Join-Path $SshDir "config.common"
Set-Content -Path $CommonSshPath -Value $CommonSsh -Encoding UTF8

$WindowsSshConfig = @"
Include config.common

# Windows-specific identities belong here if Windows itself needs SSH.
# Do not put private keys in the shared config.
"@
Set-Content -Path (Join-Path $SshDir "config") -Value $WindowsSshConfig -Encoding UTF8

Write-Host "Created shared Git config: $CommonGitPath"
Write-Host "Created shared SSH config: $CommonSshPath"
Write-Host "Private SSH keys remain OS-specific."
