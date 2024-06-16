resource "random_id" "id" {
  byte_length = 8
}
#Core RG
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
  allow_nested_items_to_be_public = true
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

resource "azurerm_subnet" "wp-dev-vn-sn2" {
  name                 = "wp-dev-vn-sn2"
  resource_group_name  = azurerm_resource_group.wordpress.name
  virtual_network_name = azurerm_virtual_network.wp-dev-vn.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints = [ "Microsoft.Storage" ]
  delegation {
    name = "as"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}
 
#Private DNS Zone for DB
resource "azurerm_private_dns_zone" "nhwpdevzone" {
  name                = "nhwpdevzone.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.wordpress.name
}

#Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "nhwpdevzonelink" {
  name                  = "vnetlinknhwpdev"
  private_dns_zone_name = azurerm_private_dns_zone.nhwpdevzone.name
  virtual_network_id    = azurerm_virtual_network.wp-dev-vn.id
  resource_group_name   = azurerm_resource_group.wordpress.name
}

# MySQL Server
resource "azurerm_mysql_flexible_server" "nhwpdev-db" {
  name                   = "nhwpdev"
  resource_group_name    = azurerm_resource_group.wordpress.name
  location               = azurerm_resource_group.wordpress.location
  administrator_login    = var.db_username
  administrator_password = var.db_password
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.wp-dev-vn-sn1.id
  private_dns_zone_id    = azurerm_private_dns_zone.nhwpdevzone.id
  sku_name               = "B_Standard_B1s"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.nhwpdevzonelink]
}

# Firewall Rule for App Service
resource "azurerm_mysql_flexible_server_firewall_rule" "app_service_access" {
  name                = "app-service-access"
  resource_group_name = azurerm_resource_group.wordpress.name
  server_name         = azurerm_mysql_flexible_server.nhwpdev-db.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# MySQL Database
resource "azurerm_mysql_flexible_database" "wordpress" {
  name                = "wordpress"
  resource_group_name = azurerm_resource_group.wordpress.name
  server_name         = azurerm_mysql_flexible_server.nhwpdev-db.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

#CDN
resource "azurerm_cdn_frontdoor_profile" "nh-wp-dev-profile" {
  name                = "nh-wp-dev-profile"
  resource_group_name = azurerm_resource_group.wordpress.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_custom_domain" "nh-wp-dev-cdn" {
  name                     = "nh-wp-dev-cdn"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.nh-wp-dev-profile.id
  host_name                = "dev.wp.noahshope.com"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "nh-wp-dev-endpoint" {
  name                = "nh-wp-dev-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_custom_domain.nh-wp-dev-cdn.cdn_frontdoor_profile_id
}

resource "azurerm_cdn_frontdoor_origin_group" "wp-dev-origin-group" {
  name                = "wp-dev-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_custom_domain.nh-wp-dev-cdn.cdn_frontdoor_profile_id
  health_probe {
    path     = "/"
    protocol = "Https"
    interval_in_seconds = 100
    request_type = "GET"
  }

  load_balancing {
    sample_size = 1
    successful_samples_required = 1
  }
  session_affinity_enabled = false
}

resource "azurerm_cdn_frontdoor_origin" "wp-dev-origin-appservice" {
  name                = "wp-dev-origin-appservice"
  certificate_name_check_enabled = false
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.wp-dev-origin-group.id
  priority            = 1
  weight              = 1000
  host_name           = azurerm_linux_web_app.wp-dev.default_hostname
  enabled = true
}

resource "azurerm_cdn_frontdoor_route" "wp-dev-route" {
  depends_on = [ azurerm_cdn_frontdoor_origin.wp-dev-origin-appservice, azurerm_cdn_frontdoor_origin_group.wp-dev-origin-group ]
  name                = "wp-dev-route"
  cdn_frontdoor_endpoint_id = azurerm_cdn_frontdoor_endpoint.nh-wp-dev-endpoint.id
  cdn_frontdoor_origin_ids = [ azurerm_cdn_frontdoor_origin.wp-dev-origin-appservice.id ]
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.wp-dev-origin-group.id
  supported_protocols = [ "Http", "Https"]
  patterns_to_match  = ["/*"]
  forwarding_protocol = "MatchRequest"
  cdn_frontdoor_custom_domain_ids = ["/subscriptions/62e7eb8b-885e-4f55-8f74-75c1b5577a65/resourceGroups/wordpress-dev-rg/providers/Microsoft.Cdn/profiles/nh-wp-dev-profile/customDomains/nh-wp-dev-cdn" ]
}

#Put it all together
#Web App
resource "azurerm_linux_web_app" "wp-dev" {
  name                = "wp-dev-app"
  resource_group_name = azurerm_resource_group.wordpress.name
  location            = azurerm_resource_group.wordpress.location
  service_plan_id     = azurerm_service_plan.plan.id
  virtual_network_subnet_id = azurerm_subnet.wp-dev-vn-sn2.id

  site_config {
    always_on        = true
    ftps_state       = "Disabled"
    vnet_route_all_enabled = true
    application_stack {
      docker_image_name = "wordpress"
      docker_registry_url = "https://index.docker.io"
    }
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"    = "true"
    "WORDPRESS_DB_HOST"                      = "${azurerm_mysql_flexible_server.nhwpdev-db.fqdn}:3306"
    "WORDPRESS_DB_NAME"                      = "wordpress"
    "WORDPRESS_DB_USER"                      = var.db_username
    "WORDPRESS_DB_PASSWORD"                  = var.db_password
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