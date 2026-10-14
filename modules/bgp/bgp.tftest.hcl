mock_provider "azurerm" {}

variables {
  cluster_name            = "aro-classic-miwi"
  resource_group_name     = "aro-classic-miwi-rg"
  location                = "eastus"
  resource_group_id       = "/subscriptions/sub/resourceGroups/aro-classic-miwi-rg"
  machine_api_identity_id = "/subscriptions/sub/resourceGroups/aro-classic-miwi-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aro-classic-miwi-machine-api"
  oidc_issuer_url         = ""
}

run "no_federation_before_issuer" {
  command = plan

  assert {
    condition     = length(azurerm_federated_identity_credential.bgp) == 0
    error_message = "Do not federate the BGP identity before the cluster OIDC issuer exists."
  }

  assert {
    condition     = length(azurerm_federated_identity_credential.machine_api_bgp) == 0
    error_message = "Do not add the BGP subject on machine-api before the issuer exists."
  }

  assert {
    condition     = !contains(azurerm_role_definition.bgp_cloud_connector.permissions[0].actions, "Microsoft.Network/networkInterfaces/write")
    error_message = "NIC writes stay on machine-api. The BGP role must not include NIC write."
  }
}
