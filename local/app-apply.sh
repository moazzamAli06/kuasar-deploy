#!/usr/bin/env bash
# Registers the deploy repo with Argo CD and applies the project + the local Application.
# The repository is private: set GITHUB_USER and GITHUB_TOKEN (read-only, "Contents: Read-only" on kuasar-deploy),
# or run interactively and type them (the token is hidden). Set REPO_PUBLIC=1 to skip credentials.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
use_context
if [ "${REPO_PUBLIC:-0}" != 1 ]; then
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    [ -t 0 ] || die "GITHUB_TOKEN is not set and there is no terminal to ask on"
    read -r -s -p "GitHub read-only token for kuasar-deploy (input hidden): " GITHUB_TOKEN; echo
  fi
  GITHUB_USER="${GITHUB_USER:-x-access-token}"   # any non-empty name works with a token
  kubectl -n argocd create secret generic repo-kuasar-deploy \
    --from-literal=type=git --from-literal=url="$DEPLOY_REPO_URL" \
    --from-literal=username="$GITHUB_USER" --from-literal=password="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n argocd label secret repo-kuasar-deploy argocd.argoproj.io/secret-type=repository --overwrite >/dev/null
fi
# apply from the checked-out repo, but follow the branch from versions.env
kubectl apply -f "$LOCAL_DIR/../argocd/project.yaml" >/dev/null
sed -e "s|targetRevision: .*|targetRevision: ${DEPLOY_BRANCH}|" "$LOCAL_DIR/../argocd/local-application.yaml" | kubectl apply -f - >/dev/null
say "Application kuasar-local applied (follows branch '$DEPLOY_BRANCH')"
