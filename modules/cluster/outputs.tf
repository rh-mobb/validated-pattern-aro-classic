output "api_server_url" {
  value = try(azapi_resource.aro_cluster.output.properties.apiserverProfile.url, null)
}

output "console_url" {
  value = try(azapi_resource.aro_cluster.output.properties.consoleProfile.url, null)
}

output "resource_id" {
  value = azapi_resource.aro_cluster.id
}

output "oidc_issuer_url" {
  value = try(azapi_resource.aro_cluster.output.properties.oidcIssuerProfile.issuerUrl, "")
}
