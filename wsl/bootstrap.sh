#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y

sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  build-essential ca-certificates curl wget unzip zip jq git git-lfs \
  openssh-client make tmux shellcheck dnsutils iputils-ping traceroute \
  mtr-tiny netcat-openbsd nmap tcpdump iperf3 openssl \
  postgresql-client redis-tools \
  ripgrep fd-find fzf bat eza zoxide direnv bash-completion htop btop tree rsync \
  gnupg lsb-release software-properties-common

mkdir -p "$HOME/.local/bin"
ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"

if ! grep -q 'HOME/.local/bin' "$HOME/.profile"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
fi

mkdir -p "$HOME/src"/{company,platform,automation,labs,knowledge,tooling}
git lfs install

"$(dirname "${BASH_SOURCE[0]}")/configure-git.sh"

echo "Thin WSL engineering control plane installed."
echo "Project runtimes belong in Dev Containers."
echo ""
echo "If you use company Git hosts (GitHub, Azure DevOps), add this public key to"
echo "each one - a single local key working on one host does not imply it's"
echo "registered on another:"
echo ""
cat "$HOME/.ssh/id_ed25519_company.pub" 2>/dev/null || true
