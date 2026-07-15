terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source = "oracle/oci", version = "~> 7.0"
    }
  }
}
provider "oci" {
  auth                 = var.auth
  region               = var.region
  tenancy_ocid         = var.tenancy_ocid
  user_ocid            = var.user_ocid
  fingerprint          = var.fingerprint
  private_key          = var.private_key
  private_key_path     = var.private_key_path
  private_key_password = var.private_key_password
  config_file_profile  = var.config_file_profile
}
module "stack" {
  source                   = "../modules/native_stack"
  hostname                 = var.name
  ssh_public_key           = local.ssh_public_key
  passbolt_domain          = var.passbolt_domain
  mariadb_root_password    = var.mariadb_root_password
  nextcloud_db_password    = var.nextcloud_db_password
  passbolt_db_password     = var.passbolt_db_password
  nextcloud_admin_password = var.nextcloud_admin_password
  role                     = var.deployment_mode == "consolidated" ? "consolidated" : "passbolt"
  database_host            = var.deployment_mode == "consolidated" ? "127.0.0.1" : oci_core_instance.database[0].private_ip
  database_allowed_cidr    = local.application_subnet_cidr
}
module "database" {
  count                    = var.deployment_mode == "distributed" ? 1 : 0
  source                   = "../modules/native_stack"
  role                     = "database"
  hostname                 = "${var.name}-database"
  ssh_public_key           = local.ssh_public_key
  mariadb_root_password    = var.mariadb_root_password
  nextcloud_db_password    = var.nextcloud_db_password
  passbolt_db_password     = var.passbolt_db_password
  nextcloud_admin_password = var.nextcloud_admin_password
  database_allowed_cidr    = local.application_subnet_cidr
}
module "nextcloud" {
  count                    = var.deployment_mode == "distributed" ? 1 : 0
  source                   = "../modules/native_stack"
  role                     = "nextcloud"
  hostname                 = "${var.name}-nextcloud"
  ssh_public_key           = local.ssh_public_key
  mariadb_root_password    = var.mariadb_root_password
  nextcloud_db_password    = var.nextcloud_db_password
  passbolt_db_password     = var.passbolt_db_password
  nextcloud_admin_password = var.nextcloud_admin_password
  database_host            = oci_core_instance.database[0].private_ip
  passbolt_domain          = null
}
data "oci_identity_availability_domains" "available" {
  compartment_id = coalesce(var.tenancy_ocid, local.compartment_id)
}
data "oci_core_images" "ubuntu" {
  count                    = var.image_id == null ? 1 : 0
  compartment_id           = coalesce(var.tenancy_ocid, local.compartment_id)
  operating_system         = var.image_operating_system
  operating_system_version = var.image_operating_system_version
  shape                    = var.shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
data "oci_core_subnet" "selected" {
  count     = var.subnet_id != null ? 1 : 0
  subnet_id = var.subnet_id
}
resource "oci_core_vcn" "stack" {
  count          = var.subnet_id == null ? 1 : 0
  compartment_id = local.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.name}-vcn"
  dns_label      = substr(replace(var.name, "-", ""), 0, 15)
}
resource "oci_core_internet_gateway" "stack" {
  count          = var.subnet_id == null ? 1 : 0
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.stack[0].id
  display_name   = "${var.name}-igw"
  enabled        = true
}
resource "oci_core_route_table" "stack" {
  count          = var.subnet_id == null ? 1 : 0
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.stack[0].id
  display_name   = "${var.name}-routes"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.stack[0].id
  }
}
resource "oci_core_subnet" "stack" {
  count                      = var.subnet_id == null ? 1 : 0
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.stack[0].id
  cidr_block                 = var.subnet_cidr
  display_name               = "${var.name}-subnet"
  dns_label                  = "stack"
  route_table_id             = oci_core_route_table.stack[0].id
  prohibit_public_ip_on_vnic = !var.assign_public_ip
}
locals {
  compartment_id          = coalesce(var.compartment_id, var.compartment_ocid)
  ssh_public_key          = var.ssh_authorized_keys_path != null ? trimspace(file(var.ssh_authorized_keys_path)) : trimspace(var.ssh_public_key)
  subnet_id               = var.subnet_id != null ? var.subnet_id : oci_core_subnet.stack[0].id
  vcn_id                  = var.subnet_id != null ? data.oci_core_subnet.selected[0].vcn_id : oci_core_vcn.stack[0].id
  discovered_image_id     = try(data.oci_core_images.ubuntu[0].images[0].id, null)
  image_id                = var.image_id != null ? var.image_id : local.discovered_image_id
  availability_domain     = coalesce(var.availability_domain, data.oci_identity_availability_domains.available.availability_domains[0].name)
  application_subnet_cidr = var.subnet_id != null ? data.oci_core_subnet.selected[0].cidr_block : var.subnet_cidr
}
resource "oci_core_network_security_group" "stack" {
  compartment_id = local.compartment_id
  vcn_id         = local.vcn_id
  display_name   = "${var.name}-nsg"
}
resource "oci_core_network_security_group_security_rule" "ssh" {
  network_security_group_id = oci_core_network_security_group.stack.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.admin_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}
resource "oci_core_network_security_group_security_rule" "apps" {
  for_each                  = toset(["80", "443", "8080"])
  network_security_group_id = oci_core_network_security_group.stack.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.app_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = tonumber(each.value)
      max = tonumber(each.value)
    }
  }
}
resource "oci_core_network_security_group_security_rule" "egress" {
  network_security_group_id = oci_core_network_security_group.stack.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}
resource "oci_core_network_security_group_security_rule" "database" {
  count                     = var.deployment_mode == "distributed" ? 1 : 0
  network_security_group_id = oci_core_network_security_group.stack.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = local.application_subnet_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 3306
      max = 3306
    }
  }
}
resource "oci_core_instance" "stack" {
  availability_domain = local.availability_domain
  compartment_id      = local.compartment_id
  display_name        = var.deployment_mode == "consolidated" ? var.name : "${var.name}-passbolt"
  shape               = var.shape
  dynamic "shape_config" {
    for_each = var.flex_shape ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }

  }
  create_vnic_details {
    subnet_id        = local.subnet_id
    assign_public_ip = var.assign_public_ip
    nsg_ids          = [oci_core_network_security_group.stack.id]
    hostname_label   = replace(var.name, "_", "-")

  }
  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.disk_size_gb
    boot_volume_vpus_per_gb = 20
  }
  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data           = base64encode(module.stack.cloud_init)
  }
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }
  preserve_boot_volume = false
  freeform_tags = {
    Application = "privacy-stack"
  }
  lifecycle {
    precondition {
      condition     = local.image_id != null
      error_message = "No available image matched image_operating_system and image_operating_system_version. Relax the version filter or set image_id explicitly."
    }
    precondition {
      condition     = length(local.ssh_public_key) > 40 && can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/]+={0,3}( .*)?$", local.ssh_public_key))
      error_message = "The resolved SSH public key is invalid or still an example placeholder. Set ssh_authorized_keys_path to a real .pub file or set ssh_public_key to the complete public key."
    }
  }
}

resource "oci_core_instance" "database" {
  count               = var.deployment_mode == "distributed" ? 1 : 0
  availability_domain = local.availability_domain
  compartment_id      = local.compartment_id
  display_name        = "${var.name}-database"
  shape               = var.shape
  dynamic "shape_config" {
    for_each = var.flex_shape ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }
  create_vnic_details {
    subnet_id        = local.subnet_id
    assign_public_ip = false
    nsg_ids          = [oci_core_network_security_group.stack.id]
    hostname_label   = replace("${var.name}-database", "_", "-")
  }
  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.disk_size_gb
    boot_volume_vpus_per_gb = 20
  }
  metadata = { ssh_authorized_keys = local.ssh_public_key, user_data = base64encode(module.database[0].cloud_init) }
  instance_options { are_legacy_imds_endpoints_disabled = true }
  preserve_boot_volume = false
  freeform_tags        = { Application = "privacy-stack", Component = "database" }
}

resource "oci_core_instance" "nextcloud" {
  count               = var.deployment_mode == "distributed" ? 1 : 0
  availability_domain = local.availability_domain
  compartment_id      = local.compartment_id
  display_name        = "${var.name}-nextcloud"
  shape               = var.shape
  dynamic "shape_config" {
    for_each = var.flex_shape ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }
  create_vnic_details {
    subnet_id        = local.subnet_id
    assign_public_ip = var.assign_public_ip
    nsg_ids          = [oci_core_network_security_group.stack.id]
    hostname_label   = replace("${var.name}-nextcloud", "_", "-")
  }
  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.disk_size_gb
    boot_volume_vpus_per_gb = 20
  }
  metadata = { ssh_authorized_keys = local.ssh_public_key, user_data = base64encode(module.nextcloud[0].cloud_init) }
  instance_options { are_legacy_imds_endpoints_disabled = true }
  preserve_boot_volume = false
  freeform_tags        = { Application = "privacy-stack", Component = "nextcloud" }
}

data "oci_core_vnic_attachments" "stack" {
  compartment_id = local.compartment_id
  instance_id    = oci_core_instance.stack.id
}
data "oci_core_vnic" "stack" {
  vnic_id = data.oci_core_vnic_attachments.stack.vnic_attachments[0].vnic_id
}
output "public_ip" {
  value = data.oci_core_vnic.stack.public_ip_address
}
output "passbolt_url" {
  value = var.passbolt_domain != null ? "http://${var.passbolt_domain}" : "http://${data.oci_core_vnic.stack.public_ip_address}"
}
output "nextcloud_public_ip" {
  value = var.deployment_mode == "distributed" ? oci_core_instance.nextcloud[0].public_ip : data.oci_core_vnic.stack.public_ip_address
}
