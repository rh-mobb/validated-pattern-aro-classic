output "resource_group_name" {
  value = local.resource_group_name
}

output "resource_group_id" {
  value = azurerm_resource_group.this[0].id
}

output "location" {
  value = local.location
}

output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "control_plane_subnet_id" {
  value = azurerm_subnet.control_plane.id
}

output "worker_subnet_id" {
  value = azurerm_subnet.worker.id
}

output "route_server_subnet_id" {
  value = azurerm_subnet.route_server.id
}

output "nsg_id" {
  value = azurerm_network_security_group.this.id
}
