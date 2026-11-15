# Local setup on Linux (Ubuntu, Debian, Fedora and similar; amd64 and arm64)

Time: 15 to 25 minutes after the tools are installed (mostly image downloads). The app images are multi-architecture.

## 1. Prerequisites (once)

1. **Docker Engine** (https://docs.docker.com/engine/install/) or Docker Desktop for Linux. Let your user run it, then log out and in again:
   ```bash
   sudo usermod -aG docker $USER
   docker info   # must show a Server section with CPUs and memory
   ```
   The engine needs **12 GB memory** (8 GB is the minimum the check accepts) and 4 or more CPUs. Rootless Docker and Podman are not tested.
2. **Packages**:
   ```bash
   sudo apt update && sudo apt install -y curl tar python3 openssl coreutils      # Debian/Ubuntu
   sudo dnf install -y curl tar python3 openssl coreutils                         # Fedora/RHEL
   ```
3. **kind and kubectl** (pinned versions in `local/versions.env`, installed to `~/.local/bin`, no sudo) come with the scripts: run section 2 once, and the first check will say they are missing. Then run `~/.kuasar-local/local/install-tools.sh`, open a new terminal (or `export PATH="$HOME/.local/bin:$PATH"`) and run the check again.
4. **A read-only GitHub token** for the private repo `kuasar-deploy` (how to create it: [LOCAL.md](LOCAL.md) section 1).
5. Nothing else may use the ports in `local/ports.env` (8080, 3000, 30101 to 30103, 30432, 30672). `ss -ltnp | grep :8080` shows what uses one.
6. Many pods watch files. If pods log `too many open files` or `inotify` errors:
   ```bash
   sudo sysctl fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=512
   ```
   Make it permanent in `/etc/sysctl.d/99-kuasar.conf`.

## 2. Run

```bash
read -rs -p "GitHub read-only token: " T; echo
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash -s -- --check   # only checks this machine
# if kind or kubectl are missing: ~/.kuasar-local/local/install-tools.sh, new terminal, then the check again
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash                # installs
```

Open http://localhost:8080 (app) and http://localhost:3000 (marketing). Status, removal and the Argo CD UI: [LOCAL.md](LOCAL.md) section 1 ("Afterwards").

## 3. Troubleshooting

| What you see | Cause and fix |
|---|---|
| `permission denied` on `/var/run/docker.sock` | step 1: add yourself to the `docker` group, log out and in |
| `kind: command not found` after `install-tools.sh` | `~/.local/bin` is not on PATH: `export PATH="$HOME/.local/bin:$PATH"` and add it to `~/.bashrc` |
| `Docker has only N GB` | raise the limit (Docker Desktop: Settings -> Resources). On Docker Engine the host memory is the limit |
| `port 8080 is already in use` | `ss -ltnp \| grep :8080` shows the program; do not stop containers you do not recognise |
| Pods `Pending` or evicted | not enough memory: free some, then `~/.kuasar-local/local/status.sh` |
| `ImagePullBackOff` | digests on branch `local` not published yet (the `sync-local` run in GitHub Actions must have finished) or no internet |
| Argo CD `repository not accessible` | token expired or wrong permission: run `~/.kuasar-local/local/app-apply.sh` again with a new token |
| Sandbox cannot reach the cluster | the cluster reaches the sandbox at `host.docker.internal`; on Docker Engine (not Desktop) add `--add-host=host.docker.internal:host-gateway` to the sandbox container, see `docs/LOCAL.md` section 6 |

## 4. Sandbox

Not part of the cluster; see [LOCAL.md](LOCAL.md) section 6. A Linux machine is the place to run the hardened gVisor sandbox: [SANDBOX-HOST.md](SANDBOX-HOST.md).
