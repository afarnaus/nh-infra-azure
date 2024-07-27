# #Core RG
# resource "azurerm_resource_group" "wordpress" {
#   name     = "wordpress-prod-rg"
#   location = "North Central US"
# }

# #Storage
# resource "azurerm_storage_account" "wordpress_storage" {
#   name                            = "nhwpprodstorage"
#   resource_group_name             = azurerm_resource_group.wordpress.name
#   location                        = azurerm_resource_group.wordpress.location
#   account_tier                    = "Standard"
#   account_replication_type        = "LRS"
#   allow_nested_items_to_be_public = true
# }

# resource "azurerm_storage_container" "wp-container" {
#   name                  = "wp-container"
#   storage_account_name  = azurerm_storage_account.wordpress_storage.name
#   container_access_type = "private"
# }

# resource "azurerm_storage_container" "wp-container-public" {
#   name                  = "wp-container-public"
#   storage_account_name  = azurerm_storage_account.wordpress_storage.name
#   container_access_type = "blob"
# }

# #ASP
# resource "azurerm_service_plan" "plan" {
#   name                = "wordpress-prod-plan"
#   resource_group_name = azurerm_resource_group.wordpress.name
#   location            = azurerm_resource_group.wordpress.location
#   os_type             = "Linux"
#   sku_name            = "P0v3"
# }

# #Network
# resource "azurerm_virtual_network" "wp-prod-vn" {
#   name                = "wp-prod-vn"
#   location            = azurerm_resource_group.wordpress.location
#   resource_group_name = azurerm_resource_group.wordpress.name
#   address_space       = ["10.40.64.0/18"]
# }

# resource "azurerm_subnet" "wp-prod-vn-sn1" {
#   name                 = "wp-prod-vn-sn1"
#   resource_group_name  = azurerm_resource_group.wordpress.name
#   virtual_network_name = azurerm_virtual_network.wp-prod-vn.name
#   address_prefixes     = ["10.40.64.0/20"]
#   service_endpoints    = ["Microsoft.Storage"]
#   delegation {
#     name = "fs"
#     service_delegation {
#       name = "Microsoft.DBforMySQL/flexibleServers"
#       actions = [
#         "Microsoft.Network/virtualNetworks/subnets/join/action",
#       ]
#     }
#   }
# }

# resource "azurerm_subnet" "wp-prod-vn-sn2" {
#   name                 = "wp-prod-vn-sn2"
#   resource_group_name  = azurerm_resource_group.wordpress.name
#   virtual_network_name = azurerm_virtual_network.wp-prod-vn.name
#   address_prefixes     = ["10.40.80.0/20"]
#   service_endpoints    = ["Microsoft.Storage"]
#   delegation {
#     name = "as"
#     service_delegation {
#       name = "Microsoft.Web/serverFarms"
#       actions = [
#         "Microsoft.Network/virtualNetworks/subnets/action",
#       ]
#     }
#   }
# }

# resource "azurerm_subnet" "wp-prod-vn-sn3" {
#   name                 = "wp-prod-vn-sn3"
#   resource_group_name  = azurerm_resource_group.wordpress.name
#   virtual_network_name = azurerm_virtual_network.wp-prod-vn.name
#   address_prefixes     = ["10.40.96.0/20"]
# }

# #Private DNS Zone for DB
# resource "azurerm_private_dns_zone" "nhwpprodzone" {
#   name                = "nhwpprodzone.mysql.database.azure.com"
#   resource_group_name = azurerm_resource_group.wordpress.name
# }

# #Private DNS Zone Virtual Network Link
# resource "azurerm_private_dns_zone_virtual_network_link" "nhwpprodzonelink" {
#   name                  = "vnetlinknhwpprod"
#   private_dns_zone_name = azurerm_private_dns_zone.nhwpprodzone.name
#   virtual_network_id    = azurerm_virtual_network.wp-prod-vn.id
#   resource_group_name   = azurerm_resource_group.wordpress.name
# }

# # MySQL Server
# resource "azurerm_mysql_flexible_server" "nhwpprod-db" {
#   name                   = "nhwpprod"
#   resource_group_name    = azurerm_resource_group.wordpress.name
#   location               = azurerm_resource_group.wordpress.location
#   administrator_login    = var.db_username
#   administrator_password = var.db_password
#   backup_retention_days  = 30
#   delegated_subnet_id    = azurerm_subnet.wp-prod-vn-sn1.id
#   private_dns_zone_id    = azurerm_private_dns_zone.nhwpprodzone.id
#   sku_name               = "B_Standard_B2ms"

#   depends_on = [azurerm_private_dns_zone_virtual_network_link.nhwpprodzonelink]
# }

# # Firewall Rule for App Service
# resource "azurerm_mysql_flexible_server_firewall_rule" "app_service_access" {
#   name                = "app-service-access"
#   resource_group_name = azurerm_resource_group.wordpress.name
#   server_name         = azurerm_mysql_flexible_server.nhwpprod-db.name
#   start_ip_address    = "0.0.0.0"
#   end_ip_address      = "0.0.0.0"
# }

# # MySQL Database
# resource "azurerm_mysql_flexible_database" "wordpress" {
#   name                = "wordpress"
#   resource_group_name = azurerm_resource_group.wordpress.name
#   server_name         = azurerm_mysql_flexible_server.nhwpprod-db.name
#   charset             = "utf8"
#   collation           = "utf8_general_ci"
# }

# resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
#   name                = "require_secure_transport"
#   resource_group_name = azurerm_resource_group.wordpress.name
#   server_name         = azurerm_mysql_flexible_server.nhwpprod-db.name
#   value               = "OFF"
# }

# #CDN
# resource "azurerm_cdn_frontdoor_profile" "nh-wp-prod-profile" {
#   name                = "nh-wp-prod-profile"
#   resource_group_name = azurerm_resource_group.wordpress.name
#   sku_name            = "Premium_AzureFrontDoor"
# }

# resource "azurerm_cdn_frontdoor_custom_domain" "nh-wp-prod-cdn" {
#   name                     = "nh-wp-prod-cdn"
#   cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.nh-wp-prod-profile.id
#   host_name                = var.final_fqdn
#   tls {
#     certificate_type    = "ManagedCertificate"
#     minimum_tls_version = "TLS12"
#   }
# }

# resource "azurerm_cdn_frontdoor_endpoint" "nh-wp-prod-endpoint" {
#   name                     = "nh-wp-prod-endpoint"
#   cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_custom_domain.nh-wp-prod-cdn.cdn_frontdoor_profile_id
# }

# resource "azurerm_cdn_frontdoor_origin_group" "wp-prod-origin-group" {
#   name                     = "wp-prod-origin-group"
#   cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_custom_domain.nh-wp-prod-cdn.cdn_frontdoor_profile_id
#   health_probe {
#     path                = "/"
#     protocol            = "Https"
#     interval_in_seconds = 100
#     request_type        = "GET"
#   }

#   load_balancing {
#     sample_size                 = 1
#     successful_samples_required = 1
#   }
#   session_affinity_enabled = false
# }

# resource "azurerm_cdn_frontdoor_origin" "wp-prod-origin-appservice" {
#   name                           = "wp-prod-origin-appservice"
#   certificate_name_check_enabled = true
#   cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.wp-prod-origin-group.id
#   priority                       = 1
#   weight                         = 1000
#   host_name                      = azurerm_linux_web_app.wp-prod.default_hostname
#   enabled                        = true
# }

# resource "azurerm_cdn_frontdoor_route" "wp-prod-route" {
#   depends_on                      = [azurerm_cdn_frontdoor_origin.wp-prod-origin-appservice, azurerm_cdn_frontdoor_origin_group.wp-prod-origin-group]
#   name                            = "wp-prod-route"
#   cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.nh-wp-prod-endpoint.id
#   cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.wp-prod-origin-appservice.id]
#   cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.wp-prod-origin-group.id
#   cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.cacheruleset.id]
#   supported_protocols             = ["Http", "Https"]
#   patterns_to_match               = ["/*"]
#   forwarding_protocol             = "MatchRequest"
#   cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.nh-wp-prod-cdn.id]
# }

# resource "azurerm_cdn_frontdoor_rule_set" "cacheruleset" {
#   name                     = "cacheruleset"
#   cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.nh-wp-prod-profile.id
# }

# resource "azurerm_cdn_frontdoor_rule" "cacheuploadsdir" {
#   depends_on                = [azurerm_cdn_frontdoor_origin_group.wp-prod-origin-group, azurerm_cdn_frontdoor_rule_set.cacheruleset]
#   name                      = "cacheuploadsdir"
#   cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.cacheruleset.id
#   order                     = 1
#   behavior_on_match         = "Stop"

#   conditions {
#     url_path_condition {
#       operator         = "BeginsWith"
#       negate_condition = false
#       match_values     = ["wp-content/uploads/"]
#       transforms       = ["Lowercase"]
#     }
#   }

#   actions {
#     route_configuration_override_action {
#       query_string_caching_behavior = "UseQueryString"
#       compression_enabled           = true
#       cache_behavior                = "OverrideAlways"
#       cache_duration                = "3.00:00:00"
#       cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.wp-prod-origin-group.id
#       forwarding_protocol           = "MatchRequest"
#     }
#   }
# }

# resource "azurerm_cdn_frontdoor_rule" "cachestaticfiles" {
#   depends_on                = [azurerm_cdn_frontdoor_origin_group.wp-prod-origin-group, azurerm_cdn_frontdoor_rule_set.cacheruleset]
#   name                      = "cachestaticfiles"
#   cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.cacheruleset.id
#   order                     = 2
#   behavior_on_match         = "Stop"

#   conditions {
#     url_path_condition {
#       operator         = "BeginsWith"
#       negate_condition = false
#       match_values     = ["wp-includes/", "wp-content/themes/"]
#       transforms       = ["Lowercase"]
#     }
#     url_file_extension_condition {
#       operator         = "Equal"
#       negate_condition = false
#       match_values     = ["css", "js", "gif", "png", "jpg", "ico", "ttf", "otf", "woff", "woff2"]
#       transforms       = ["Lowercase"]
#     }
#   }
#   actions {
#     route_configuration_override_action {
#       query_string_caching_behavior = "UseQueryString"
#       compression_enabled           = true
#       cache_behavior                = "OverrideAlways"
#       cache_duration                = "3.00:00:00"
#     }
#   }
# }

# #Put it all together
# #Web App
# resource "azurerm_linux_web_app" "wp-prod" {
#   name                      = "wp-prod-app"
#   resource_group_name       = azurerm_resource_group.wordpress.name
#   location                  = azurerm_resource_group.wordpress.location
#   service_plan_id           = azurerm_service_plan.plan.id
#   virtual_network_subnet_id = azurerm_subnet.wp-prod-vn-sn2.id

#   site_config {
#     always_on              = true
#     ftps_state             = "Disabled"
#     vnet_route_all_enabled = true
#     application_stack {
#       docker_image_name   = "wordpress"
#       docker_registry_url = "https://index.docker.io"
#     }
#   }

#   app_settings = {
#     "WORDPRESS_LOCAL_STORAGE_CACHE_ENABLED" = "true"
#     "WORDPRESS_DB_HOST"                   = "${azurerm_mysql_flexible_server.nhwpprod-db.fqdn}:3306"
#     "WORDPRESS_DB_NAME"                   = "wordpress"
#     "WORDPRESS_DB_USER"                   = var.db_username
#     "WORDPRESS_DB_PASSWORD"               = var.db_password
#   }

#   logs {

#     http_logs {
#       file_system {
#         retention_in_days = 90
#         retention_in_mb   = 50
#       }
#     }

#   }
# }

# resource "azurerm_app_service_custom_hostname_binding" "app-service-binding" {
#   hostname            = var.final_fqdn
#   app_service_name    = azurerm_linux_web_app.wp-prod.name
#   resource_group_name = azurerm_resource_group.wordpress.name
# }