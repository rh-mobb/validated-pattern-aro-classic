# Greenfield compute example; CNV, storage and BGP operators belong to the virt sibling.
location     = "eastus"
cluster_name = "aro-classic-virt"
domain       = "classicvirt"
aro_version  = "4.21.22"

api_visibility     = "Public"
ingress_visibility = "Public"

# Replace with a local file before deployment; never commit the secret itself.
pull_secret_path = "~/Downloads/pull-secret.txt"

netapp_subnet_prefix       = "10.0.3.0/24"
route_server_subnet_prefix = "10.0.4.0/26"

initial_worker_pool = "worker"
node_pools = {
  # Default workers host installer GitOps and platform services. Leave untainted.
  worker = {
    vm_size  = "Standard_D4s_v5"
    replicas = 3
  }

  # VM workload nodes, separate from the BGP speaker pool.
  np-virt = {
    vm_size  = "Standard_D8s_v6"
    replicas = 2
    zones    = ["1", "2"]
    labels = {
      pool     = "np-virt"
      workload = "virtualization"
    }
    taints = [{ key = "workload", value = "virtualization", effect = "NoSchedule" }]
  }

  # BGP speakers: the virt sibling discovers this pool through bgp_router=true.
  np-bgp = {
    vm_size  = "Standard_D8s_v6"
    replicas = 2
    zones    = ["1", "2"]
    labels = {
      pool       = "np-bgp"
      workload   = "bgp"
      bgp_router = "true"
    }
    taints = [{ key = "workload", value = "bgp", effect = "NoSchedule" }]
  }
}
