# Federated credential after the cluster exists (same pattern as validated-pattern-aro-hcp terraform/bgp.tf).
# Classic uses machine-api for managed-RG NIC IP forwarding (HCP uses cluster-api-azure). See virt sibling docs.
locals {
  bgp_cloud_connector_federated_subject = "system:serviceaccount:openshift-bgp-cloud-connector:openshift-bgp-cloud-connector-controller-manager"
}

resource "azurerm_federated_identity_credential" "bgp_cloud_connector" {
  name      = "machine-api-bgp-cloud-connector"
  parent_id = module.identities.machine_api_id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.cluster.oidc_issuer_url
  subject   = local.bgp_cloud_connector_federated_subject

  depends_on = [module.cluster]
}
