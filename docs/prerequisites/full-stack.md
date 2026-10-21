# Full-stack deployment

One operator team runs the **Classic MIWI installer** from this repository using `clusters/<name>/terraform.tfvars`. Azure Route Server, sibling BGP MI, ANF, Trident, and bgp-cloud-connector GitOps live in [`validated-pattern-openshift-virt`](https://github.com/rh-mobb/validated-pattern-openshift-virt) after `make cluster.<name>.platform`.

## What Terraform creates

| Component | Module |
|-----------|--------|
| RG, VNet, CP/worker subnets, NSG | [`modules/network/`](../../modules/network/) |
| Key Vault, ESO MI, pull secret (optional) | [`modules/platform-secrets/`](../../modules/platform-secrets/) |
| Nine platform MIs + cluster MSI RBAC | [`modules/identities/`](../../modules/identities/) |
| Classic cluster (AzAPI) | [`modules/cluster/`](../../modules/cluster/) |
| `machine-api` federated credential for bgp-cloud-connector | [`terraform/bgp.tf`](../../terraform/bgp.tf) |

**Not** created here: Route Server, BGP MI, ANF, Trident, CNV, Entra console OIDC.

## Before you start

1. [Account prerequisites](account.md).
2. Copy or use [`clusters/aro-classic-miwi/`](../../clusters/aro-classic-miwi/) example tfvars.
3. Place pull secret at `pull_secret_path` (gitignored).

```bash
make setup
```

## Deployment workflow

```bash
make cluster.aro-classic-miwi.plan
make cluster.aro-classic-miwi.apply
make cluster.aro-classic-miwi.login
make cluster.aro-classic-miwi.machinesets
make cluster.aro-classic-miwi.bootstrap
make cluster.aro-classic-miwi.platform
```

Teardown:

```bash
DESTROY_CONFIRM=yes make cluster.aro-classic-miwi.destroy
```

## Permissions by deployment step

Minimum Azure RBAC for a greenfield deploy (exact roles vary by org policy). Deployer typically needs **Contributor** and **User Access Administrator** on the subscription or target RG to create identities and role assignments.

| Step | `make` target | Azure (summary) |
|------|---------------|-----------------|
| Tool check | `setup` | None |
| Plan / apply | `cluster.<name>.plan` / `.apply` | Create RG, VNet, subnets, NSG, UAMI, role assignments, Key Vault, `openShiftClusters` |
| Kubeconfig / login | `cluster.<name>.kubeconfig`, `.show-credentials`, `.login` | `Microsoft.RedHatOpenShift/openShiftClusters/listCredentials/action` (via `az aro list-credentials` + `oc login`) |
| Re-apply (if plan shows FICs) | `.apply` after cluster Succeeded | `federatedIdentityCredentials/write` on ESO and machine-api identities |
| Platform file | `cluster.<name>.platform` | Read Terraform state outputs and labeled live worker readiness |
| MachineSets | `cluster.<name>.machinesets` | Helm 4 release; OpenShift permissions to read Infrastructure, Machines and Nodes, and manage MachineSets and Helm release Secrets |
| GitOps bootstrap | `cluster.<name>.bootstrap` | OpenShift GitOps install + `aro-platform-metadata`; ESO federation must exist |
| Destroy | `cluster.<name>.destroy` | Delete cluster, then remaining resources |

OpenShift: the installer admin kubeconfig is used by the sibling for operator installation and BGP configuration. The installer does not apply BGP manifests.

See [Architecture](../architecture.md) for identity and network privacy tables.
