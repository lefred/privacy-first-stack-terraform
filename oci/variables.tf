variable "region" {
  type = string
}
variable "auth" {
  description = "OCI provider authentication mode: APIKey, InstancePrincipal, ResourcePrincipal, SecurityToken, or OKEWorkloadIdentity."
  type        = string
  default     = "APIKey"
  validation {
    condition     = contains(["APIKey", "InstancePrincipal", "ResourcePrincipal", "SecurityToken", "OKEWorkloadIdentity"], var.auth)
    error_message = "auth must be a supported OCI Terraform provider authentication mode."
  }
}
variable "tenancy_ocid" {
  description = "Optional OCI tenancy OCID for API-key authentication. Omit when using workload identity or environment configuration."
  type        = string
  default     = null
}
variable "user_ocid" {
  description = "Optional OCI user OCID for API-key authentication."
  type        = string
  default     = null
}
variable "fingerprint" {
  description = "Optional OCI API signing-key fingerprint."
  type        = string
  default     = null
}
variable "private_key_path" {
  description = "Optional path to the OCI API private key on the Terraform runner."
  type        = string
  default     = null
}
variable "private_key" {
  description = "Optional PEM private-key content. Prefer this sensitive variable on HCP Terraform and env0, where a workstation path is unavailable."
  type        = string
  default     = null
  sensitive   = true
}
variable "private_key_password" {
  description = "Optional passphrase for an encrypted API private key."
  type        = string
  default     = null
  sensitive   = true
}
variable "config_file_profile" {
  description = "Optional OCI config-file profile, primarily for local or SecurityToken authentication."
  type        = string
  default     = null
}
variable "compartment_id" {
  description = "Target compartment OCID. compartment_ocid is accepted as a compatibility alias."
  type        = string
  default     = null
}
variable "compartment_ocid" {
  description = "Compatibility alias for compartment_id."
  type        = string
  default     = null
}
variable "availability_domain" {
  description = "Availability domain name. When null, the first available domain is selected."
  type        = string
  default     = null
}
variable "subnet_id" {
  description = "Existing subnet OCID. When null, Terraform creates a VCN, internet gateway, route table, and subnet."
  type        = string
  default     = null
}
variable "image_id" {
  description = "Existing Ubuntu image OCID. When null, the newest image matching the operating-system filters is selected."
  type        = string
  default     = null
}
variable "image_operating_system" {
  description = "Operating-system label used for automatic OCI image discovery."
  type        = string
  default     = "Canonical Ubuntu"
}
variable "image_operating_system_version" {
  description = "Optional exact OCI operating-system version filter. Null accepts the newest available version."
  type        = string
  default     = null
}
variable "vcn_cidr" {
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
  description = "consolidated uses one VM; distributed uses separate Passbolt, Nextcloud, and MariaDB VMs."
  type        = string
  default     = "consolidated"
  validation {
    condition     = contains(["consolidated", "distributed"], var.deployment_mode)
    error_message = "deployment_mode must be consolidated or distributed."
  }
}
variable "shape" {
  type    = string
  default = "VM.Standard.E2.1.Micro"
}
variable "flex_shape" {
  type    = bool
  default = false
}
variable "ocpus" {
  type    = number
  default = 2
}
variable "memory_in_gbs" {
  type    = number
  default = 16
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
  description = "Passbolt host name or IP. When null, cloud-init discovers the OCI public IP from instance metadata."
  type        = string
  default     = null
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
