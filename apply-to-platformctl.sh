#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-}"
[[ -n "$ROOT" ]] || {
  echo "Usage: $0 /path/to/platformctl" >&2
  exit 2
}

ROOT="$(cd "$ROOT" && pwd)"
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$PKG/overlay"

[[ -f "$ROOT/setup.ps1" ]] || {
  echo "ERROR: not a platformctl repository: $ROOT" >&2
  exit 2
}

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$ROOT/.state/modular-services-labs-backup-$STAMP"
mkdir -p "$BACKUP"

backup_file() {
  local rel="$1"
  local src="$ROOT/$rel"
  local dst="$BACKUP/$rel"
  [[ -f "$src" ]] || return 0
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
}

for rel in \
  development/services/compose.yaml \
  development/services/versions.env \
  development/services/.env.example \
  scripts/posix/services.sh \
  scripts/ci/validate.ps1 \
  policy/development.json \
  schema/development-policy.schema.json \
  setup \
  setup.ps1 \
  scripts/posix/workstation.sh \
  platform/linux/bootstrap.sh; do
  backup_file "$rel"
done

echo "=== Installing platformctl v3.5.1 ==="

while IFS= read -r -d '' src; do
  rel="${src#"$OVERLAY/"}"
  dst="$ROOT/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
done < <(find "$OVERLAY" -type f -print0)

rm -f \
  "$ROOT/development/services/compose.yaml" \
  "$ROOT/development/services/versions.env" \
  "$ROOT/development/services/.env.example"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import json
import sys

root = Path(sys.argv[1])

policy_path = root / "policy/development.json"
policy = json.loads(policy_path.read_text(encoding="utf-8"))
policy["version"] = "1.2.1"

ds = policy["developmentServices"]
ds["catalog"] = "development/catalog.json"
ds["credentialsFile"] = "~/.config/workstation/services"
ds["allowedServices"] = [
    "postgres","pgbouncer","pgadmin",
    "redis","redisinsight",
    "kafka","kafbat-ui",
    "opensearch","opensearch-dashboards",
    "rabbitmq","mongodb","minio","mailpit","dev-dashboard",
]
ds["profiles"] = {
    "core": ["postgres","redis"],
    "messaging": ["kafka","rabbitmq"],
    "search": ["opensearch"],
    "data": ["postgres","pgbouncer","mongodb"],
    "integration": ["minio","mailpit"],
    "ui": ["dev-dashboard","pgadmin","redisinsight","kafbat-ui","opensearch-dashboards"],
    "all": [
        "postgres","pgbouncer","pgadmin",
        "redis","redisinsight",
        "kafka","kafbat-ui",
        "opensearch","opensearch-dashboards",
        "rabbitmq","mongodb","minio","mailpit","dev-dashboard",
    ],
}

policy["labs"] = {
    "enabled": True,
    "catalog": "labs/catalog.json",
    "stateRoot": "~/.local/state/platformctl/labs",
    "defaultRuntime": "docker",
    "kubernetesProvider": "k3d",
    "kubernetesCluster": "platform-labs",
    "productionPromotion": "iac-only",
}

policy_path.write_text(json.dumps(policy, indent=2) + "\n", encoding="utf-8")

schema_path = root / "schema/development-policy.schema.json"
schema = json.loads(schema_path.read_text(encoding="utf-8"))
required = schema.setdefault("required", [])
if "labs" not in required:
    required.append("labs")

schema.setdefault("properties", {})["labs"] = {
    "type": "object",
    "required": [
        "enabled","catalog","stateRoot","defaultRuntime",
        "kubernetesProvider","kubernetesCluster","productionPromotion"
    ],
    "properties": {
        "enabled": {"type": "boolean"},
        "catalog": {"type": "string"},
        "stateRoot": {"type": "string"},
        "defaultRuntime": {"type": "string", "enum": ["docker","kubernetes"]},
        "kubernetesProvider": {"type": "string"},
        "kubernetesCluster": {"type": "string"},
        "productionPromotion": {"type": "string"},
    },
}
schema_path.write_text(json.dumps(schema, indent=2) + "\n", encoding="utf-8")

p = root / "setup"
text = p.read_text(encoding="utf-8")
old = "validate|doctor|enforce|project|services|editor|sync|publish|autosync|update|dry-run|help)"
new = "validate|doctor|enforce|project|services|lab|editor|sync|publish|autosync|update|dry-run|help)"
if new not in text:
    if old not in text:
        raise SystemExit("ERROR: could not patch setup command list")
    text = text.replace(old, new, 1)
p.write_text(text, encoding="utf-8")

p = root / "scripts/posix/workstation.sh"
text = p.read_text(encoding="utf-8")
lab_case = '  lab) exec "$ROOT/scripts/posix/labs.sh" "$@" ;;'
if lab_case not in text:
    anchor = '  services) exec "$ROOT/scripts/posix/services.sh" "$@" ;;'
    if anchor not in text:
        raise SystemExit("ERROR: services dispatcher not found")
    text = text.replace(anchor, anchor + "\n" + lab_case, 1)

help_line = "  lab list|info|toolchain|cluster|up|status|logs|test|stop|destroy|report\n"
if help_line not in text:
    anchor = "  services reset <service> [--yes]\n"
    if anchor not in text:
        raise SystemExit("ERROR: services help anchor not found")
    text = text.replace(anchor, anchor + help_line, 1)
p.write_text(text, encoding="utf-8")

p = root / "setup.ps1"
text = p.read_text(encoding="utf-8")
lab_block = '''    "lab" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "scripts\\common\\labs.ps1" -Arguments @($Rest)
        } else {
            & bash (Join-Path $Root "scripts/posix/labs.sh") @Rest
            exit $LASTEXITCODE
        }
    }

'''
if '"lab" {' not in text:
    anchor = '    "editor" {'
    if anchor not in text:
        raise SystemExit("ERROR: editor dispatcher not found in setup.ps1")
    text = text.replace(anchor, lab_block + anchor, 1)

help_line = "  lab list|info|toolchain|up|test  run isolated Docker/Kubernetes architecture labs\n"
if help_line not in text:
    anchor = "  services down                     stop catalog containers, preserve data\n"
    if anchor not in text:
        raise SystemExit("ERROR: services help anchor not found in setup.ps1")
    text = text.replace(anchor, anchor + help_line, 1)
p.write_text(text, encoding="utf-8")

p = root / "platform/linux/bootstrap.sh"
text = p.read_text(encoding="utf-8")
if "NO_LAB_TOOLS=0" not in text:
    text = text.replace("NO_AUTOSYNC=0", "NO_AUTOSYNC=0\nNO_LAB_TOOLS=0", 1)

arg_line = '  [[ "$arg" == "--no-autosync" ]] && NO_AUTOSYNC=1'
if '--no-lab-tools' not in text:
    if arg_line not in text:
        raise SystemExit("ERROR: bootstrap argument anchor not found")
    text = text.replace(
        arg_line,
        arg_line + '\n  [[ "$arg" == "--no-lab-tools" ]] && NO_LAB_TOOLS=1',
        1,
    )

if "install-lab-toolchain.sh" not in text:
    anchor = '"$ROOT/platform/linux/install-docker.sh"'
    insert = '''"$ROOT/platform/linux/install-docker.sh"

if [[ "$NO_LAB_TOOLS" -eq 0 ]]; then
  "$ROOT/scripts/posix/install-lab-toolchain.sh"
fi'''
    if anchor not in text:
        raise SystemExit("ERROR: Docker bootstrap anchor not found")
    text = text.replace(anchor, insert, 1)

p.write_text(text, encoding="utf-8")
PY

chmod +x \
  "$ROOT/setup" \
  "$ROOT/scripts/posix/workstation.sh" \
  "$ROOT/scripts/posix/services.sh" \
  "$ROOT/scripts/posix/labs.sh" \
  "$ROOT/scripts/posix/install-lab-toolchain.sh"

find "$ROOT/labs" -type f -name '*.sh' -exec chmod +x {} +

echo "Validating shell syntax..."
bash -n "$ROOT/setup"
bash -n "$ROOT/scripts/posix/workstation.sh"
bash -n "$ROOT/scripts/posix/services.sh"
bash -n "$ROOT/scripts/posix/labs.sh"
bash -n "$ROOT/scripts/posix/install-lab-toolchain.sh"

echo "Validating JSON syntax..."
python3 -m json.tool "$ROOT/development/catalog.json" >/dev/null
python3 -m json.tool "$ROOT/labs/catalog.json" >/dev/null
python3 -m json.tool "$ROOT/policy/development.json" >/dev/null
python3 -m json.tool "$ROOT/schema/development-policy.schema.json" >/dev/null

echo
echo "platformctl v3.5.1 applied successfully."
echo "Backup: $BACKUP"
echo
echo "Next:"
echo '  pwsh.exe -NoLogo -NoProfile -File ./setup.ps1 validate'
echo '  workstation services list'
echo '  workstation lab list'
