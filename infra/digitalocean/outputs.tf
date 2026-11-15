output "kubeconfig" {
  value     = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive = true
}

output "database_host" {
  description = "Private host name; goes into the ConnectionStrings secrets."
  value       = digitalocean_database_cluster.postgres.private_host
}

output "database_port" {
  value = digitalocean_database_cluster.postgres.port
}

output "database_admin_password" {
  value     = digitalocean_database_cluster.postgres.password
  sensitive = true
}

output "sandbox_private_ip" {
  description = "overlays/<env>: EndpointSlice address and sandbox-host-egress cidr (/32)."
  value       = digitalocean_droplet.sandbox.ipv4_address_private
}

output "node_network_cidr" {
  description = "overlays/<env>: sandbox-host-ingress cidr."
  value       = var.vpc_cidr
}
