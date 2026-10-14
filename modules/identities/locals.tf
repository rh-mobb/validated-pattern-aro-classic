locals {
  operator_api_keys = {
    cloud_controller_manager = "cloud-controller-manager"
    ingress                  = "ingress"
    machine_api              = "machine-api"
    disk_csi_driver          = "disk-csi-driver"
    cloud_network_config     = "cloud-network-config"
    image_registry           = "image-registry"
    file_csi_driver          = "file-csi-driver"
    aro_operator             = "aro-operator"
    cluster_msi              = "cluster"
  }

  identity_names = {
    for key, short in local.operator_api_keys : key => "${var.cluster_name}-${short}"
  }

  platform_workload_identity_keys = [
    for key, short in local.operator_api_keys : short if key != "cluster_msi"
  ]
}
