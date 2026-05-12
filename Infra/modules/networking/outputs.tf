output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = azurerm_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = azurerm_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of database subnets"
  value       = azurerm_subnet.database[*].id
}

output "bastion_subnet_id" {
  description = "ID of the Bastion subnet"
  value       = azurerm_subnet.bastion.id
}

output "public_nsg_id" {
  description = "ID of the public Network Security Group"
  value       = azurerm_network_security_group.public.id
}

output "private_nsg_id" {
  description = "ID of the private Network Security Group"
  value       = azurerm_network_security_group.private.id
}

output "database_nsg_id" {
  description = "ID of the database Network Security Group"
  value       = azurerm_network_security_group.database.id
}

output "bastion_host_name" {
  description = "Name of the Bastion Host"
  value       = azurerm_bastion_host.main.name
}

output "appgw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw.id
}
