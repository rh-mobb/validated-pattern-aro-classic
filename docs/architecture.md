# Architecture

## Cluster API

- Resource: `Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25` (AzAPI).
- Identity: user-assigned cluster MSI `${cluster_name}-cluster`.
- `platformWorkloadIdentities`: eight operators (not the cluster MSI).

## Identities

| Azure name | ARM platform key | Role |
|------------|------------------|------|
| `${cluster_name}-cloud-controller-manager` | `cloud-controller-manager` | ARO built-in operator RBAC |
| `${cluster_name}-ingress` | `ingress` | ARO built-in operator RBAC |
| `${cluster_name}-machine-api` | `machine-api` | ARO built-in operator RBAC; **networkInterfaceClientID** for BGP |
| `${cluster_name}-disk-csi-driver` | `disk-csi-driver` | ARO built-in operator RBAC |
| `${cluster_name}-cloud-network-config` | `cloud-network-config` | ARO built-in operator RBAC |
| `${cluster_name}-image-registry` | `image-registry` | ARO built-in operator RBAC |
| `${cluster_name}-file-csi-driver` | `file-csi-driver` | ARO built-in operator RBAC |
| `${cluster_name}-aro-operator` | `aro-operator` | ARO built-in operator RBAC |
| `${cluster_name}-cluster` | (cluster MSI only) | Cluster resource identity |
| `${cluster_name}-bgp` | — | Custom Route Server role on customer RG |

Federated credentials (audience `openshift`, subject `system:serviceaccount:openshift-bgp-cloud-connector:openshift-bgp-cloud-connector-controller-manager`) are created on `${cluster_name}-bgp` and additively on `machine-api` after `oidc_issuer_url` is set.

## Network (profile `aro-classic-miwi`)

| CIDR | Use |
|------|-----|
| `10.0.0.0/16` | VNet |
| `10.0.0.0/23` | Control plane subnet |
| `10.0.2.0/23` | Worker subnet |
| `10.0.12.0/26` | `RouteServerSubnet` (no NSG) |

## Network privacy

| Path | Classification | Notes |
|------|----------------|-------|
| API / ingress (Public profile) | Documented exception | `api_visibility` / `ingress_visibility` Public |
| Route Server Standard public IP | Documented exception | Azure SDN management; BGP neighbors are RFC1918 |
| Route Server `virtualRouterIps` | RFC1918 | Operator-managed peers |
| VNet worker / CP NICs | RFC1918 | — |

## Permissions (summary)

- Deployer: Contributor + User Access Administrator on the subscription or customer RG (role assignments for nine MIs, Route Server, custom BGP role).
- ARO RP: Network Contributor on VNet and NSG (Terraform assigns via `azuread_service_principal` lookup).
