mock_provider "azurerm" {
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-nsg" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet" }
  }
}

variables {
  cluster_name        = "aro-classic-miwi"
  resource_group_name = "aro-classic-miwi-rg"
  location            = "eastus"
}

run "virt_ready_cidrs" {
  command = plan

  assert {
    condition     = azurerm_subnet.control_plane.address_prefixes[0] == "10.0.0.0/23"
    error_message = "Control plane subnet must be 10.0.0.0/23."
  }

  assert {
    condition     = azurerm_subnet.worker.address_prefixes[0] == "10.0.2.0/24"
    error_message = "Worker subnet must be 10.0.2.0/24 (CP /23; reserved 10.0.3.0/24 and 10.0.4.0/26 are sibling-owned)."
  }
}

# Mock apply stores initial tags in isolated test state; no Azure requests.
run "create_with_tags" {
  command = apply
  variables {
    tags = { cost-center = "policy-owned" }
  }
}

run "post_create_tag_changes_are_ignored" {
  command = plan
  variables {
    tags = { team = "new-value" }
  }

  assert {
    condition     = azurerm_resource_group.this[0].tags == tomap({ cost-center = "policy-owned" })
    error_message = "azurerm_resource_group.this[0] must preserve externally managed tags after creation."
  }

  assert {
    condition     = azurerm_virtual_network.this.tags == tomap({ cost-center = "policy-owned" })
    error_message = "azurerm_virtual_network.this must preserve externally managed tags after creation."
  }

  assert {
    condition     = azurerm_network_security_group.this.tags == tomap({ cost-center = "policy-owned" })
    error_message = "azurerm_network_security_group.this must preserve externally managed tags after creation."
  }
}
