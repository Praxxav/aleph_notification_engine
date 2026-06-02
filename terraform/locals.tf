locals {
  # Dynamically capture the active Terraform workspace (e.g. dev or prod)
  environment = terraform.workspace

  # Define environment configurations side-by-side (Zero repeated module files!)
  workspace_config = {
    default = {
      location           = "eastus2"
      vnet_address_space = ["10.10.0.0/16"]
      aks_subnet_prefix  = "10.10.0.0/20"
      db_subnet_prefix   = "10.10.16.0/24"
      node_count         = 2
      vm_size            = "Standard_B2s_v2"
      k8s_namespace      = "default"
    }
    dev = {
      location           = "eastus2"
      vnet_address_space = ["10.10.0.0/16"]
      aks_subnet_prefix  = "10.10.0.0/20"
      db_subnet_prefix   = "10.10.16.0/24"
      node_count         = 2
      vm_size            = "Standard_B2s_v2"
      k8s_namespace      = "default"
    }
    prod = {
      location           = "eastus2"
      vnet_address_space = ["10.20.0.0/16"]
      aks_subnet_prefix  = "10.20.0.0/20"
      db_subnet_prefix   = "10.20.16.0/24"
      node_count         = 3
      vm_size            = "Standard_B2s_v2"
      k8s_namespace      = "production" # Separate namespace for production pods
    }
  }

  # Load the config lookup for the current active workspace
  cfg = local.workspace_config[local.environment]
}
