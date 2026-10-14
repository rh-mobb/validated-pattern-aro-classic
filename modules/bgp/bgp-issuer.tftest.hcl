mock_provider "azurerm" {}

variables {
  cluster_name            = "aro-classic-miwi"
  resource_group_name     = "aro-classic-miwi-rg"
  location                = "eastus"
  resource_group_id       = "/subscriptions/sub/resourceGroups/aro-classic-miwi-rg"
  machine_api_identity_id = "/subscriptions/sub/resourceGroups/aro-classic-miwi-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aro-classic-miwi-machine-api"
  oidc_issuer_url         = "https://eastus.oic.aro.azure.com/example"
}

run "federation_after_issuer" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.bgp[0].audience[0] == "openshift"
    error_message = "Classic MIWI audience is openshift."
  }

  assert {
    condition     = azurerm_federated_identity_credential.machine_api_bgp[0].subject == "system:serviceaccount:openshift-bgp-cloud-connector:openshift-bgp-cloud-connector-controller-manager"
    error_message = "Additive machine-api credential must target the BGP operator ServiceAccount."
  }

  assert {
    condition     = azurerm_federated_identity_credential.machine_api_bgp[0].user_assigned_identity_id == var.machine_api_identity_id
    error_message = "NIC token exchange federates machine-api, not the BGP identity."
  }
}
