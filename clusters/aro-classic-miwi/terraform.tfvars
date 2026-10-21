location     = "eastus"
cluster_name = "aro-classic-miwi"
domain       = "classicmiwi"
aro_version  = "4.21.22"

api_visibility     = "Public"
ingress_visibility = "Public"

pull_secret_path = "/Users/pczarkow/Downloads/pull-secret.txt"

# Reserved for validated-pattern-openshift-virt (not created here).
netapp_subnet_prefix       = "10.0.3.0/24"
route_server_subnet_prefix = "10.0.4.0/26"

# One source for compute shape: this named pool supplies initial ARM worker sizing.
# After installation, the machinesets target adopts the existing default MachineSets.
initial_worker_pool = "worker"
node_pools = {
  worker = {
    vm_size  = "Standard_D4s_v5"
    replicas = 3
  }
  # Optional virt pool. Replicas are TOTAL across the selected zones.
  # np-virt = {
  #   vm_size  = "Standard_D8s_v6"
  #   replicas = 2
  #   zones    = ["1", "2"]
  #   labels = {
  #     workload   = "virtualization"
  #     bgp_router = "true"
  #   }
  # }
}
