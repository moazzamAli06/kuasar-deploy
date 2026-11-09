#!/usr/bin/env bash
# Seal plain Kubernetes Secret files so they can be committed.
#   tools/seal-secrets.sh staging secrets-plain/staging/*.yaml
# Plain files live ONLY in secrets-plain/ (git-ignored). The sealed output goes to overlays/<env>/sealed/ and is safe to commit.
# Needs: kubeseal, and kubectl pointed at the cluster where the Sealed Secrets controller runs.
set -euo pipefail
env="${1:?environment (staging|production)}"; shift
ns="kuasar-${env}"
for f in "$@"; do
  name="$(basename "$f")"
  kubeseal --format yaml --namespace "$ns" --controller-name sealed-secrets --controller-namespace sealed-secrets < "$f" > "overlays/${env}/sealed/${name}"
  echo "sealed ${name}  (add '- ${name}' to overlays/${env}/sealed/kustomization.yaml)"
done
