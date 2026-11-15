output "cluster_name" {
  description = "aws eks update-kubeconfig --name <this> --region <region>"
  value       = module.eks.cluster_name
}

output "database_host" {
  value = aws_db_instance.postgres.address
}

output "database_port" {
  value = aws_db_instance.postgres.port
}

output "database_admin_password" {
  value     = random_password.db.result
  sensitive = true
}

output "sandbox_private_ip" {
  value = aws_instance.sandbox.private_ip
}

output "node_network_cidr" {
  value = var.vpc_cidr
}
