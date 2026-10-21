variable "cluster_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "pull_secret_content" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Red Hat pull secret JSON; when empty, Key Vault secret is not created."
}

variable "pull_secret_key_vault_secret_name" {
  type    = string
  default = "redhat-pull-secret"

  validation {
    condition     = can(regex("^[0-9a-zA-Z-]{1,127}$", var.pull_secret_key_vault_secret_name))
    error_message = "pull_secret_key_vault_secret_name must be 1-127 alphanumeric characters or hyphens."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
