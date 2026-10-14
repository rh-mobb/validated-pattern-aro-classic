locals {
  resource_group_name         = "${var.cluster_name}-rg"
  managed_resource_group_name = "${var.cluster_name}-managed-rg"
  pull_secret = (
    trimspace(var.pull_secret) != "" ? var.pull_secret :
    (trimspace(var.pull_secret_path) != "" ? file(pathexpand(var.pull_secret_path)) : "{}")
  )
}

module "network" {
  source              = "../modules/network"
  cluster_name        = var.cluster_name
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags
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
  worker_count                 = var.worker_count
  tags                         = var.tags

  depends_on = [module.identities]
}

module "routeserver" {
  source                 = "../modules/routeserver"
  cluster_name           = var.cluster_name
  location               = module.network.location
  resource_group_name    = module.network.resource_group_name
  route_server_subnet_id = module.network.route_server_subnet_id
  tags                   = var.tags
}

module "bgp" {
  source                  = "../modules/bgp"
  cluster_name            = var.cluster_name
  resource_group_name     = module.network.resource_group_name
  location                = module.network.location
  resource_group_id       = module.network.resource_group_id
  machine_api_identity_id = module.identities.machine_api_id
  oidc_issuer_url         = trimspace(var.oidc_issuer_url)
  tags                    = var.tags
}
