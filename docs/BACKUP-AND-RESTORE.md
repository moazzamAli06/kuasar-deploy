# Backup and restore

| Data | Where it lives | Backup | Restore |
|---|---|---|---|
| Kubernetes objects | Git | Git itself (this repository) | Argo CD sync |
| PostgreSQL (all service databases) | managed database | the cloud service's automated backups and point-in-time recovery (`infra/` enables them: 14 days on AWS and Azure, PITR on GCP; DigitalOcean daily backups are on by default) | restore to a new instance in the cloud console/CLI, then update the connection strings |
| Project sources (`repos` volume) | PVC | Velero snapshot schedule (`platform/backup`) | Velero restore |
| RabbitMQ | PVC | same Velero schedule; queues are transient work, so losing them is recoverable | Velero restore or re-create |
| Secrets | secret manager or sealed secrets in Git | the secret manager's own versioning; keep the Sealed Secrets controller key in a safe place (without it sealed files cannot be decrypted on a new cluster) | re-apply |
| Sandbox host | VM | nothing to back up: re-create it with `infra/` and the install scripts; its secrets (`/etc/kuasar/sandbox.env`) must be stored elsewhere | rebuild |

## Velero
Install Velero with your cloud's object storage and snapshot plugin (chart `velero`, https://vmware-tanzu.github.io/helm-charts), then apply `argocd/addons-optional.yaml` (`backup-schedules`). Velero's cloud-specific setup (bucket, workload identity, plugin) is not in this repository because it differs per cloud and per account: follow Velero's provider guide.

## Restore drill (do this before go-live, then every quarter)
1. In a scratch cluster, install Velero against the same bucket.
2. `velero backup get`, then `velero restore create --from-backup <name> --namespace-mappings kuasar-production:kuasar-restore-test`.
3. Restore the database to a new instance from a point in time and point a test environment at it.
4. Write down how long it took and what was missing.

## Recovery targets
Define them with the business and record them here: RPO (how much data you may lose) and RTO (how long you may be down). The defaults above give a database RPO of minutes (PITR), a volume RPO of 24 hours (daily schedule) and an RTO that you only know after the drill.
