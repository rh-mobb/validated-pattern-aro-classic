data "azurerm_client_config" "current" {}

locals {
  have_pull_secret = length(trimspace(var.pull_secret_content)) > 0
  tags             = var.tags

  eso_namespace         = "external-secrets-operator"
  eso_service_account   = "external-secrets-sa"
  eso_federated_subject = "system:serviceaccount:${local.eso_namespace}:${local.eso_service_account}"

  key_vault_secrets_user_role_id = "4633458b-17de-408a-b874-0445c86b69e6"
}

resource "random_string" "key_vault_suffix" {
  length  = 13
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_key_vault" "this" {
  name                          = "cust-kv-${random_string.key_vault_suffix.result}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
  tags                          = local.tags

  lifecycle {
    ignore_changes = [soft_delete_retention_days, tags]
  }
}

resource "azurerm_role_assignment" "deployer_key_vault_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "pull_secret" {
  count = local.have_pull_secret ? 1 : 0

  name         = var.pull_secret_key_vault_secret_name
  value        = var.pull_secret_content
  key_vault_id = azurerm_key_vault.this.id
  content_type = "application/json"

  depends_on = [azurerm_role_assignment.deployer_key_vault_admin]
}

resource "azurerm_user_assigned_identity" "eso" {
  name                = "${var.cluster_name}-eso"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_role_assignment" "eso_key_vault_secrets_user" {
  scope                            = azurerm_key_vault.this.id
  role_definition_id               = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${local.key_vault_secrets_user_role_id}"
  principal_id                     = azurerm_user_assigned_identity.eso.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
