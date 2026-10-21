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
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000099"
    }
  }
}
mock_provider "random" {}
mock_provider "local" {}

variables {
  cluster_name = "aro-classic-miwi"
  location     = "eastus"
  domain       = "classicmiwi"
  aro_version  = "4.21.22"
  pull_secret  = "{}"
}

run "platform_identity_keys" {
  command = plan

  assert {
    condition     = contains(output.platform_workload_identity_key_names, "machine-api")
    error_message = "platformWorkloadIdentities must include machine-api."
  }

  assert {
    condition     = !contains(output.platform_workload_identity_key_names, "cluster")
    error_message = "cluster MSI must not be a platformWorkloadIdentities key."
  }
}

run "platform_contract_for_virt_sibling" {
  command = plan

  assert {
    condition     = output.platform.contract_version == 1
    error_message = "platform.contract_version must be 1."
  }

  assert {
    condition     = output.platform.network.reserved.netapp_subnet_prefix == "10.0.3.0/24"
    error_message = "platform must publish reserved netapp_subnet_prefix for the virt sibling."
  }

  assert {
    condition     = output.platform.installer == "classic"
    error_message = "platform.installer must identify Classic for sibling documentation."
  }
}

# The Bats lifecycle test also inspects this run's ARM resource plan to prove
# these day-2 entries never reach workerProfiles through the root module wiring.
run "day2_intent_with_distinct_day0_sizing" {
  command = plan

  variables {
    worker_count        = 9
    worker_vm_size      = "Standard_D16s_v5"
    worker_disk_size_gb = 1024
    node_pools = {
      base = {
        vm_size      = "Standard_D8s_v5"
        replicas     = 4
        disk_size_gb = 256
      }
      np-virt = {
        vm_size      = "Standard_D8s_v6"
        replicas     = 2
        disk_size_gb = 512
        labels = {
          bgp_router = "true"
          workload   = "virtualization"
        }
      }
    }
    initial_worker_pool = "base"
  }

  assert {
    condition     = keys(output.platform.node_pools) == ["base", "np-virt"]
    error_message = "All defined pools must be exported without adding a synthetic worker pool."
  }

  assert {
    condition = (
      output.platform.node_pools["np-virt"].vm_size == "Standard_D8s_v6" &&
      output.platform.node_pools["np-virt"].replicas == 2 &&
      output.platform.node_pools["np-virt"].disk_size_gb == 512 &&
      output.platform.node_pools["np-virt"].labels.bgp_router == "true" &&
      output.platform.node_pools["np-virt"].labels.workload == "virtualization"
    )
    error_message = "The sibling contract must preserve day-2 sizing and labels independently of day-0 workers."
  }

  assert {
    condition = (
      yamldecode(local_file.machinesets_values.content).initialWorkerPool == "base" &&
      yamldecode(local_file.machinesets_values.content).nodePools["np-virt"].replicas == 2
    )
    error_message = "Terraform must write the desired Helm values for the named initial pool and additional pools."
  }
}

run "initial_pool_must_exist" {
  command = plan
  variables {
    initial_worker_pool = "missing"
  }
  expect_failures = [var.initial_worker_pool]
}

run "reject_fractional_pool_replicas" {
  command = plan
  variables {
    node_pools = { worker = { vm_size = "Standard_D4s_v5", replicas = 1.5 } }
  }
  expect_failures = [var.node_pools]
}

run "reject_empty_worker_population" {
  command = plan
  variables {
    node_pools = { worker = { vm_size = "Standard_D4s_v5", replicas = 0 } }
  }
  expect_failures = [var.node_pools]
}

# Account metadata must remain known even while the network has pending changes.
run "platform_secrets_account_lookup_is_plan_time" {
  command = plan

  assert {
    condition     = output.tenant_id == "00000000-0000-0000-0000-000000000004"
    error_message = "Network changes must not defer the platform-secrets account lookup until apply."
  }
}

run "reject_route_server_overlap_with_control_plane" {
  command = plan

  variables {
    route_server_subnet_prefix = "10.0.0.0/26"
  }

  expect_failures = [terraform_data.platform_cidrs]
}
