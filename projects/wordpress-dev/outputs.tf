output "dbname" {
  value = azurerm_mysql_flexible_server.nhwpdev-db.fqdn
}

output "dbuser" {
    value = "dbadmin"
    }

output "dbpassword" {
    value = random_password.mysql.result
}

output "appservice" {
    value = azurerm_linux_web_app.wp-dev.name
}

output "appserviceplan" {
    value = azurerm_service_plan.plan.name
}