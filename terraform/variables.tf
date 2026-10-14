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

variable "oidc_issuer_url" {
  type        = string
  default     = ""
  description = "Cluster OIDC issuer URL; set after first apply for BGP federated credentials."
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
  type    = number
  default = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}
