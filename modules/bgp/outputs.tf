output "bgp_client_id" {
  value = azurerm_user_assigned_identity.bgp.client_id
}

output "bgp_identity_id" {
  value = azurerm_user_assigned_identity.bgp.id
}
