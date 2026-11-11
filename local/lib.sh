# Shared helpers for the local scripts (source this; works on macOS and Linux/WSL2 with bash 3.2+).
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; . "$LOCAL_DIR/versions.env"; . "$LOCAL_DIR/ports.env"; set +a
KCTX="kind-$CLUSTER_NAME"

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31mxx %s\033[0m\n' "$*" >&2; exit 1; }

os_name() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux) if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl2; else echo linux; fi ;;
    *) echo unsupported ;;
  esac
}
arch_name() { case "$(uname -m)" in x86_64|amd64) echo amd64 ;; arm64|aarch64) echo arm64 ;; *) echo other ;; esac; }

# true when something already listens on 127.0.0.1:$1 (pure bash, no lsof/ss needed)
port_in_use() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

# a >= b for dotted versions
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

# Fills @NAME@ placeholders from the environment: render_template in out
render_template() {
  local in=$1 out=$2 sedargs=() v
  for v in CLUSTER_NAME KIND_NODE_IMAGE EDGE_PORT MARKETING_PORT PG_PORT BRIDGE_PROJECT_PORT BRIDGE_ORGANIZATION_PORT BRIDGE_BILLING_PORT BRIDGE_RABBITMQ_PORT; do
    sedargs+=(-e "s|@${v}@|${!v}|g")
  done
  sed "${sedargs[@]}" "$in" > "$out"
}

use_context() { kubectl config use-context "$KCTX" >/dev/null 2>&1 || die "no cluster '$CLUSTER_NAME' (run local/bootstrap.sh)"; }

# Prints problems and returns non-zero if the machine cannot run the stack. Never changes anything.
preflight() {
  local bad=0 os arch mem cpus p
  os=$(os_name); arch=$(arch_name)
  say "Machine: $os / $arch"
  [ "$os" != unsupported ] || { warn "unsupported OS (use macOS, Linux, or Windows with WSL2 Ubuntu)"; bad=1; }
  [ "$arch" != other ] || { warn "unsupported CPU architecture"; bad=1; }
  if [ "$os" = linux ] || [ "$os" = wsl2 ]; then :; fi
  for t in docker kind kubectl openssl curl python3 base64; do
    command -v "$t" >/dev/null || { warn "missing tool: $t (see docs/LOCAL-$( [ "$os" = macos ] && echo MACOS || echo WINDOWS ).md)"; bad=1; }
  done
  if command -v kind >/dev/null; then
    ver_ge "$(kind version | sed -n 's/^kind v\([0-9.]*\).*/\1/p')" "$KIND_MIN_VERSION" || { warn "kind is older than $KIND_MIN_VERSION"; bad=1; }
  fi
  if command -v docker >/dev/null; then
    if docker info >/dev/null 2>&1; then
      mem=$(( $(docker info --format '{{.MemTotal}}') / 1024 / 1024 / 1024 ))
      cpus=$(docker info --format '{{.NCPU}}')
      say "Docker has ${cpus} CPUs and about ${mem} GB memory"
      [ "$mem" -ge "$MIN_DOCKER_MEMORY_GB" ] || { warn "Docker has only ${mem} GB; need at least $MIN_DOCKER_MEMORY_GB (12 advised). Docker Desktop -> Settings -> Resources (Windows: .wslconfig)"; bad=1; }
      [ "$cpus" -ge "$MIN_DOCKER_CPUS" ] || warn "Docker has ${cpus} CPUs; $MIN_DOCKER_CPUS or more advised"
    else
      warn "Docker is not running"; bad=1
    fi
  fi
  if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
    for p in $EDGE_PORT $MARKETING_PORT $PG_PORT $BRIDGE_PROJECT_PORT $BRIDGE_ORGANIZATION_PORT $BRIDGE_BILLING_PORT $BRIDGE_RABBITMQ_PORT; do
      if port_in_use "$p"; then warn "port $p is already in use on this machine (stop what uses it; for the old compose stack: docker compose down)"; bad=1; fi
    done
  fi
  return $bad
}
