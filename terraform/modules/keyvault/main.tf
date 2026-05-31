data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-aleph-${var.environment}-${substr(md5(var.resource_group_name), 0, 6)}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Grant the deploying user/service principal "Key Vault Administrator" access to manage secrets
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait 30 seconds for the role assignment to propagate globally in Azure AD
resource "time_sleep" "wait_for_rbac" {
  depends_on      = [azurerm_role_assignment.deployer_kv_admin]
  create_duration = "30s"
}
