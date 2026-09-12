terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate" 
    storage_account_name = "day0516192"                     
    container_name       = "tfstate"                       
    key                  = "dev.terraform.tfstate"       
  }
  }

  