# Infrastructure (OpenTofu)

One root module per cloud. Each creates: a private network, a managed Kubernetes cluster with a node pool, a managed PostgreSQL, and the **sandbox host** VM (Docker + gVisor, see [../docs/SANDBOX-HOST.md](../docs/SANDBOX-HOST.md)). They are independent: use only the clouds you deploy to.

| Folder | Cluster | PostgreSQL | Sandbox host | Cloud component to use |
|---|---|---|---|---|
| `digitalocean/` | DOKS | Managed Databases (port 25060) | Droplet | `components/cloud-do` |
| `aws/` | EKS | RDS | EC2 | `components/cloud-aws` |
| `gcp/` | GKE (Dataplane V2) | Cloud SQL (private IP) | Compute Engine | `components/cloud-gcp` |
| `azure/` | AKS (Cilium) | PostgreSQL Flexible Server | Linux VM | `components/cloud-azure` |

```bash
cd infra/<cloud>
tofu init
tofu plan -var-file=prod.tfvars     # copy terraform.tfvars.example to prod.tfvars first
tofu apply -var-file=prod.tfvars
tofu output                         # values to put into the overlay: sandbox_private_ip, node_network_cidr, database host and port
```

State: use a remote backend with locking (S3 + DynamoDB, GCS, Azure Blob, or DigitalOcean Spaces) and add a `backend` block; local state is only for trying things out. Never commit `*.tfvars` or state (`.gitignore` covers them).

Status: these modules are written to current provider documentation but have **not been applied** to a real account. CI runs `tofu fmt -check` and `tofu validate` on each (`.github/workflows/infra.yml`). Run `tofu plan` and review it before the first apply; costs start when you apply.

Not covered: DNS, Cloudflare tunnel and its secrets, the container registry, and the sandbox host's application files (those come from the `kuasarai` repository).
