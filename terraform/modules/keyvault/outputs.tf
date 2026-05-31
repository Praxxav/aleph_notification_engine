output "key_vault_id" {
  value       = azurerm_key_vault.kv.id
  depends_on  = [time_sleep.wait_for_rbac]
  description = "The ID of the Key Vault."
}

output "key_vault_name" {
  value       = azurerm_key_vault.kv.name
  description = "The name of the Key Vault."
}

output "key_vault_uri" {
  value       = azurerm_key_vault.kv.vault_uri
  description = "The URI of the Key Vault."
}
