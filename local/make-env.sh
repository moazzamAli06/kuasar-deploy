#!/usr/bin/env bash
# Creates local/.env.local (or tops it up) with freshly generated secrets for local development.
# It only ADDS values that are missing; anything already in .env.local is left exactly as it is.
#   usage: local/make-env.sh   (writes local/.env.local, git-ignored; local-only values, never reuse them elsewhere)
set -euo pipefail
cd "$(dirname "$0")"
touch .env.local
have() { grep -q "^$1=" .env.local; }
add()  { have "$1" || { echo "$1=$2" >> .env.local; echo "  added $1"; }; }
rand() { openssl rand -hex "${1:-16}"; }

echo "Checking .env.local ..."
add POSTGRES_PASSWORD            "$(rand)"
add INTERNAL_SERVICE_KEY         "$(rand 24)"
add SECRETBOX_KEY                "$(openssl rand -base64 32)"
add AI_CREDENTIALS_KEY          "$(openssl rand -base64 32)"
add AUDIT_EXPORT_SIGNING_KEY      "$(openssl rand -hex 32)"
add BILLING_WEBHOOK_SECRET        "$(openssl rand -hex 32)"
add AUTH_EXTERNAL_STATE_KEY       "$(rand 24)"   # signs Google / Microsoft / company sign-in; harmless while those are off
add GITHUB_STATE_KEY             "$(rand 24)"   # signs the GitHub connect flow; harmless while the GitHub App is off
add RABBITMQ_USER                "kuasar"
add RABBITMQ_PASSWORD            "$(rand)"

ai_credentials_key=$(sed -n 's/^AI_CREDENTIALS_KEY=//p' .env.local | tail -n 1)
ai_credentials_key_length=$(printf '%s' "$ai_credentials_key" | openssl base64 -d -A 2>/dev/null | wc -c | tr -d ' ')
if [[ ! "$ai_credentials_key" =~ ^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$ ]] || [ "$ai_credentials_key_length" != 32 ]; then
  echo "ERROR: AI_CREDENTIALS_KEY must be base64 encoding exactly 32 random bytes." >&2
  echo "The existing value was preserved. Replace it manually only if no stored provider credentials depend on it." >&2
  exit 1
fi

# One database owner (migrations only) and one app role (runtime only) per service.
for svc in IDENTITY ORGANIZATION PROJECT AUDIT PLATFORM AI SANDBOX BILLING; do
  add "DB_${svc}_OWNER_PASSWORD" "$(rand)"
  add "DB_${svc}_APP_PASSWORD"   "$(rand)"
done

# Access-token signing: an ECDSA P-256 key pair. The PRIVATE key goes to identity-service only; everybody verifies with theA PUBLIC key.
if ! have JWT_PRIVATE_KEY_BASE64; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  openssl ecparam -name prime256v1 -genkey -noout -out "$tmp/private.pem" 2>/dev/null
  openssl ec -in "$tmp/private.pem" -pubout -out "$tmp/public.pem" 2>/dev/null
  add JWT_KEY_ID               "k1"
  add JWT_PRIVATE_KEY_BASE64   "$(base64 < "$tmp/private.pem" | tr -d '\n')"
  add JWT_PUBLIC_KEY_BASE64    "$(base64 < "$tmp/public.pem" | tr -d '\n')"
fi

# Optional: who becomes platform operator on first start (still has to enrol MFA before the admin API lets them in).
have PLATFORM_ADMIN_EMAIL || echo "  (PLATFORM_ADMIN_EMAIL / PLATFORM_ADMIN_INITIAL_PASSWORD not set - no platform admin will be created)"
echo "Done. .env.local is git-ignored; never commit it."
