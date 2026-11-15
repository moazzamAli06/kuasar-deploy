# Release and rollback

## Release flow
1. The app repo's CI builds, scans and signs images, then opens a pull request here that sets new digests in `overlays/staging` (`tools/set-digest.py`). Check passes (`check.yml`), merge: Argo CD deploys staging automatically.
2. Verify staging (health, a smoke test, the migration Jobs finished).
3. Run the app repo's **promote** workflow: it opens a pull request that copies staging's digests to `overlays/production` (`tools/promote.py`). Review and merge.
4. A release manager presses Sync on `kuasar-production` (or `argocd app sync kuasar-production`).
5. `sync-local.yml` refreshes branch `local` from `main`, so laptops receive the staging digests.

## Rollback
- **Normal:** revert the digest commit in Git and sync. Git stays the source of truth.
- **Emergency:** `argocd app rollback kuasar-production <id>`, then revert in Git straight away so Argo CD does not drift back.
- Never `kubectl edit` a running environment.

## Database migrations
Migrations run as Argo Sync hooks (wave 1) before the services update. **A rollback does not undo a schema change.** So every migration must be backward compatible with the previous release (expand, deploy, then contract in a later release): add columns as nullable, never rename or drop in the same release that stops using them.

## Failure behaviour
- A failing migration Job stops the sync before any service changes (the `activeDeadlineSeconds` is 600 s).
- Secrets must exist before the first sync; the Jobs and Deployments refuse to start without them ([SECRETS.md](SECRETS.md)).
- Production never syncs on its own, so a merged digest change waits for a person.

## Updating platform pieces
Argo CD, the RabbitMQ operator, Sealed Secrets and the kind node image are pinned (procedure and known breaking changes: [UPGRADING.md](UPGRADING.md)) (`local/versions.env`, `argocd/addons.yaml`, `platform/`). Renovate opens pull requests for them (`renovate.json`). Test an upgrade on a clean local cluster (`local/bootstrap.sh`, or the **smoke** workflow) and on staging before production.
