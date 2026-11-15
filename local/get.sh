#!/usr/bin/env bash
# Downloads the local-run scripts from GitHub (no git, no clone) into ~/.kuasar-local and runs bootstrap.
#   read -rs -p "GitHub token: " T; echo; curl -fsSL -H "Authorization: Bearer $T" \
#     https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash -s -- --check
# Arguments are passed to bootstrap.sh (--check = only check this machine). Run it again without --check to install.
# The token is read-only ("Contents: Read-only" on kuasar-deploy), is kept only in the local cluster, and is never written to disk by this script.
set -euo pipefail
REPO=moazzamAli06/kuasar-deploy; REF="${SCRIPTS_REF:-main}"; DEST="${KUASAR_LOCAL_HOME:-$HOME/.kuasar-local}"
for t in curl tar; do command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }; done
if [ -z "${GITHUB_TOKEN:-}" ]; then
  [ -r /dev/tty ] || { echo "set GITHUB_TOKEN (read-only token for $REPO)" >&2; exit 1; }
  printf 'GitHub read-only token for %s (input hidden): ' "$REPO" >/dev/tty
  read -rs GITHUB_TOKEN </dev/tty; echo >/dev/tty
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo "==> Downloading scripts ($REPO@$REF) to $DEST"
curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/tarball/$REF" -o "$tmp/src.tgz" || { echo "download failed: check the token (Contents: Read-only on $REPO)" >&2; exit 1; }
mkdir "$tmp/x" && tar xzf "$tmp/src.tgz" -C "$tmp/x" --strip-components=1
rm -rf "$DEST"; mkdir -p "$DEST"
cp -R "$tmp/x/local" "$tmp/x/argocd" "$DEST/"
chmod +x "$DEST"/local/*.sh
export GITHUB_TOKEN GITHUB_USER="${GITHUB_USER:-x-access-token}"
exec "$DEST/local/bootstrap.sh" "$@"
