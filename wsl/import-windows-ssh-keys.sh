#!/usr/bin/env bash
set -euo pipefail

# Copies existing Windows-host SSH keys into WSL's native filesystem, rather
# than generating separate WSL-only keys (the approach configure-git.sh /
# configure-shared-git-ssh.sh take). Useful when your Windows-side keys are
# already registered with the Git hosts you use - re-registering a second,
# WSL-only key on every host is unnecessary busywork.
#
# Explicitly a copy, never a reference straight into /mnt/c: OpenSSH refuses
# a private key with NTFS-loose permissions, and an /mnt/c path can't be
# chmod'd to satisfy it. Windows stays canonical - re-run this after adding a
# new Windows key and it picks it up.
#
# Deliberately NOT wired into bootstrap: importing arbitrary existing keys
# is a bigger action than generating a fresh one, and this directory may
# contain keys for unrelated purposes (e.g. a cloud VM access key) that
# should not be silently swept in without you looking at what's there.

if ! command -v cmd.exe >/dev/null 2>&1; then
  echo "ERROR: Windows interoperability is unavailable." >&2
  exit 1
fi

WIN_HOME_WIN="$(cmd.exe /d /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')"
if [[ -z "$WIN_HOME_WIN" || "$WIN_HOME_WIN" == "%USERPROFILE%" ]]; then
  echo "ERROR: Unable to determine Windows USERPROFILE." >&2
  exit 1
fi
WIN_SSH="$(wslpath -u "$WIN_HOME_WIN")/.ssh"

if [[ ! -d "$WIN_SSH" ]]; then
  echo "No Windows ~/.ssh directory found ($WIN_SSH) - nothing to import." >&2
  exit 0
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

imported=()
for pub in "$WIN_SSH"/*.pub; do
  [[ -e "$pub" ]] || continue
  name="$(basename "$pub" .pub)"
  priv="$WIN_SSH/$name"
  [[ -f "$priv" ]] || continue  # a .pub with no matching private key isn't a usable identity

  cp "$priv" "$HOME/.ssh/$name"
  cp "$pub" "$HOME/.ssh/$name.pub"
  chmod 600 "$HOME/.ssh/$name"
  chmod 644 "$HOME/.ssh/$name.pub"
  imported+=("$name")
done

if [[ "${#imported[@]}" -eq 0 ]]; then
  echo "No private/public key pairs found under $WIN_SSH."
  exit 0
fi

echo "Imported ${#imported[@]} key pair(s) from Windows:"
for name in "${imported[@]}"; do
  echo "  ~/.ssh/$name"
  ssh-keygen -lf "$HOME/.ssh/$name.pub"
done

echo ""
echo "These are copies - Windows stays canonical. Re-run this script after adding a"
echo "new Windows key to pick it up here too."
echo ""
echo "Add or update Host blocks in ~/.ssh/config yourself to point the right host at"
echo "the right key (IdentityFile ~/.ssh/<name>, IdentitiesOnly yes) - this script"
echo "does not guess which key belongs to which Git host or service."
