resource "azurerm_container_registry" "acr" {
  name                = "acraleph${var.environment}${substr(md5(var.resource_group_name), 0, 6)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
