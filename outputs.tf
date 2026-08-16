# outputs.tf (root module)

output "vpc_name" {
  value = module.network.network_name
}

output "subnet_name" {
  value = module.network.subnet_name
}

output "vm_service_account_email" {
  value = module.service_account.email
}

output "mig_name" {
  value       = module.vm.mig_name
  description = "Name of the Managed Instance Group backing the application."
}

output "load_balancer_ip" {
  value       = module.load_balancer.lb_ip_address
  description = "Public IP address of the external HTTP Load Balancer. Point DNS here."
}

output "cloud_sql_connection_name" {
  value       = module.database.instance_connection_name
  description = "Cloud SQL instance connection name, used by the Cloud SQL Auth Proxy."
}

output "cloud_sql_private_ip" {
  value     = module.database.private_ip_address
  sensitive = true
}
