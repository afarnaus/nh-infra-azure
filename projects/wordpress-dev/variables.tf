variable "db_username" {
  description = "The username for the MySQL database."
  type        = string
}
variable "db_password" {
  description = "The password for the MySQL database."
  type        = string
}
variable "admin_username" {
  description = "The username for the VMs."
  type        = string
}

variable "admin_password" {
  description = "Admin Password for Windows VMss"
  type        = string
}
variable "admin_ssh_key" {
  description = "The SSH public key to use for the VMs."
  type        = string
}
