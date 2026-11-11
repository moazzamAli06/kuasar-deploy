# The sandbox execution host

Customer code runs on a separate machine (a DigitalOcean Droplet, or a Linux VM locally) with Docker and **gVisor (`runsc`)**, never in this cluster. Why: the sandbox joins each run's Docker network and proxies previews to container addresses on it, so it must live on the same Docker host (`kuasarai/docs/operations/blocker-solutions.md`, section 4; ADR-0010).

In the cluster:
- `Service sandbox` has **no selector**; `EndpointSlice sandbox-host` points at the host's private address (set per overlay, currently the placeholder `192.0.2.10`). `ai`, `gateway` and `cloudflared` keep calling `sandbox:8080` / `:8090`.
- `bridge-project` (30101), `bridge-organization` (30102), `bridge-billing` (30103) and `bridge-rabbitmq` (30672) are NodePorts the host uses to call in. Restrict them in the **cloud firewall** to the host's address, and in the cluster with the `sandbox-host-ingress` policy (set the VPC range in the overlay).
- Only the `migrate-sandbox` Job still runs in the cluster.

On the host (files in the `kuasarai` repo): `infrastructure/sandbox-host/install-host.sh` (gVisor), `sandbox.env.example` -> `/etc/kuasar/sandbox.env`, `compose.sandbox.yml`, then `tools/verify-sandbox-host.sh` (every line must say PASS). Add the host as a trusted source of the managed database. The host's secrets are NOT sealed secrets: they live in `/etc/kuasar/sandbox.env` (root, mode 600).

Before the first sync, set in `overlays/<env>/kustomization.yaml`: the host's private address (EndpointSlice and egress policy) and the node network CIDR (ingress policy).
