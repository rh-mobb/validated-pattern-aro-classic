mock_provider "azurerm" {}

variables {
  cluster_name           = "aro-classic-miwi"
  location               = "eastus"
  resource_group_name    = "aro-classic-miwi-rg"
  route_server_subnet_id = "/subscriptions/sub/resourceGroups/aro-classic-miwi-rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/RouteServerSubnet"
}

run "route_server_skus" {
  command = plan

  assert {
    condition     = azurerm_public_ip.route_server.sku == "Standard"
    error_message = "Route Server public IP must be Standard SKU."
  }

  assert {
    condition     = azurerm_public_ip.route_server.allocation_method == "Static"
    error_message = "Route Server public IP must use static allocation."
  }

  assert {
    condition     = azurerm_route_server.this.sku == "Standard"
    error_message = "Route Server must be Standard SKU."
  }
}
