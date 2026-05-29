variable "location" {
  type        = string
  default     = "eastus2"
  description = "The Azure region to deploy to."
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "The environment label."
}

variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.20.0.0/16"]
  description = "The VNet address space."
}

variable "aks_subnet_prefix" {
  type        = string
  default     = "10.20.0.0/20"
  description = "The subnet prefix for AKS."
}

variable "db_subnet_prefix" {
  type        = string
  default     = "10.20.16.0/24"
  description = "The subnet prefix for PostgreSQL."
}

variable "node_count" {
  type        = number
  default     = 3
  description = "The node count for AKS in production."
}

variable "vm_size" {
  type        = string
  default     = "Standard_D4s_v5"
  description = "The VM size for AKS nodes in production."
}
