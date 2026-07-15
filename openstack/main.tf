terraform {
  required_version = ">= 1.5"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack", version = "~> 3.0"
    }
  }
}
provider "openstack" {
  cloud = var.cloud
}
module "stack" {
  source                   = "../modules/native_stack"
  hostname                 = var.name
  ssh_public_key           = var.ssh_public_key
  passbolt_domain          = var.passbolt_domain
  mariadb_root_password    = var.mariadb_root_password
  nextcloud_db_password    = var.nextcloud_db_password
  passbolt_db_password     = var.passbolt_db_password
  nextcloud_admin_password = var.nextcloud_admin_password
  role                     = var.deployment_mode == "consolidated" ? "consolidated" : "passbolt"
  database_host            = var.deployment_mode == "consolidated" ? "127.0.0.1" : openstack_networking_port_v2.database[0].all_fixed_ips[0]
  database_allowed_cidr    = var.database_allowed_cidr
}
module "database" {
  count                    = var.deployment_mode == "distributed" ? 1 : 0
  source                   = "../modules/native_stack"
  role                     = "database"
  hostname                 = "${var.name}-database"
  ssh_public_key           = var.ssh_public_key
  mariadb_root_password    = var.mariadb_root_password
  nextcloud_db_password    = var.nextcloud_db_password
  passbolt_db_password     = var.passbolt_db_password
  nextcloud_admin_password = var.nextcloud_admin_password
  database_allowed_cidr    = var.database_allowed_cidr
}
module "nextcloud" {
  count                    = var.deployment_mode == "distributed" ? 1 : 0
  source                   = "../modules/native_stack"
  role                     = "nextcloud"
  hostname                 = "${var.name}-nextcloud"
  ssh_public_key           = var.ssh_public_key
  mariadb_root_password    = var.mariadb_root_password
  nextcloud_db_password    = var.nextcloud_db_password
  passbolt_db_password     = var.passbolt_db_password
  nextcloud_admin_password = var.nextcloud_admin_password
  database_host            = openstack_networking_port_v2.database[0].all_fixed_ips[0]
}
data "openstack_images_image_v2" "ubuntu" {
  count       = var.image_id == null ? 1 : 0
  name        = var.image_name
  most_recent = true
}
data "openstack_networking_network_v2" "external" {
  count    = var.network_id == null ? 1 : 0
  name     = var.external_network
  external = true
}
resource "openstack_networking_network_v2" "stack" {
  count          = var.network_id == null ? 1 : 0
  name           = "${var.name}-network"
  admin_state_up = true
}
resource "openstack_networking_subnet_v2" "stack" {
  count           = var.network_id == null ? 1 : 0
  name            = "${var.name}-subnet"
  network_id      = openstack_networking_network_v2.stack[0].id
  cidr            = var.subnet_cidr
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.dns_nameservers
}
resource "openstack_networking_router_v2" "stack" {
  count               = var.network_id == null ? 1 : 0
  name                = "${var.name}-router"
  external_network_id = data.openstack_networking_network_v2.external[0].id
}
resource "openstack_networking_router_interface_v2" "stack" {
  count     = var.network_id == null ? 1 : 0
  router_id = openstack_networking_router_v2.stack[0].id
  subnet_id = openstack_networking_subnet_v2.stack[0].id
}
locals {
  network_id = var.network_id != null ? var.network_id : openstack_networking_network_v2.stack[0].id
  image_id   = var.image_id != null ? var.image_id : data.openstack_images_image_v2.ubuntu[0].id
}
resource "openstack_networking_secgroup_v2" "stack" {
  name        = "${var.name}-sg"
  description = "Privacy stack access"
}
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  security_group_id = openstack_networking_secgroup_v2.stack.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.admin_cidr
}
resource "openstack_networking_secgroup_rule_v2" "apps" {
  for_each          = toset(["80", "443", "8080"])
  security_group_id = openstack_networking_secgroup_v2.stack.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = tonumber(each.value)
  port_range_max    = tonumber(each.value)
  remote_ip_prefix  = var.app_cidr
}
resource "openstack_networking_secgroup_rule_v2" "database" {
  count             = var.deployment_mode == "distributed" ? 1 : 0
  security_group_id = openstack_networking_secgroup_v2.stack.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_ip_prefix  = var.database_allowed_cidr
}
resource "openstack_networking_port_v2" "stack" {
  name               = "${var.name}-port"
  network_id         = local.network_id
  security_group_ids = [openstack_networking_secgroup_v2.stack.id]
}
resource "openstack_networking_port_v2" "database" {
  count              = var.deployment_mode == "distributed" ? 1 : 0
  name               = "${var.name}-database-port"
  network_id         = local.network_id
  security_group_ids = [openstack_networking_secgroup_v2.stack.id]
}
resource "openstack_networking_port_v2" "nextcloud" {
  count              = var.deployment_mode == "distributed" ? 1 : 0
  name               = "${var.name}-nextcloud-port"
  network_id         = local.network_id
  security_group_ids = [openstack_networking_secgroup_v2.stack.id]
}
resource "openstack_compute_instance_v2" "stack" {
  name        = var.name
  flavor_name = var.flavor_name
  key_pair    = var.key_pair
  user_data   = module.stack.cloud_init
  network {
    port = openstack_networking_port_v2.stack.id
  }
  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = var.disk_size_gb
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}
resource "openstack_compute_instance_v2" "database" {
  count       = var.deployment_mode == "distributed" ? 1 : 0
  name        = "${var.name}-database"
  flavor_name = var.flavor_name
  key_pair    = var.key_pair
  user_data   = module.database[0].cloud_init
  network {
    port = openstack_networking_port_v2.database[0].id
  }
  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = var.disk_size_gb
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}
resource "openstack_compute_instance_v2" "nextcloud" {
  count       = var.deployment_mode == "distributed" ? 1 : 0
  name        = "${var.name}-nextcloud"
  flavor_name = var.flavor_name
  key_pair    = var.key_pair
  user_data   = module.nextcloud[0].cloud_init
  network {
    port = openstack_networking_port_v2.nextcloud[0].id
  }
  block_device {
    uuid                  = local.image_id
    source_type           = "image"
    volume_size           = var.disk_size_gb
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}
resource "openstack_networking_floatingip_v2" "stack" {
  count = var.assign_public_ip ? 1 : 0
  pool  = var.external_network
}
resource "openstack_networking_floatingip_associate_v2" "stack" {
  count       = var.assign_public_ip ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.stack[0].address
  port_id     = openstack_networking_port_v2.stack.id
  depends_on  = [openstack_networking_router_interface_v2.stack]
}
resource "openstack_networking_floatingip_v2" "nextcloud" {
  count = var.deployment_mode == "distributed" && var.assign_public_ip ? 1 : 0
  pool  = var.external_network
}
resource "openstack_networking_floatingip_associate_v2" "nextcloud" {
  count       = var.deployment_mode == "distributed" && var.assign_public_ip ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.nextcloud[0].address
  port_id     = openstack_networking_port_v2.nextcloud[0].id
  depends_on  = [openstack_networking_router_interface_v2.stack]
}
output "public_ip" {
  value = try(openstack_networking_floatingip_v2.stack[0].address, null)
}
output "passbolt_url" {
  value = var.passbolt_domain != null ? "https://${var.passbolt_domain}" : try("https://${openstack_networking_floatingip_v2.stack[0].address}", null)
}
output "nextcloud_public_ip" {
  value = var.deployment_mode == "distributed" ? try(openstack_networking_floatingip_v2.nextcloud[0].address, null) : try(openstack_networking_floatingip_v2.stack[0].address, null)
}
