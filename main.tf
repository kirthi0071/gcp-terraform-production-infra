# main.tf (root module)
#
# This file's ONLY job is composition: call each child module in dependency
# order, and thread outputs from one module into the inputs of the next.
# No `resource` blocks belong here directly -- if you find yourself adding
# one, it almost certainly belongs inside a module instead.
#
# DEPENDENCY FLOW:
#   network  --> subnet_self_link, network_id
#      |                                  |
#      v                                  v
#   firewall (uses network_id)      vm (uses subnet_self_link + SA email)
#                                          |
#   service-account --> service_account_email --^
#                                          |
#                                          v
#                              load-balancer (uses vm's instance_group)
#
#   database (uses network_id, independent of vm/lb, wired to the app via
#             its private IP / connection name at the application layer,
#             not through Terraform resource dependency)

module "network" {
  source = "./modules/network"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  subnet_cidr = var.subnet_cidr
  labels      = local.common_labels
}

module "firewall" {
  source = "./modules/firewall"

  project_id               = var.project_id
  name_prefix               = local.name_prefix
  network_id                = module.network.network_id
  ssh_source_ranges         = var.ssh_source_ranges
  enable_ssh_from_anywhere = var.enable_ssh_from_anywhere
  labels                     = local.common_labels
}

module "service_account" {
  source = "./modules/service-account"

  project_id  = var.project_id
  name_prefix = local.name_prefix
}

module "vm" {
  source = "./modules/vm"

  project_id             = var.project_id
  name_prefix            = local.name_prefix
  region                 = var.region
  zone                   = var.zone
  machine_type           = var.machine_type
  image                  = var.vm_image
  subnet_self_link       = module.network.subnet_self_link
  service_account_email  = module.service_account.email
  labels                 = local.common_labels

  depends_on = [module.firewall]
}

module "database" {
  source = "./modules/database"

  project_id           = var.project_id
  name_prefix          = local.name_prefix
  region               = var.region
  network_id           = module.network.network_id
  db_version           = var.db_version
  tier                 = var.db_tier
  disk_size_gb         = var.db_disk_size_gb
  deletion_protection = var.db_deletion_protection
  db_password          = var.db_password
  labels               = local.common_labels
}

module "load_balancer" {
  source = "./modules/load-balancer"

  project_id              = var.project_id
  name_prefix             = local.name_prefix
  backend_instance_group  = module.vm.instance_group
  labels                  = local.common_labels
}
