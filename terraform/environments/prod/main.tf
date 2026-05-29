resource "azurerm_resource_group" "rg" {
  name     = "rg-aleph-notification-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "azurerm_client_config" "current" {}

module "vnet" {
  source              = "../../modules/vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
  vnet_address_space  = var.vnet_address_space
  aks_subnet_prefix   = var.aks_subnet_prefix
  db_subnet_prefix    = var.db_subnet_prefix
}

module "acr" {
  source              = "../../modules/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
}

module "keyvault" {
  source              = "../../modules/keyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

module "db" {
  source              = "../../modules/db"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
  subnet_id           = module.vnet.db_subnet_id
  private_dns_zone_id = module.vnet.private_dns_zone_id
  key_vault_id        = module.keyvault.key_vault_id
}

module "queue" {
  source              = "../../modules/queue"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
}

module "aks" {
  source              = "../../modules/aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
  subnet_id           = module.vnet.aks_subnet_id
  acr_id              = module.acr.acr_id
  node_count          = var.node_count
  vm_size             = var.vm_size
}

module "identity" {
  source                        = "../../modules/identity"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  environment                   = var.environment
  key_vault_id                  = module.keyvault.key_vault_id
  storage_account_id            = module.queue.storage_account_id
  oidc_issuer_url               = module.aks.oidc_issuer_url
  csi_secret_identity_object_id = module.aks.csi_secret_identity_object_id
  k8s_namespace                 = "production" # Exposing namespaces parameter
}
