resource "azurerm_resource_group" "rg" {
  name     = "rg-aleph-notification-${local.environment}"
  location = local.cfg.location

  tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

data "azurerm_client_config" "current" {}

# DRY Module Execution — All modules are reusable blocks imported once!
# Zero repetition of environment-specific code.

module "vnet" {
  source              = "./modules/vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = local.environment
  vnet_address_space  = local.cfg.vnet_address_space
  aks_subnet_prefix   = local.cfg.aks_subnet_prefix
  db_subnet_prefix    = local.cfg.db_subnet_prefix
}

module "acr" {
  source              = "./modules/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = local.environment
}

module "keyvault" {
  source              = "./modules/keyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = local.environment
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

module "db" {
  source              = "./modules/db"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = local.environment
  subnet_id           = module.vnet.db_subnet_id
  private_dns_zone_id = module.vnet.private_dns_zone_id
  key_vault_id        = module.keyvault.key_vault_id
}

module "queue" {
  source              = "./modules/queue"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = local.environment
}

module "aks" {
  source              = "./modules/aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = local.environment
  subnet_id           = module.vnet.aks_subnet_id
  acr_id              = module.acr.acr_id
  node_count          = local.cfg.node_count
  vm_size             = local.cfg.vm_size
}

module "identity" {
  source                        = "./modules/identity"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  environment                   = local.environment
  key_vault_id                  = module.keyvault.key_vault_id
  storage_account_id            = module.queue.storage_account_id
  oidc_issuer_url               = module.aks.oidc_issuer_url
  csi_secret_identity_object_id = module.aks.csi_secret_identity_object_id
  k8s_namespace                 = local.cfg.k8s_namespace
}
