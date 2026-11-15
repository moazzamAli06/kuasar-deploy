# Local setup on macOS (Intel and Apple Silicon)

Time: 15 to 25 minutes after the tools are installed (mostly image downloads). Works the same on Intel (amd64) and Apple Silicon (arm64): the app images are multi-architecture.

## 1. Prerequisites (once)

1. **Docker Desktop** (https://www.docker.com/products/docker-desktop). Settings -> Resources: **12 GB memory** (8 GB is the minimum the check accepts), **6 or more CPUs**. Apply & restart. Apple Silicon: leave "Use Rosetta for x86_64 emulation" on (only some third-party images need it).
2. **Homebrew** (https://brew.sh), then:
   ```bash
   brew install kind kubectl
   ```
   `python3`, `openssl` and `curl` ship with macOS (or the Xcode command line tools: `xcode-select --install`).
3. **A read-only GitHub token** for the private repo `kuasar-deploy`: GitHub -> Settings -> Developer settings -> Fine-grained personal access tokens -> only repository `kuasar-deploy` -> permission *Contents: Read-only*. Keep it ready; the script asks for it and hides what you type. It is stored only inside your local cluster.
4. Nothing else may use ports **8080, 3000, 30101 to 30103, 30432, 30672**. If the old compose stack is running: `docker compose down` in the `kuasarai` folder.

## 2. Run

```bash
read -rs -p "GitHub read-only token: " T; echo
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash -s -- --check   # only checks this machine
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash                # installs
```
No git and no clone: the command downloads the small helper scripts to `~/.kuasar-local`. The cluster and Argo CD read the manifests directly from GitHub (branch `local`). Later commands: `~/.kuasar-local/local/status.sh`, `~/.kuasar-local/local/cluster-down.sh`.
When it ends it prints the addresses: app http://localhost:8080 , marketing http://localhost:3000 , and the Argo CD login.

## 3. Daily use

| Task | Command |
|---|---|
| What is running / what is stuck | `~/.kuasar-local/local/status.sh` |
| Stop without losing data | quit Docker Desktop, or `docker stop kuasar-control-plane`; later `docker start kuasar-control-plane` |
| Remove everything | `~/.kuasar-local/local/cluster-down.sh` |
| Open the Argo CD UI | `kubectl -n argocd port-forward svc/argocd-server 8443:443` then https://localhost:8443 |

## 4. Troubleshooting

| What you see | Cause and fix |
|---|---|
| `Docker has only N GB` | raise memory in Docker Desktop Settings -> Resources |
| `port 8080 is already in use` | stop what uses it: `lsof -nP -iTCP:8080 -sTCP:LISTEN` shows the program; do not stop containers you do not recognise |
| Pods `Pending` | not enough memory: raise Docker memory, then `local/status.sh` |
| `ImagePullBackOff` | digests on branch `local` not published yet (the first `images` and `sync-local` runs in GitHub Actions must have finished) or no internet |
| `exec format error` on Apple Silicon | an image was built for amd64 only: the `images` workflow must have built `linux/arm64`; tell the team |
| Argo CD says `repository not accessible` | token expired or wrong permission: run `local/app-apply.sh` again with a new token |
| Browser shows nothing on 8080 | `local/status.sh`; the app is ready only when it reports `Healthy` |

## 5. Sandbox (build and preview of customer projects)

Not part of the cluster. See `docs/LOCAL.md` section 9: runs on Docker Desktop **without gVisor** and only for your own projects. A hardened sandbox needs a Linux machine (`docs/SANDBOX-HOST.md`).
