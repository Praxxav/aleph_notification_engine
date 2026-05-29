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

variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "Address space for the VNet."
}

variable "aks_subnet_prefix" {
  type        = string
  default     = "10.0.0.0/20"
  description = "Address prefix for the AKS subnet."
}

variable "db_subnet_prefix" {
  type        = string
  default     = "10.0.16.0/24"
  description = "Address prefix for the DB subnet."
}
