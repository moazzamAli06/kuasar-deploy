# Upgrading the pinned platform versions

Pins live in `local/versions.env` (kind, node image, Argo CD, RabbitMQ operator, Calico, kubectl), `platform/rabbitmq-operator/kustomization.yaml` (same operator version as `versions.env`) and `argocd/addons.yaml` (Sealed Secrets chart). Renovate opens pull requests for them.

## Current set (bumped 2026-11-15)
| Piece | Version | Previous |
|---|---|---|
| kind | v0.33.0 | v0.25.0 |
| Kubernetes node image | v1.36.4 (digest pinned) | v1.31.2 |
| kubectl | v1.36.6 | v1.31.4 |
| Argo CD | v3.6.1 | v2.13.2 |
| RabbitMQ cluster operator | v2.21.0 (not newer, see below) | v2.11.0 |


## Breaking changes that affect this repository
1. **Argo CD 3 hides `EndpointSlice` by default** (`resource.exclusions`). `base/sandbox-host/endpointslice.yaml` is managed on purpose, so without a fix sync is rejected for that resource. `argocd/argocd-cm-overrides.yaml` restores it. `local/argocd-install.sh` applies it; **for a cloud install apply it yourself right after Argo CD**: `kubectl apply --server-side --force-conflicts -f argocd/argocd-cm-overrides.yaml`.
2. **Annotation-based resource tracking** is the default since Argo CD 3.0. A fresh install is unaffected. An existing Argo CD 2.x installation that used labels re-labels on the next sync; check `kubectl get cm argocd-cm -n argocd -o jsonpath='{.data.application\.resourceTrackingMethod}'` first.
3. **Fine-grained RBAC for `update`/`delete` of sub-resources and log access** (3.0): if you define custom policies beyond the `release-manager` role in `argocd/project.yaml`, review them.
4. **SSH repositories use known_hosts** (3.5): the SSH `repoURL`s in `argocd/` rely on GitHub's host key shipped with Argo CD.
5. **The Argo CD kubectl-client-side-apply limit**: the ApplicationSet CRD no longer fits client-side apply (3.3). The scripts and docs already use `--server-side`.

6. **RabbitMQ operator 2.22 and later need cert-manager** (their `cluster-operator.yml` contains `Certificate` and `Issuer` resources for the webhook; without cert-manager the operator pod never starts). 2.21.0 is the newest release without that requirement, so it is pinned, and Renovate is told not to go past it (`renovate.json`). Moving on means installing cert-manager first in `local/cluster-up.sh`, in the cloud guides and in `argocd/addons.yaml`.

## Existing clusters: go one minor at a time
Argo CD supports upgrades from one minor version to the next. For a running production cluster on 2.13: 2.14, then 3.0, 3.1, and so on, reading `docs/operator-manual/upgrading/<from>-<to>.md` in the Argo CD repository at each step, and testing on staging first. The jump to the latest is only safe on a **fresh** local cluster. Do the same for the RabbitMQ operator (read its release notes between 2.11 and 2.23) and never change the RabbitMQ image and the operator in one step.

## RabbitMQ itself
`base/rabbitmq/rabbitmqcluster.yaml` pins RabbitMQ 3.13, which is end of life upstream. Moving to 4.x is a separate project: enable all stable feature flags on 3.13 first, upgrade one minor at a time, and test the application's client library. It is not part of this bump.

## Procedure for the next upgrade
1. Change the versions in one pull request (Renovate groups the local ones).
2. On a clean machine: `local/cluster-down.sh`, then `local/bootstrap.sh` (or run the **smoke** workflow). It must end `Synced` and `Healthy`.
3. Staging first, wait a day, then production.
4. Update the table above.

## What was tested on 2026-11-15 (macOS, Docker Desktop, kind v0.33.0, local kubectl v1.30.5)
Tested for real, in a throwaway cluster:
- `local/cluster-up.sh`: kind with node image Kubernetes v1.36.4, the RabbitMQ operator v2.21.0. Worked on the second attempt; the first failed in kubeadm (the API server did not answer) while about 30 other containers were running on the machine with 9.7 GB of Docker memory. If cluster creation times out for you, free memory and retry.
- `local/argocd-install.sh`: Argo CD v3.6.1 and the `argocd-cm` override. All components Running.
- **The EndpointSlice problem, both ways:** with the override an Application containing a selector-less Service and an EndpointSlice synced and created the EndpointSlice. With Argo CD's default exclusions the same Application reported `Synced/Healthy` while the log said "EndpointSlice ... is excluded in the settings" and nothing was created. A silent failure, which is why the override is required.
- The full `overlays/local` render passed a server-side dry run on Kubernetes 1.36 with the operator's CRDs.
- A real RabbitMQ 3.13 cluster under operator 2.21.0 (`ALLREPLICASREADY`, pod Running), and the digest-pinned `postgres:16-alpine` StatefulSet with the repository's init script (8 `kuasar_*` databases created).

Not tested (needs the app images and branch `local`, which only exist once these changes are pushed): the Argo CD sync of the real application, the migration Jobs and the services on the new versions; `NETWORK_POLICY=1` (Calico v3.33.1 against Kubernetes 1.36); the smoke workflow; staging and production (their renders only fail the dry run here because their namespaces and the SealedSecret CRD do not exist in the test cluster). Also untested: `kubectl` v1.36.6 itself (the machine has 1.30.5; the scripts do not check kubectl/server skew, which should stay within one minor version).
