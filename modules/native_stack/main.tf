locals {
  template_values = {
    mariadb_root_password_b64    = base64encode(var.mariadb_root_password)
    nextcloud_db_password_b64    = base64encode(var.nextcloud_db_password)
    passbolt_db_password_b64     = base64encode(var.passbolt_db_password)
    nextcloud_admin_user_b64     = base64encode(var.nextcloud_admin_user)
    nextcloud_admin_password_b64 = base64encode(var.nextcloud_admin_password)
    passbolt_domain_b64          = base64encode(var.passbolt_domain != null ? var.passbolt_domain : "")
    database_host_b64            = base64encode(var.database_host)
    database_allowed_cidr        = var.database_allowed_cidr
  }

  install_script = templatefile("${path.module}/${var.role == "consolidated" ? "install.sh" : "install-${var.role}.sh"}.tftpl", local.template_values)

  cloud_init = yamlencode({
    hostname         = var.hostname
    manage_etc_hosts = true
    package_update   = true
    ssh_pwauth       = false
    users = [{
      name                = "stackadmin"
      groups              = ["sudo"]
      shell               = "/bin/bash"
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      ssh_authorized_keys = [var.ssh_public_key]

    }]
    write_files = [{
      path        = "/usr/local/sbin/install-privacy-stack"
      owner       = "root:root"
      permissions = "0700"
      content     = local.install_script

    }]
    runcmd = [["/usr/local/sbin/install-privacy-stack"]]

  })
}

output "cloud_init" {
  value     = "#cloud-config\n${local.cloud_init}"
  sensitive = true
}

output "application_ports" {
  value = {
    passbolt_http = 80, passbolt_https = 443, nextcloud_http = 8080
  }
}
