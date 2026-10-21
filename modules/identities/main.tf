locals {
  cluster_msi_key     = "cluster_msi"
  other_identity_keys = toset([for k in keys(local.identity_names) : k if k != local.cluster_msi_key])

  aro_federated_credential_role_definition_name = "Azure Red Hat OpenShift Federated Credential"
}

resource "azurerm_user_assigned_identity" "this" {
  for_each = local.identity_names

  name                = each.value
  location            = var.location
  resource_group_name = var.resource_group_name

  # Tags may be injected by Azure Policy even without configured tags.
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "random_uuid" "role_assignment_names" {
  for_each = local.other_identity_keys

  keepers = {
    scope        = azurerm_user_assigned_identity.this[each.key].id
    principal_id = azurerm_user_assigned_identity.this[local.cluster_msi_key].principal_id
    role_def     = local.aro_federated_credential_role_definition_name
    authoring    = "builtin_name_v1"
  }
}

resource "azurerm_role_assignment" "cluster_msi_federated_credential" {
  for_each = local.other_identity_keys

  name                             = random_uuid.role_assignment_names[each.key].result
  scope                            = azurerm_user_assigned_identity.this[each.key].id
  role_definition_name             = local.aro_federated_credential_role_definition_name
  principal_id                     = azurerm_user_assigned_identity.this[local.cluster_msi_key].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true

  depends_on = [random_uuid.role_assignment_names]
}
