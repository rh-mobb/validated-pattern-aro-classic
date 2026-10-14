provider "azurerm" {
  features {}
}

provider "azapi" {}

provider "azuread" {}

provider "random" {}

data "azuread_service_principal" "aro_rp" {
  display_name = "Azure Red Hat OpenShift RP"
}
