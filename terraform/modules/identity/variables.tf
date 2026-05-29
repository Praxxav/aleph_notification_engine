variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region to deploy to."
}

variable "environment" {
  type        = string
  description = "The environment label (dev or prod)."
}

variable "key_vault_id" {
  type        = string
  description = "The ID of the Key Vault."
}

variable "storage_account_id" {
  type        = string
  description = "The ID of the storage account containing the queue."
}

variable "oidc_issuer_url" {
  type        = string
  description = "The OIDC issuer URL of the AKS cluster."
}

variable "csi_secret_identity_object_id" {
  type        = string
  description = "The principal (object) ID of the Secret Identity created by AKS for the Secrets Store CSI Driver."
}

variable "k8s_namespace" {
  type        = string
  default     = "default"
  description = "The Kubernetes namespace where resources are deployed."
}
