# platformctl v3.5.1 — Modular Services + Labs Repair

This release fixes two issues in v3.5.0:

1. the corporate Windows endpoint can block a downloaded `apply-to-platformctl.ps1`
   under RemoteSigned/App Control because the downloaded archive/script carries
   Mark-of-the-Web;
2. the old `scripts/ci/validate.ps1` still expected the retired monolithic files
   `development/services/compose.yaml`, `versions.env`, and `.env.example`.

v3.5.1 includes a validator for the modular service catalog and a fully functional
WSL/Bash installer. On the corporate endpoint, the WSL installer is the preferred path
because it does not require weakening PowerShell execution policy.

## Preferred repair path: WSL

First disable autosync while the repository is partially migrated:

```bash
workstation autosync disable
```

Extract this package outside the `platformctl` repository.

Then from WSL:

```bash
bash /path/to/platformctl-modular-services-labs-v3.5.1/apply-to-platformctl.sh \
  "/mnt/c/Users/AndrewKariuki/OneDrive - WIOCC/Documents/platformctl"
```

Validate:

```bash
cd "/mnt/c/Users/AndrewKariuki/OneDrive - WIOCC/Documents/platformctl"

pwsh.exe -NoLogo -NoProfile -File ./setup.ps1 validate
```

Then:

```bash
workstation services list
workstation services doctor
workstation lab list
workstation lab toolchain doctor
```

Once validation passes:

```bash
workstation autosync enable
```

## PowerShell alternative

Do not use `-ExecutionPolicy Bypass`.

Verify the downloaded ZIP hash first, then unblock the trusted extracted update files:

```powershell
Get-FileHash .\platformctl-modular-services-labs-v3.5.1.zip -Algorithm SHA256

Get-ChildItem `
  -LiteralPath .\platformctl-modular-services-labs-v3.5.1 `
  -Recurse `
  -Force `
  -File |
ForEach-Object {
    Unblock-File -LiteralPath $_.FullName
}
```

Then run:

```powershell
pwsh.exe `
  -NoLogo `
  -NoProfile `
  -File ".\apply-to-platformctl.ps1" `
  -RepoPath "C:\Users\AndrewKariuki\OneDrive - WIOCC\Documents\platformctl"
```

The update is idempotent and repairs a partially applied v3.5.0 repository.

## Validation changes

The validator now expects:

```text
development/catalog.json
development/services/<service>/
  service.json
  versions.env
  defaults.env
  .env.example
  compose.yaml
  README.md
```

and validates the architecture-lab catalog under:

```text
labs/catalog.json
```

The legacy monolithic files are intentionally rejected if they reappear.
