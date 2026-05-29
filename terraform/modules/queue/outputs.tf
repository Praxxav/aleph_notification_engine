output "storage_account_id" {
  value       = azurerm_storage_account.storage.id
  description = "The ID of the storage account."
}

output "storage_account_name" {
  value       = azurerm_storage_account.storage.name
  description = "The name of the storage account."
}

output "storage_queue_name" {
  value       = azurerm_storage_queue.queue.name
  description = "The name of the notifications queue."
}

output "queue_account_url" {
  value       = azurerm_storage_account.storage.primary_queue_endpoint
  description = "The primary queue service endpoint URL."
}
