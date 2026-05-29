resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-aleph-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aksaleph${var.environment}"

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.vm_size
    vnet_subnet_id = var.subnet_id
    os_disk_size_gb = 30
    
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable OIDC Issuer & Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Enable Azure Key Vault Secrets Store CSI Driver
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "5m"
  }

  network_profile {
    network_plugin    = "azure"
    dns_service_ip    = "192.168.0.10"
    service_cidr      = "192.168.0.0/16"
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count, # Ignore autoscale count fluctuations if enabled later
    ]
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Attach ACR to AKS: Grant AcrPull role to the AKS Kubelet Identity
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
