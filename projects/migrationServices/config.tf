terraform {
  backend "azurerm" {
    resource_group_name  = "nh-tf-static-resources"
    storage_account_name = "nhterraformstate"
    container_name       = "terraform"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}