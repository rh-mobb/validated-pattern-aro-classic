# Desired configuration only. Cluster discovery and Helm run through Make after login.
resource "local_file" "machinesets_values" {
  filename = "${coalesce(var.machinesets_directory, "${path.root}/../clusters/${var.cluster_name}/machinesets")}/values.yaml"
  content = yamlencode({
    initialWorkerPool = var.initial_worker_pool
    nodePools         = local.effective_node_pools
  })
  file_permission      = "0600"
  directory_permission = "0700"
}

output "machinesets_values" {
  description = "Desired Helm values, also written to the profile machinesets/values.yaml."
  value       = yamldecode(local_file.machinesets_values.content)
}

output "machinesets_values_yaml" {
  description = "Exact generated values file content, for restoring disposable local artifacts."
  value       = local_file.machinesets_values.content
}
