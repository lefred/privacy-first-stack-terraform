terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm", version = "~> 4.0"
    }

  }
}
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
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
  database_host            = var.deployment_mode == "consolidated" ? "127.0.0.1" : azurerm_network_interface.database[0].private_ip_address
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
  database_host            = azurerm_network_interface.database[0].private_ip_address
}
locals {
  resource_group_name = coalesce(var.resource_group_name, "${var.name}-rg")
  subnet_id           = var.subnet_id != null ? var.subnet_id : azurerm_subnet.stack[0].id
}
resource "azurerm_resource_group" "stack" {
  count    = var.resource_group_name == null ? 1 : 0
  name     = local.resource_group_name
  location = var.location
}
resource "azurerm_virtual_network" "stack" {
  count               = var.subnet_id == null ? 1 : 0
  name                = "${var.name}-vnet"
  location            = var.location
  resource_group_name = local.resource_group_name
  address_space       = [var.vnet_cidr]
  depends_on          = [azurerm_resource_group.stack]
}
resource "azurerm_subnet" "stack" {
  count                = var.subnet_id == null ? 1 : 0
  name                 = "${var.name}-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.stack[0].name
  address_prefixes     = [var.subnet_cidr]
}
resource "azurerm_public_ip" "stack" {
  count               = var.assign_public_ip ? 1 : 0
  name                = "${var.name}-ip"
  location            = var.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.stack]
}
resource "azurerm_public_ip" "nextcloud" {
  count               = var.deployment_mode == "distributed" && var.assign_public_ip ? 1 : 0
  name                = "${var.name}-nextcloud-ip"
  location            = var.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.stack]
}
resource "azurerm_network_security_group" "stack" {
  name                = "${var.name}-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name
  depends_on          = [azurerm_resource_group.stack]
  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_cidr
    destination_address_prefix = "*"
  }
  dynamic "security_rule" {
    for_each = var.deployment_mode == "distributed" ? [1] : []
    content {
      name                       = "database"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3306"
      source_address_prefix      = var.database_allowed_cidr
      destination_address_prefix = "*"
    }
  }
  security_rule {
    name                       = "apps"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "8080"]
    source_address_prefix      = var.app_cidr
    destination_address_prefix = "*"
  }
}
resource "azurerm_network_interface" "stack" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = local.resource_group_name
  depends_on          = [azurerm_resource_group.stack]
  ip_configuration {
    name                          = "primary"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.stack[0].id : null

  }
}
resource "azurerm_network_interface_security_group_association" "stack" {
  network_interface_id      = azurerm_network_interface.stack.id
  network_security_group_id = azurerm_network_security_group.stack.id
}
resource "azurerm_network_interface" "database" {
  count               = var.deployment_mode == "distributed" ? 1 : 0
  name                = "${var.name}-database-nic"
  location            = var.location
  resource_group_name = local.resource_group_name
  ip_configuration {
    name                          = "primary"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [azurerm_resource_group.stack]
}
resource "azurerm_network_interface" "nextcloud" {
  count               = var.deployment_mode == "distributed" ? 1 : 0
  name                = "${var.name}-nextcloud-nic"
  location            = var.location
  resource_group_name = local.resource_group_name
  ip_configuration {
    name                          = "primary"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.nextcloud[0].id : null
  }
  depends_on = [azurerm_resource_group.stack]
}
resource "azurerm_network_interface_security_group_association" "database" {
  count                     = var.deployment_mode == "distributed" ? 1 : 0
  network_interface_id      = azurerm_network_interface.database[0].id
  network_security_group_id = azurerm_network_security_group.stack.id
}
resource "azurerm_network_interface_security_group_association" "nextcloud" {
  count                     = var.deployment_mode == "distributed" ? 1 : 0
  network_interface_id      = azurerm_network_interface.nextcloud[0].id
  network_security_group_id = azurerm_network_security_group.stack.id
}
resource "azurerm_linux_virtual_machine" "stack" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = local.resource_group_name
  size                            = var.vm_size
  admin_username                  = "stackadmin"
  network_interface_ids           = [azurerm_network_interface.stack.id]
  custom_data                     = base64encode(module.stack.cloud_init)
  disable_password_authentication = true
  depends_on                      = [azurerm_resource_group.stack]
  admin_ssh_key {
    username   = "stackadmin"
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.disk_size_gb
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
resource "azurerm_linux_virtual_machine" "database" {
  count                           = var.deployment_mode == "distributed" ? 1 : 0
  name                            = "${var.name}-database"
  location                        = var.location
  resource_group_name             = local.resource_group_name
  size                            = var.vm_size
  admin_username                  = "stackadmin"
  network_interface_ids           = [azurerm_network_interface.database[0].id]
  custom_data                     = base64encode(module.database[0].cloud_init)
  disable_password_authentication = true
  admin_ssh_key {
    username   = "stackadmin"
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.disk_size_gb
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
resource "azurerm_linux_virtual_machine" "nextcloud" {
  count                           = var.deployment_mode == "distributed" ? 1 : 0
  name                            = "${var.name}-nextcloud"
  location                        = var.location
  resource_group_name             = local.resource_group_name
  size                            = var.vm_size
  admin_username                  = "stackadmin"
  network_interface_ids           = [azurerm_network_interface.nextcloud[0].id]
  custom_data                     = base64encode(module.nextcloud[0].cloud_init)
  disable_password_authentication = true
  admin_ssh_key {
    username   = "stackadmin"
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.disk_size_gb
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
output "public_ip" {
  value = try(azurerm_public_ip.stack[0].ip_address, null)
}
output "passbolt_url" {
  value = var.passbolt_domain != null ? "https://${var.passbolt_domain}" : try("https://${azurerm_public_ip.stack[0].ip_address}", null)
}
output "nextcloud_public_ip" {
  value = var.deployment_mode == "distributed" && var.assign_public_ip ? azurerm_public_ip.nextcloud[0].ip_address : null
}
