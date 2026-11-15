data "digitalocean_kubernetes_versions" "current" {}

resource "digitalocean_vpc" "main" {
  name     = var.name
  region   = var.region
  ip_range = var.vpc_cidr
}

resource "digitalocean_kubernetes_cluster" "main" {
  name         = var.name
  region       = var.region
  version      = data.digitalocean_kubernetes_versions.current.latest_version
  vpc_uuid     = digitalocean_vpc.main.id
  auto_upgrade = false
  ha           = true

  node_pool {
    name       = "default"
    size       = var.node_size
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
  }
}

resource "digitalocean_database_cluster" "postgres" {
  name                 = "${var.name}-pg"
  engine               = "pg"
  version              = "16"
  size                 = var.database_size
  region               = var.region
  node_count           = 2
  private_network_uuid = digitalocean_vpc.main.id
}

resource "digitalocean_droplet" "sandbox" {
  name       = "${var.name}-sandbox"
  image      = "ubuntu-24-04-x64"
  size       = var.sandbox_size
  region     = var.region
  vpc_uuid   = digitalocean_vpc.main.id
  ssh_keys   = var.ssh_key_fingerprints
  user_data  = file("${path.module}/../sandbox-host/cloud-init.yaml")
  monitoring = true
}

resource "digitalocean_firewall" "sandbox" {
  name        = "${var.name}-sandbox"
  droplet_ids = [digitalocean_droplet.sandbox.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.admin_cidrs
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = [var.vpc_cidr]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8090"
    source_addresses = [var.vpc_cidr]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Managed PostgreSQL accepts connections only from the cluster and the sandbox host.
resource "digitalocean_database_firewall" "postgres" {
  cluster_id = digitalocean_database_cluster.postgres.id

  rule {
    type  = "k8s"
    value = digitalocean_kubernetes_cluster.main.id
  }
  rule {
    type  = "droplet"
    value = digitalocean_droplet.sandbox.id
  }
}
