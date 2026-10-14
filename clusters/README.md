# Cluster profiles

Each subdirectory is a deployment profile with committed example `terraform.tfvars` (unless noted). Operator copies may use a private tfvars file; state lives in `infrastructure.tfstate` (gitignored).

| Profile | Purpose |
|---------|---------|
| [`aro-classic-miwi`](aro-classic-miwi/) | Classic MIWI + Route Server + BGP identity wiring |
