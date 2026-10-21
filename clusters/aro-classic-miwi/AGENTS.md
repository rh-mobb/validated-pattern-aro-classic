# Agent playbook — `clusters/aro-classic-miwi`

Step-by-step **done-when** gates for AI operators. Human runbook: [Classic MIWI deploy](../../docs/guides/classic-miwi.md). Generic Live Azure: root [`AGENTS.md`](../../AGENTS.md#live-azure-deployments).

If this file and classic-miwi.md disagree on a `make` target, **the guide wins for commands**; **this file wins for stop-and-ask**.

## When to run

- User asks to deploy, verify, or destroy the Classic MIWI example.
- PR changes this profile, platform contract, GitOps bootstrap, or destroy order.
- User asks for virt/ANF/Route Server — continue in sibling `validated-pattern-openshift-virt` (`clusters/aro-classic-miwi`).

Skip live E2E for refactors with no operator-facing behavior (note in the PR).

Do **not** claim deploy done without `login`, `machinesets`, `bootstrap`, and `platform` when the user asked for full parity (same bar as HCP minus `external-auth`).

## Recipe facts

| Item | Value |
|------|--------|
| Profile / `cluster_name` | `aro-classic-miwi` |
| Customer RG | `aro-classic-miwi-rg` |
| Managed RG | `aro-classic-miwi-managed-rg` |
| API | `openShiftClusters@2025-07-25` |
| VNet | `10.0.0.0/16`; CP `10.0.0.0/23`; workers `10.0.2.0/24` |
| Reserved (sibling) | ANF `10.0.3.0/24`; Route Server `10.0.4.0/26` |
| Workers (day 0) | `worker` × 3 `Standard_D4s_v5` via the named `initial_worker_pool` entry in `node_pools` / first-create `workerProfiles` |
| Workers (day 2) | All pools, including adopted defaults, via the local Helm 4 chart and `machinesets` target; tfvars `node_pools` is the source |
| BGP NIC writes | `machine_api_client_id` in `platform.json` → virt sibling `networkInterfaceClientID` |
| Virt sibling | `ARO_HCP_ROOT=<this repo>` `ARO_HCP_PROFILE=aro-classic-miwi` |

## Steps 0–6 (installer)

Use tmux ([root AGENTS.md](../../AGENTS.md#long-running-operations-tmux)). Unset `TF_VAR_*` in the **same** session as every `make`.

### Step 0 — Preflight

Follow root Live Azure preflight. Also:

- `pull_secret_path` in tfvars points to a readable file (or operator chose to use inline test secret — not for live).
- Quota for Classic OpenShift and Dsv5/Dsv6 workers in `location` (virt needs Dsv6 8+ cores on speaker pool).

**Done when:** Subscription matches intent; no unapproved `TF_VAR_*`; operator confirmed names/region; `make cluster.aro-classic-miwi.plan` summarized.

### Step 1 — Plan

```bash
make cluster.aro-classic-miwi.plan
```

**Done when:** Plan matches the ask (network, identities, cluster, KV/ESO, machine-api FIC; **no** Route Server or BGP MI in this root).

### Step 2 — Apply

```bash
make cluster.aro-classic-miwi.apply
```

**Done when:** `az aro show -g aro-classic-miwi-rg -n aro-classic-miwi` — `provisioningState` **Succeeded**. If plan still shows `azurerm_federated_identity_credential` for ESO or BGP to create, run **apply again**.

### Step 3 — Cluster access

```bash
make cluster.aro-classic-miwi.kubeconfig
# or: make cluster.aro-classic-miwi.login
```

**Done when:** `.kube/config` exists; `oc whoami` or `oc get nodes` works.

### Step 3a — MachineSets

```bash
make cluster.aro-classic-miwi.machinesets-render
make cluster.aro-classic-miwi.machinesets
```

**Done when:** Helm 4 release `machinesets` in `openshift-machine-api` owns the default
and configured extra MachineSets, preserving default names/selectors. Desired workers
pass the script's Machine-UID/Node Ready, SKU and label checks before workloads start.
Generated files are under this profile's `machinesets/`. Do not auto-confirm removals
or scale-down: report names/counts and obtain explicit operator authorization before
setting `MACHINESETS_CONFIRM=<Azure cluster name>`. Template changes do not roll workers.

### Step 4 — GitOps bootstrap

```bash
make cluster.aro-classic-miwi.bootstrap
```

**Done when:** OpenShift GitOps Available; ESO `ClusterSecretStore` exists.

### Step 5 — Platform

```bash
make cluster.aro-classic-miwi.platform
```

**Done when:** `platform.json` has `contract_version == 1`, non-empty `machine_api_client_id`, `network.reserved` CIDRs, and at least one `node_pools` entry with `labels.bgp_router == "true"` when virt is in scope. Each labeled pool must have the requested Ready nodes, labels, and VM size; `platform` checks this before writing. Kubeconfig must match the exported API URL, and labeled pools must not share matching workers. Reconcile MachineSets first if the check fails.

## Steps 7–8 (virt sibling — optional)

In `validated-pattern-openshift-virt`:

```bash
export KUBECONFIG_PATH=/path/to/validated-pattern-aro-classic/.kube/config
# Set sibling terraform.tfvars platform_json to the installer-generated file.
ARO_HCP_ROOT=/path/to/validated-pattern-aro-classic ARO_HCP_PROFILE=aro-classic-miwi \
  make cluster.aro-classic-miwi.apply
make cluster.aro-classic-miwi.bootstrap
```

**Done when:** ANF pool, Trident, Route Server, bgp-cloud-connector CSV Ready, sample `BGPRouting` (live E2E). Destroy **sibling first**, then installer destroy.

## Destroy

```bash
# After sibling destroy/cleanup when virt was applied
DESTROY_CONFIRM=yes make cluster.aro-classic-miwi.destroy
```

**Done when:** Customer RG and managed RG gone; `terraform state list` empty.

## Known failure modes

| Symptom | Likely cause | Action |
|---------|----------------|--------|
| Virt plan: empty `network_interface_client_id` | Stale `platform.json` | Re-run installer `platform` after apply |
| Virt plan: no `bgp_router` pool | `node_pools` missing label | Add `np-virt` (or label MachineSet) and re-run `platform` |
| Overlap error on apply | Worker CIDR collides with `10.0.3.0/24` / `10.0.4.0/26` | Fix tfvars CIDRs per root `platform.tf` preconditions |
