output "cluster_name" {
  description = "az aks get-credentials --resource-group <name> --name <this>"
  value       = azurerm_kubernetes_cluster.main.name
}

output "database_host" {
  value = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "database_port" {
  value = 5432
}

output "database_admin_password" {
  value     = random_password.db.result
  sensitive = true
}

output "sandbox_private_ip" {
  value = azurerm_network_interface.sandbox.private_ip_address
}

output "node_network_cidr" {
  value = var.vnet_cidr
}
