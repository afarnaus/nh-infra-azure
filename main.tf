provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tf-rg" {
  name     = "terraform-rg"
  location = "Central US"
}