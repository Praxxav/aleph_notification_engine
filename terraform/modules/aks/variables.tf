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
  description = "The ID of the subnet where AKS nodes should be placed."
}

variable "acr_id" {
  type        = string
  description = "The ID of the Azure Container Registry."
}

variable "node_count" {
  type        = number
  default     = 2
  description = "The number of nodes in the system pool (minimum 2)."
}

variable "vm_size" {
  type        = string
  default     = "Standard_D2s_v5"
  description = "The size of the Virtual Machines for the nodes."
}
