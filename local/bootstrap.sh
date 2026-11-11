#!/usr/bin/env bash
# One command: checks the machine, creates the local cluster, installs Argo CD, creates the secrets and starts the app.
#   local/bootstrap.sh               interactive (asks for the GitHub token, hidden)
#   local/bootstrap.sh --check       only check this machine, change nothing
# Non-interactive: GITHUB_USER, GITHUB_TOKEN (or REPO_PUBLIC=1) in the environment. SYNC_TIMEOUT_MIN (default 30).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

preflight || die "Fix the points above and run again. Nothing was changed."
[ "${1:-}" = "--check" ] && { say "This machine is ready."; exit 0; }

"$LOCAL_DIR/cluster-up.sh"
"$LOCAL_DIR/argocd-install.sh"
"$LOCAL_DIR/secrets.sh"
"$LOCAL_DIR/app-apply.sh"

say "Waiting for Argo CD to deploy the app (first run: image pulls and migrations take 5 to 15 minutes)"
deadline=$(( $(date +%s) + ${SYNC_TIMEOUT_MIN:-30} * 60 ))
last=""
while :; do
  sync=$(kubectl -n argocd get application kuasar-local -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
  health=$(kubectl -n argocd get application kuasar-local -o jsonpath='{.status.health.status}' 2>/dev/null || true)
  ready=$(kubectl -n "$NAMESPACE" get pods --no-headers 2>/dev/null | awk '$3=="Running"||$3=="Completed"{n++} END{print n+0}')
  total=$(kubectl -n "$NAMESPACE" get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')
  line="sync=${sync:-?} health=${health:-?} pods running/finished ${ready}/${total}"
  [ "$line" = "$last" ] || { echo "   $line"; last=$line; }
  if [ "$sync" = Synced ] && [ "$health" = Healthy ]; then break; fi
  if [ "$(date +%s)" -gt "$deadline" ]; then
    warn "Not healthy after ${SYNC_TIMEOUT_MIN:-30} minutes. Run local/status.sh to see what is waiting."
    exit 2
  fi
  sleep 15
done

say "Done"
echo "  App:            http://localhost:${EDGE_PORT}        Marketing: http://localhost:${MARKETING_PORT}"
echo "  Argo CD UI:     kubectl -n argocd port-forward svc/argocd-server ${ARGO_PORT}:443   then https://localhost:${ARGO_PORT}"
echo "  Argo user:      admin   password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "  Status anytime: local/status.sh      Remove everything: local/cluster-down.sh"
