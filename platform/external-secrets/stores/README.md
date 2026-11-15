Examples of the ClusterSecretStore named `kuasar` that `components/external-secrets` points at. Copy the one for your cloud, fill the values,
apply it once with kubectl (it is cluster-scoped and holds no secret, so it may live in Git elsewhere). Identity: use workload identity
(IRSA, GKE Workload Identity, Azure Workload Identity), never a long-lived key.

Remote secrets: one per Kubernetes Secret, named `kuasar/<env>/<secret name>`, value a JSON object whose keys are the Secret keys
(docs/SECRETS.md). Example: `kuasar/production/kuasar-identity` = `{"ConnectionStrings__Identity":"...","SecretBox__Key":"..."}`.
