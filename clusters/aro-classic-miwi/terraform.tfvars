location     = "eastus"
cluster_name = "aro-classic-miwi"
domain       = "classicmiwi"
aro_version  = "4.21.22"

api_visibility     = "Public"
ingress_visibility = "Public"

# pull_secret_path = "../tmp/pull-secret.txt"

# After first apply, set from: terraform output -raw oidc_issuer_url (then apply again).
oidc_issuer_url = ""
