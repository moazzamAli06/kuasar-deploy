#!/usr/bin/env bash
# Creates the kind cluster, the RabbitMQ operator and the app namespace. Safe to run again.
# LOCAL_REGISTRY=1 also starts a local image registry (developer mode, see docs/LOCAL.md section 4).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
REG_NAME=kind-registry; REG_PORT=5055

if [ "${LOCAL_REGISTRY:-0}" = 1 ]; then
  if [ "$(docker inspect -f '{{.State.Running}}' $REG_NAME 2>/dev/null || true)" != true ]; then
    docker rm -f $REG_NAME >/dev/null 2>&1 || true
    docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --network bridge --name $REG_NAME registry:2 >/dev/null
  fi
fi

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  say "Creating cluster '$CLUSTER_NAME' ($KIND_NODE_IMAGE); the first run downloads about 1 GB"
  cfg="$LOCAL_DIR/.rendered-kind-config.yaml"
  render_template "$LOCAL_DIR/kind-config.yaml.tmpl" "$cfg"
  kind create cluster --config "$cfg"
  rm -f "$cfg"
fi
use_context

if [ "${LOCAL_REGISTRY:-0}" = 1 ]; then
  for node in $(kind get nodes --name "$CLUSTER_NAME"); do
    docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:${REG_PORT}"
    docker exec -i "$node" sh -c "cat > /etc/containerd/certs.d/localhost:${REG_PORT}/hosts.toml" <<TOML
[host."http://${REG_NAME}:5000"]
TOML
  done
  docker network connect kind $REG_NAME 2>/dev/null || true
fi

say "RabbitMQ operator $RABBITMQ_OPERATOR_VERSION"
kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/download/${RABBITMQ_OPERATOR_VERSION}/cluster-operator.yml" >/dev/null
kubectl -n rabbitmq-system rollout status deploy/rabbitmq-cluster-operator --timeout=180s
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"
say "Cluster ready (context $KCTX, namespace $NAMESPACE)"
