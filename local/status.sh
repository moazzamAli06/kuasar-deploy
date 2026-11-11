#!/usr/bin/env bash
# Plain overview: is the cluster up, what is Argo CD doing, which pods are not ready and why.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME" || die "no local cluster. Start with local/bootstrap.sh"
use_context
say "Argo CD application"
kubectl -n argocd get application kuasar-local -o jsonpath='sync={.status.sync.status} health={.status.health.status} revision={.status.sync.revision}{"\n"}' 2>/dev/null || warn "application not found"
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
