#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/labs/toolchain.env"

BIN="$HOME/.local/bin"
mkdir -p "$BIN"

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64)
    KARCH=amd64
    ;;
  aarch64|arm64)
    KARCH=arm64
    ;;
  *)
    echo "ERROR: unsupported architecture: $arch" >&2
    exit 2
    ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

install_kubectl() {
  local version="${KUBECTL_VERSION#v}"
  local url="https://dl.k8s.io/release/v${version}/bin/linux/${KARCH}/kubectl"
  echo "Installing kubectl v${version}..."
  curl --fail --location --retry 3 "$url" -o "$tmp/kubectl"
  curl --fail --location --retry 3 "$url.sha256" -o "$tmp/kubectl.sha256"
  printf '%s  %s\n' "$(cat "$tmp/kubectl.sha256")" "$tmp/kubectl" | sha256sum -c -
  cp -f "$tmp/kubectl" "$BIN/kubectl"
  chmod +x "$BIN/kubectl"
}

install_helm() {
  local archive="helm-${HELM_VERSION}-linux-${KARCH}.tar.gz"
  local url="https://get.helm.sh/${archive}"
  echo "Installing Helm ${HELM_VERSION}..."
  curl --fail --location --retry 3 "$url" -o "$tmp/$archive"
  curl --fail --location --retry 3 "$url.sha256sum" -o "$tmp/$archive.sha256sum"
  (
    cd "$tmp"
    sha256sum -c "$archive.sha256sum"
  )
  tar -xzf "$tmp/$archive" -C "$tmp"
  cp -f "$tmp/linux-${KARCH}/helm" "$BIN/helm"
  chmod +x "$BIN/helm"
}

install_k3d() {
  local binary="k3d-linux-${KARCH}"
  local url="https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/${binary}"
  echo "Installing k3d ${K3D_VERSION}..."
  curl --fail --location --retry 3 "$url" -o "$tmp/k3d"
  curl --fail --location --retry 3 \
    "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/checksums.txt" \
    -o "$tmp/k3d-checksums.txt"
  expected="$(awk -v n="$binary" '$2 == n {print $1}' "$tmp/k3d-checksums.txt" | head -n1)"
  [[ -n "$expected" ]] || {
    echo "ERROR: k3d checksum entry not found." >&2
    exit 3
  }
  printf '%s  %s\n' "$expected" "$tmp/k3d" | sha256sum -c -
  cp -f "$tmp/k3d" "$BIN/k3d"
  chmod +x "$BIN/k3d"
}

install_kubectl
install_helm
install_k3d

echo "Lab toolchain installation complete."
"$BIN/kubectl" version --client 2>/dev/null || true
"$BIN/helm" version --short 2>/dev/null || true
"$BIN/k3d" version 2>/dev/null | head -n2 || true
