# kuasar-deploy

Kubernetes manifests and Argo CD definitions for Kuasar AI. **No application code lives here.** Argo CD watches this repo; the app repo's CI only opens pull requests that change image digests.

Plan and background: `kuasarai/docs/operations/cicd-kubernetes-argocd-plan.md` and `production-kubernetes-argocd.md`.

```
base/            one folder per workload (Deployment, Service, migration Job) + network policies, RabbitMQ, cloudflared
overlays/
  staging/       namespace kuasar-staging, auto-sync. Image digests, URLs, replicas.
  production/    namespace kuasar-production, manual sync. 2 replicas, PodDisruptionBudgets, 3-node RabbitMQ.
  */sealed/      encrypted secrets (SealedSecret), committed
argocd/          AppProject, ApplicationSet (staging + production), add-ons (Sealed Secrets, RabbitMQ operator)
platform/        cluster add-on manifests
tools/           set-digest.py, promote.py, seal-secrets.sh, check-policies.py
docs/SECRETS.md  every secret and key each environment needs
docs/SANDBOX-HOST.md  the separate gVisor machine that runs customer code
```

## Before the first deploy (checklist)
1. Docker Hub org is `moazzamali06`; GitHub owner is `moazzamAli06`. Still to set: `REPLACE_ORG:release-managers` in `argocd/project.yaml` (an SSO group; a personal GitHub account has no teams, so use an Argo CD user or group name).
2. Fill the placeholders in the overlays: public URLs, preview domain, `Sandbox__DockerEndpoint` (the sandbox Droplet).
3. Create the DOKS cluster, install Argo CD, apply `argocd/addons.yaml` (Sealed Secrets, RabbitMQ operator). Verify the pinned versions in those files are current.
4. Create and seal every secret in `docs/SECRETS.md`, put the files under `overlays/<env>/sealed/` and list them in its `kustomization.yaml`. Create `rabbitmq-default-user` first.
5. Apply `argocd/project.yaml` and `argocd/applicationset.yaml`.

## How a release flows
1. App repo CI builds, scans and signs images, then opens a PR here that sets new digests in `overlays/staging` (`tools/set-digest.py`). Merge it: Argo CD deploys staging.
2. Run the app repo's **promote** workflow: it opens a PR copying staging's digests to `overlays/production` (`tools/promote.py`). Review, merge, then press Sync on `kuasar-production`.
3. Roll back by reverting the digest commit (or `argocd app rollback`).

Order inside a sync: wave 0 config, secrets, Services, volumes, RabbitMQ; wave 1 migration Jobs (each uses its own database owner login); wave 2 services; wave 3 gateways and web; wave 4 cloudflared. The Jobs are Argo "Sync" hooks in wave 1, not PreSync, because PreSync would run before the ConfigMaps and Secrets they need exist.

## Rules
- Never `kubectl edit` a running environment; change Git.
- No plain `Secret` in Git. `tools/check-policies.py` and gitleaks enforce it in CI.
- Images are referenced by digest only. The all-zero digests in the overlays are placeholders and cannot be pulled until CI replaces them.
