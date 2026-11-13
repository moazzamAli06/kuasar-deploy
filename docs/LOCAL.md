# Run Kuasar AI on your Mac with Argo CD (kind)

What you get: a local Kubernetes cluster (kind) where **Argo CD watches this GitHub repository** (`overlays/local`) and deploys the app, exactly the way it will later run on DigitalOcean. Only the things in `overlays/local` differ from the cloud.

```
kuasarai code --(tools/k8s-build.sh)--> local registry localhost:5055 --digest--> overlays/local --git push--> GitHub
                                                                                                                 |
                                                       Argo CD (in kind) <---------- watches main ---------------+
                                                            └── deploys: Postgres, RabbitMQ, 8 services, gateways, web
You: http://localhost:8080 (app + API)   http://localhost:3000 (marketing site)   https://localhost:8443 (Argo CD UI)
```

## Quick path (any machine)

```bash
read -rs -p "GitHub read-only token: " T; echo
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash -s -- --check   # only checks this machine
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash                # installs
```
No git and no clone: the command downloads the small helper scripts to `~/.kuasar-local`. The cluster and Argo CD read the manifests directly from GitHub (branch `local`). Later commands: `~/.kuasar-local/local/status.sh`, `~/.kuasar-local/local/cluster-down.sh`.

(From a checkout of this repo you can also run `local/bootstrap.sh --check` and `local/bootstrap.sh` directly.)
Per-OS prerequisites and troubleshooting: `docs/LOCAL-MACOS.md`, `docs/LOCAL-WINDOWS.md` (Windows uses WSL2 Ubuntu).

The sections below are the same thing step by step (what `bootstrap.sh` does). Versions live in `local/versions.env`, host ports in `local/ports.env`. Secrets are generated for this machine into `local/.env.local` (git-ignored); the `kuasarai` repo is not needed.

## 0. Before you start (once)

1. Docker Desktop: Settings -> Resources -> **8 CPUs, 12 GB memory** if you can (minimum 10 GB). Apply and restart.
2. Install the tools: `brew install kind` (kubectl is already installed). Check with `kind version`.
3. Stop the compose stack, it uses ports 8080 and 3000 and a lot of memory:
   ```bash
   cd ~/Repositories/kuasarai && docker compose down
   ```
   (Add no `-v`: your compose data stays.)
4. Secrets: `local/secrets.sh` creates `local/.env.local` itself on first run (or pass the path of another env file).
5. Both repos checked out side by side: `~/Repositories/kuasarai` and `~/Repositories/kuasar-deploy`.

## 1. Create the cluster and the local registry

```bash
cd ~/Repositories/kuasar-deploy
local/cluster-up.sh
```
Creates the registry (`localhost:5055`), the kind cluster `kuasar`, installs the RabbitMQ operator, creates namespace `kuasar-local`.
Check: `kubectl get nodes` shows `Ready`.

## 2. Install Argo CD

```bash
local/argocd-install.sh
```
It prints the `admin` password. Open the UI in a second terminal:
```bash
kubectl -n argocd port-forward svc/argocd-server 8443:443
```
Then https://localhost:8443 (accept the self-signed certificate warning).

## 3. Create the Secrets (not in Git)

```bash
local/secrets.sh
```
Creates all Secrets in `kuasar-local` from `local/.env.local` (database passwords, JWT keys, RabbitMQ user, ...). Nothing is printed. Run it again whenever `.env` changes.

## 4. (Developer mode only) Build the images yourself

> Skip this on a normal machine: `overlays/local` uses the public multi-arch Docker Hub images (digests copied from staging by `sync-local.yml` onto branch `local`). Use this step only on the machine that builds images: start the cluster with `LOCAL_REGISTRY=1 local/cluster-up.sh`, set `path: overlays/local-registry` in `argocd/local-application.yaml`, and the digests are per-machine (do not push them to a branch others follow).


```bash
cd ~/Repositories/kuasarai
tools/k8s-build.sh            # all 13 images, one at a time: the first run takes 20 to 40 minutes
```
It pushes the images to `localhost:5055` and writes their digests into `kuasar-deploy/overlays/local/kustomization.yaml`. Argo CD reads from GitHub, so publish that change:
```bash
cd ~/Repositories/kuasar-deploy
git add -A && git commit -m "local: first images" && git push
```
(The first push also publishes the `local/` scripts, `overlays/local` and `argocd/local-application.yaml`: Argo CD needs them on `main`.)
Later builds can name services: `tools/k8s-build.sh identity ai`.

## 5. Connect Argo CD to the GitHub repo and start syncing

If the repository is private, create a **read-only** token: GitHub -> Settings -> Developer settings -> Fine-grained tokens -> repository `kuasar-deploy` -> permission *Contents: Read-only*. Then:
```bash
GITHUB_USER=moazzamAli06 GITHUB_TOKEN=<paste token> local/app-apply.sh
```
(You type the token yourself; it is stored only as a Secret inside the local cluster. If the repo is public, run `local/app-apply.sh` with no variables.)

Watch it deploy:
```bash
kubectl -n argocd get applications -w
kubectl -n kuasar-local get pods -w
```
In the Argo UI, open `kuasar-local`. Order: config, Postgres, RabbitMQ -> migration Jobs -> services -> gateways and web. The first sync takes 5 to 10 minutes (image pulls, migrations). `Synced` + `Healthy` means done.

## 6. Use it

- App: http://localhost:8080 , marketing site: http://localhost:3000
- Health: `cd ~/Repositories/kuasarai && tools/doctor.sh` and the end-to-end test `tools/e2e.sh` (point both at `http://localhost:8080`).
- Local behaviour (from the overlay): emails are logged not sent, billing is the test provider with test checkout allowed, invitation tokens are returned, AI answer verification is off.
- Real AI answers: add the provider key to the `kuasar-ai` secret (`kubectl -n kuasar-local edit secret kuasar-ai` is awkward with base64; easier: add `AI_ECONOMY_API_KEY=...` in `local/secrets.sh` and run it again, then `kubectl -n kuasar-local rollout restart deploy/ai`).

## 7. The GitOps drills (what Argo CD is for)

1. **Deploy by Git:** rebuild one service (`tools/k8s-build.sh identity`), commit and push the new digest: Argo CD rolls only that service.
2. **Rollback:** `git revert HEAD && git push`: Argo CD returns to the previous digest.
3. **Migration stops a bad release:** make a migration fail (wrong owner password in the secret) and sync: the Job fails and the services are not touched (wave order).
4. **Drift healing:** `kubectl -n kuasar-local scale deploy/identity --replicas=0`: Argo CD scales it back.

## 8. Day to day

| Task | Command |
|---|---|
| Stop everything, keep data | `kind` has no pause: use `docker stop kuasar-control-plane kind-registry`; `docker start` both to resume |
| Wipe the cluster and start over | `local/cluster-down.sh` then step 1 again |
| Quick test without Git | `kubectl apply -k overlays/local` (Argo CD will revert it: pause with `kubectl -n argocd patch app kuasar-local --type merge -p '{"spec":{"syncPolicy":null}}'`) |
| Logs of a service | `kubectl -n kuasar-local logs deploy/identity` |
| Why a pod does not start | `kubectl -n kuasar-local describe pod <name>` |
| Database from the Mac | `psql -h localhost -p 30432 -U postgres` (password: `POSTGRES_PASSWORD` in `.env`) |

## 9. The sandbox (building and previewing projects)

The sandbox needs Docker and, in the cloud, gVisor, so it runs **outside** the cluster. Locally the cluster calls it at `host.docker.internal:8080/8090` (overlay `sandbox` Service is an ExternalName). Start it from the compose file in `kuasarai/infrastructure/sandbox-host/` on Docker Desktop, pointing its database/RabbitMQ/service URLs at the NodePorts `localhost:30432`, `30672`, `30101`, `30102`, `30103` (set in its `sandbox.env`).
This mode has **no gVisor**: use it only for your own projects. The gVisor rehearsal (a Linux VM) is described in `docs/SANDBOX-HOST.md`. Until the sandbox is running, everything else works; building or previewing a project reports that the build machine is unavailable.

## Known limits of the local run

- kind's default network layer does not enforce NetworkPolicy, so the policies in `base/` are present but not tested here (Cilium would test them: see `kuasarai/docs/operations/local-kubernetes-plan.md`).
- Requests are tiny and limits are the production ones, so memory spikes can still evict pods on a 10 GB Docker Desktop; raise it to 12 GB.
- Postgres here is a single pod; in the cloud it is DigitalOcean Managed PostgreSQL.
- Nothing in this guide has been run yet on this Mac. Expect to fix small things on the first sync (read-only filesystem paths, probe timings) and tell me what you see.
