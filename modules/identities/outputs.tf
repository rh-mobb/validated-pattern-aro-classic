output "cluster_msi_id" {
  value = azurerm_user_assigned_identity.this["cluster_msi"].id
}

output "machine_api_id" {
  value = azurerm_user_assigned_identity.this["machine_api"].id
}

output "machine_api_client_id" {
  value = azurerm_user_assigned_identity.this["machine_api"].client_id
}

output "platform_workload_identities" {
  description = "ARM platformWorkloadIdentities map (eight operators, excludes cluster MSI)."
  value = {
    for key, short in local.operator_api_keys : short => azurerm_user_assigned_identity.this[key].id
    if key != "cluster_msi"
  }
}

output "platform_workload_identity_key_names" {
  description = "API keys for platformWorkloadIdentities (plan-time assertion)."
  value       = local.platform_workload_identity_keys
}
