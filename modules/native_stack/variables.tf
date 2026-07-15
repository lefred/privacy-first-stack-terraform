variable "hostname" {
  type = string
}
variable "ssh_public_key" {
  type = string
}
variable "mariadb_root_password" {
  type      = string
  sensitive = true
}
variable "nextcloud_db_password" {
  type      = string
  sensitive = true
}
variable "passbolt_db_password" {
  type      = string
  sensitive = true
}
variable "nextcloud_admin_user" {
  type    = string
  default = "admin"
}
variable "nextcloud_admin_password" {
  type      = string
  sensitive = true
}
variable "passbolt_domain" {
  description = "Passbolt host name or IP. When null, the installer attempts OCI public-IP metadata and then falls back to the primary host IP."
  type        = string
  default     = null
}
variable "role" {
  description = "Component installed by this cloud-init payload."
  type        = string
  default     = "consolidated"
  validation {
    condition     = contains(["consolidated", "database", "nextcloud", "passbolt"], var.role)
    error_message = "role must be consolidated, database, nextcloud, or passbolt."
  }
}
variable "database_host" {
  description = "MariaDB host used by distributed application nodes."
  type        = string
  default     = "127.0.0.1"
}
variable "database_allowed_cidr" {
  description = "CIDR allowed to connect to MariaDB in distributed mode."
  type        = string
  default     = "10.0.0.0/8"
}
