variable "cluster_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "machine_api_identity_id" {
  type = string
}

variable "oidc_issuer_url" {
  type    = string
  default = ""
}

variable "bgp_federated_subject" {
  type    = string
  default = "system:serviceaccount:openshift-bgp-cloud-connector:openshift-bgp-cloud-connector-controller-manager"
}

variable "tags" {
  type    = map(string)
  default = {}
}
