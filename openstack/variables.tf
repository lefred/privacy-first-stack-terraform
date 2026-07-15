variable "cloud" {
  type    = string
  default = null
}
variable "name" {
  type    = string
  default = "privacy-stack"
}
variable "deployment_mode" {
  description = "consolidated installs all services on one VM; distributed creates separate database, Passbolt, and Nextcloud VMs."
  type        = string
  default     = "consolidated"
  validation {
    condition     = contains(["consolidated", "distributed"], var.deployment_mode)
    error_message = "deployment_mode must be consolidated or distributed."
  }
}
variable "database_allowed_cidr" {
  description = "Internal CIDR allowed to reach MariaDB in distributed mode."
  type        = string
  default     = "10.42.1.0/24"
}
variable "image_name" {
  type    = string
  default = "Ubuntu 24.04"
}
variable "image_id" {
  description = "Existing Ubuntu image ID. When null, image_name is discovered automatically."
  type        = string
  default     = null
}
variable "flavor_name" {
  type    = string
  default = "m1.large"
}
variable "network_id" {
  description = "Existing tenant network ID. When null, Terraform creates a network, subnet, and router."
  type        = string
  default     = null
}
variable "subnet_cidr" {
  type    = string
  default = "10.42.1.0/24"
}
variable "dns_nameservers" {
  type    = list(string)
  default = ["1.1.1.1", "9.9.9.9"]
}
variable "external_network" {
  description = "External network/pool name, used for floating IPs and automatic router creation."
  type        = string
  default     = "public"
}
variable "key_pair" {
  type    = string
  default = null
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
