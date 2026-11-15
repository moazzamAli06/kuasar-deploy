#!/usr/bin/env bash
# Plain overview: is the cluster up, what is Argo CD doing, which pods are not ready and why.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME" || die "no local cluster. Start with local/bootstrap.sh"
use_context
say "Argo CD application"
sync=$(kubectl -n argocd get application kuasar-local -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
health=$(kubectl -n argocd get application kuasar-local -o jsonpath='{.status.health.status}' 2>/dev/null || true)
rev=$(kubectl -n argocd get application kuasar-local -o jsonpath='{.status.sync.revision}' 2>/dev/null || true)
if [ -z "$sync$health" ]; then
  warn "application not found"
else
  echo "sync=${sync:-?} health=${health:-?} revision=${rev:-?}"
  case "${sync}:${health}" in
    Synced:Healthy) echo "The app is up to date and healthy." ;;
    OutOfSync:Missing) echo "The app is not finished installing. If rabbitmq is not Running yet, wait and run this again. Do not force an update." ;;
    *) echo "Something is still starting or is stuck. The pods below show which one." ;;
  esac
fi
kubectl -n argocd get application kuasar-local -o jsonpath='{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}' 2>/dev/null
say "Pods"
kubectl -n "$NAMESPACE" get pods 2>/dev/null
bad=$(kubectl -n "$NAMESPACE" get pods --no-headers 2>/dev/null | awk '$3!="Running" && $3!="Completed"{print $1}')
for p in $bad; do
  say "Why $p is not running"
  kubectl -n "$NAMESPACE" describe pod "$p" | sed -n '/^Events:/,$p' | tail -8
done
say "Recent warnings"
kubectl -n "$NAMESPACE" get events --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null | tail -8
say "Health check through the gateway"
curl -fsS -m 5 "http://localhost:${EDGE_PORT}/health" >/dev/null 2>&1 && echo "http://localhost:${EDGE_PORT}/health ok" || echo "http://localhost:${EDGE_PORT}/health not answering yet"
