#!/usr/bin/env bash
set -euo pipefail

# Research computing toolchain for PhD/CS research work: LaTeX (TeX Live),
# Pandoc, Quarto, and pixi (reproducible scientific environments). Managed
# via "workstation research", see scripts/posix/research.sh and
# docs/research-computing.md.
#
# TeX Live and Pandoc are genuine system packages (matching this script's
# apt/dnf/pacman list, same as the rest of bootstrap.sh) - a real human
# running bootstrap.sh interactively gets prompted for their sudo password
# once, same as everywhere else in this repo. Quarto and pixi install
# sudo-free into $HOME/.local, same pattern as
# platform/linux/install-security-tools.sh.

BIN_DIR="$HOME/.local/bin"
SHARE_DIR="$HOME/.local/share"
mkdir -p "$BIN_DIR" "$SHARE_DIR"

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    texlive-latex-base texlive-latex-recommended texlive-latex-extra \
    texlive-fonts-recommended texlive-bibtex-extra biber latexmk pandoc
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y texlive-scheme-basic texlive-collection-latexextra \
    biber latexmk pandoc
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm texlive-core texlive-latexextra \
    texlive-bibtexextra biber pandoc
else
  echo "NOTE: unsupported package manager - install TeX Live and Pandoc yourself." >&2
fi

# --- Quarto: no default repo package - official tar.gz release, sudo-free ---
if ! command -v quarto >/dev/null 2>&1; then
  QUARTO_URL="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/quarto-dev/quarto-cli/releases/latest)"
  QUARTO_VERSION="${QUARTO_URL##*/tag/v}"
  curl -fsSL -o /tmp/quarto.tar.gz \
    "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.tar.gz"
  rm -rf "$SHARE_DIR/quarto"
  mkdir -p "$SHARE_DIR/quarto"
  tar -xzf /tmp/quarto.tar.gz -C "$SHARE_DIR/quarto" --strip-components=1
  rm -f /tmp/quarto.tar.gz
  ln -sf "$SHARE_DIR/quarto/bin/quarto" "$BIN_DIR/quarto"
fi

# --- pixi: official install script, sudo-free. Defaults to ~/.pixi/bin and
# self-editing .bashrc/.zshrc with its own PATH line - redirected to
# $BIN_DIR (already on PATH via shell/{bash,zsh}/architect.*rc) and told not
# to touch shell rc files that are this repo's own managed fragments. ---
if ! command -v pixi >/dev/null 2>&1; then
  PIXI_BIN_DIR="$BIN_DIR" PIXI_NO_PATH_UPDATE=1 sh -c "$(curl -fsSL https://pixi.sh/install.sh)"
fi

echo "Research toolchain installed. Run 'workstation research doctor' to verify."
