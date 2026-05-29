output "aks_id" {
  value       = azurerm_kubernetes_cluster.aks.id
  description = "The ID of the AKS cluster."
}

output "aks_name" {
  value       = azurerm_kubernetes_cluster.aks.name
  description = "The name of the AKS cluster."
}

output "oidc_issuer_url" {
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  description = "The OIDC issuer URL of the AKS cluster."
}

output "kube_config_raw" {
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
  description = "The raw kubeconfig content."
}

output "csi_secret_identity_object_id" {
  value       = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id
  description = "The principal (object) ID of the User Assigned Identity created by AKS for the Secrets Store CSI Driver."
}
