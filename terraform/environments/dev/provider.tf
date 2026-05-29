terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }

  # Will be configured during bootstrap step. Can also be passed via -backend-config command line arguments in CI/CD.
  backend "azurerm" {
    resource_group_name  = "rg-aleph-tfstate"
    storage_account_name = "stalephsdevtfstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}
