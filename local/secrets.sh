#!/usr/bin/env bash
# Creates every Secret the app needs in the local namespace. Values are never printed or committed.
#   local/secrets.sh [path/to/env-file]     default: local/.env.local (created by local/make-env.sh if missing)
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ENV_FILE="${1:-$LOCAL_DIR/.env.local}"
NS=$NAMESPACE
if [ ! -f "$ENV_FILE" ]; then
  [ "$ENV_FILE" = "$LOCAL_DIR/.env.local" ] || die "no env file at $ENV_FILE"
  "$LOCAL_DIR/make-env.sh" >/dev/null
fi
use_context
kubectl get ns $NS >/dev/null 2>&1 || kubectl create ns $NS
set -a; . "$ENV_FILE"; set +a

need() { for v in "$@"; do [ -n "${!v:-}" ] || { echo "$v is empty in $ENV_FILE"; exit 1; }; done; }
need POSTGRES_PASSWORD INTERNAL_SERVICE_KEY SECRETBOX_KEY RABBITMQ_USER RABBITMQ_PASSWORD JWT_KEY_ID JWT_PRIVATE_KEY_BASE64 JWT_PUBLIC_KEY_BASE64 \
     AUDIT_EXPORT_SIGNING_KEY BILLING_WEBHOOK_SECRET AI_CREDENTIALS_KEY

# secret NAME key=value ...   (applies idempotently; values go through stdin-less --from-literal and are never echoed)
secret() { local name=$1; shift; local args=(); for kv in "$@"; do args+=(--from-literal="$kv"); done
  kubectl -n $NS create secret generic "$name" "${args[@]}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null; echo "secret/$name"; }
cs() { # <Name> <svc> <owner|app>
  local up; up=$(echo "$2" | tr a-z A-Z); local pw="DB_${up}_$(echo "$3" | tr a-z A-Z)_PASSWORD"
  echo "Host=postgres;Database=kuasar_$2;Username=$2_$3;Password=${!pw};GSS Encryption Mode=Disable"; }

# Postgres bootstrap: superuser + the 16 role passwords read by init-databases.sh
pg=("POSTGRES_PASSWORD=$POSTGRES_PASSWORD")
for s in IDENTITY ORGANIZATION PROJECT AUDIT PLATFORM AI SANDBOX BILLING; do
  for r in OWNER APP; do v="DB_${s}_${r}_PASSWORD"; need "$v"; pg+=("$v=${!v}"); done
done
secret postgres-init "${pg[@]}"

# RabbitMQ default user (must exist BEFORE the cluster so the operator uses it)
secret rabbitmq-default-user "username=$RABBITMQ_USER" "password=$RABBITMQ_PASSWORD"

secret kuasar-shared "Internal__ServiceKey=$INTERNAL_SERVICE_KEY" "RabbitMq__Username=$RABBITMQ_USER" "RabbitMq__Password=$RABBITMQ_PASSWORD" \
  "Jwt__VerificationKeys__0__KeyId=$JWT_KEY_ID" "Jwt__VerificationKeys__0__PublicKeyBase64=$JWT_PUBLIC_KEY_BASE64"
secret kuasar-ai-orchestrator "INTERNAL_SERVICE_KEY=$INTERNAL_SERVICE_KEY"

secret kuasar-identity "ConnectionStrings__Identity=$(cs Identity identity app)" "SecretBox__Key=$SECRETBOX_KEY" \
  "Jwt__KeyId=$JWT_KEY_ID" "Jwt__PrivateKeyBase64=$JWT_PRIVATE_KEY_BASE64" \
  "Platform__AdminEmail=${PLATFORM_ADMIN_EMAIL:-}" "Platform__AdminInitialPassword=${PLATFORM_ADMIN_INITIAL_PASSWORD:-}" \
  "Auth__External__StateKey=${AUTH_EXTERNAL_STATE_KEY:-local-state-key-not-for-production}"
secret kuasar-organization "ConnectionStrings__Organization=$(cs Organization organization app)"
secret kuasar-project "ConnectionStrings__Project=$(cs Project project app)" "SecretBox__Key=$SECRETBOX_KEY" "GitHub__StateKey=${GITHUB_STATE_KEY:-local-state-key-not-for-production}"
secret kuasar-audit "ConnectionStrings__Audit=$(cs Audit audit app)" "Audit__Export__SigningKey=$AUDIT_EXPORT_SIGNING_KEY"
secret kuasar-ai "ConnectionStrings__Ai=$(cs Ai ai app)" "AiCredentials__Key=$AI_CREDENTIALS_KEY"
secret kuasar-billing "ConnectionStrings__Billing=$(cs Billing billing app)" "Billing__WebhookSecret=$BILLING_WEBHOOK_SECRET"
secret kuasar-platform "ConnectionStrings__Platform=$(cs Platform platform app)"

# Migration Jobs use the database OWNER login; the running services never see it.
secret kuasar-identity-migrate "ConnectionStrings__Identity=$(cs Identity identity owner)"
secret kuasar-organization-migrate "ConnectionStrings__Organization=$(cs Organization organization owner)"
secret kuasar-project-migrate "ConnectionStrings__Project=$(cs Project project owner)"
secret kuasar-audit-migrate "ConnectionStrings__Audit=$(cs Audit audit owner)"
secret kuasar-ai-migrate "ConnectionStrings__Ai=$(cs Ai ai owner)"
secret kuasar-billing-migrate "ConnectionStrings__Billing=$(cs Billing billing owner)"
secret kuasar-platform-migrate "ConnectionStrings__Platform=$(cs Platform platform owner)"
secret kuasar-sandbox-migrate "ConnectionStrings__Sandbox=$(cs Sandbox sandbox owner)"
echo "done. Secrets exist only in the local cluster."
