# Availability, scaling and ingress

## What is built in (base and production)
- **Spreading:** every Deployment prefers different nodes (`kubernetes.io/hostname`) and different zones (`topology.kubernetes.io/zone`), as a soft preference (`ScheduleAnyway`), so a small or single-zone cluster still schedules. `cloudflared` is spread too.
- **Rollouts:** single-replica services use `maxSurge: 0, maxUnavailable: 1` (never two copies at once). In production, `identity` and `organization` (2 replicas) roll with `maxSurge: 1, maxUnavailable: 0`, so a deploy never removes capacity.
- **Disruptions:** PodDisruptionBudgets in production for every service with 2 replicas, including `cloudflared`.
- **Probes:** all services have startup, liveness and readiness probes except `ai-orchestrator`, which exposes no HTTP port in its manifest (add a probe if the image offers a health endpoint).

## Autoscaling (opt-in): `components/autoscaling`
HorizontalPodAutoscalers (CPU 70% of the request, 2 to 6 replicas) for `identity`, `organization`, `gateway`, `edge-gateway`, `platform-web`, `marketing-web`. The component removes `replicas` from those Deployments so Argo CD and the autoscaler do not fight.
```yaml
components:
- ../../components/cloud-aws
- ../../components/autoscaling
```
Needs metrics-server (present on DOKS, GKE and AKS; install it on EKS) and enough node headroom: pair it with the cluster autoscaler the `infra/` modules enable. The other services are not scaled: they are not designed for several replicas (`project` uses a ReadWriteOnce volume).
CPU is measured against the *requests* in `base/`; revisit those numbers with real load data before trusting the thresholds.

## Ingress without Cloudflare (opt-in): `components/ingress`
Cloudflare Tunnel is the default entry. `components/ingress` replaces it with standard `Ingress` resources: it deletes `cloudflared`, adds Ingresses for the app (`edge-gateway`), the marketing site and the project previews (wildcard host to the sandbox host), and lets a labelled ingress-controller namespace through the edge NetworkPolicy.

Checklist:
1. Install a controller your cloud supports: AWS Load Balancer Controller, GKE Ingress, AKS application routing, Traefik or Envoy Gateway. `ingress-nginx` is retired upstream, so do not start a new setup with it.
2. Install cert-manager and a ClusterIssuer (the preview wildcard needs a DNS-01 issuer), or use the cloud's managed certificates.
3. In your overlay, patch the placeholders: hosts (`REPLACE-DOMAIN.example`), `ingressClassName` (`REPLACE_INGRESS_CLASS`), the issuer annotation (`REPLACE_CLUSTER_ISSUER`).
4. `kubectl label namespace <controller namespace> kuasar.ai/ingress-controller=true`. Controllers that run outside the cluster (an ALB in IP mode) need an `ipBlock` rule for their addresses instead.
5. The visitor's address: Cloudflare's `CF-Connecting-IP` header disappears. The edge gateway then records the controller's address unless its nginx reads `X-Forwarded-For`; that configuration is inside the image, not in this repository.

Status: it renders and passes the policy checks (CI does both), and has **not been tried on a real cluster**. The preview host mapping is inferred from the manifests (the tunnel pod carries the sandbox-egress label): compare it with your tunnel's public hostnames.

## Pod network and the visitor address
`base/edge-gateway/trusted-proxies.conf` trusts the real-visitor header only from the pod network, and every cloud numbers pods differently. `cloud-aws` (the VPC range, because the VPC CNI gives pods VPC addresses) and `cloud-gcp` (the pods secondary range) override it with the ranges that `infra/` creates; DigitalOcean, Azure (pod CIDR set explicitly in `infra/azure`) and kind use the base `10.244.0.0/16`. If your pod range differs, edit the component's `trusted-proxies.conf`. If the range is wrong, nothing breaks: visitors just appear with the proxy's address.
