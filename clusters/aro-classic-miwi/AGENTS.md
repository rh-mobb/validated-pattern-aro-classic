# Agent playbook — `clusters/aro-classic-miwi`

Human runbook: [Classic MIWI deploy](../../docs/guides/classic-miwi.md). Root halt rules: [`AGENTS.md`](../../AGENTS.md).

## Recipe facts

| Item | Value |
|------|--------|
| Profile / `cluster_name` | `aro-classic-miwi` |
| API | `openShiftClusters@2025-07-25` |
| Workers | Default 3× `Standard_D4s_v5` via Terraform `worker_count` |
| Route Server | `${cluster_name}-routeserver` on `RouteServerSubnet` `10.0.12.0/26` |
| BGP NIC client | `machine-api` client id (`network_interface_client_id` in `platform.json`) |

## Done-when (deploy)

1. Preflight: subscription, no stray `TF_VAR_*`, `make cluster.aro-classic-miwi.plan` summarized.
2. `make cluster.aro-classic-miwi.apply` — cluster `Succeeded` in Azure.
3. `make cluster.aro-classic-miwi.kubeconfig` — `.kube/config` exists.
4. `oidc_issuer_url` in tfvars; second `apply`; `make cluster.aro-classic-miwi.platform` — `platform.json` with matching `network_interface_client_id` and `machine_api_client_id`.
5. BGP operator installed separately; `render-bgp.sh` applied; `BGPCloudConfiguration` Ready (live E2E only).

## Destroy

`DESTROY_CONFIRM=yes make cluster.aro-classic-miwi.destroy`. Cluster AzAPI resource is targeted first.

## Known failure modes

| Symptom | Cause | Action |
|---------|--------|--------|
| `platform.sh` exits 1 | Empty `oidc_issuer_url` | Second apply after setting issuer in tfvars |
| Federated credentials missing | Skipped second apply | Set `oidc_issuer_url` and re-apply |
| Wrong NIC auth in BGP CR | Used `bgp_client_id` for `networkInterfaceClientID` | Use `machine_api_client_id` from `platform.json` |
| Destroy leaves identities | Cluster not deleted first | Use `make cluster.*.destroy` (ordered script) |
