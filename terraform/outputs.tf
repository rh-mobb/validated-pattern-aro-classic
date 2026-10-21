output "cluster_name" {
  value = var.cluster_name
}

output "resource_group_name" {
  value = module.network.resource_group_name
}

output "location" {
  value = module.network.location
}

output "tenant_id" {
  value = module.platform_secrets.tenant_id
}

output "key_vault_name" {
  value = module.platform_secrets.key_vault_name
}

output "key_vault_id" {
  value = module.platform_secrets.key_vault_id
}

output "key_vault_uri" {
  value = module.platform_secrets.key_vault_uri
}

output "eso_client_id" {
  description = "ESO workload identity client ID for aro-platform-metadata."
  value       = module.platform_secrets.eso_client_id
}

output "pull_secret_key_vault_secret_name" {
  value = module.platform_secrets.pull_secret_key_vault_secret_name
}

output "api_visibility" {
  value = var.api_visibility
}

output "ingress_visibility" {
  value = var.ingress_visibility
}

output "machine_api_client_id" {
  value = module.identities.machine_api_client_id
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

output "platform" {
  description = "Versioned contract for validated-pattern-openshift-virt (terraform output -json platform)."
  value = {
    contract_version    = 1
    installer           = "classic"
    subscription_id     = data.azurerm_client_config.current.subscription_id
    tenant_id           = module.platform_secrets.tenant_id
    location            = module.network.location
    cluster_name        = var.cluster_name
    cluster_id          = module.cluster.resource_id
    resource_group_name = module.network.resource_group_name
    network = {
      vnet_id              = module.network.vnet_id
      vnet_name            = module.network.vnet_name
      address_prefix       = module.network.address_prefix
      worker_subnet_id     = module.network.worker_subnet_id
      worker_subnet_name   = module.network.worker_subnet_name
      worker_subnet_prefix = module.network.worker_subnet_prefix
      nsg_id               = module.network.nsg_id
      reserved = {
        netapp_subnet_prefix       = var.netapp_subnet_prefix
        route_server_subnet_prefix = var.route_server_subnet_prefix
      }
    }
    oidc_issuer_url       = module.cluster.oidc_issuer_url
    key_vault_id          = module.platform_secrets.key_vault_id
    key_vault_name        = module.platform_secrets.key_vault_name
    key_vault_uri         = module.platform_secrets.key_vault_uri
    eso_client_id         = module.platform_secrets.eso_client_id
    machine_api_client_id = module.identities.machine_api_client_id
    api_url               = module.cluster.api_server_url
    api_visibility        = var.api_visibility
    cluster_version       = var.aro_version
    node_pools = {
      for name, p in local.effective_node_pools : name => {
        vm_size      = p.vm_size
        replicas     = p.replicas
        disk_size_gb = coalesce(try(p.disk_size_gb, null), 128)
        subnet_id    = try(p.subnet_id, null)
        labels       = coalesce(p.labels, {})
      }
    }
  }
}
