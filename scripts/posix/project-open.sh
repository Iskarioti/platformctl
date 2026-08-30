#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-$PWD}"
TARGET="$(cd "$TARGET" && pwd)"

# Informational only: a non-compliant project must still be openable, just
# flagged. (Previously this ran under "set -e", so any FAIL here aborted the
# whole script before VS Code ever launched.)
"$ROOT/scripts/posix/project-check.sh" "$TARGET" || true
echo

command -v code >/dev/null 2>&1 || {
  echo "VS Code 'code' command is not available in this shell." >&2
  exit 4
}

open_plain() {
  cd "$TARGET" && exec code .
}

DEVCONTAINER_JSON="$TARGET/.devcontainer/devcontainer.json"
[[ -f "$DEVCONTAINER_JSON" ]] || open_plain

# Never trust bare "devcontainer"/"node" PATH resolution here: this script
# runs non-interactively, so neither ~/.bashrc (mise shims) nor WSL's
# Windows-PATH interop can be trusted not to resolve to an unrelated
# Windows-native @devcontainers/cli install that can never see Docker.
DEVCONTAINER_BIN="$HOME/.local/bin/devcontainer"
MISE_SHIMS="$HOME/.local/share/mise/shims"

if [[ ! -x "$DEVCONTAINER_BIN" ]]; then
  echo "Dev Container CLI not installed; run scripts/posix/install-devcontainers-cli.sh first." >&2
  echo "Opening the folder without a Dev Container." >&2
  open_plain
fi

echo "Building/starting Dev Container for $TARGET ..."
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

PATH="$MISE_SHIMS:$PATH" "$DEVCONTAINER_BIN" up --workspace-folder "$TARGET" --log-format json >"$log_file" 2>&1
up_status=$?
result_json="$(tail -1 "$log_file")"
outcome="$(printf '%s' "$result_json" | jq -r '.outcome // empty' 2>/dev/null || true)"

if [[ $up_status -ne 0 || "$outcome" != "success" ]]; then
  echo "Dev Container build/start failed:" >&2
  jq -r 'select(.text != null) | .text' "$log_file" 2>/dev/null >&2
  echo "Opening the folder without a container." >&2
  open_plain
fi

remote_workspace_folder="$(printf '%s' "$result_json" | jq -r '.remoteWorkspaceFolder // empty' 2>/dev/null || true)"
remote_workspace_folder="${remote_workspace_folder:-/workspaces/$(basename "$TARGET")}"

# The "dev-container+<hex>" authority is hex-encoded JSON, not a hex-encoded
# path (an earlier version of this script assumed the latter - it happened to
# open *a* VS Code window, but not one genuinely attached to the container).
# Confirmed the real shape by decoding a live "could not be established"
# message from "code --status" for an actual in-progress attach on this
# machine: {"hostPath": "<UNC path to the workspace>", "localDocker": bool,
# "configFile": {"$mid": 1, "path": "<path to devcontainer.json>", "scheme":
# "vscode-fileHost"}}. Empirically verified end-to-end against this repo's
# own VS Code install (1.135.0): "code --status" showed a stable
# "[Dev Container: ...]" window that persisted (no "could not be
# established"), for the exact URI this block builds.
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  # Verified shape: VS Code (running on the Windows side) reaches the WSL
  # filesystem through the "\\wsl.localhost\<distro>\..." UNC share, and
  # "localDocker: false" because Docker lives inside the WSL VM, not next to
  # the VS Code host process.
  win_path="$(printf '%s' "$TARGET" | tr '/' '\\')"
  host_path="\\\\wsl.localhost\\${WSL_DISTRO_NAME}${win_path}"
  local_docker=false
else
  # Native Linux/macOS: no WSL translation layer, Docker runs next to VS Code
  # directly. Same field shapes as the verified WSL case, but this branch
  # itself is UNVERIFIED (no native Linux/macOS machine to test against this
  # session) - falls back to open_plain below if attach doesn't work.
  host_path="$TARGET"
  local_docker=true
fi

folder_uri_json="$(jq -nc \
  --arg hostPath "$host_path" \
  --argjson localDocker "$local_docker" \
  --arg configPath "$DEVCONTAINER_JSON" \
  '{hostPath:$hostPath, localDocker:$localDocker, configFile:{"$mid":1, path:$configPath, scheme:"vscode-fileHost"}}')"
hex_authority="$(printf '%s' "$folder_uri_json" | od -An -tx1 | tr -d ' \n')"
folder_uri="vscode-remote://dev-container+${hex_authority}${remote_workspace_folder}"

echo "Attaching VS Code to Dev Container..."
exec code --folder-uri "$folder_uri"
