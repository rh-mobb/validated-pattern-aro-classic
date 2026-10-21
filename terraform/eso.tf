# Federated credential after cluster exists (issuer from cluster output).
resource "azurerm_federated_identity_credential" "eso" {
  name      = "eso-external-secrets"
  parent_id = module.platform_secrets.eso_identity_id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.cluster.oidc_issuer_url
  subject   = module.platform_secrets.eso_federated_subject

  depends_on = [module.cluster]
}
