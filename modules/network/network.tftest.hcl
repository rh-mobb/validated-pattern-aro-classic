mock_provider "azurerm" {}

variables {
  cluster_name        = "aro-classic-miwi"
  resource_group_name = "aro-classic-miwi-rg"
  location            = "eastus"
}

run "cidrs_and_route_server_subnet" {
  command = plan

  assert {
    condition     = azurerm_subnet.route_server.name == "RouteServerSubnet"
    error_message = "Azure requires the subnet name RouteServerSubnet."
  }

  assert {
    condition     = azurerm_subnet.route_server.address_prefixes[0] == "10.0.12.0/26"
    error_message = "New Route Server subnets must be /26 or larger. This profile uses 10.0.12.0/26."
  }

  assert {
    condition     = azurerm_subnet.control_plane.address_prefixes[0] == "10.0.0.0/23"
    error_message = "Control plane subnet must be 10.0.0.0/23."
  }

  assert {
    condition     = azurerm_subnet.worker.address_prefixes[0] == "10.0.2.0/23"
    error_message = "Worker subnet must be 10.0.2.0/23."
  }

}
