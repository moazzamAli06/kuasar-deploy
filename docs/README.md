# Documentation index

| I want to... | Read |
|---|---|
| Understand how the pieces fit | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Run the app on my laptop | [LOCAL.md](LOCAL.md) (overview), then [macOS](LOCAL-MACOS.md), [Linux](LOCAL-LINUX.md) or [Windows](LOCAL-WINDOWS.md) |
| Deploy to a cloud | the guide for your cloud: [DigitalOcean](clouds/digitalocean.md), [AWS](clouds/aws.md), [Google Cloud](clouds/gcp.md), [Azure](clouds/azure.md) |
| Ship or roll back a release | [RELEASE-AND-ROLLBACK.md](RELEASE-AND-ROLLBACK.md) |
| Upgrade Kubernetes, Argo CD, kind or the RabbitMQ operator | [UPGRADING.md](UPGRADING.md) |
| Know which secrets exist | [SECRETS.md](SECRETS.md) |
| Set up the machine that runs customer code | [SANDBOX-HOST.md](SANDBOX-HOST.md) |
| Create the cloud infrastructure with code | [../infra/README.md](../infra/README.md) |
| Review security controls | [SECURITY.md](SECURITY.md) |
| Add monitoring and alerts | [OBSERVABILITY.md](OBSERVABILITY.md) |
| Scale, spread over zones, or use an ingress instead of Cloudflare | [SCALING-AND-INGRESS.md](SCALING-AND-INGRESS.md) |
| Back up and restore | [BACKUP-AND-RESTORE.md](BACKUP-AND-RESTORE.md) |

Where each thing runs:

| Target | Overlay | Cloud component | Secrets |
|---|---|---|---|
| Laptop (macOS, Linux, Windows WSL2) | `overlays/local` | `components/cloud-kind` | plain Secrets from `local/secrets.sh` |
| Staging / production on DigitalOcean | `overlays/staging`, `overlays/production` | `components/cloud-do` | Sealed Secrets |
| Another cloud | your own `overlays/<env>-<cloud>` (see the cloud guide) | `components/cloud-aws`, `-gcp` or `-azure` | Sealed Secrets (or an external secret store) |
