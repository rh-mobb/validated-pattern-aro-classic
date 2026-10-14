mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "azuread" {
  mock_data "azuread_service_principal" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000099"
    }
  }
}
mock_provider "random" {}

variables {
  cluster_name    = "aro-classic-miwi"
  location        = "eastus"
  domain          = "classicmiwi"
  aro_version     = "4.21.22"
  pull_secret     = "{}"
  oidc_issuer_url = ""
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
