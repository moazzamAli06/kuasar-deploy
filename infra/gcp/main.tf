resource "google_compute_network" "main" {
  name                    = var.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name                     = var.name
  region                   = var.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

resource "google_container_cluster" "main" {
  name                     = var.name
  location                 = var.region
  network                  = google_compute_network.main.id
  subnetwork               = google_compute_subnetwork.main.id
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = true

  datapath_provider = "ADVANCED_DATAPATH" # Dataplane V2: enforces NetworkPolicy

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "default" {
  name     = "default"
  cluster  = google_container_cluster.main.id
  location = var.region

  autoscaling {
    min_node_count = var.min_nodes_per_zone
    max_node_count = var.max_nodes_per_zone
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.node_machine_type
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    shielded_instance_config {
      enable_secure_boot = true
    }
  }
}

# ---- Cloud SQL, private IP only ----
resource "google_compute_global_address" "private_services" {
  name          = "${var.name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "postgres" {
  name                = "${var.name}-pg"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = true

  settings {
    tier              = var.database_tier
    availability_type = "REGIONAL"
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }
  }

  depends_on = [google_service_networking_connection.private]
}

resource "google_sql_user" "admin" {
  name     = "kuasar_admin"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db.result
}

# ---- Sandbox host ----
resource "google_compute_instance" "sandbox" {
  name         = "${var.name}-sandbox"
  machine_type = var.sandbox_machine_type
  zone         = var.zone
  tags         = ["sandbox-host"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    access_config {} # public address for package downloads; inbound is closed by the firewall rules below
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    user-data = file("${path.module}/../sandbox-host/cloud-init.yaml")
  }
}

resource "google_compute_firewall" "sandbox_from_cluster" {
  name          = "${var.name}-sandbox-from-cluster"
  network       = google_compute_network.main.id
  source_ranges = [var.subnet_cidr, var.pods_cidr]
  target_tags   = ["sandbox-host"]

  allow {
    protocol = "tcp"
    ports    = ["8080", "8090"]
  }
}

resource "google_compute_firewall" "sandbox_ssh" {
  name          = "${var.name}-sandbox-ssh"
  network       = google_compute_network.main.id
  source_ranges = var.admin_cidrs
  target_tags   = ["sandbox-host"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# The sandbox host calls the NodePort bridge services on the cluster nodes.
resource "google_compute_firewall" "nodeports_from_sandbox" {
  name        = "${var.name}-nodeports-from-sandbox"
  network     = google_compute_network.main.id
  source_tags = ["sandbox-host"]

  allow {
    protocol = "tcp"
    ports    = ["30101-30103", "30672"]
  }
}
