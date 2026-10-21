mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      output = {
        properties = {
          clusterProfile = { oidcIssuer = "https://issuer.example/" }
        }
      }
    }
  }
}

variables {
  cluster_name                = "aro-classic-miwi"
  location                    = "eastus"
  resource_group_name         = "aro-classic-miwi-rg"
  managed_resource_group_name = "aro-classic-miwi-managed-rg"
  domain                      = "classicmiwi"
  pull_secret                 = "{}"
  aro_version                 = "4.21.22"
  control_plane_subnet_id     = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/aro-classic-miwi-rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/control-plane"
  worker_subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/aro-classic-miwi-rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/worker"
  cluster_msi_resource_id     = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/aro-classic-miwi-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aro-classic-miwi-cluster"
  worker_profiles = {
    worker = {
      vm_size  = "Standard_D4s_v5"
      replicas = 3
    }
  }
  platform_workload_identities = {
    "cloud-controller-manager" = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ccm"
    "ingress"                  = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ingress"
    "machine-api"              = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/machine-api"
    "disk-csi-driver"          = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/disk"
    "cloud-network-config"     = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/net"
    "image-registry"           = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/reg"
    "file-csi-driver"          = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/file"
    "aro-operator"             = "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/op"
  }
}

# A mocked apply creates Terraform test state only; no Azure API is called.
run "install_default_workers" {
  command = apply

  assert {
    condition = (
      length(azapi_resource.aro_cluster.body.properties.workerProfiles) == 1 &&
      azapi_resource.aro_cluster.body.properties.workerProfiles[0].name == "worker" &&
      azapi_resource.aro_cluster.body.properties.workerProfiles[0].count == 3 &&
      azapi_resource.aro_cluster.body.properties.workerProfiles[0].vmSize == "Standard_D4s_v5" &&
      azapi_resource.aro_cluster.body.properties.workerProfiles[0].diskSizeGB == 128
    )
    error_message = "Initial creation must use the configured default worker sizing."
  }
}

run "post_install_worker_edits_are_ignored" {
  command = plan

  variables {
    worker_profiles = {
      worker = {
        vm_size      = "Standard_D8s_v6"
        replicas     = 6
        disk_size_gb = 256
      }
    }
  }

  assert {
    condition     = azapi_resource.aro_cluster.id == run.install_default_workers.resource_id
    error_message = "Sizing edits must preserve the existing cluster identity."
  }

  assert {
    condition = (
      azapi_resource.aro_cluster.body.properties.workerProfiles[0].count == 3 &&
      azapi_resource.aro_cluster.body.properties.workerProfiles[0].vmSize == "Standard_D4s_v5" &&
      azapi_resource.aro_cluster.body.properties.workerProfiles[0].diskSizeGB == 128
    )
    error_message = "Post-install count, SKU, and disk edits must leave the original ARM worker profile unchanged."
  }
}

run "miwi_cluster_body" {
  command = plan

  assert {
    condition     = azapi_resource.aro_cluster.type == "Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25"
    error_message = "Classic MIWI cluster must use API 2025-07-25."
  }

  assert {
    condition     = azapi_resource.aro_cluster.identity[0].type == "UserAssigned"
    error_message = "Cluster identity type must be UserAssigned."
  }

  assert {
    condition = contains(
      keys(azapi_resource.aro_cluster.body.properties.platformWorkloadIdentityProfile.platformWorkloadIdentities),
      "machine-api"
    )
    error_message = "Cluster body must register the machine-api workload identity."
  }

  assert {
    condition = !contains(
      keys(azapi_resource.aro_cluster.body.properties.platformWorkloadIdentityProfile.platformWorkloadIdentities),
      "cluster"
    )
    error_message = "Cluster MSI must not appear inside platformWorkloadIdentities."
  }
}
