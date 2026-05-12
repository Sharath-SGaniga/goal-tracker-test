output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = module.networking.vnet_id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = module.networking.vnet_name
}

output "frontend_public_ip" {
  description = "The public IP address of the Application Gateway"
  value       = var.deploy_compute ? module.frontend[0].public_ip_address : "Compute resources not deployed"
}

output "application_gateway_name" {
  description = "The name of the Application Gateway"
  value       = var.deploy_compute ? module.frontend[0].application_gateway_name : "Compute resources not deployed"
}

output "backend_internal_lb_ip" {
  description = "The private IP address of the internal load balancer"
  value       = var.deploy_compute ? module.backend[0].load_balancer_private_ip : "Compute resources not deployed"
}

output "postgres_server_name" {
  description = "The name of the PostgreSQL server"
  value       = module.database.server_name
}

output "postgres_server_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL server"
  value       = module.database.server_fqdn
}

output "postgres_replica_name" {
  description = "The name of the PostgreSQL replica server"
  value       = module.database.replica_name
}

output "postgres_admin_username" {
  description = "The administrator username of the PostgreSQL server"
  value       = module.database.administrator_login
  sensitive   = true
}

output "postgres_admin_password" {
  description = "The administrator password of the PostgreSQL server"
  value       = module.database.administrator_password
  sensitive   = true
}

output "postgres_database_name" {
  description = "The name of the PostgreSQL database"
  value       = module.database.database_name
}

output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = module.keyvault.key_vault_uri
}

output "private_dns_zone_name" {
  description = "The name of the private DNS zone"
  value       = module.dns.private_dns_zone_name
}

output "frontend_vmss_id" {
  description = "The ID of the frontend Virtual Machine Scale Set"
  value       = var.deploy_compute ? module.frontend[0].vmss_id : "Compute resources not deployed"
}

output "backend_vmss_id" {
  description = "The ID of the backend Virtual Machine Scale Set"
  value       = var.deploy_compute ? module.backend[0].vmss_id : "Compute resources not deployed"
}

output "bastion_host_name" {
  description = "The name of the Bastion Host"
  value       = module.networking.bastion_host_name
}

output "frontend_ssh_private_key" {
  description = "Private key for SSH access to the frontend VMs"
  value       = var.deploy_compute ? module.frontend[0].ssh_private_key : null
  sensitive   = true
}

output "backend_ssh_private_key" {
  description = "Private key for SSH access to the backend VMs"
  value       = var.deploy_compute ? module.backend[0].ssh_private_key : null
  sensitive   = true
}

output "frontend_url" {
  description = "The URL of the frontend application"
  value       = var.deploy_compute ? "http://${module.frontend[0].public_ip_address}" : "Frontend not deployed"
}

output "backend_load_balancer_ip" {
  description = "The private IP address of the backend load balancer"
  value       = var.deploy_compute ? module.backend[0].load_balancer_private_ip : "Backend not deployed"
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "keyvault_id" {
  description = "The ID of the Key Vault"
  value       = module.keyvault.key_vault_id
}
