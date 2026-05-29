output "api_client_id" {
  value       = azurerm_user_assigned_identity.api.client_id
  description = "The client ID of the user-assigned identity for the API."
}

output "worker_client_id" {
  value       = azurerm_user_assigned_identity.worker.client_id
  description = "The client ID of the user-assigned identity for the worker."
}
