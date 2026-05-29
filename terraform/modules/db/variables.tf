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

variable "subnet_id" {
  type        = string
  description = "The ID of the delegated DB subnet."
}

variable "private_dns_zone_id" {
  type        = string
  description = "The ID of the private DNS zone for PostgreSQL."
}

variable "admin_username" {
  type        = string
  default     = "alephadmin"
  description = "The administrator username for PostgreSQL."
}

variable "db_name" {
  type        = string
  default     = "notifications"
  description = "The name of the database to create."
}

variable "key_vault_id" {
  type        = string
  description = "The ID of the Key Vault to store secrets."
}
