#!/usr/bin/env bash
set -euo pipefail

# Research computing toolchain - see platform/linux/install-research-tools.sh
# for the full rationale per tool.
#
# mactex-no-gui is MacTeX (the standard macOS TeX Live distribution) without
# the GUI apps (TeXShop, BibDesk, etc.) - a full working LaTeX toolchain,
# smaller footprint than the full mactex cask.

brew install --cask mactex-no-gui quarto
brew install pandoc pixi

echo "Research toolchain installed. Run 'workstation research doctor' to verify."
