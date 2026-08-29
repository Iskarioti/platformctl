#!/usr/bin/env bash
set -euo pipefail
STATE="${1:?state directory required}"
mkdir -p "$STATE/certs"
chmod 700 "$STATE" "$STATE/certs"

if [[ ! -f "$STATE/.env" ]]; then
  umask 077
  printf 'REDIS_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 24)" > "$STATE/.env"
fi

# shellcheck disable=SC1090
source "$STATE/.env"

if [[ ! -f "$STATE/certs/ca.crt" ]]; then
  openssl req -x509 -newkey rsa:3072 -sha256 -days 30 -nodes \
    -subj "/CN=platformctl-lab-ca" \
    -keyout "$STATE/certs/ca.key" \
    -out "$STATE/certs/ca.crt" >/dev/null 2>&1

  openssl req -newkey rsa:3072 -nodes \
    -subj "/CN=redis-security" \
    -keyout "$STATE/certs/server.key" \
    -out "$STATE/certs/server.csr" >/dev/null 2>&1

  cat > "$STATE/certs/server.ext" <<'EOF'
subjectAltName=DNS:redis-security,DNS:dev-redis-security,DNS:localhost,IP:127.0.0.1
extendedKeyUsage=serverAuth
EOF

  openssl x509 -req -sha256 -days 30 \
    -in "$STATE/certs/server.csr" \
    -CA "$STATE/certs/ca.crt" \
    -CAkey "$STATE/certs/ca.key" \
    -CAcreateserial \
    -extfile "$STATE/certs/server.ext" \
    -out "$STATE/certs/server.crt" >/dev/null 2>&1

  openssl req -newkey rsa:3072 -nodes \
    -subj "/CN=platformctl-client" \
    -keyout "$STATE/certs/client.key" \
    -out "$STATE/certs/client.csr" >/dev/null 2>&1

  printf 'extendedKeyUsage=clientAuth\n' > "$STATE/certs/client.ext"

  openssl x509 -req -sha256 -days 30 \
    -in "$STATE/certs/client.csr" \
    -CA "$STATE/certs/ca.crt" \
    -CAkey "$STATE/certs/ca.key" \
    -CAcreateserial \
    -extfile "$STATE/certs/client.ext" \
    -out "$STATE/certs/client.crt" >/dev/null 2>&1
fi

printf 'user default off\nuser admin on >%s ~* +@all\n' "$REDIS_ADMIN_PASSWORD" > "$STATE/users.acl"
chmod 600 "$STATE/.env" "$STATE/users.acl" "$STATE/certs/"*.key
