output "vmss_id" {
  description = "ID of the Virtual Machine Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.vmss.id
}

output "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.vmss.name
}

output "application_gateway_id" {
  description = "ID of the Application Gateway (frontend only)"
  value       = var.is_frontend ? azurerm_application_gateway.frontend[0].id : null
}

output "application_gateway_name" {
  description = "Name of the Application Gateway (frontend only)"
  value       = var.is_frontend ? azurerm_application_gateway.frontend[0].name : null
}

output "load_balancer_id" {
  description = "ID of the Load Balancer (backend only)"
  value       = var.is_frontend ? null : azurerm_lb.backend[0].id
}

output "load_balancer_name" {
  description = "Name of the Load Balancer (backend only)"
  value       = var.is_frontend ? null : azurerm_lb.backend[0].name
}

output "load_balancer_private_ip" {
  description = "Private IP address of the internal Load Balancer (backend only)"
  value       = var.is_frontend ? null : azurerm_lb.backend[0].private_ip_address
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway (frontend only)"
  value       = var.is_frontend ? azurerm_public_ip.lb[0].ip_address : null
}

output "ssh_private_key" {
  description = "Private key for SSH access to the VMs (for administrative purpose only)"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "identity_principal_id" {
  description = "Principal ID of the Managed Identity"
  value       = azurerm_user_assigned_identity.vmss_identity.principal_id
}

output "managed_identity_id" {
  description = "ID of the User Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.vmss_identity.id
}
