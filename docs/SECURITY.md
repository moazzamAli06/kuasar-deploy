# Security controls

| Layer | Control | Where | Status |
|---|---|---|---|
| Pods | non-root, read-only root filesystem, no privilege escalation, capabilities dropped, seccomp, limits and requests | `base/`, checked in CI by `tools/check-policies.py` | enforced in CI |
| Images | pinned by digest, including third-party images | `overlays/*/kustomization.yaml`, CI, Renovate | enforced in CI |
| Network | default-deny NetworkPolicies, explicit allows | `base/network-policies` | needs a cluster that enforces them (EKS VPC CNI policy mode, GKE Dataplane V2, AKS Cilium: set up by `infra/`; locally `NETWORK_POLICY=1`) |
| Namespaces | Pod Security Admission: `enforce: baseline`, `audit` and `warn: restricted` | `argocd/applicationset.yaml` (`managedNamespaceMetadata`) | applied on the next sync of staging/production |
| Admission | image digest required, image signatures verified | `platform/kyverno-policies` (Kyverno) | **Audit mode**, optional add-on |
| Secrets | Sealed Secrets, or the cloud secret manager through External Secrets | `docs/SECRETS.md`, `components/external-secrets` | no plain Secret in Git (CI + gitleaks) |
| Supply chain | Actions pinned by SHA, kubeconform checksum verified, least-privilege workflow permissions | `.github/workflows` | done |
| Access | release managers may sync production | `argocd/project.yaml` | set the real group (`REPLACE_ORG:release-managers`) |

## Turning on admission policies
1. Install the add-ons: `kubectl apply -n argocd -f argocd/addons-optional.yaml` (or just the `kyverno` and `kyverno-policies` documents).
2. Look at the reports for a few days: `kubectl get policyreport,clusterpolicyreport -A`. Operator-created pods (RabbitMQ) may report missing digests.
3. For signature verification, confirm how the app repository's CI signs images and fix the `keyless` issuer and subject in `platform/kyverno-policies/verify-images.yaml` (they are placeholders). Test with one staging pod.
4. Switch `validationFailureAction` to `Enforce` per policy, adding `exclude` rules for what you cannot control.

## Tightening Pod Security
Move `enforce` from `baseline` to `restricted` once `kubectl get events -n kuasar-staging | grep PodSecurity` shows no warnings (the RabbitMQ operator's pods are the likely reason it is `baseline` today).

## Secret manager instead of Sealed Secrets
See `components/external-secrets/kustomization.yaml` (how to use it), `platform/external-secrets/stores/` (a `ClusterSecretStore` per cloud) and `argocd/addons-optional.yaml` (the operator). Remote secrets are named `kuasar/<env>/<secret name>`; the value is a JSON object with the keys listed in [SECRETS.md](SECRETS.md). Remove `- sealed` from the overlay when you switch.
