variable "region" {
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
variable "subnet_id" {
  description = "Existing subnet ID. When null, Terraform creates a VPC, internet gateway, route table, and subnet."
  type        = string
  default     = null
}
variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}
variable "subnet_cidr" {
  type    = string
  default = "10.42.1.0/24"
}
variable "availability_zone" {
  type    = string
  default = null
}
variable "instance_type" {
  type    = string
  default = "t3.large"
}
variable "disk_size_gb" {
  type    = number
  default = 80
}
variable "assign_public_ip" {
  type    = bool
  default = true
}
variable "key_name" {
  type    = string
  default = null
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
