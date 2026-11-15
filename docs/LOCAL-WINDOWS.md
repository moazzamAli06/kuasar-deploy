# Local setup on Windows 10/11 (WSL2)

All scripts are bash, so everything runs **inside Ubuntu on WSL2**. Docker Desktop provides the container engine to Ubuntu. You use the app from your normal Windows browser.

Time: 30 to 45 minutes the first time (WSL2 and Docker install), then 15 to 25 minutes for the app.

## 1. Prerequisites (once)

1. **Windows**: Windows 11, or Windows 10 version 22H2 or newer. Virtualization must be enabled in BIOS/UEFI (Task Manager -> Performance -> CPU shows "Virtualization: Enabled").
2. **WSL2 + Ubuntu.** In PowerShell as administrator:
   ```powershell
   wsl --install -d Ubuntu
   ```
   Restart if asked, then open "Ubuntu" from the Start menu and create your Linux user.
3. **Memory for WSL2.** Create `C:\Users\<you>\.wslconfig` (Notepad) with:
   ```
   [wsl2]
   memory=12GB
   processors=6
   ```
   (Use `memory=8GB` on a 16 GB machine; then expect the AI service to be the first thing to struggle.) Apply: `wsl --shutdown` in PowerShell.
4. **Docker Desktop** (https://www.docker.com/products/docker-desktop): Settings -> General -> "Use the WSL 2 based engine" on; Settings -> Resources -> WSL integration -> turn on **Ubuntu**. In Ubuntu, `docker version` must show a Server section.
5. **Tools inside Ubuntu** (open the Ubuntu terminal):
   ```bash
   sudo apt update && sudo apt install -y curl python3 openssl coreutils
   ```
   Then download the scripts once (steps 6 and 2 below show the command; the first run stops at the check because kubectl and kind are missing) and install the tools:
   ```bash
   ~/.kuasar-local/local/install-tools.sh     # kubectl and kind, versions pinned, into ~/.local/bin
   ```
   If it tells you to add `~/.local/bin` to the PATH, add the printed line to `~/.bashrc` and open a new Ubuntu terminal.
   Work in the Ubuntu terminal and keep files in the Linux home (`~`), never under `/mnt/c/...`: the Windows drive is very slow and can add Windows line endings.
6. **A read-only GitHub token** for `kuasar-deploy` (GitHub -> Settings -> Developer settings -> Fine-grained personal access tokens -> only that repository -> *Contents: Read-only*). The script asks for it with hidden input.
7. Ports **8080, 3000, 30101 to 30103, 30432, 30672** must be free on Windows (IIS, other Docker containers and some VPN or dev tools use 8080).

## 2. Run (in the Ubuntu terminal)

```bash
read -rs -p "GitHub read-only token: " T; echo
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash -s -- --check   # only checks this machine
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash                # installs
```
No git and no clone: the command downloads the small helper scripts to `~/.kuasar-local`. The cluster and Argo CD read the manifests directly from GitHub (branch `local`). Later commands: `~/.kuasar-local/local/status.sh`, `~/.kuasar-local/local/cluster-down.sh`.
Then open **http://localhost:8080** in Edge or Chrome on Windows (WSL forwards the port). Marketing site: http://localhost:3000.

## 3. Daily use

| Task | Command (Ubuntu terminal) |
|---|---|
| What is running / stuck | `~/.kuasar-local/local/status.sh` |
| Pause | quit Docker Desktop (or `wsl --shutdown` in PowerShell); start Docker Desktop again and the cluster comes back |
| Remove everything | `~/.kuasar-local/local/cluster-down.sh` |
| Argo CD UI | `kubectl -n argocd port-forward svc/argocd-server 8443:443`, then https://localhost:8443 in the Windows browser |

## 4. Troubleshooting

| What you see | Cause and fix |
|---|---|
| `Docker is not running` or `docker: command not found` in Ubuntu | start Docker Desktop; check Settings -> Resources -> WSL integration -> Ubuntu is on |
| `Docker has only N GB` | the limit comes from `.wslconfig`; edit, then `wsl --shutdown`, restart Docker Desktop |
| `bad interpreter: /bin/bash^M` or odd `$'\r'` errors | files were checked out with Windows line endings (repo cloned on `/mnt/c` or `core.autocrlf=true`): delete `~/.kuasar-local` and run the download command again from the Ubuntu terminal |
| `port 8080 is already in use` | on Windows: `netstat -ano | findstr :8080` shows the process id; stop that program (or choose to free the port); do not stop containers you do not recognise |
| `http://localhost:8080` does not open from Windows | `wsl --shutdown` and restart Docker Desktop; check the Windows firewall is not blocking Docker Desktop; make sure `.wslconfig` does not set `networkingMode=mirrored` together with a VPN that blocks loopback |
| Very slow downloads or timeouts | you are working under `/mnt/c`: use the Ubuntu home `~` |
| Pods `Pending` | not enough memory: raise it in `.wslconfig` |
| `ImagePullBackOff` | `local` branch digests not published yet (first `images` and `sync-local` runs must have finished) or no internet |
| Argo CD `repository not accessible` | token expired or wrong permission: run `local/app-apply.sh` again with a new token |

Windows on ARM (Snapdragon): works with the arm64 images, but Docker Desktop for Windows on ARM is newer; treat it as untested.

## 5. Sandbox (build and preview of customer projects)

Not part of the cluster. It runs in the same Docker engine **without gVisor** and only for your own projects (`docs/LOCAL.md` section 9). A hardened sandbox needs a Linux machine or VM (`docs/SANDBOX-HOST.md`).
