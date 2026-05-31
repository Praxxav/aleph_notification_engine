output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the resource group."
}

output "aks_cluster_name" {
  value       = module.aks.aks_name
  description = "The name of the AKS cluster."
}

output "acr_login_server" {
  value       = module.acr.login_server
  description = "The ACR login server URL."
}

output "key_vault_uri" {
  value       = module.keyvault.key_vault_uri
  description = "The Key Vault URI."
}

output "key_vault_name" {
  value       = module.keyvault.key_vault_name
  description = "The Key Vault Name."
}

output "storage_account_name" {
  value       = module.queue.storage_account_name
  description = "The name of the storage account."
}

output "queue_account_url" {
  value       = module.queue.queue_account_url
  description = "The primary queue service endpoint URL."
}

output "api_managed_identity_client_id" {
  value       = module.identity.api_client_id
  description = "The client ID of the API managed identity."
}

output "worker_managed_identity_client_id" {
  value       = module.identity.worker_client_id
  description = "The client ID of the worker managed identity."
}
