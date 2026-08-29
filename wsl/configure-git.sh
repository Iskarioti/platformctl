#!/usr/bin/env bash
set -euo pipefail

# Idempotent by design (AGENTS.md rule 9): re-running this must not
# re-prompt or hang. If a name/email is already configured (set by hand, or
# by an earlier run of this script), it's left untouched.
EXISTING_NAME="$(git config --global user.name || true)"
EXISTING_EMAIL="$(git config --global user.email || true)"

if [[ -n "$EXISTING_NAME" && -n "$EXISTING_EMAIL" ]]; then
  echo "Git identity already configured: $EXISTING_NAME <$EXISTING_EMAIL>"
elif [[ -t 0 ]]; then
  read -r -p "Git display name: " GIT_NAME
  read -r -p "Git email: " GIT_EMAIL
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
else
  echo "WARNING: git user.name/user.email are not set and this is not an interactive" >&2
  echo "session (e.g. running from bootstrap) - skipping. Run this script directly" >&2
  echo "yourself, or 'git config --global user.name/user.email' by hand." >&2
fi

git config --global init.defaultBranch main
git config --global pull.ff only
git config --global fetch.prune true
git config --global core.autocrlf input
git config --global rerere.enabled true
git config --global diff.algorithm histogram

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ ! -f "$HOME/.ssh/id_ed25519_company" ]]; then
  ssh-keygen -t ed25519 -a 64 -f "$HOME/.ssh/id_ed25519_company" \
    -C "$GIT_EMAIL"
fi

cat > "$HOME/.ssh/config" <<'EOF'
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
EOF
chmod 600 "$HOME/.ssh/config"

echo
echo "Public key:"
cat "$HOME/.ssh/id_ed25519_company.pub"
echo
echo "Add this public key to the approved Git provider."
