#!/usr/bin/env bash
# Installs Argo CD (pinned version) into the local cluster.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
use_context
kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd
say "Argo CD $ARGOCD_VERSION"
kubectl apply -n argocd --server-side --force-conflicts -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" >/dev/null
# Argo CD 3 hides EndpointSlice by default; this repo manages one (sandbox host), so override resource.exclusions
kubectl apply --server-side --force-conflicts -f "$LOCAL_DIR/../argocd/argocd-cm-overrides.yaml" >/dev/null
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
