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
  description = "Classic MIWI exposes issuer on clusterProfile.oidcIssuer (not HCP oidcIssuerProfile.issuerUrl)."
  value = coalesce(
    try(azapi_resource.aro_cluster.output.properties.clusterProfile.oidcIssuer, ""),
    try(azapi_resource.aro_cluster.output.properties.oidcIssuerProfile.issuerUrl, "")
  )
}
