mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  cluster_name            = "aro-classic-miwi"
  resource_group_name     = "aro-classic-miwi-rg"
  location                = "eastus"
  vnet_id                 = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet"
  control_plane_subnet_id = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/control-plane"
  worker_subnet_id        = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/worker"
  nsg_id                  = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg"
  aro_rp_object_id        = "00000000-0000-0000-0000-000000000099"
}

run "nine_identities_and_api_map" {
  command = plan

  assert {
    condition     = length(local.identity_names) == 9
    error_message = "Classic MIWI uses cluster MSI plus eight platform operators."
  }

  assert {
    condition     = length(local.platform_workload_identity_keys) == 8
    error_message = "platformWorkloadIdentities has eight keys."
  }

  assert {
    condition     = contains(local.platform_workload_identity_keys, "machine-api")
    error_message = "machine-api must be an ARM platformWorkloadIdentities key."
  }

  assert {
    condition     = !contains(local.platform_workload_identity_keys, "cluster")
    error_message = "The cluster MSI is the resource identity, not a platformWorkloadIdentities entry."
  }

  assert {
    condition     = local.identity_names.machine_api == "aro-classic-miwi-machine-api"
    error_message = "machine-api Azure name must be <cluster>-machine-api."
  }
}
