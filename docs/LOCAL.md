# Run Kuasar AI on a laptop with Argo CD (kind)

Status: written 2026-11-13, not yet run end to end on a second machine (see "Known limits").

What you get: a local Kubernetes cluster (kind) where **Argo CD watches this GitHub repository** (branch `local`, folder `overlays/local`) and deploys the app the same way it will later run on DigitalOcean. You do **not** clone this repository: the cluster and Argo CD read it from GitHub, and a small download provides the helper scripts.

```
GitHub kuasar-deploy, branch "local"  (= main + the staging image digests, kept by .github/workflows/sync-local.yml)
        ^
        | Argo CD (inside kind) pulls, using a read-only token stored only in your local cluster
        v
kind cluster "kuasar":  Postgres, RabbitMQ, 8 services, gateways, web   <- images: public multi-arch Docker Hub images
You:  http://localhost:8080 (app + API)   http://localhost:3000 (marketing)   https://localhost:8443 (Argo CD UI, via port-forward)
```

Works on macOS (Intel, Apple Silicon), Linux and Windows (inside WSL2). Prerequisites and troubleshooting per OS: [LOCAL-MACOS.md](LOCAL-MACOS.md), [LOCAL-WINDOWS.md](LOCAL-WINDOWS.md).

## 1. Quick path

You need Docker, `kind`, `kubectl`, `curl`, `tar`, `python3`, `openssl` and a **read-only GitHub token** (fine-grained, only repository `kuasar-deploy`, permission *Contents: Read-only*).

```bash
read -rs -p "GitHub read-only token: " T; echo
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash -s -- --check   # only checks this machine
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash                # installs
```
`get.sh` downloads the `local/` and `argocd/` folders into `~/.kuasar-local` (no git, no checkout) and runs `bootstrap.sh`, which:

1. checks the machine (OS and CPU, tools, Docker memory at least 8 GB and 12 advised, free ports) and changes nothing if something is wrong;
2. creates the kind cluster (`local/kind-config.yaml.tmpl`, node image pinned in `local/versions.env`) and the RabbitMQ operator;
3. installs Argo CD (pinned);
4. generates this machine's own secrets into `~/.kuasar-local/local/.env.local` and creates the Kubernetes Secrets from them (values are never printed);
5. registers the repository in Argo CD with your token and applies the `kuasar-local` Application;
6. waits until Argo CD reports `Synced` and `Healthy` (first run 5 to 15 minutes) and prints the addresses and the Argo CD admin login.

Afterwards:

| Task | Command |
|---|---|
| What is running, what waits and why | `~/.kuasar-local/local/status.sh` |
| Remove everything (data is lost) | `~/.kuasar-local/local/cluster-down.sh` |
| Open the Argo CD UI | `kubectl -n argocd port-forward svc/argocd-server 8443:443`, then https://localhost:8443 |
| Update the scripts | run the install command again; it replaces `~/.kuasar-local` and keeps the cluster |

If you already have a checkout of this repository, `local/bootstrap.sh --check` and `local/bootstrap.sh` do the same.

## 2. Configuration files

| File | What |
|---|---|
| `local/versions.env` | kind and kubectl versions, Kubernetes node image, Argo CD and RabbitMQ operator versions, cluster and namespace names, repo URL, branch (`local`), minimum Docker memory/CPUs |
| `local/ports.env` | host ports (app 8080, marketing 3000, Argo 8443, Postgres 30432, sandbox bridges 30101 to 30103 and 30672). 8080 and 3000 are also written into `overlays/local` (public URLs, CORS): change both together |
| `local/.env.local` | this machine's generated secrets, git-ignored. Delete it only together with the cluster (the database passwords inside Postgres must match) |

## 3. What is different from the cloud (everything in `overlays/local`)

- Postgres runs as a pod (`overlays/local/postgres`), initialised by the same `init-databases.sh` as docker compose; in the cloud it is DigitalOcean Managed PostgreSQL.
- Plain Kubernetes Secrets created by `local/secrets.sh`; in the cloud Sealed Secrets.
- Images: public Docker Hub images by digest, no pull secret. The digests on branch `local` are copied from staging, so local runs what staging runs.
- Traffic enters through kind port mappings and NodePorts instead of Cloudflare Tunnel (`cloudflared` is removed).
- Small resource requests (limits unchanged), 1 replica each, small volumes, test settings: emails are logged, billing is the test provider with test checkout allowed, invitation tokens are returned, AI answer verification is off.
- The sandbox is not in the cluster (section 6).

## 4. The branch `local`

`.github/workflows/sync-local.yml` rebuilds branch `local` after every push to `main`: `main` plus one commit that copies the digests of `overlays/staging` into `overlays/local`. Never commit to it by hand. If that workflow fails, create or refresh the branch manually:
```bash
git checkout -B local origin/main && python3 tools/promote.py overlays/staging overlays/local
git commit -am "local: staging digests" && git push --force origin local
```
(As of 2026-11-13 the workflow had not produced the branch; it was created by hand. A likely cause is the default `GITHUB_TOKEN` not being allowed to push a branch that contains workflow files; check the Actions log.)

## 5. GitOps drills (what Argo CD is for)

1. **Deploy by Git:** merge a digest change into `main`; `sync-local` updates `local`; Argo CD rolls only that service.
2. **Rollback:** revert the digest commit; Argo CD returns to the previous image.
3. **A failing migration stops the release:** a wrong owner password in a `*-migrate` secret makes the Job fail and the services are not touched (sync waves).
4. **Drift healing:** `kubectl -n kuasar-local scale deploy/identity --replicas=0`; Argo CD scales it back.

Quick test without Git: `kubectl apply -k` needs a checkout; pause Argo CD first or it reverts the change: `kubectl -n argocd patch app kuasar-local --type merge -p '{"spec":{"syncPolicy":null}}'`.

Useful: `kubectl -n kuasar-local logs deploy/identity`, `kubectl -n kuasar-local describe pod <name>`, database from the host: `psql -h localhost -p 30432 -U postgres` (password: `POSTGRES_PASSWORD` in `.env.local`).

## 6. The sandbox (building and previewing projects)

The sandbox needs Docker and, in the cloud, gVisor, so it runs **outside** the cluster. Locally the cluster calls it at `host.docker.internal:8080/8090` (the overlay turns the `sandbox` Service into an ExternalName). Start it from `infrastructure/sandbox-host/` in the `kuasarai` repo on Docker Desktop, with its database, RabbitMQ and service URLs set to the NodePorts `localhost:30432`, `30672`, `30101`, `30102`, `30103` (in `sandbox.env`). This mode has **no gVisor**: use it only for your own projects. The hardened setup is described in [SANDBOX-HOST.md](SANDBOX-HOST.md). Until a sandbox runs, everything else works and build/preview reports that the build machine is unavailable.

## 7. Developer mode: build the images yourself

Only for the machine that builds images (needs the `kuasarai` repo next to a checkout of this repo).
1. `LOCAL_REGISTRY=1 local/cluster-up.sh` starts a registry on `localhost:5055` and tells the cluster about it.
2. `kuasarai/tools/k8s-build.sh [service ...]` builds, pushes, and writes the digests into `overlays/local-registry` (per machine: they are architecture specific).
3. Point the Application at `overlays/local-registry` and the branch you work on. Do not push these digests to a branch other machines follow.

## 8. Known limits

- **Not proven yet:** `bootstrap.sh`, the Argo CD sync and the migrations have only been tested in pieces (machine check, template rendering, secret generation, cluster creation once). Expect small fixes on the first full run (read-only filesystem paths, probe timings) and report what `status.sh` shows.
- kind's default network layer does not enforce NetworkPolicy, so the policies in `base/` are present but untested here.
- Memory: requests are small but limits are the production ones; with less than 12 GB, pods can be evicted.
- Windows on ARM is untested.
