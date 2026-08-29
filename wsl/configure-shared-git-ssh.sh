#!/usr/bin/env bash
set -euo pipefail

echo "=== Shared Git / SSH configuration ==="

# Use cmd.exe rather than PowerShell static .NET calls. This remains compatible
# with managed Windows endpoints running PowerShell ConstrainedLanguage.
if ! command -v cmd.exe >/dev/null 2>&1; then
  echo "ERROR: Windows interoperability is unavailable."
  exit 1
fi

WIN_HOME_WIN="$(cmd.exe /d /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')"
if [[ -z "$WIN_HOME_WIN" || "$WIN_HOME_WIN" == "%USERPROFILE%" ]]; then
  echo "ERROR: Unable to determine Windows USERPROFILE."
  exit 1
fi
WIN_HOME="$(wslpath -u "$WIN_HOME_WIN")"

COMMON_GIT="$WIN_HOME/.config/git/common.gitconfig"
WINDOWS_COMMON_SSH="$WIN_HOME/.ssh/config.common"

if [[ ! -f "$COMMON_GIT" ]]; then
  echo "ERROR: Shared Git configuration not found: $COMMON_GIT"
  echo "Run windows/35-shared-config.ps1 first."
  exit 1
fi

git config --global include.path "$COMMON_GIT"
git config --global core.autocrlf input

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Keep the Windows file canonical but copy it into the Linux filesystem so
# OpenSSH sees normal Linux ownership/permissions instead of /mnt/c ACLs.
if [[ -f "$WINDOWS_COMMON_SSH" ]]; then
  install -m 600 "$WINDOWS_COMMON_SSH" "$HOME/.ssh/config.common"
else
  cat > "$HOME/.ssh/config.common" <<'SSHCOMMON'
Host *
    ServerAliveInterval 30
    ServerAliveCountMax 3
    TCPKeepAlive yes
    HashKnownHosts yes
SSHCOMMON
  chmod 600 "$HOME/.ssh/config.common"
fi

cat > "$HOME/.ssh/config" <<'SSHCONFIG'
Include ~/.ssh/config.common

Host github-company
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_company
    IdentitiesOnly yes

Host ssh.dev.azure.com
    HostName ssh.dev.azure.com
    User git
    IdentityFile ~/.ssh/id_ed25519_company
    IdentitiesOnly yes
SSHCONFIG
chmod 600 "$HOME/.ssh/config"

EMAIL="$(git config user.email || true)"
if [[ ! -f "$HOME/.ssh/id_ed25519_company" ]]; then
  ssh-keygen -t ed25519 -a 64 -f "$HOME/.ssh/id_ed25519_company" -C "${EMAIL:-company-workstation}"
fi
chmod 600 "$HOME/.ssh/id_ed25519_company"
chmod 644 "$HOME/.ssh/id_ed25519_company.pub"

echo "Windows profile : $WIN_HOME_WIN"
echo "WSL path        : $WIN_HOME"
echo "Git common      : $COMMON_GIT"
echo "SSH common copy : $HOME/.ssh/config.common"
echo "Private key     : $HOME/.ssh/id_ed25519_company"
echo
echo "Public key:"
cat "$HOME/.ssh/id_ed25519_company.pub"
