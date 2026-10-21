# Invoked by Bats with the actual committed example tfvars, not copied pool definitions.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000004"
      subscription_id = "00000000-0000-0000-0000-000000000001"
      object_id       = "00000000-0000-0000-0000-000000000002"
    }
  }
}
mock_provider "azapi" {}
mock_provider "azuread" {
  mock_data "azuread_service_principal" {
    defaults = { object_id = "00000000-0000-0000-0000-000000000099" }
  }
}
mock_provider "random" {}
mock_provider "local" {}

run "virt_example_compute" {
  command = plan
  variables {
    pull_secret = "{}"
  }

  assert {
    condition = (
      var.cluster_name == "aro-classic-virt" &&
      var.initial_worker_pool == "worker" &&
      keys(output.machinesets_values.nodePools) == ["np-bgp", "np-virt", "worker"] &&
      sum([for p in output.machinesets_values.nodePools : p.replicas]) == 7
    )
    error_message = "The virt example must define three pools with seven total workers."
  }

  assert {
    condition = (
      output.platform.node_pools["np-bgp"].labels.bgp_router == "true" &&
      output.machinesets_values.nodePools["np-virt"].taints[0].value == "virtualization" &&
      output.machinesets_values.nodePools["np-bgp"].taints[0].value == "bgp" &&
      length(output.machinesets_values.nodePools.worker.taints) == 0
    )
    error_message = "Extra pools must export their labels and distinct taints; defaults stay untainted."
  }
}
