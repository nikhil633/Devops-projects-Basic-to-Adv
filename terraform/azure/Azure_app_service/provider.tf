terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 4.8.0"
    }
  }

  required_version = ">=1.9.0"
}

provider "azurerm" {
  subscription_id = "f626625b-e3b0-4db1-9ede-d461bfe18a56"

  features {
  }
}