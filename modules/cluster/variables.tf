variable "cluster_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "managed_resource_group_name" {
  type = string
}

variable "domain" {
  type = string
}

variable "pull_secret" {
  type      = string
  sensitive = true
}

variable "aro_version" {
  type = string
}

variable "control_plane_subnet_id" {
  type = string
}

variable "worker_subnet_id" {
  type = string
}

variable "cluster_msi_resource_id" {
  type = string
}

variable "platform_workload_identities" {
  type = map(string)
}

variable "control_plane_vm_size" {
  type    = string
  default = "Standard_D8s_v5"
}

variable "worker_profiles" {
  description = "ARM workerProfiles map (name -> vm_size, replicas, optional disk_size_gb, subnet_id)."
  type = map(object({
    vm_size      = string
    replicas     = number
    disk_size_gb = optional(number, 128)
    subnet_id    = optional(string)
    labels       = optional(map(string), {})
  }))
}

variable "api_server_visibility" {
  type    = string
  default = "Public"
}

variable "ingress_visibility" {
  type    = string
  default = "Public"
}

variable "pod_cidr" {
  type    = string
  default = "10.128.0.0/14"
}

variable "service_cidr" {
  type    = string
  default = "172.30.0.0/16"
}

variable "outbound_type" {
  type    = string
  default = null
}

variable "preconfigured_nsg" {
  type    = string
  default = "Enabled"
}

variable "encryption_at_host" {
  type    = bool
  default = false
}

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
  })
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
