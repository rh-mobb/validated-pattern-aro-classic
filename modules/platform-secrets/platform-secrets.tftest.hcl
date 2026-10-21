mock_provider "azurerm" {
  mock_resource "azurerm_key_vault" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.KeyVault/vaults/test-vault" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = { principal_id = "00000000-0000-0000-0000-000000000003" }
  }
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000004"
      subscription_id = "00000000-0000-0000-0000-000000000001"
      object_id       = "00000000-0000-0000-0000-000000000002"
    }
  }
}

mock_provider "random" {}

run "pull_secret_optional" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    location            = "eastus"
    resource_group_name = "test-rg"
    pull_secret_content = ""
  }

  assert {
    condition     = length(azurerm_key_vault_secret.pull_secret) == 0
    error_message = "Empty pull secret must not create Key Vault secret."
  }
}

run "pull_secret_stored" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    location            = "eastus"
    resource_group_name = "test-rg"
    pull_secret_content = "{\"auths\":{}}"
  }

  assert {
    condition     = length(azurerm_key_vault_secret.pull_secret) == 1
    error_message = "Non-empty pull secret must create Key Vault secret."
  }

  assert {
    condition     = azurerm_user_assigned_identity.eso.name == "test-cluster-eso"
    error_message = "ESO identity must be named <cluster>-eso."
  }
}

variables {
  cluster_name        = "test-cluster"
  location            = "eastus"
  resource_group_name = "test-rg"
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
    condition     = azurerm_key_vault.this.tags == tomap({ cost-center = "policy-owned" })
    error_message = "azurerm_key_vault.this must preserve externally managed tags after creation."
  }

  assert {
    condition     = azurerm_user_assigned_identity.eso.tags == tomap({ cost-center = "policy-owned" })
    error_message = "azurerm_user_assigned_identity.eso must preserve externally managed tags after creation."
  }
}
