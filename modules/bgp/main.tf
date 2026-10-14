resource "azurerm_user_assigned_identity" "bgp" {
  name                = "${var.cluster_name}-bgp"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_definition" "bgp_cloud_connector" {
  name        = "${var.cluster_name}-bgp-cloud-connector"
  scope       = var.resource_group_id
  description = "bgp-cloud-connector: Azure Route Server BGP connections in the customer RG."

  permissions {
    actions = [
      "Microsoft.Network/virtualHubs/read",
      "Microsoft.Network/virtualHubs/ipConfigurations/read",
      "Microsoft.Network/virtualHubs/bgpConnections/read",
      "Microsoft.Network/virtualHubs/bgpConnections/write",
      "Microsoft.Network/virtualHubs/bgpConnections/delete",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",
    ]
    not_actions = []
  }

  assignable_scopes = [var.resource_group_id]
}

resource "azurerm_role_assignment" "bgp_cloud_connector" {
  scope                            = var.resource_group_id
  role_definition_id               = azurerm_role_definition.bgp_cloud_connector.role_definition_resource_id
  principal_id                     = azurerm_user_assigned_identity.bgp.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "bgp" {
  count = trimspace(var.oidc_issuer_url) != "" ? 1 : 0

  name                       = "bgp-cloud-connector"
  user_assigned_identity_id  = azurerm_user_assigned_identity.bgp.id
  audience                   = ["openshift"]
  issuer    = var.oidc_issuer_url
  subject   = var.bgp_federated_subject
}

resource "azurerm_federated_identity_credential" "machine_api_bgp" {
  count = trimspace(var.oidc_issuer_url) != "" ? 1 : 0

  name                       = "bgp-cloud-connector"
  user_assigned_identity_id  = var.machine_api_identity_id
  audience                   = ["openshift"]
  issuer    = var.oidc_issuer_url
  subject   = var.bgp_federated_subject
}
