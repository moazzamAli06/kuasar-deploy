# Secrets each environment needs

Nothing here goes into Git in plain text. Create each Secret locally, seal it with `tools/seal-secrets.sh`, commit the sealed file under `overlays/<env>/sealed/`, and list it in that folder's `kustomization.yaml`.

Create the namespace's secrets BEFORE the first sync: the migration Jobs and Deployments refuse to start without them.

## `cloudflared`

| Key | Required | Note |
|---|---|---|
| `TUNNEL_TOKEN` | yes | from the Cloudflare Zero Trust tunnel; hostnames are routed in the Cloudflare dashboard |

## `dockerhub-pull`

| Key | Required | Note |
|---|---|---|
| `.dockerconfigjson` | yes | type kubernetes.io/dockerconfigjson, read-only Docker Hub token |

## `kuasar-ai`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Ai` | yes |  |
| `AiCredentials__Key` | yes |  |
| `AI_ECONOMY_API_KEY` | only if the feature is used |  |
| `AI_STRONG_API_KEY` | only if the feature is used |  |
| `AI_OPENAI_ECONOMY_API_KEY` | only if the feature is used |  |
| `AI_OPENAI_STRONG_API_KEY` | only if the feature is used |  |

## `kuasar-ai-migrate`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Ai` | yes | database OWNER login, used only by the migrate Job |

## `kuasar-ai-orchestrator`

| Key | Required | Note |
|---|---|---|
| `INTERNAL_SERVICE_KEY` | yes | same value as Internal__ServiceKey in kuasar-shared |

## `kuasar-audit`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Audit` | yes |  |
| `Audit__Export__SigningKey` | yes |  |

## `kuasar-audit-migrate`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Audit` | yes | database OWNER login, used only by the migrate Job |

## `kuasar-billing`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Billing` | yes |  |
| `Billing__WebhookSecret` | yes |  |
| `Billing__StripeSecretKey` | only if the feature is used |  |

## `kuasar-billing-migrate`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Billing` | yes | database OWNER login, used only by the migrate Job |

## `kuasar-identity`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Identity` | yes |  |
| `SecretBox__Key` | yes |  |
| `Platform__AdminInitialPassword` | only if the feature is used |  |
| `Jwt__KeyId` | yes |  |
| `Jwt__PrivateKeyBase64` | yes |  |
| `Email__ResendApiKey` | only if the feature is used |  |
| `Auth__External__StateKey` | only if the feature is used |  |
| `Auth__External__Google__ClientId` | only if the feature is used |  |
| `Auth__External__Google__ClientSecret` | only if the feature is used |  |
| `Auth__External__Microsoft__ClientId` | only if the feature is used |  |
| `Auth__External__Microsoft__ClientSecret` | only if the feature is used |  |

## `kuasar-identity-migrate`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Identity` | yes | database OWNER login, used only by the migrate Job |

## `kuasar-organization`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Organization` | yes |  |
| `Email__ResendApiKey` | only if the feature is used |  |

## `kuasar-organization-migrate`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Organization` | yes | database OWNER login, used only by the migrate Job |

## `kuasar-platform`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Platform` | yes |  |

## `kuasar-platform-migrate`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Platform` | yes | database OWNER login, used only by the migrate Job |

## `kuasar-project`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Project` | yes |  |
| `SecretBox__Key` | yes |  |
| `GitHub__AppId` | only if the feature is used |  |
| `GitHub__AppSlug` | only if the feature is used |  |
| `GitHub__ClientId` | only if the feature is used |  |
| `GitHub__ClientSecret` | only if the feature is used |  |
| `GitHub__PrivateKeyBase64` | only if the feature is used |  |
| `GitHub__StateKey` | only if the feature is used |  |

## `kuasar-project-migrate`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Project` | yes | database OWNER login, used only by the migrate Job |

## `kuasar-sandbox` (NOT USED IN THE CLUSTER: these values go in `/etc/kuasar/sandbox.env` on the execution host, see SANDBOX-HOST.md)

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Sandbox` | yes |  |
| `Sandbox__PreviewKey` | only if the feature is used |  |

## `kuasar-sandbox-migrate`

| Key | Required | Note |
|---|---|---|
| `ConnectionStrings__Sandbox` | yes | database OWNER login, used only by the migrate Job |

## `kuasar-shared`

| Key | Required | Note |
|---|---|---|
| `Internal__ServiceKey` | yes |  |
| `RabbitMq__Username` | yes |  |
| `RabbitMq__Password` | yes |  |
| `Jwt__VerificationKeys__0__KeyId` | yes |  |
| `Jwt__VerificationKeys__0__PublicKeyBase64` | yes |  |
| `OTEL_EXPORTER_OTLP_HEADERS` | only if the feature is used |  |

## `rabbitmq-default-user`

| Key | Required | Note |
|---|---|---|
| `username` | yes | must equal RabbitMq__Username |
| `password` | yes | must equal RabbitMq__Password; create BEFORE the cluster so the operator uses it |

## Local environment (`kuasar-local`)

Not sealed: `local/secrets.sh` creates these as plain Secrets from `local/.env.local` (generated by `local/make-env.sh`). Same names and keys as above, plus `postgres-init` (the Postgres superuser password and the 16 `DB_<SERVICE>_OWNER/APP_PASSWORD` values read by `init-databases.sh`), and `rabbitmq-default-user`. There is no `cloudflared`, `dockerhub-pull` (images are public) or `kuasar-sandbox` secret locally. The Argo CD repository credential (`repo-kuasar-deploy` in namespace `argocd`) holds the read-only GitHub token you typed at install. Nothing is committed.
