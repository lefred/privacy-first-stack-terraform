variable "project_id" {
  type = string
}
variable "region" {
  type = string
}
variable "zone" {
  type = string
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
  type    = string
  default = "10.42.0.0/16"
}
variable "subnetwork" {
  description = "Existing subnetwork name in var.region. When null, Terraform creates a custom network and subnetwork."
  type        = string
  default     = null
}
variable "subnet_cidr" {
  type    = string
  default = "10.42.1.0/24"
}
variable "machine_type" {
  type    = string
  default = "e2-standard-2"
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
  description = "SSH public-key content. When null, ssh_authorized_keys_path is read on the Terraform runner."
  type        = string
  default     = null
}
variable "ssh_authorized_keys_path" {
  description = "Path to an SSH public key on the Terraform runner. Used when ssh_public_key is null."
  type        = string
  default     = null
}
variable "ssh_private_key_path" {
  description = "Optional operator SSH private-key path retained for tfvars compatibility; provisioning does not require it."
  type        = string
  default     = null
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
