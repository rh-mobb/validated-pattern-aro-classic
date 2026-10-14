locals {
  role_definitions = {
    aro_cloud_controller_manager = "Azure Red Hat OpenShift Cloud Controller Manager"
    aro_cluster_ingress_operator = "Azure Red Hat OpenShift Cluster Ingress Operator"
    aro_network_operator         = "Azure Red Hat OpenShift Network Operator"
    aro_file_storage_operator    = "Azure Red Hat OpenShift File Storage Operator"
    aro_service_operator         = "Azure Red Hat OpenShift Service Operator"
    network_contributor          = "Network Contributor"
    aro_machine_api_operator     = "Azure Red Hat OpenShift Machine API Operator"
    aro_image_registry_operator  = "Azure Red Hat OpenShift Image Registry Operator"
    aro_disk_csi_driver_operator = "Azure Red Hat OpenShift Disk Storage Operator"
  }

  subnet_scoped_identities = {
    disk_csi_driver          = local.role_definitions.aro_disk_csi_driver_operator
    cloud_controller_manager = local.role_definitions.aro_cloud_controller_manager
    ingress                  = local.role_definitions.aro_cluster_ingress_operator
    machine_api              = local.role_definitions.aro_machine_api_operator
    file_csi_driver          = local.role_definitions.aro_file_storage_operator
    aro_operator             = local.role_definitions.aro_service_operator
  }

  vnet_scoped_identities = {
    cloud_network_config = local.role_definitions.aro_network_operator
    image_registry       = local.role_definitions.aro_image_registry_operator
    file_csi_driver      = local.role_definitions.aro_file_storage_operator
  }

  identity_principal_ids = {
    for k, id in azurerm_user_assigned_identity.this : k => id.principal_id
  }
}

resource "azurerm_role_assignment" "control_plane_subnet" {
  for_each = local.subnet_scoped_identities

  scope                = var.control_plane_subnet_id
  role_definition_name = each.value
  principal_id         = local.identity_principal_ids[each.key]
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "control_plane_subnet_image_registry" {
  scope                = var.control_plane_subnet_id
  role_definition_name = local.role_definitions.aro_image_registry_operator
  principal_id         = local.identity_principal_ids["image_registry"]
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "compute_subnet" {
  for_each = local.subnet_scoped_identities

  scope                = var.worker_subnet_id
  role_definition_name = each.value
  principal_id         = local.identity_principal_ids[each.key]
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "vnet" {
  for_each = local.vnet_scoped_identities

  scope                = var.vnet_id
  role_definition_name = each.value
  principal_id         = local.identity_principal_ids[each.key]
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aro_rp_vnet" {
  scope                = var.vnet_id
  role_definition_name = local.role_definitions.network_contributor
  principal_id         = var.aro_rp_object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "nsg_platform_identities" {
  for_each = toset([
    "machine_api",
    "aro_operator",
    "file_csi_driver",
    "disk_csi_driver",
    "cloud_controller_manager",
    "cloud_network_config",
    "ingress",
    "image_registry",
  ])

  scope                = var.nsg_id
  role_definition_name = local.role_definitions.network_contributor
  principal_id         = local.identity_principal_ids[each.key]
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aro_rp_nsg" {
  scope                = var.nsg_id
  role_definition_name = local.role_definitions.network_contributor
  principal_id         = var.aro_rp_object_id
  principal_type       = "ServicePrincipal"
}
