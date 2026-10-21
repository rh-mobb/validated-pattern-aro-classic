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

output "address_prefix" {
  value = var.vnet_address_space
}

output "worker_subnet_name" {
  value = azurerm_subnet.worker.name
}

output "worker_subnet_prefix" {
  value = var.worker_subnet_prefix
}

output "control_plane_subnet_id" {
  value = azurerm_subnet.control_plane.id
}

output "worker_subnet_id" {
  value = azurerm_subnet.worker.id
}

output "nsg_id" {
  value = azurerm_network_security_group.this.id
}
