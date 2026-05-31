# Global variables (if needed to override locations or scopes)

variable "default_location" {
  type        = string
  default     = "eastus2"
  description = "Fallback Azure region to deploy resources."
}
