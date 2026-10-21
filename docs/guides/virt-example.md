# Greenfield virtualization compute example

The `aro-classic-virt` profile demonstrates the local Helm 4 MachineSet workflow with
one initial pool and two extra pools. Its compute lifecycle and local baseline bootstrap
were live-validated on 2026-10-16; the test cluster was subsequently destroyed. See the
[recorded validation and its limits](compute-machine-pools.md#live-validation-recorded-on-2026-10-16).
Terraform provisions the Classic MIWI installer; CNV, ANF,
Trident, Route Server and BGP remain in `validated-pattern-openshift-virt`.

Edit [`clusters/aro-classic-virt/terraform.tfvars`](../../clusters/aro-classic-virt/terraform.tfvars)
before deployment, especially the pull-secret path, region, domain and version.
Confirm subscription quota and SKU/zone availability for your region during preflight.
The profile uses the installer default network CIDRs in its own VNet/resource group.

The two extra pool blocks are enabled in tfvars for the seven-worker shape below.
Removing or commenting out those blocks and applying Terraform updates
the desired Helm values; review `.machinesets-render` and explicitly confirm the
wrapper deletion to remove those pools.

## Compute shape

- `worker`: three `Standard_D4s_v5` nodes, initially created by ARM and subsequently
  adopted by Helm. No custom labels or taints; hosts installer GitOps/platform services.
- `np-virt`: two `Standard_D8s_v6` nodes, one in each of zones 1/2. Node labels
  `pool=np-virt` and `workload=virtualization`; taint
  `workload=virtualization:NoSchedule`.
- `np-bgp`: two `Standard_D8s_v6` nodes, one in each of zones 1/2. Node labels
  `pool=np-bgp`, `workload=bgp`, and `bgp_router=true`; taint
  `workload=bgp:NoSchedule`.

Seven workers total. Extra-pool replica counts are totals, not counts per zone.
The distinct labels keep platform readiness checks from counting a worker in two pools.
Only `np-bgp` is advertised as a speaker pool to the virt sibling.

## Installer workflow

Follow [account prerequisites](../prerequisites/account.md), the root agent live Azure
preflight when using an agent, and [Classic MIWI deploy](classic-miwi.md). Substitute
this profile name in Make commands:

```bash
make setup
make cluster.aro-classic-virt.plan
make cluster.aro-classic-virt.apply
make cluster.aro-classic-virt.login
make cluster.aro-classic-virt.machinesets-render
make cluster.aro-classic-virt.machinesets
make cluster.aro-classic-virt.bootstrap
make cluster.aro-classic-virt.platform
```

Re-apply before bootstrap only when the plan still shows pending federated credentials.
The profile has an installer GitOps overlay containing the same platform baseline as
the basic example. It does not install virtualization operators itself.

Terraform writes desired Helm values under `clusters/aro-classic-virt/machinesets/`;
the wrapper adds discovery and rendered manifests. Generated files are ignored.
For adoption, deletion confirmation and the worker-rolling gap, see
[Compute machine pools](compute-machine-pools.md).

## Workload placement and tolerations

The example intentionally isolates the extra nodes with `NoSchedule` taints. The virt
sibling's default CNV manifest does not configure these custom tolerations or restrict
VM placement to `np-virt`. Configure placement in the sibling/tenant workload layer
before expecting workloads to use the pools. The installer sets node configuration;
it does not patch child workload manifests.

For workloads intended for `np-virt`, use a matching selector and toleration:

```yaml
nodeSelector:
  pool: np-virt
tolerations:
  - key: workload
    operator: Equal
    value: virtualization
    effect: NoSchedule
```

These are Pod scheduling fields; apply them through each workload's supported placement
API, including CNV's HyperConverged node placement and VM templates where appropriate.
Required node agents must also tolerate the taint. On `np-bgp`, verify the deployed FRR
and BGP-related workloads tolerate `workload=bgp:NoSchedule`. A toleration permits
scheduling on a tainted node; the selector determines placement.

MachineSet readiness proves requested node ownership, Ready state, labels and SKU.
It does not prove CNV/FRR scheduling, BGP sessions or guest connectivity, and the wrapper
currently does not validate live taints. Inspect Nodes and workload scheduling during
an explicitly requested live validation.

## Virt sibling handoff

Point the sibling profile's `platform_json` at this installer's
`clusters/aro-classic-virt/platform.json`, and use `ARO_HCP_PROFILE=aro-classic-virt`
with `ARO_HCP_ROOT` set to this checkout. Prepare a corresponding sibling profile and
its workload placement/tolerations; the installer profile does not create those files.
Follow the sibling's install and validation workflow. Destroy the sibling before the
installer whenever sibling resources have been provisioned.

## Classic sibling validation on 2026-10-19

The seven-worker profile was redeployed and attached to the virt sibling. A Classic
attachment consumed `machine_api_client_id`, reused installer Argo CD, and created
ANF (1 TiB Flexible, 128 MiB/s) and Route Server. CNV became healthy, the Trident backend
bound, a 100 GiB RWX claim shared a file between Pods on different virt workers, and a
VMI ran with that claim attached as a data disk. Both BGP speakers established sessions
to both Route Server endpoints, and forwarding was enabled on all seven worker NICs.

The initial attachment identified these GitOps changes:

- Remove the HCP-only worker selector from the `kubevirt-hyperconverged` Subscription
  on Classic. The shipped `virt-operator` also requires control-plane affinity; combining
  it with a worker selector leaves its Pods Pending. Removing the Subscription override
  allowed both operator replicas to run on Classic control-plane nodes.
- Set HyperConverged workload placement to `pool=np-virt` with a
  `workload=virtualization:NoSchedule` toleration. Keep infrastructure components on
  the untainted platform workers.
- Restrict `azure-nic-ip-forwarding` to worker nodes while retaining tolerations for
  the extra-pool taints.
- Remove the empty `ImageChange` trigger from the BGP Docker BuildConfig. The API drops
  that trigger, causing persistent Argo OutOfSync; `ConfigChange` alone converged.

The initial test applied these changes through inline Argo patches. The sibling's
`feat/classic-gitops-overlays` branch now carries shared fixes in `gitops/base`,
operator placement in `gitops/overlays/azure-classic` and `azure-hcp`, and this
example's pool selectors/tolerations in `gitops/profiles/aro-classic-virt`.
The `azure` overlay remains an HCP compatibility alias. The installer profile alone
does not configure the sibling's workload placement.

Select the committed Classic profile when running the sibling bootstrap:

```bash
GITOPS_PLATFORM=classic \
GITOPS_PATH=gitops/profiles/aro-classic-virt \
GITOPS_REVISION=feat/classic-gitops-overlays \
make cluster.aro-classic-virt.bootstrap
```

A clean teardown and rebuild on 2026-10-19 consumed commit `c694230` from that
branch. The resulting Argo Application used this profile with no inline Kustomize
patches and reached Synced/Healthy with a successful operation. CNV was Available
and not Degraded, the Trident backend was Bound, CDI reported a 4 GiB memory limit,
and all four BGP sessions established. All seven worker NICs had forwarding enabled;
the three master NICs did not. The cross-node RWX shared-file test passed.

The fresh VMI boot check did **not** pass: two attempts stayed Scheduled after
`SyncVMI` timeouts; the root-disk sidecar exited and the handler subsequently
reported `containerdisk rootdisk still not ready after one minute`. Logs and status
were retained locally. The cause is unresolved; the earlier attachment's successful
VMI run is not proof of VM boot on this rebuild.

The fresh private VNet probe reached the speaker CUDN Pod at `192.168.100.6` and the
non-speaker Pod at `192.168.100.4`; both preserved source IP `10.0.5.4`. Its effective
CUDN route used speaker next hops `10.0.2.7` and `10.0.2.8`. The temporary VM, disk,
NIC and subnet were removed and verified absent afterward.

A live BGP Pod used the webhook-injected Azure token at
`/var/run/secrets/azure/tokens/azure-identity-token`, with audience
`api://AzureADTokenExchange`. The separate `openshift`-audience projection was also
present; it was not the Azure credential path. Recheck both paths when changing the
operator revision.

External Azure-to-CUDN connectivity was verified from a temporary private VNet VM
at `10.0.5.4`. HTTP requests to CUDN Pods on a BGP speaker (`192.168.100.7:8080`)
and a non-speaker virt worker (`192.168.100.4:8080`) both succeeded. Both endpoints
reported the original source IP `10.0.5.4`. The probe NIC had an active
`192.168.100.0/24` route through speaker next hops `10.0.2.7` and `10.0.2.8`.

Earlier HTTP probes from a default worker host timed out. An explicitly approved
read-only node lookup showed Linux policy routing selected `ovn-k8s-mp1` in table
1053, bypassing Azure Route Server. That host probe therefore tests a different path
from the successful private VNet probe. Guest networking, migration and worker
replacement were not validated by these checks.


## Settled-stack smoke follow-up on 2026-10-20

Follow-up tests booted the imported Fedora 44 image from an ANF-backed PVC and
live-migrated that VMI between the two virt workers. Its guest boot ID stayed the
same and an in-memory heartbeat counter advanced on the destination. A later retry
of the original Fedora 42 container-disk configuration also reached Running/Ready
on the original worker. The earlier failure no longer reproduced; startup timing
is a lead, not an established root cause. These VM checks used the default pod
network, not guest CUDN networking.

Run the reusable smoke workflow from the **virt sibling checkout**, with this
installer's kubeconfig:

```bash
export KUBECONFIG_PATH=/path/to/validated-pattern-aro-classic/clusters/aro-classic-virt/.kube/config
make cluster.aro-classic-virt.stack-ready
make cluster.aro-classic-virt.smoke
```

The sibling owns these targets. The gate requires 120 seconds of continuous
cluster/operator, GitOps, CNV, storage, BGP/FRR, worker-agent and image-import
readiness. It resets when health drops, relevant Pods restart/roll, or the Argo
revision changes. The smoke runner repeats the barrier after provisioning its
disks and before each VM, then tests PVC-backed Fedora and the Fedora 42
container-disk case without automatic boot retries. It retains sanitized JSON
reports in the sibling profile's `logs/virt-smoke/` and removes only its own
unique namespace and test volumes. Existing test VMIs and catalog images remain
untouched. Settings and prerequisites are in the sibling's
[consume guide](https://github.com/rh-mobb/validated-pattern-openshift-virt/blob/feat/classic-gitops-overlays/docs/guides/consume.md#settled-stack-smoke-test).

For a cold rebuild, bootstrap can return before the operator APIs are registered;
the readiness inventory currently fails immediately if an API is absent. Wait
for CNV/CDI/BGP API registration, then allow the initial image imports and disk
provisioning a larger overall budget:

```bash
SMOKE_TIMEOUT_SECONDS=3600 make cluster.aro-classic-virt.smoke
```

The 2026-10-20 clean rebuild at sibling commit `8b76ccf` passed both boot sources
with this budget and unchanged 120-second stability windows. An earlier invocation
hit the default 30-minute deadline during root-disk cloning, before launching any
VM; its cleanup succeeded. Keep that outcome separate from a VM boot failure.

### Clean rebuild validation on 2026-10-20

The previous sibling and installer were destroyed, both resource groups were
verified absent, and both Terraform states were empty before creation. The new
cluster used infrastructure ID `aro-classic-virt-98vk6`, OpenShift 4.21.22 and the
same three compute pools. All seven workers passed SKU, label and taint checks.
The sibling used `gitops/profiles/aro-classic-virt` at `8b76ccf` without inline
Argo patches. Argo, CNV, Trident and BGP reached their required healthy states;
four FRR sessions and forwarding on all seven worker NICs were verified.

The settled-stack smoke passed both PVC-backed Fedora 44 and Fedora 42
container-disk boots with guest agents connected. A BGP controller Pod change
reset the barrier before the second boot, demonstrating that readiness was
checked continuously. A separate Fedora VMI live-migrated from virt worker 1 to
worker 2 in PreCopy mode, retaining its VMI UID and guest boot ID; its in-memory
heartbeat counter advanced from 2 to 14. These guest checks used the default pod
network, not guest CUDN networking or packet-loss measurement.

A temporary private VNet VM reached HTTP endpoints on speaker and non-speaker
CUDN Pods; both preserved source IP `10.0.5.4`. Its NIC had an active
`192.168.100.0/24` route through both speakers. The probe VM, disk, NIC and subnet
were verified absent afterward. Disposable boot and migration namespaces and
volumes were removed; the cluster and six catalog images were retained.

The initial local apply process was interrupted after submitting cluster creation.
Azure completed successfully; the existing cluster was imported into backed-up
Terraform state before a reviewed recovery apply created the two federated
credentials. The subsequent installer plan was clean. This recovery was separate
from the API-registration and smoke-budget findings above; neither pre-boot smoke
failure attempted a VM startup.

The final installer plan showed no changes. The sibling plan showed six in-place,
tag-only updates removing `app-code` and `cost-center`, consistent with the Azure
policy tags observed earlier. Those changes were not applied. There were no
planned additions, deletions or replacements; sibling tag ownership remains a
follow-up.

### Repeat clean validation on 2026-10-21

A fresh OpenShift 4.21.22 cluster (`aro-classic-virt-wfdbr`) deployed with the same
three pools and sibling Classic profile at `8b76ccf`, without inline Argo patches.
The installer created all 72 resources, including both federated credentials, in
one apply; the sibling created 15 resources. All ten nodes became Ready, and the
seven workers passed SKU, label and taint checks. CNV, Trident, BGP and all four
FRR sessions passed validation; all seven worker NICs had forwarding enabled.

After API registration, the 3600-second smoke run waited for all six catalog
imports and passed both Fedora boot sources with unchanged 120-second stability
barriers. A brief Argo sync-state change reset the initial barrier. A separate
PVC-backed Fedora VMI migrated from virt worker 2 to worker 1, retaining its VMI
UID and guest boot ID while its heartbeat counter advanced from 2 to 15.

External HTTP to speaker and non-speaker CUDN Pods preserved source IP
`10.0.5.4`. The private probe VM, disk, NIC and subnet, plus disposable test Pods,
VMIs, namespaces and ANF volumes, were verified removed. This run did not capture
the probe NIC's effective route table. Migration used the default pod network;
guest CUDN migration and worker replacement remain untested.

The installer drift plan was clean. The sibling again showed only the six
policy-tag updates described above; they were not applied. Formatting, lint and
tests passed in both repositories.

The sibling and installer were then destroyed in that order. All six catalog
volumes, Route Server, the Classic cluster and both resource groups were removed;
both Terraform states were verified empty. This teardown completed without the
polling-connection recovery needed in the earlier run.
