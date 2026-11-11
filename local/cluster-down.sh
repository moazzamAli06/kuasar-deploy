#!/usr/bin/env bash
# Removes the local cluster (all data in it is lost) and the optional registry.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
kind delete cluster --name "$CLUSTER_NAME"
docker rm -f kind-registry >/dev/null 2>&1 || true
