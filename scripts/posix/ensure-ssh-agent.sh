#!/usr/bin/env bash
set -uo pipefail

# Ensures a persistent ssh-agent is listening at a FIXED socket path
# ($HOME/.ssh/agent.sock), and that the company identities are loaded into it.
#
# Every governed Dev Container (this repo's own templates, plus adopted
# projects like wiocchub-api/wiocchub-app) mounts this exact socket path and
# forwards it in as SSH_AUTH_SOCK - never a direct mount of the private key
# file itself. A container can ask the agent to sign a challenge, but can
# never read the key material back out through the socket, so a compromised
# container (malicious dependency, container escape) cannot exfiltrate the
# key for reuse elsewhere.
#
# The fixed path matters as much as the agent itself: "ssh-agent" with no
# "-a" picks a new random /tmp/ssh-*/agent.<pid> socket every time it starts,
# which a devcontainer.json mount can't reference. Non-interactive
# invocations (this repo's own project-open.sh among them) also can't rely
# on $SSH_AUTH_SOCK being set by ~/.bashrc, so devcontainer.json's mount
# targets this fixed path directly instead of ${localEnv:SSH_AUTH_SOCK}.
#
# Deliberately loads ONLY company-purposed identities - this agent's socket
# gets forwarded into every Dev Container project-open.sh opens, and an
# agent signs with whatever's loaded into it. Never add a personal key here
# (e.g. ~/.ssh/id_rsa_iskarioti): it would become usable from inside every
# governed company/platform project's container, not just the ones that
# should have it.
#
# The list below matches ~/.ssh/config's Host blocks for company git hosts
# as of 2026-08-30: "id_ed25519_company" (github-company) and "id_rsa"
# (ssh.dev.azure.com - what wiocchub-api/wiocchub-app actually clone/push
# through). Check ~/.ssh/config yourself before trusting this list blindly -
# it's not derived from it automatically, same as import-windows-ssh-keys.sh
# never guesses which key belongs to which host either. Add a key's basename
# here if you configure a new company git host with its own identity.

SOCK="$HOME/.ssh/agent.sock"
COMPANY_KEYS=(id_ed25519_company id_rsa)

agent_listening() {
  SSH_AUTH_SOCK="$SOCK" ssh-add -l >/dev/null 2>&1
  # exit code 2 means "can't connect to the agent" - 0 (has keys) and 1 (no
  # keys loaded yet) both mean a live agent is listening.
  [[ $? -ne 2 ]]
}

if ! agent_listening; then
  rm -f "$SOCK"
  ssh-agent -a "$SOCK" >/dev/null
fi

loaded="$(SSH_AUTH_SOCK="$SOCK" ssh-add -l 2>/dev/null | awk '{print $2}')"
for name in "${COMPANY_KEYS[@]}"; do
  key="$HOME/.ssh/$name"
  [[ -f "$key" && -f "$key.pub" ]] || continue
  fingerprint="$(ssh-keygen -lf "$key.pub" 2>/dev/null | awk '{print $2}')"
  [[ -n "$fingerprint" ]] || continue
  grep -qxF "$fingerprint" <<<"$loaded" && continue
  # Non-fatal: a passphrase-protected key can't be added without a TTY/
  # askpass helper. If this fails silently here, add it yourself once per
  # WSL session: SSH_AUTH_SOCK="$HOME/.ssh/agent.sock" ssh-add ~/.ssh/<name>
  SSH_AUTH_SOCK="$SOCK" ssh-add "$key" >/dev/null 2>&1 || true
done
