#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

FONT_ROOT="$HOME/.local/share/fonts"
JB_DIR="$FONT_ROOT/JetBrainsMono"
NERD_DIR="$FONT_ROOT/JetBrainsMonoNerd"

mkdir -p "$JB_DIR" "$NERD_DIR"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to read workstation.json." >&2
    exit 2
fi

VERSION="$(
    jq -r '.fonts.editor.version' "$ROOT/workstation.json"
)"

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
    echo "ERROR: JetBrains Mono version is not defined in workstation.json." >&2
    exit 3
fi

echo "=== Linux Fonts ==="
echo "Editor:   JetBrains Mono $VERSION"
echo "Terminal: JetBrainsMono Nerd Font Mono"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Official JetBrains Mono
#
# Pin to the version declared by workstation.json.
# Do not depend on GitHub's latest-release API.
# ---------------------------------------------------------------------------

JB_ARCHIVE="$TMP/JetBrainsMono.zip"

JB_URL="https://github.com/JetBrains/JetBrainsMono/releases/download/v${VERSION}/JetBrainsMono-${VERSION}.zip"

echo ""
echo "Downloading JetBrains Mono $VERSION..."

if ! curl \
    --fail \
    --location \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout 15 \
    "$JB_URL" \
    --output "$JB_ARCHIVE"
then
    echo "ERROR: Unable to download JetBrains Mono $VERSION." >&2
    echo "URL: $JB_URL" >&2
    exit 4
fi

JB_EXTRACT="$TMP/jetbrainsmono"

mkdir -p "$JB_EXTRACT"

unzip -oq \
    "$JB_ARCHIVE" \
    -d "$JB_EXTRACT"

mapfile -t JB_FONTS < <(
    find "$JB_EXTRACT/fonts/ttf" \
        -maxdepth 1 \
        -type f \
        -name 'JetBrainsMono-*.ttf' \
        -print |
    sort
)

if [[ "${#JB_FONTS[@]}" -eq 0 ]]; then
    echo "ERROR: JetBrains Mono archive contained no expected TTF files." >&2
    exit 5
fi

for source in "${JB_FONTS[@]}"; do

    name="$(basename "$source")"
    target="$JB_DIR/$name"

    if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
        echo "UNCHANGED $name"
        continue
    fi

    cp -f "$source" "$target"
    echo "INSTALLED $name"
done

# ---------------------------------------------------------------------------
# Nerd Font
#
# This font is principally used by terminal renderers. In WSL, Windows
# Terminal uses the Windows-installed font, but retain the Linux copy for
# native Linux portability and GUI applications.
# ---------------------------------------------------------------------------

NERD_ARCHIVE="$TMP/JetBrainsMonoNerd.zip"

NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

echo ""
echo "Downloading JetBrainsMono Nerd Font..."

if curl \
    --fail \
    --location \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout 15 \
    "$NERD_URL" \
    --output "$NERD_ARCHIVE"
then

    NERD_EXTRACT="$TMP/nerd"
    mkdir -p "$NERD_EXTRACT"

    unzip -oq \
        "$NERD_ARCHIVE" \
        -d "$NERD_EXTRACT"

    while IFS= read -r -d '' source; do

        name="$(basename "$source")"
        target="$NERD_DIR/$name"

        if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
            echo "UNCHANGED $name"
        else
            cp -f "$source" "$target"
            echo "INSTALLED $name"
        fi

    done < <(
        find "$NERD_EXTRACT" \
            -type f \
            -name '*.ttf' \
            -print0
    )

else
    echo "WARNING: Nerd Font download was unavailable." >&2

    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WARNING: Continuing because Windows Terminal supplies the terminal font for WSL." >&2
    else
        echo "ERROR: Nerd Font installation failed on native Linux." >&2
        exit 6
    fi
fi

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f
fi

echo ""
echo "Linux font installation complete."
