# Deploy on DigitalOcean (DOKS)

Cloud component: `components/cloud-do` (storage class `do-block-storage`, database port 25060). Database: DigitalOcean Managed PostgreSQL. Sandbox host: a Droplet in the same VPC ([SANDBOX-HOST.md](../SANDBOX-HOST.md)).

The cluster commands below are examples, not tested in this repository: adjust names, regions and sizes, and check the cloud's current docs.

## 1. Create the cluster
With OpenTofu (cluster, network, managed PostgreSQL and sandbox host in one go): [`infra/digitalocean`](../../infra/README.md). Or by hand:
```bash
doctl kubernetes cluster create kuasar-prod --region fra1 --version latest \
  --node-pool "name=pool;size=s-4vcpu-8gb;count=3;auto-scale=true;min-nodes=3;max-nodes=6"
```
Add the cluster's VPC and the Droplet as trusted sources of the managed database. Database connections use port 25060 and require TLS.

Sizing: start with 3 nodes of 4 vCPU and 8 GB for production, then adjust from a load test and the pods' requests (`kubectl top`).

## 2. Install Argo CD and the add-ons
```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/<version from local/versions.env>/manifests/install.yaml
kubectl apply --server-side --force-conflicts -f argocd/argocd-cm-overrides.yaml   # Argo CD 3 hides EndpointSlice by default; the sandbox host needs one
kubectl apply -n argocd -f argocd/addons.yaml     # Sealed Secrets and the RabbitMQ operator
```
Registering the private repository: use a deploy key or a GitHub App credential (an Argo CD `repository` Secret), not a personal token.

## 3. Secrets
Create every secret listed in [SECRETS.md](../SECRETS.md). Two supported ways:
- **Sealed Secrets** (default in this repo): `tools/seal-secrets.sh <env> secrets-plain/<env>/*.yaml`, commit the output under `overlays/<env>/sealed/` and list it in that folder's `kustomization.yaml`. Create `rabbitmq-default-user` first.
- **Cloud secret manager** (`components/external-secrets`, a `ClusterSecretStore` from `platform/external-secrets/stores`, [SECURITY.md](../SECURITY.md)): DigitalOcean has no native secret manager; Sealed Secrets is the right choice. It replaces the `sealed/` folder.

## 4. Point the environment at this cloud
`overlays/staging` and `overlays/production` already include `components/cloud-do`: fill the placeholders (public URLs, the sandbox host address, the VPC range) and continue with step 5.

## 5. Entry and DNS
Cloudflare Tunnel (`cloudflared`) already provides the entry: no load balancer is needed.

## 6. Sync and verify
```bash
kubectl apply -f argocd/project.yaml -f argocd/applicationset.yaml
argocd app sync kuasar-production        # production is manual
kubectl -n kuasar-production get pods
```
Check the migration Jobs completed, then the public `/health` URL.

## Checklist before go-live
- [ ] Storage class exists in the cluster (`kubectl get storageclass`).
- [ ] NetworkPolicy is enforced by the cluster's network layer.
- [ ] Database reachable from the pods on port 25060; managed backups on.
- [ ] Sandbox host reachable from the nodes; firewall limits the bridge NodePorts (30101 to 30103, 30672) to the host.
- [ ] All secrets from [SECRETS.md](../SECRETS.md) present before the first sync.
- [ ] `REPLACE_ORG:release-managers` in `argocd/project.yaml` replaced with a real group.
