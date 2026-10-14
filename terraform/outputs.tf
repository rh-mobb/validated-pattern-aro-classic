output "resource_group_name" {
  value = module.network.resource_group_name
}

output "machine_api_client_id" {
  value = module.identities.machine_api_client_id
}

output "bgp_client_id" {
  value = module.bgp.bgp_client_id
}

output "network_interface_client_id" {
  description = "BGPCloudConfiguration networkInterfaceClientID (machine-api)."
  value       = module.identities.machine_api_client_id
}

output "route_server_name" {
  value = module.routeserver.route_server_name
}

output "oidc_issuer_url" {
  value = module.cluster.oidc_issuer_url
}

output "api_server_url" {
  value = module.cluster.api_server_url
}

output "console_url" {
  value = module.cluster.console_url
}

output "platform_workload_identity_key_names" {
  value = module.identities.platform_workload_identity_key_names
}
