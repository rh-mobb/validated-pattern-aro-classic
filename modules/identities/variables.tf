variable "cluster_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "control_plane_subnet_id" {
  type = string
}

variable "worker_subnet_id" {
  type = string
}

variable "nsg_id" {
  type = string
}

variable "aro_rp_object_id" {
  type        = string
  description = "Object ID of the Azure Red Hat OpenShift resource provider service principal."
}
