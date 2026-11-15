output "cluster_name" {
  description = "gcloud container clusters get-credentials <this> --region <region>"
  value       = google_container_cluster.main.name
}

output "database_host" {
  value = google_sql_database_instance.postgres.private_ip_address
}

output "database_port" {
  value = 5432
}

output "database_admin_password" {
  value     = random_password.db.result
  sensitive = true
}

output "sandbox_private_ip" {
  value = google_compute_instance.sandbox.network_interface[0].network_ip
}

output "node_network_cidr" {
  value = var.subnet_cidr
}
