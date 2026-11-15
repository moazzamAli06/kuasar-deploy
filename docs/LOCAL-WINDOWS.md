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
4. **Docker Desktop** (https://www.docker.com/products/docker-desktop): Settings -> General -> "Use the WSL 2 based engine" on; Settings -> Resources -> WSL integration -> turn on **Ubuntu**. In Ubuntu, `docker info` must show a **Server** section (CPUs and memory). If it says `permission denied` on `/var/run/docker.sock`, your Ubuntu user is not allowed to use Docker yet:
   ```bash
   sudo usermod -aG docker $USER
   ```
   Close Ubuntu. In PowerShell run `wsl --shutdown`, open Ubuntu again, and run `docker info` once more.
5. **Packages inside Ubuntu** (open the Ubuntu terminal, and stay in the Linux home `~`, never under `/mnt/c/...`: the Windows drive is very slow and can add Windows line endings):
   ```bash
   sudo apt update && sudo apt install -y curl python3 openssl coreutils
   ```
   `kind` and `kubectl` are installed in section 2, after the helper scripts have been downloaded. They are not apt packages.
6. **A read-only GitHub token** for `kuasar-deploy` (how to create it: [LOCAL.md](LOCAL.md) section 1). The script asks for it with hidden input.
7. Ports **8080, 3000, 30101 to 30103, 30432, 30672** must be free on Windows (IIS, other Docker containers and some VPN or dev tools use 8080).

## 2. Run (in the Ubuntu terminal)

No git and no clone. Each command below downloads the helper scripts to `~/.kuasar-local`. The cluster and Argo CD read the manifests directly from GitHub (branch `local`).

**2a. Download the scripts and check the machine.** Paste the token when asked (nothing is shown as you type):

```bash
read -rs -p "GitHub read-only token: " T; echo
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash -s -- --check
```

On a new Ubuntu this check **stops** with `missing tool: kind` and `missing tool: kubectl`. That is expected: the scripts are now in `~/.kuasar-local`, and nothing else was changed. Continue with 2b. If the check ends with `This machine is ready.`, skip to 2c.

**2b. Install kind and kubectl** (pinned versions, into `~/.local/bin`, no sudo):

```bash
~/.kuasar-local/local/install-tools.sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
kind version
kubectl version --client
```

`kind version` must print a version. If it says `command not found`, close the Ubuntu terminal, open it again, and run `kind version` once more. Then repeat the check from 2a. It must end with `This machine is ready.` before you install.

**2c. Install the cluster** (5 to 15 minutes the first time):

```bash
read -rs -p "GitHub read-only token: " T; echo
curl -fsSL -H "Authorization: Bearer $T" https://raw.githubusercontent.com/moazzamAli06/kuasar-deploy/main/local/get.sh | GITHUB_TOKEN=$T bash
```

Then open **http://localhost:8080** in Edge or Chrome on Windows (WSL forwards the port). Marketing site: http://localhost:3000.

The first install often sits on the database and the queue for several minutes before the app pods appear. That is normal. Do not force a sync. Check progress with the status command below; the app is ready when it reports `Healthy` and `http://localhost:8080/health ok`.

## 3. Daily use

Run these in the Ubuntu terminal. `status.sh` is a file already on the machine. Do not `curl` it into `bash`; that drops the helper files it needs and prints `./lib.sh: No such file or directory`.

| Task | Command (Ubuntu terminal) |
|---|---|
| What is running / stuck | `~/.kuasar-local/local/status.sh` |
| Pause | quit Docker Desktop (or `wsl --shutdown` in PowerShell); start Docker Desktop again and the cluster comes back |
| Remove everything | `~/.kuasar-local/local/cluster-down.sh` |

**Argo CD in the browser, status, removal:** same commands as everywhere, see [LOCAL.md](LOCAL.md) section 1 ("Afterwards"); run them in the Ubuntu terminal and open the browser on Windows.

## 4. Troubleshooting

| What you see | Cause and fix |
|---|---|
| `missing tool: kind` or `missing tool: kubectl` | expected on the first check. The scripts are already downloaded. Run section 2b (`install-tools.sh`), then the check again |
| `kind: command not found` after `install-tools.sh` | `~/.local/bin` is not on PATH. Run `source ~/.bashrc`, or close Ubuntu and open it again, then `kind version` |
| `permission denied` on `/var/run/docker.sock` | Ubuntu user cannot use Docker. Step 4: `sudo usermod -aG docker $USER`, then `wsl --shutdown` in PowerShell, reopen Ubuntu |
| `Docker is not running` or `docker: command not found` in Ubuntu | start Docker Desktop; check Settings -> Resources -> WSL integration -> Ubuntu is on |
| `./lib.sh: No such file or directory` | `status.sh` was piped from `curl` into `bash`. Run `~/.kuasar-local/local/status.sh` instead |
| `rabbitmq-server-0` stuck, `default_user.conf` missing | the queue secret has no password file. Run `~/.kuasar-local/local/secrets.sh`, then `kubectl -n kuasar-local delete pod rabbitmq-server-0`. Wait until that pod is `Running`; the other apps start after it. Do not force a sync |
| `sync=OutOfSync` and only `postgres-0` and `rabbitmq-server-0` | the app waits until the queue is `Running`. Give it a few minutes and run `status.sh` again |
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

Not part of the cluster. It runs in the same Docker engine **without gVisor** and only for your own projects (`docs/LOCAL.md` section 6). A hardened sandbox needs a Linux machine or VM (`docs/SANDBOX-HOST.md`).
