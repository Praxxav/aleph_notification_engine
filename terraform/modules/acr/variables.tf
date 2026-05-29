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
