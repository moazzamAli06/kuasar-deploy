#!/usr/bin/env bash
# Linux / WSL2 only: installs kubectl and kind (pinned in versions.env) into ~/.local/bin. No sudo needed.
# macOS: use "brew install kind kubectl" instead (docs/LOCAL-MACOS.md).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
[ "$(uname -s)" = Linux ] || die "this script is for Linux/WSL2; on macOS use: brew install kind kubectl"
arch=$(arch_name); [ "$arch" != other ] || die "unsupported CPU architecture"
bin="$HOME/.local/bin"; mkdir -p "$bin"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

say "kubectl $KUBECTL_VERSION"
curl -fsSL -o "$tmp/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl"
curl -fsSL -o "$tmp/kubectl.sha256" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl.sha256"
echo "$(cat "$tmp/kubectl.sha256")  $tmp/kubectl" | sha256sum -c - >/dev/null || die "kubectl checksum mismatch"
install -m 0755 "$tmp/kubectl" "$bin/kubectl"

say "kind $KIND_VERSION"
curl -fsSL -o "$tmp/kind" "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${arch}"
curl -fsSL -o "$tmp/kind.sha256" "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${arch}.sha256sum"
( cd "$tmp" && echo "$(awk '{print $1}' kind.sha256)  kind" | sha256sum -c - >/dev/null ) || die "kind checksum mismatch"
install -m 0755 "$tmp/kind" "$bin/kind"

case ":$PATH:" in *":$bin:"*) ;; *) warn "add this line to ~/.bashrc, then open a new terminal:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;; esac
"$bin/kubectl" version --client | head -1; "$bin/kind" version
