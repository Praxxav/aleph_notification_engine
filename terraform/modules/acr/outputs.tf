output "acr_id" {
  value       = azurerm_container_registry.acr.id
  description = "The ID of the Azure Container Registry."
}

output "acr_name" {
  value       = azurerm_container_registry.acr.name
  description = "The name of the Azure Container Registry."
}

output "login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "The login server URL for the Azure Container Registry."
}
