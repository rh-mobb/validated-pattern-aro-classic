output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "pull_secret_key_vault_secret_name" {
  value = var.pull_secret_key_vault_secret_name
}

output "eso_identity_id" {
  description = "Resource ID of the ESO workload identity (not a platform operator MI)."
  value       = azurerm_user_assigned_identity.eso.id
}

output "eso_client_id" {
  description = "Client ID for openshift-gitops/aro-platform-metadata and ESO ServiceAccount annotation."
  value       = azurerm_user_assigned_identity.eso.client_id
}

output "eso_federated_subject" {
  value = local.eso_federated_subject
}
