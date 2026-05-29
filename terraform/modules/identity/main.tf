# User-Assigned Managed Identity for the API Workload
resource "azurerm_user_assigned_identity" "api" {
  name                = "id-aleph-${var.environment}-api"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# User-Assigned Managed Identity for the Worker Workload
resource "azurerm_user_assigned_identity" "worker" {
  name                = "id-aleph-${var.environment}-worker"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# --- Role Assignments: Key Vault Secrets User ---

resource "azurerm_role_assignment" "api_kv_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

resource "azurerm_role_assignment" "worker_kv_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

# Crucial: Allow the AKS Key Vault CSI Secrets Provider driver identity to read secrets to sync them
resource "azurerm_role_assignment" "csi_kv_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.csi_secret_identity_object_id
}

# --- Role Assignments: Storage Queue Access ---

# API needs to send messages to the queue
resource "azurerm_role_assignment" "api_queue_sender" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Message Sender"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Worker needs to read, delete and process messages from the queue
resource "azurerm_role_assignment" "worker_queue_processor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Queue Data Message Processor"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

# Worker also needs "Storage Blob Data Reader" or general reader permissions to see Storage Queue metadata if needed (Processor covers it, but general account access is good)
resource "azurerm_role_assignment" "worker_queue_reader" {
  scope                = var.storage_account_id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

resource "azurerm_role_assignment" "api_queue_reader" {
  scope                = var.storage_account_id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# --- Federated Identity Credentials for Workload Identity ---

resource "azurerm_federated_identity_credential" "api" {
  name                = "fed-aleph-${var.environment}-api"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.api.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.k8s_namespace}:notification-api"
}

resource "azurerm_federated_identity_credential" "worker" {
  name                = "fed-aleph-${var.environment}-worker"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.worker.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.k8s_namespace}:notification-worker"
}
