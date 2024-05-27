provider "azurerm" {
  features {}
  use_oidc        = true
}

resource "azurerm_resource_group" "tf-rg" {
  name     = "terraform-rg"
  location = "Central US"
}