variable "db_username" {
  description = "The username for the MySQL database."
  type        = string
}

variable "db_password" {
  description = "The password for the MySQL database."
  type        = string
}
variable "final_fqdn" {
  description = "The final FQDN for the WordPress site."
  type        = string
}