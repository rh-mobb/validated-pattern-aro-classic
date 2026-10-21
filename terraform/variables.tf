variable "cluster_name" {
  type        = string
  description = "ARO Classic cluster name."
}

variable "location" {
  type = string
}

variable "domain" {
  type = string
}

variable "aro_version" {
  type = string
}

variable "pull_secret_path" {
  type        = string
  default     = ""
  description = "Path to Red Hat pull secret JSON file."
}

variable "pull_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Inline pull secret for tests; live deploys use pull_secret_path."
}

variable "pull_secret_key_vault_secret_name" {
  type        = string
  default     = "redhat-pull-secret"
  description = "Key Vault secret name for the Red Hat pull secret (bootstrap / ESO)."

  validation {
    condition     = can(regex("^[0-9a-zA-Z-]{1,127}$", var.pull_secret_key_vault_secret_name))
    error_message = "pull_secret_key_vault_secret_name must be 1-127 alphanumeric characters or hyphens."
  }
}

variable "api_visibility" {
  type    = string
  default = "Public"
}

variable "ingress_visibility" {
  type    = string
  default = "Public"
}

variable "worker_count" {
  type        = number
  default     = 3
  description = "Default worker pool size when node_pools is empty."
}

variable "worker_vm_size" {
  type        = string
  default     = "Standard_D4s_v5"
  description = "Default worker VM size when node_pools is empty."
}

variable "worker_disk_size_gb" {
  type        = number
  default     = 128
  description = "Default worker OS disk size when node_pools is empty."
}

variable "vnet_address_space" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VNet CIDR."
}

variable "control_plane_subnet_prefix" {
  type        = string
  default     = "10.0.0.0/23"
  description = "Control plane subnet CIDR."
}

variable "worker_subnet_prefix" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Worker subnet CIDR for the initial ARM worker profile."
}

variable "netapp_subnet_prefix" {
  type        = string
  default     = "10.0.3.0/24"
  description = "Reserved for sibling ANF delegated subnet (not created here)."
}

variable "route_server_subnet_prefix" {
  type        = string
  default     = "10.0.4.0/26"
  description = "Reserved for sibling RouteServerSubnet (/26 or larger; not created here)."
}

variable "initial_worker_pool" {
  description = "Named node_pools entry used for ARM worker sizing at installation, then adopted as existing default MachineSets. Keep this name stable."
  type        = string
  default     = "worker"

  validation {
    condition     = length(var.node_pools) == 0 ? var.initial_worker_pool == "worker" : contains(keys(var.node_pools), var.initial_worker_pool)
    error_message = "initial_worker_pool must name a node_pools entry (or worker when using the legacy worker_* fallback)."
  }
}

variable "machinesets_directory" {
  description = "Generated MachineSet values directory; Make sets this to the selected profile's machinesets directory."
  type        = string
  default     = null
}

variable "node_pools" {
  description = "Worker pools: the named initial pool supplies day-0 ARM sizing; all pools are managed through the local MachineSets Helm chart after login. Replicas are totals across zones."
  type = map(object({
    vm_size      = string
    replicas     = number
    disk_size_gb = optional(number, 128)
    subnet_id    = optional(string)
    labels       = optional(map(string), {})
    tags         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string, "")
      effect = string
    })), [])
    zones = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([for name, p in var.node_pools :
      can(regex("^[a-z][a-z0-9-]{0,29}$", name)) &&
      p.replicas >= 0 && p.replicas == floor(p.replicas) &&
      p.disk_size_gb > 0 && p.disk_size_gb == floor(p.disk_size_gb) &&
      trimspace(p.vm_size) != "" &&
      length(distinct(p.zones)) == length(p.zones) &&
      alltrue([for z in p.zones : contains(["1", "2", "3"], z)]) &&
      alltrue([for t in p.taints : contains(["NoSchedule", "PreferNoSchedule", "NoExecute"], t.effect)]) &&
      !contains(keys(p.labels), "machine.openshift.io/cluster-api-machineset")
    ])
    error_message = "Pools require DNS-style names (up to 30 characters), non-negative integer replicas, a VM size, a positive integer disk size, unique zones 1/2/3, valid taints, and no reserved MachineSet identity label."
  }

  validation {
    condition     = length(var.node_pools) == 0 || sum([for p in var.node_pools : p.replicas]) >= 1
    error_message = "At least one desired worker replica must remain."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
