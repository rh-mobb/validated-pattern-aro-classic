# Account prerequisites

- Azure subscription with **Azure Red Hat OpenShift** quota in the target region.
- Permission to create user-assigned managed identities, role assignments, VNets, and `Microsoft.RedHatOpenShift/openShiftClusters`.
- **Azure CLI** with `az aro` extension (Classic — not `az aro hcp`).
- **Terraform** `>= 1.9`.
- Red Hat pull secret for cluster create (`pull_secret_path` in cluster tfvars).

Confirm subscription:

```bash
az account show
```
