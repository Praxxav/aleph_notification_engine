resource "azurerm_storage_account" "storage" {
  name                     = "staleph${var.environment}${substr(md5(var.resource_group_name), 0, 6)}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Enforce identity-based access only
  shared_access_key_enabled = false
  public_network_access_enabled = true # Can be locked down to subnets later

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_storage_queue" "queue" {
  name                 = "notifications"
  storage_account_name = azurerm_storage_account.storage.name
}
