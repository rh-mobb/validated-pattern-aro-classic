# Architecture

## Cluster API

- Resource: `Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25` (AzAPI).
- Identity: user-assigned cluster MSI `${cluster_name}-cluster`.
- `platformWorkloadIdentities`: eight operators (not the cluster MSI).

### Cluster lifecycle audit (2026-10-20)

An audit of AzureRM update handling, the ARO `2025-07-25` API update policy and
12 isolated Terraform plan experiments found no lifecycle change needed for this
pattern's current ownership model. The existing ignores for `body`, `tags`,
`timeouts`, `type` and `response_export_values` were retained unchanged.

The cluster body remains install-only: OpenShift manages version upgrades,
Helm-managed MachineSets manage day-2 compute, and the write-only pull secret and
MIWI mappings remain under the installation guard. Tags remain policy-owned.
Some API fields support updates; retaining the body ignore is an ownership decision,
not a claim that every field is immutable. The audit used copied state and plans
only; it made no Azure changes and did not validate live API updates.

## Identities

| Azure name | ARM platform key | Role |
|------------|------------------|------|
| `${cluster_name}-cloud-controller-manager` | `cloud-controller-manager` | ARO built-in operator RBAC |
| `${cluster_name}-ingress` | `ingress` | ARO built-in operator RBAC |
| `${cluster_name}-machine-api` | `machine-api` | ARO built-in operator RBAC; **networkInterfaceClientID** for BGP (virt sibling) |
| `${cluster_name}-disk-csi-driver` | `disk-csi-driver` | ARO built-in operator RBAC |
| `${cluster_name}-cloud-network-config` | `cloud-network-config` | ARO built-in operator RBAC |
| `${cluster_name}-image-registry` | `image-registry` | ARO built-in operator RBAC |
| `${cluster_name}-file-csi-driver` | `file-csi-driver` | ARO built-in operator RBAC |
| `${cluster_name}-aro-operator` | `aro-operator` | ARO built-in operator RBAC |
| `${cluster_name}-cluster` | (cluster MSI only) | Cluster resource identity |
| `${cluster_name}-eso` | — | Key Vault Secrets User; **not** a `platformWorkloadIdentities` entry |

Customer Key Vault `cust-kv-<suffix>` stores the Red Hat pull secret when `pull_secret_path` / `pull_secret` is set at apply time. Bootstrap and ESO read it via workload identity.

Azure resource tags are set from configuration at creation where supported; subsequent tag changes are ignored by Terraform so Azure Policy can manage them. This includes the customer resource group, VNet, NSG, managed identities, Key Vault, and the existing cluster lifecycle guard. Editing `tags` in tfvars does not update existing resources. MachineSet VM tags remain managed through the Helm values.

The Key Vault/ESO module depends on the resource-group output rather than the entire network module. Azure account metadata stays available at plan time, preventing unrelated network changes from producing unknown identity IDs and unnecessary Key Vault RBAC replacements.

Federated credentials (installer root):

| Credential | Audience | Subject | When |
|------------|----------|---------|------|
| BGP (`machine-api`) | `api://AzureADTokenExchange` | `openshift-bgp-cloud-connector` SA | `terraform/bgp.tf` after cluster (`module.cluster.oidc_issuer_url`) |
| ESO (`eso-external-secrets`) | `api://AzureADTokenExchange` | `system:serviceaccount:external-secrets-operator:external-secrets-sa` | `terraform/eso.tf` after cluster |

Sibling [`validated-pattern-openshift-virt`](https://github.com/rh-mobb/validated-pattern-openshift-virt) creates `${cluster_name}-bgp`, Azure Route Server, ANF, and federates the BGP MI for Route Server API calls.

GitOps publishes `openshift-gitops/aro-platform-metadata` (`esoClientId`, `keyVaultUri`, `azureTenantId`) for the in-cluster ESO annotation Job (same contract as ARO HCP).

## Network (profile `aro-classic-miwi`)

| CIDR | Use |
|------|-----|
| `10.0.0.0/16` | VNet |
| `10.0.0.0/23` | Control plane subnet |
| `10.0.2.0/24` | Worker subnet |
| `10.0.3.0/24` | Reserved ANF (sibling creates delegated subnet) |
| `10.0.4.0/26` | Reserved Route Server (sibling creates `RouteServerSubnet`) |

The root validates both reserved ranges are inside the VNet and do not overlap
the control-plane subnet, worker subnet, or each other before publishing the
sibling contract. The Route Server range must be `/26` or larger.

## Compute (day 0 vs day 2)

`node_pools` is the source for compute configuration. The named `initial_worker_pool`
supplies the single ARM `worker` profile during cluster creation; subsequent cluster
body changes are ignored. After login, the installer adopts the ARO-created default
MachineSets and manages all configured pools through the local `helm/machinesets/`
chart. This differs from HCP because Classic day-2 compute uses the Machine API rather
than ARM node-pool children.

Terraform writes desired Helm values under `clusters/<profile>/machinesets/`.
`scripts/machinesets.sh` requires Helm 4, discovers complete live provider templates,
previews changes and wraps Helm. Helm retains the resource inventory and original
provider templates. Deletions and scale-down require explicit confirmation and Ready
replacement capacity. The wrapper waits for desired-worker readiness, not completion
of removed Machines' asynchronous cloud cleanup; operators verify deletion separately.
Readiness checks do not validate taints, schedulability or workload health.
Template changes warn but do not roll existing workers.
Bootstrap depends on MachineSet reconciliation and worker readiness; Argo does not
manage these MachineSets.

The versioned platform contract exports all desired pools. Its existing checks require
labeled pools to match disjoint live Ready-node sets with the requested SKU, labels,
and minimum replicas. Unlabeled entries remain desired sizing rather than inventory.
See [Compute machine pools](guides/compute-machine-pools.md) for adoption, deletion,
generated files and known propagation limitations.

The optional `aro-classic-virt` example defines three untainted default workers plus
two virtualization and two BGP workers. The extra pools have distinct labels and
`NoSchedule` taints; workload placement and tolerations belong in the virt sibling.
See the [virt example](guides/virt-example.md) for the full configuration.

## Platform contract

`make cluster.<name>.platform` writes `platform.json` (`contract_version` 1) for the virt sibling: `network.reserved`, `node_pools` (include `labels.bgp_router = "true"` for speaker pools), `machine_api_client_id`, `oidc_issuer_url`. BGP operator installation, `BGPCloudConfiguration`, `BGPRouting`, and sample CUDN workloads belong to the sibling; this installer does not render or apply them.

For an explicitly selected local-only bootstrap (`GITOPS_LOCAL_ONLY=1`), the installer
applies the baseline and metadata but defers the root Argo Application until a published
Git source exists. Continuous Git reconciliation is not configured in that mode.

## Network privacy

| Path | Classification | Notes |
|------|----------------|-------|
| API / ingress (Public profile) | Documented exception | `api_visibility` / `ingress_visibility` Public |
| Route Server Standard public IP (sibling) | Documented exception | Azure SDN management; BGP neighbors are RFC1918 |
| VNet worker / CP NICs | RFC1918 | — |
| ANF NFS (sibling) | RFC1918 | VNet-delegated subnet |

## Permissions (summary)

- Deployer: Contributor + User Access Administrator on the subscription or customer RG (role assignments for nine MIs + ESO).
- Virt sibling apply: additional Contributor + UAA on customer RG for ANF, Route Server, Trident custom role (see sibling docs).
- ARO RP: Network Contributor on VNet and NSG (Terraform assigns via `azuread_service_principal` lookup).
