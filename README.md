# kuasar-deploy

Kubernetes manifests and Argo CD definitions for Kuasar AI. **No application code lives here.** Argo CD watches this repo; the app repo's CI only opens pull requests that change image digests.

Start at [docs/README.md](docs/README.md). Design: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

```
base/            cloud-neutral: one folder per workload (Deployment, Service, migration Job) + network policies, RabbitMQ, cloudflared
components/      cloud-do, cloud-aws, cloud-gcp, cloud-azure, cloud-kind: storage class and database port per cloud
overlays/
  staging/       namespace kuasar-staging, auto-sync. Image digests, URLs, replicas.
  production/    namespace kuasar-production, manual sync. 2 replicas, PodDisruptionBudgets, 3-node RabbitMQ.
  local/         namespace kuasar-local, for laptops (kind): in-cluster Postgres, NodePorts, small requests, Docker Hub digests copied from staging.
  local-registry/  developer variant of local: images from a local registry (per-machine digests)
  */sealed/      encrypted secrets (SealedSecret), committed
argocd/          AppProject, ApplicationSet (staging + production), add-ons (Sealed Secrets, RabbitMQ operator), local-application.yaml (local environment)
platform/        cluster add-on manifests
local/           one-command local run: get.sh (download, no clone), bootstrap.sh, status.sh, secrets.sh, versions.env, ports.env ...
tools/           set-digest.py, promote.py, seal-secrets.sh, check-policies.py, gen-secrets.py (docs/SECRETS.md and ExternalSecrets from secrets/catalog.yaml), check-local-secrets.py (local/secrets.sh matches the catalog)
.github/workflows/  check.yml (render + policy + secret scan), sync-local.yml (keeps branch "local"), smoke.yml (kind end-to-end, manual/weekly)
infra/           OpenTofu per cloud: cluster, network, managed PostgreSQL, sandbox host (not yet applied anywhere: see infra/README.md)
components/      (see above) plus opt-in: external-secrets, observability, alerts, autoscaling, ingress
docs/            index in docs/README.md: architecture, local guides, per-cloud guides, release runbook, secrets, sandbox host
renovate.json    keeps pinned versions and digests current
```

## Run it on a laptop (macOS, Linux, Windows with WSL2)
Argo CD in a local kind cluster follows branch `local` of this repo (main plus the staging digests, maintained by `sync-local.yml`). No clone is needed; see `docs/LOCAL.md` for the one-command start (`local/get.sh`). Branch `local` is generated: never commit to it.

## Deploy it
| Where | Guide |
|---|---|
| Laptop: macOS, Linux, Windows (WSL2) | [docs/LOCAL.md](docs/LOCAL.md) |
| DigitalOcean (DOKS) | [docs/clouds/digitalocean.md](docs/clouds/digitalocean.md) |
| AWS (EKS) | [docs/clouds/aws.md](docs/clouds/aws.md) |
| Google Cloud (GKE) | [docs/clouds/gcp.md](docs/clouds/gcp.md) |
| Azure (AKS) | [docs/clouds/azure.md](docs/clouds/azure.md) |

Every cloud follows the same steps: create the cluster, install Argo CD and the add-ons, create the secrets ([docs/SECRETS.md](docs/SECRETS.md)), pick the overlay plus the cloud component, apply `argocd/project.yaml` and `argocd/applicationset.yaml`. Day-to-day releases: [docs/RELEASE-AND-ROLLBACK.md](docs/RELEASE-AND-ROLLBACK.md).

Open items before the first production deploy: `REPLACE_ORG:release-managers` in `argocd/project.yaml` (an SSO group, or an Argo CD user or group name; a personal GitHub account has no teams), and the placeholders in the overlays (public URLs, sandbox host address, VPC range).

## Rules
- Never `kubectl edit` a running environment; change Git.
- No plain `Secret` in Git. `tools/check-policies.py` and gitleaks enforce it in CI.
- Images are referenced by digest only (the multi-arch manifest-list digest, so one digest serves amd64 and arm64). Zero digests are placeholders and cannot be pulled; CI replaces them.
- Local secrets are plain Secrets created by `local/secrets.sh` on the machine; they never enter Git (`local/.env.local` is ignored).
