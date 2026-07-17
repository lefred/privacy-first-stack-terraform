terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
  }
}
provider "aws" {
  region = var.region
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
  database_host            = var.deployment_mode == "consolidated" ? "127.0.0.1" : aws_instance.database[0].private_ip
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
  database_host            = aws_instance.database[0].private_ip
}
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
data "aws_subnet" "selected" {
  count = var.subnet_id != null ? 1 : 0
  id    = var.subnet_id
}
data "aws_availability_zones" "available" {
  count = var.subnet_id == null ? 1 : 0
  state = "available"
}
resource "aws_vpc" "stack" {
  count                = var.subnet_id == null ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}
resource "aws_internet_gateway" "stack" {
  count  = var.subnet_id == null ? 1 : 0
  vpc_id = aws_vpc.stack[0].id
  tags   = { Name = "${var.name}-igw" }
}
resource "aws_subnet" "stack" {
  count                   = var.subnet_id == null ? 1 : 0
  vpc_id                  = aws_vpc.stack[0].id
  cidr_block              = var.subnet_cidr
  availability_zone       = coalesce(var.availability_zone, data.aws_availability_zones.available[0].names[0])
  map_public_ip_on_launch = var.assign_public_ip
  tags                    = { Name = "${var.name}-subnet" }
}
resource "aws_route_table" "stack" {
  count  = var.subnet_id == null ? 1 : 0
  vpc_id = aws_vpc.stack[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.stack[0].id
  }
  tags = { Name = "${var.name}-routes" }
}
resource "aws_route_table_association" "stack" {
  count          = var.subnet_id == null ? 1 : 0
  subnet_id      = aws_subnet.stack[0].id
  route_table_id = aws_route_table.stack[0].id
}
locals {
  ssh_public_key          = var.ssh_authorized_keys_path != null ? trimspace(file(var.ssh_authorized_keys_path)) : trimspace(var.ssh_public_key)
  key_name                = var.key_name != null ? var.key_name : aws_key_pair.stack[0].key_name
  subnet_id               = var.subnet_id != null ? var.subnet_id : aws_subnet.stack[0].id
  vpc_id                  = var.subnet_id != null ? data.aws_subnet.selected[0].vpc_id : aws_vpc.stack[0].id
  application_subnet_cidr = var.subnet_id != null ? data.aws_subnet.selected[0].cidr_block : var.subnet_cidr
}
resource "aws_key_pair" "stack" {
  count      = var.key_name == null ? 1 : 0
  key_name   = "${var.name}-terraform"
  public_key = local.ssh_public_key

  tags = { Name = "${var.name}-terraform" }
}
resource "aws_security_group" "stack" {
  name_prefix = "${var.name}-"
  vpc_id      = local.vpc_id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  dynamic "ingress" {
    for_each = [80, 443, 8080]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.app_cidr]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  dynamic "ingress" {
    for_each = var.deployment_mode == "distributed" ? [1] : []
    content {
      description = "MariaDB from application subnet"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = [local.application_subnet_cidr]
    }
  }
}
resource "aws_instance" "stack" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.stack.id]
  associate_public_ip_address = var.assign_public_ip
  key_name                    = local.key_name
  user_data                   = module.stack.cloud_init
  user_data_replace_on_change = true
  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = {
    Name = var.deployment_mode == "consolidated" ? var.name : "${var.name}-passbolt"
  }
}
resource "aws_instance" "database" {
  count                       = var.deployment_mode == "distributed" ? 1 : 0
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.stack.id]
  associate_public_ip_address = false
  key_name                    = local.key_name
  user_data                   = module.database[0].cloud_init
  user_data_replace_on_change = true
  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = { Name = "${var.name}-database" }
}
resource "aws_instance" "nextcloud" {
  count                       = var.deployment_mode == "distributed" ? 1 : 0
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.stack.id]
  associate_public_ip_address = var.assign_public_ip
  key_name                    = local.key_name
  user_data                   = module.nextcloud[0].cloud_init
  user_data_replace_on_change = true
  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = { Name = "${var.name}-nextcloud" }
}
output "public_ip" {
  value = aws_instance.stack.public_ip
}
output "nextcloud_url" {
  value = "http://${coalesce(aws_instance.stack.public_ip, aws_instance.stack.private_ip)}:8080"
}
output "passbolt_url" {
  value = "https://${var.passbolt_domain != null ? var.passbolt_domain : aws_instance.stack.public_ip}"
}
output "nextcloud_public_ip" {
  value = var.deployment_mode == "distributed" ? aws_instance.nextcloud[0].public_ip : aws_instance.stack.public_ip
}
