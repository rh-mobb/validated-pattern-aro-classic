# Compute: initial workers and Helm-managed MachineSets

ARO Classic has an initial ARM worker profile, while additional compute is managed by
OpenShift MachineSets. Unlike HCP ARM node pools, this installer uses a local Helm 4
chart to manage compute after creation, including adopting the existing default
MachineSets. Helm runs before workload bootstrap, independently of Argo CD.

## Define pools once

Edit `clusters/<profile>/terraform.tfvars`:

```hcl
initial_worker_pool = "worker"
node_pools = {
  worker = {
    vm_size  = "Standard_D4s_v5"
    replicas = 3
  }
  np-virt = {
    vm_size  = "Standard_D8s_v6"
    replicas = 2
    zones    = ["1", "2"]
    labels = {
      bgp_router = "true"
      workload   = "virtualization"
    }
  }
}
```

`replicas` is the total across zones. The wrapper divides it evenly, assigning any
remainder in zone order. Omitted zones use the discovered default zones. The initial
pool adopts every existing default MachineSet, retaining names and selectors; its
zones cannot be changed. Keep `initial_worker_pool` stable after adoption.

Each pool accepts `vm_size`, `replicas`, `disk_size_gb` (default 128), `labels`, Azure
VM `tags`, `taints` (`key`, `value`, `effect`), `zones`, and optional `subnet_id`.
Additional subnets must already exist and satisfy ARO networking requirements.

The initial pool alone supplies ARM sizing, under the ARM profile name `worker`.
The cluster resource ignores subsequent body changes. All later compute changes use
MachineSets. Legacy `worker_*` inputs still provide a single `worker` pool when
`node_pools` is empty; do not mix them with an explicit map.

## Apply before bootstrap

```bash
make cluster.aro-classic-miwi.plan
make cluster.aro-classic-miwi.apply
make cluster.aro-classic-miwi.machinesets-render  # login + discovery + local preview
make cluster.aro-classic-miwi.machinesets        # login + Helm + worker readiness
make cluster.aro-classic-miwi.bootstrap
make cluster.aro-classic-miwi.platform
```

Run the installer plan/apply workflow after changing tfvars so the generated values
and state outputs reflect your changes. `bootstrap` depends on `machinesets`, which
depends on `login`; it will not install workloads if compute reconciliation fails.
A preview discovers cluster details but makes no cluster changes.

Terraform writes `clusters/<profile>/machinesets/values.yaml`. The wrapper writes
`discovered.yaml` and `rendered.yaml` beside it. These files are generated and ignored;
change tfvars rather than generated YAML. The wrapper restores desired values from
Terraform outputs if the local file is lost. Make supplies the output directory using
the selected profile, even when profile and Azure cluster names differ.

The script checks the kubeconfig API against Terraform outputs, discovers default
worker MachineSets, and copies their complete provider configuration, including MIWI,
image, disk and security settings. It stores the original templates in the Helm release
values so later edits do not become discovery defaults. No credential Secret contents
are read. Initial adoption is limited to matching default workers; resources owned by
another Helm release are rejected.

The chart is local at `helm/machinesets/`; no chart repository or Terraform Kubernetes
provider is involved. The release is `machinesets` in `openshift-machine-api`. Helm 4
is required by both setup and the wrapper; Helm 2/3 are rejected. Do not also manage
these resources through Argo CD, another release, or an autoscaler.

## Changes and deletions

The wrapper reports deletions and replica reductions by comparing desired configuration,
Helm's previous values, and live replicas. Normal apply/bootstrap stops before those
mutations. After reviewing the preview, explicitly confirm the cluster:

```bash
MACHINESETS_CONFIRM=aro-classic-miwi make cluster.aro-classic-miwi.machinesets
```

Removing a pool from tfvars and applying Terraform changes the desired values; the
next confirmed Helm upgrade removes its MachineSets. This can delete Machines and
VMs. A pool/zone rename is an addition plus a deletion. First add the replacement pool,
apply it and wait for Ready nodes; then remove the old pool in a separate run. The
wrapper requires the desired replacement workers to be Ready before destructive
changes and rejects an empty desired worker population. `helm uninstall` bypasses
these checks and can remove all adopted workers; do not use it for normal lifecycle.

### Verify deletion completion

The wrapper waits for the desired workers to be Ready. It does **not** wait for removed
MachineSets' child Machines, Nodes or Azure VMs to disappear. Helm removes the MachineSets;
the Machine API drains the child Machines and deletes their infrastructure asynchronously.
A successful wrapper exit can therefore precede completed deletion.

Before removing a pool, record its MachineSet, Machine, Node and Azure VM names and the
UIDs of retained MachineSets. After the confirmed upgrade, inspect the same cluster:

```bash
# Example profile; use the kubeconfig and managed resource group for your deployment.
export KUBECONFIG="$PWD/clusters/aro-classic-virt/.kube/config"
oc get machinesets -n openshift-machine-api \
  -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,DESIRED:.spec.replicas,READY:.status.readyReplicas
oc get machines -n openshift-machine-api
oc get nodes
az vm list -g aro-classic-virt-managed-rg --query '[].name' -o tsv
```

Repeat these checks until the removed pool's MachineSets, Machines, Nodes and VMs are
absent. Retained MachineSet UIDs should be unchanged and their requested workers Ready.
For a replica reduction, verify the remaining replica count and track the specific
Machines selected for deletion. If cleanup stalls, inspect the deleting Machines and
events before taking corrective action:

```bash
oc describe machine <deleting-machine> -n openshift-machine-api
oc get events -n openshift-machine-api --sort-by=.lastTimestamp
```

Do not remove finalizers or force-delete Machines to bypass a stalled cloud cleanup.
Once compute changes are verified, run `make cluster.<profile>.platform` to refresh the
sibling contract; Terraform apply and the MachineSet wrapper do not rewrite `platform.json`.

### Template changes and release recovery

Known gap: template changes do not roll existing Machines or reliably propagate labels,
taints, VM tags, SKU or disk settings to existing Machines/Nodes. The wrapper warns on
template changes; it does not patch child resources or delete Machines to force a rollout.
A readiness timeout can therefore require an operator-managed worker replacement.
The Helm release retains its original discovery baseline for repeatable rendering
and declarative label/tag removal. OpenShift upgrades and out-of-band provider-template
changes have not been validated with this workflow; review rendered image and security
settings before reconciling or expanding capacity after either change.
Failed or pending Helm releases stop further wrapper operations. Inspect `helm status`
and `helm history` in `openshift-machine-api` and reconcile partial resources before
retrying. This prevents a failed revision from hiding pending deletions. Helm rollback
is not a VM recovery mechanism. No automatic rollback or force replacement
is used. The wrapper uses Helm 4 client-side patches for compatibility with ARO-created
field managers; it does not force server-side field ownership.

Readiness checks use live Machine owner UIDs and their Node references, requiring the
requested count of non-deleting Ready nodes with the desired SKU and node labels.
For scale-down, this counts current qualifying workers; it does not predict which
Machines the Machine API will select for deletion.
The checks do not validate taints, Node schedulability, workload placement or workload
health. Inspect live Node taints separately and verify the workloads' selectors and
tolerations. `MACHINESETS_WAIT_SECONDS` defaults to 1800 and covers desired-worker
readiness, not deletion completion. Helm success alone does not establish worker
readiness. The platform command retains its labeled-pool checks before the virt-sibling
handoff.

## Live validation recorded on 2026-10-16

An authorized ARO Classic MIWI deployment of `aro-classic-virt` in East US on OpenShift
4.21.22, using Helm 4.2.0, verified:

- Adoption of all three default zone-scoped MachineSets with names and selectors preserved.
- Creation of two virt and two BGP workers across zones 1/2, with seven workers Ready
  and the requested SKUs, labels and live taints verified.
- Repeat reconciliation preserving all seven MachineSet UIDs and replica counts.
- Removal of both extra pools through tfvars, Terraform apply and a confirmed Helm
  upgrade: all four extra MachineSets, Machines, Nodes and Azure VMs disappeared,
  leaving the three default workers Ready with unchanged MachineSet UIDs.
- Local baseline bootstrap, ESO Key Vault synchronization and platform export. The
  root Argo Application was deferred because the Git source was unpublished.

The cluster was then destroyed; both resource groups were confirmed absent and Terraform
state empty. This records a completed test, not a currently running deployment. It does
not validate CNV, BGP dataplane, populated-pool drain behavior, scale-down within a pool,
worker rollouts or recovery from failed Helm releases. Mocked tests cover additional
validation and guard behavior.
