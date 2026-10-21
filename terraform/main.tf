locals {
  resource_group_name         = "${var.cluster_name}-rg"
  managed_resource_group_name = "${var.cluster_name}-managed-rg"
  pull_secret = (
    trimspace(var.pull_secret) != "" ? var.pull_secret :
    (trimspace(var.pull_secret_path) != "" ? file(pathexpand(var.pull_secret_path)) : "{}")
  )

  # Legacy worker_* inputs remain a fallback for existing profiles.
  effective_node_pools = length(var.node_pools) > 0 ? var.node_pools : tomap({
    worker = {
      vm_size      = var.worker_vm_size
      replicas     = var.worker_count
      disk_size_gb = var.worker_disk_size_gb
      subnet_id    = null
      labels       = tomap({})
      tags         = tomap({})
      taints       = []
      zones        = []
    }
  })

  initial_pool = try(local.effective_node_pools[var.initial_worker_pool], local.effective_node_pools["worker"], null)
  initial_worker_profiles = {
    worker = local.initial_pool
  }
}

module "network" {
  source                      = "../modules/network"
  cluster_name                = var.cluster_name
  location                    = var.location
  resource_group_name         = local.resource_group_name
  vnet_address_space          = var.vnet_address_space
  control_plane_subnet_prefix = var.control_plane_subnet_prefix
  worker_subnet_prefix        = var.worker_subnet_prefix
  tags                        = var.tags
}

module "platform_secrets" {
  source                            = "../modules/platform-secrets"
  cluster_name                      = var.cluster_name
  location                          = var.location
  resource_group_name               = module.network.resource_group_name
  pull_secret_content               = local.pull_secret != "{}" ? local.pull_secret : ""
  pull_secret_key_vault_secret_name = var.pull_secret_key_vault_secret_name
  tags                              = var.tags

  # resource_group_name already carries the resource-group dependency.
  # A module-wide dependency would defer account metadata reads and churn RBAC.
}

module "identities" {
  source                  = "../modules/identities"
  cluster_name            = var.cluster_name
  resource_group_name     = module.network.resource_group_name
  location                = module.network.location
  vnet_id                 = module.network.vnet_id
  control_plane_subnet_id = module.network.control_plane_subnet_id
  worker_subnet_id        = module.network.worker_subnet_id
  nsg_id                  = module.network.nsg_id
  aro_rp_object_id        = data.azuread_service_principal.aro_rp.object_id
}

module "cluster" {
  source                       = "../modules/cluster"
  cluster_name                 = var.cluster_name
  location                     = var.location
  resource_group_name          = module.network.resource_group_name
  managed_resource_group_name  = local.managed_resource_group_name
  domain                       = var.domain
  pull_secret                  = local.pull_secret
  aro_version                  = var.aro_version
  control_plane_subnet_id      = module.network.control_plane_subnet_id
  worker_subnet_id             = module.network.worker_subnet_id
  cluster_msi_resource_id      = module.identities.cluster_msi_id
  platform_workload_identities = module.identities.platform_workload_identities
  api_server_visibility        = var.api_visibility
  ingress_visibility           = var.ingress_visibility
  worker_profiles              = local.initial_worker_profiles
  tags                         = var.tags

  depends_on = [module.identities]
}
