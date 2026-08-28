# New Machine

## First machine: publish the repository

After extracting/downloading this repository and initializing Git:

```bash
git init
git add .
git commit -m "feat: reproducible workstation v3"
```

Then:

```text
workstation publish
```

The default publish target is a private GitHub repository named
`system-platform-architect-workstation`.

## Any later machine

Windows:

```powershell
git clone <your-repository-url>
cd system-platform-architect-workstation
.\bootstrap.ps1
```

Linux or macOS:

```bash
git clone <your-repository-url>
cd system-platform-architect-workstation
./bootstrap
```

Bootstrap installs platform prerequisites, fonts, prompt, editor configuration,
Git hooks, global workstation command and background autosync.
