output "vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "The ID of the virtual network."
}

output "vnet_name" {
  value       = azurerm_virtual_network.vnet.name
  description = "The name of the virtual network."
}

output "aks_subnet_id" {
  value       = azurerm_subnet.aks.id
  description = "The ID of the AKS subnet."
}

output "db_subnet_id" {
  value       = azurerm_subnet.db.id
  description = "The ID of the PostgreSQL Flexible Server delegated subnet."
}

output "private_dns_zone_id" {
  value       = azurerm_private_dns_zone.postgres.id
  description = "The ID of the private DNS zone for PostgreSQL."
}

output "private_dns_zone_name" {
  value       = azurerm_private_dns_zone.postgres.name
  description = "The name of the private DNS zone for PostgreSQL."
}
