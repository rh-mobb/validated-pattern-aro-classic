variable "cluster_name" {
  type        = string
  description = "Cluster name prefix for Azure resources."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Customer resource group name."
}

variable "create_resource_group" {
  type        = bool
  default     = true
  description = "Create the resource group when true."
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
  description = "Worker subnet CIDR (must not overlap control_plane_subnet_prefix or reserved sibling CIDRs)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to taggable resources."
}
