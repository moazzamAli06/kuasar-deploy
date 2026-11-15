# Deploy on Azure (AKS)

Cloud component: `components/cloud-azure` (storage class `managed-csi`, database port 5432). Database: Azure Database for PostgreSQL Flexible Server (private access). Sandbox host: an Azure VM in the same virtual network ([SANDBOX-HOST.md](../SANDBOX-HOST.md)).

The cluster commands below are examples, not tested in this repository: adjust names, regions and sizes, and check the cloud's current docs.

## 1. Create the cluster
With OpenTofu (cluster, network, managed PostgreSQL and sandbox host in one go): [`infra/azure`](../../infra/README.md). Or by hand:
```bash
az aks create -g kuasar-rg -n kuasar-prod --node-count 3 --node-vm-size Standard_D4s_v5 \
  --network-plugin azure --network-policy cilium --enable-cluster-autoscaler --min-count 3 --max-count 6
```
`--network-policy cilium` (or `calico`) makes AKS enforce NetworkPolicy. `managed-csi` is built in. Use private access for the PostgreSQL server and allow 5432 from the node subnet.

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
- **Cloud secret manager** (`components/external-secrets`, a `ClusterSecretStore` from `platform/external-secrets/stores`, [SECURITY.md](../SECURITY.md)): Azure Key Vault with the External Secrets Operator is the common choice; Sealed Secrets also works. It replaces the `sealed/` folder.

## 4. Point the environment at this cloud
Create `overlays/production-azure/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../production
components:
- ../../components/cloud-azure     # replaces the storage class and database port set by cloud-do
patches:
- target: {kind: EndpointSlice, name: sandbox-host}
  patch: |-
    - {op: replace, path: /endpoints/0/addresses/0, value: "<sandbox host private IP>"}
```
Also patch `sandbox-host-egress` and `sandbox-host-ingress` as `overlays/production/kustomization.yaml` does, with this cloud's addresses. Add an entry for the new path to `argocd/applicationset.yaml`. Narrow the `db-egress` policy to the database's CIDR.

## 5. Entry and DNS
Cloudflare Tunnel still works. A native alternative is the application routing add-on or Application Gateway for Containers in front of `edge-gateway` (not included yet).

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
- [ ] Database reachable from the pods on port 5432; managed backups on.
- [ ] Sandbox host reachable from the nodes; firewall limits the bridge NodePorts (30101 to 30103, 30672) to the host.
- [ ] All secrets from [SECRETS.md](../SECRETS.md) present before the first sync.
- [ ] `REPLACE_ORG:release-managers` in `argocd/project.yaml` replaced with a real group.
