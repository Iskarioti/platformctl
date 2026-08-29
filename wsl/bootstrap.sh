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

echo "Thin WSL engineering control plane installed."
echo "Project runtimes belong in Dev Containers."
