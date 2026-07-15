variable "subscription_id" {
  type = string
}
variable "resource_group_name" {
  description = "Existing resource group name. When null, Terraform creates one."
  type        = string
  default     = null
}
variable "location" {
  type = string
}
variable "subnet_id" {
  description = "Existing subnet resource ID. When null, Terraform creates a VNet and subnet."
  type        = string
  default     = null
}
variable "vnet_cidr" {
  type    = string
  default = "10.42.0.0/16"
}
variable "subnet_cidr" {
  type    = string
  default = "10.42.1.0/24"
}
variable "name" {
  type    = string
  default = "privacy-stack"
}
variable "deployment_mode" {
  type    = string
  default = "consolidated"
  validation {
    condition     = contains(["consolidated", "distributed"], var.deployment_mode)
    error_message = "deployment_mode must be consolidated or distributed."
  }
}
variable "database_allowed_cidr" {
  description = "CIDR permitted to connect to MariaDB in distributed mode."
  type        = string
  default     = "10.42.0.0/16"
}
variable "vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}
variable "disk_size_gb" {
  type    = number
  default = 80
}
variable "assign_public_ip" {
  type    = bool
  default = true
}
variable "ssh_public_key" {
  type = string
}
variable "admin_cidr" {
  type = string
}
variable "app_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
variable "passbolt_domain" {
  type    = string
  default = null
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
variable "nextcloud_admin_password" {
  type      = string
  sensitive = true
}
