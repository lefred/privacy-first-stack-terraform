terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source = "hashicorp/google", version = "~> 7.0"
    }
  }
}
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
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
  database_host            = var.deployment_mode == "consolidated" ? "127.0.0.1" : google_compute_instance.database[0].network_interface[0].network_ip
  database_allowed_cidr    = var.database_allowed_cidr
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
  database_allowed_cidr    = var.database_allowed_cidr
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
  database_host            = google_compute_instance.database[0].network_interface[0].network_ip
}
data "google_compute_subnetwork" "selected" {
  count  = var.subnetwork != null ? 1 : 0
  name   = var.subnetwork
  region = var.region
}
resource "google_compute_network" "stack" {
  count                   = var.subnetwork == null ? 1 : 0
  name                    = "${var.name}-network"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "stack" {
  count         = var.subnetwork == null ? 1 : 0
  name          = "${var.name}-subnet"
  region        = var.region
  network       = google_compute_network.stack[0].id
  ip_cidr_range = var.subnet_cidr
}
locals {
  ssh_public_key = var.ssh_authorized_keys_path != null ? trimspace(file(var.ssh_authorized_keys_path)) : trimspace(coalesce(var.ssh_public_key, ""))
  network_id     = var.subnetwork != null ? data.google_compute_subnetwork.selected[0].network : google_compute_network.stack[0].id
  subnet_id      = var.subnetwork != null ? data.google_compute_subnetwork.selected[0].self_link : google_compute_subnetwork.stack[0].id
}
resource "google_compute_firewall" "stack" {
  name    = "${var.name}-apps"
  network = local.network_id
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }
  source_ranges = [var.app_cidr]
  target_tags   = [var.name]
}
resource "google_compute_firewall" "ssh" {
  name    = "${var.name}-ssh"
  network = local.network_id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [var.admin_cidr]
  target_tags   = [var.name]
}
resource "google_compute_firewall" "database" {
  count   = var.deployment_mode == "distributed" ? 1 : 0
  name    = "${var.name}-database"
  network = local.network_id
  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
  source_ranges = [var.database_allowed_cidr]
  target_tags   = ["${var.name}-database"]
}
resource "google_compute_instance" "stack" {
  name         = var.name
  machine_type = var.machine_type
  tags         = [var.name]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork = local.subnet_id
    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }
  metadata = {
    ssh-keys               = "stackadmin:${local.ssh_public_key}"
    user-data              = module.stack.cloud_init
    block-project-ssh-keys = "TRUE"
    enable-oslogin         = "FALSE"
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  lifecycle {
    precondition {
      condition     = length(local.ssh_public_key) > 40 && can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/]+={0,3}( .*)?$", local.ssh_public_key))
      error_message = "The resolved SSH public key is invalid or still an example placeholder. Set ssh_authorized_keys_path to a real .pub file or set ssh_public_key to the complete public key."
    }
  }
}
resource "google_compute_instance" "database" {
  count        = var.deployment_mode == "distributed" ? 1 : 0
  name         = "${var.name}-database"
  machine_type = var.machine_type
  tags         = ["${var.name}-database"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork = local.subnet_id
  }
  metadata = {
    ssh-keys               = "stackadmin:${local.ssh_public_key}"
    user-data              = module.database[0].cloud_init
    block-project-ssh-keys = "TRUE"
    enable-oslogin         = "FALSE"
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}
resource "google_compute_instance" "nextcloud" {
  count        = var.deployment_mode == "distributed" ? 1 : 0
  name         = "${var.name}-nextcloud"
  machine_type = var.machine_type
  tags         = [var.name]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork = local.subnet_id
    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }
  metadata = {
    ssh-keys               = "stackadmin:${local.ssh_public_key}"
    user-data              = module.nextcloud[0].cloud_init
    block-project-ssh-keys = "TRUE"
    enable-oslogin         = "FALSE"
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}
output "public_ip" {
  value = try(google_compute_instance.stack.network_interface[0].access_config[0].nat_ip, null)
}
output "passbolt_url" {
  value = var.passbolt_domain != null ? "https://${var.passbolt_domain}" : try("https://${google_compute_instance.stack.network_interface[0].access_config[0].nat_ip}", null)
}
output "nextcloud_public_ip" {
  value = var.deployment_mode == "distributed" ? try(google_compute_instance.nextcloud[0].network_interface[0].access_config[0].nat_ip, null) : try(google_compute_instance.stack.network_interface[0].access_config[0].nat_ip, null)
}
