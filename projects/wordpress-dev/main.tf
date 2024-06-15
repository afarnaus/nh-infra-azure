# Resource Group
# --------------

resource "azurerm_resource_group" "wordpress" {
  name     = "wordpress-dev-rg"
  location = "North Central US"
}

#Storage
resource "azurerm_storage_account" "wordpress_storage" {
  name                            = "nhwpdevstorage"
  resource_group_name             = azurerm_resource_group.wordpress.name
  location                        = azurerm_resource_group.wordpress.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "wp-container" {
  name                  = "wp-container"
  storage_account_name  = azurerm_storage_account.wordpress_storage.name
  container_access_type = "private"
}

#ASP
resource "azurerm_service_plan" "plan" {
  name                = "wordpress-dev-plan"
  resource_group_name = azurerm_resource_group.wordpress.name
  location            = azurerm_resource_group.wordpress.location
  os_type             = "Linux"
  sku_name            = "B3"
}

#ActualService
# resource "azurerm_app_service" "app" {
#   name                    = "wp-dev-app"
#   location                = azurerm_resource_group.wordpress.location
#   resource_group_name     = azurerm_resource_group.wordpress.name
#   app_service_plan_id     = azurerm_service_plan.plan.id
#   https_only              = true
#   client_affinity_enabled = false

#   app_settings = {
#     "WEBSITES_ENABLE_APP_SERVICE_STORAGE"    = "false"
#     "WORDPRESS_DB_HOST"                      = azurerm_mysql_flexible_server.nhwpdev-db.fqdn
#     "WORDPRESS_DB_NAME"                      = "wordpress"
#     "WORDPRESS_DB_USER"                      = "dbadmin"
#     "WORDPRESS_DB_PASSWORD"                  = random_password.mysql.result
#   }

#   site_config {
#     always_on        = true
#     min_tls_version  = 1.2
#     ftps_state       = "Disabled"
#     linux_fx_version = "DOCKER|wordpress:latest"
#   }

#   logs {
#     application_logs {}

#     http_logs {
#       file_system {
#         retention_in_days = 90
#         retention_in_mb   = 50
#       }
#     }
#   }
# }

resource "azurerm_linux_web_app" "wp-dev" {
  name                = "wp-dev-app"
  resource_group_name = azurerm_resource_group.wordpress.name
  location            = azurerm_resource_group.wordpress.location
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    always_on        = true
    ftps_state       = "Disabled"
    application_stack {
      docker_image_name = "wordpress:latest"
    }
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"    = "false"
    "WORDPRESS_DB_HOST"                      = azurerm_mysql_flexible_server.nhwpdev-db.fqdn
    "WORDPRESS_DB_NAME"                      = "wordpress"
    "WORDPRESS_DB_USER"                      = "dbadmin"
    "WORDPRESS_DB_PASSWORD"                  = random_password.mysql.result
  }

  logs {
    application_logs {
      file_system_level = "Verbose"
    }

    http_logs {
      file_system {
        retention_in_days = 90
        retention_in_mb   = 50
      }
    }
  
  }
  
}

#Network
resource "azurerm_virtual_network" "wp-dev-vn" {
  name                = "wp-dev-vn"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "wp-dev-vn-sn1" {
  name                 = "wp-dev-vn-sn1"
  resource_group_name  = azurerm_resource_group.wordpress.name
  virtual_network_name = azurerm_virtual_network.wp-dev-vn.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "example" {
  name                = "nhwpdevzone.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.wordpress.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "vnetlinknhwpdev"
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = azurerm_virtual_network.wp-dev-vn.id
  resource_group_name   = azurerm_resource_group.wordpress.name
}

resource "random_password" "mysql" {
  length           = 64
  special          = false
}
# MySQL

resource "azurerm_mysql_flexible_server" "nhwpdev-db" {
  name                   = "nhwpdev"
  resource_group_name    = azurerm_resource_group.wordpress.name
  location               = azurerm_resource_group.wordpress.location
  administrator_login    = "dbadmin"
  administrator_password = random_password.mysql.result
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.wp-dev-vn-sn1.id
  private_dns_zone_id    = azurerm_private_dns_zone.example.id
  sku_name               = "B_Standard_B2s"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.example]
}

# Firewall Rule
resource "azurerm_mysql_flexible_server_firewall_rule" "app_service_access" {
  for_each = {
    for ip in azurerm_subnet.wp-dev-vn-sn1.service_endpoints : ip => {
      key = ip
    }
  }
  name                = "app-service-access-${each.key}"
  resource_group_name = azurerm_resource_group.wordpress.name
  server_name         = azurerm_mysql_flexible_server.nhwpdev-db.name
  start_ip_address    = each.key
  end_ip_address      = each.key
}

resource "azurerm_mysql_flexible_database" "wordpress" {
  name                = "wordpress"
  resource_group_name = azurerm_resource_group.wordpress.name
  server_name         = azurerm_mysql_flexible_server.nhwpdev-db.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}



