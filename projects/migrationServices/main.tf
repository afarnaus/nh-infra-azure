data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "tf-rg" {
  name     = "nh-terraform-rg"
  location = "North Central US"
}

resource "azurerm_storage_account" "functions_storage" {
  name                            = "nhfunctionstorage"
  resource_group_name             = azurerm_resource_group.tf-rg.name
  location                        = azurerm_resource_group.tf-rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_service_plan" "fuction_asp" {
  name                = "nh-tf-managed-asp"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "nh-function-app-v2" {
  name                       = "nh-migration-function-app-v2"
  resource_group_name        = azurerm_resource_group.tf-rg.name
  location                   = azurerm_resource_group.tf-rg.location
  service_plan_id            = azurerm_service_plan.fuction_asp.id
  storage_account_name       = azurerm_storage_account.functions_storage.name
  storage_account_access_key = azurerm_storage_account.functions_storage.primary_access_key
  zip_deploy_file            = data.archive_file.python_function_package.output_path

  site_config {
    application_insights_connection_string = azurerm_application_insights.function_app_insights.connection_string
    application_insights_key               = azurerm_application_insights.function_app_insights.instrumentation_key
    application_stack {
      python_version = "3.11"
    }
  }
  app_settings = {
    AzureWebJobsStorage            = azurerm_storage_account.functions_storage.primary_connection_string
    SCM_DO_BUILD_DURING_DEPLOYMENT = true
  }
  identity {
    type = "SystemAssigned"
  }
}
resource "azurerm_application_insights" "function_app_insights" {
  name                = "nh-tf-managed-ai"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  application_type    = "other"
  retention_in_days   = 30
}

data "archive_file" "python_function_package" {
  type        = "zip"
  source_dir  = "${path.module}/functions/"
  output_path = "${path.module}/out/17jun20204.zip"
  #Excludes for python
  excludes = [
    ".git/*",
    ".gitignore",
    ".vscode/*",
    ".vscode/*",
    ".terraform/*",
    ".terraform/*",
    "terraform.tfstate",
    "terraform.tfstate.backup",
    "terraform.tfvars",
    "local.settings.json",
  ]
}

data "azuread_user" "alex" {
  user_principal_name = "alex@noahshope.com"
}

resource "azurerm_key_vault" "key_vault" {
  name                            = "nh-tf-managed-kv"
  resource_group_name             = azurerm_resource_group.tf-rg.name
  location                        = azurerm_resource_group.tf-rg.location
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = "standard"
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  purge_protection_enabled        = false
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azuread_user.alex.id
    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
      "Release",
      "Rotate",
      "GetRotationPolicy",
      "SetRotationPolicy",
    ]
    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
    storage_permissions = [
      "Backup",
      "Delete",
      "DeleteSAS",
      "Get",
      "GetSAS",
      "List",
      "ListSAS",
      "Purge",
      "Recover",
      "RegenerateKey",
      "Restore",
      "Set",
      "SetSAS",
      "Update",
    ]
  }
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_linux_function_app.nh-function-app-v2.identity[0].principal_id
    key_permissions = [
      "Decrypt",
      "Encrypt",
      "Get",
      "List",
      "UnwrapKey",
      "Verify",
    ]
    secret_permissions = [
      "Get",
      "List"
    ]
    storage_permissions = [
      "Get",
      "GetSAS",
      "List",
      "ListSAS",
    ]
  }
}