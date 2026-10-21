# Agent playbook — aro-classic-virt

Human workflow: [Virt example](../../docs/guides/virt-example.md). Follow root
[Live Azure](../../AGENTS.md#live-azure-deployments) preflight and stop-and-ask rules.
Compute adoption, extra-pool creation, repeat reconciliation, deletion and local baseline
bootstrap were live-validated on 2026-10-16. That test cluster was then destroyed; both RGs
were absent and Terraform state empty. See the compute guide's recorded validation;
that compute-only record is not virt/BGP dataplane evidence. A later clean rebuild
on 2026-10-19 used the sibling Classic profile at commit `c694230` without inline
Argo patches. See the operator guide for the separate attachment and dataplane record.

A further clean rebuild on 2026-10-20 used sibling commit `8b76ccf` and the Classic
profile without inline patches. Both settled-stack boot sources, separate live
migration with guest heartbeat continuity, and external speaker/non-speaker CUDN
HTTP passed. See the operator guide for recovery details, pre-boot API-registration
and timeout findings, cleanup evidence and limits; these checks did not exercise
guest CUDN migration or worker replacement.

The 2026-10-21 repeat used infrastructure ID `aro-classic-virt-wfdbr`, the same
sibling pin and Classic profile, and completed both applies without recovery.
Both boot sources, live migration (worker 2 to 1; same guest boot ID, heartbeat
2 to 15), and external speaker/non-speaker CUDN HTTP passed. Disposable resources
were removed. See the operator guide for the recorded limits and drift.
This repeat was subsequently torn down: both resource groups were absent and
both installer and sibling Terraform states had zero managed resources.

Both extra pools are enabled for the virt/BGP deployment test. Active desired state
is seven workers across the three pools below.

## Profile facts

- Profile and Azure cluster: `aro-classic-virt`; RG: `aro-classic-virt-rg`;
  managed RG: `aro-classic-virt-managed-rg`.
- Initial `worker`: 3 × Standard_D4s_v5, no taints or custom labels.
- `np-virt`: 2 × Standard_D8s_v6 across zones 1/2; labels `pool=np-virt`,
  `workload=virtualization`; taint `workload=virtualization:NoSchedule`.
- `np-bgp`: 2 × Standard_D8s_v6 across zones 1/2; labels `pool=np-bgp`,
  `workload=bgp`, `bgp_router=true`; taint `workload=bgp:NoSchedule`.
- Seven desired workers; extra pools are Helm MachineSets, not ARM worker profiles.
- CIDRs and version come from the committed tfvars. Replace `pull_secret_path` locally.

## Done-when gates

Only run live steps when explicitly requested. Every apply/destroy requires root
preflight, including Azure identity, TF_VAR leftovers, existing resources and a plan.
Use tmux and profile logs for long-running ARM operations. Never auto-confirm removals.

1. **Plan/apply:** `make cluster.aro-classic-virt.plan` shows one ARM worker profile
   with three workers and profile-local Helm values. After authorized apply,
   `az aro show -g aro-classic-virt-rg -n aro-classic-virt` reports Succeeded.
   Re-apply only when the plan shows pending federated credentials.
2. **Access:** `make cluster.aro-classic-virt.login` succeeds.
3. **Compute:** preview with `.machinesets-render`, then `.machinesets`. Helm 4
   owns adopted defaults plus two MachineSets per extra pool (one replica each in
   zones 1/2). All seven requested workers pass the wrapper's ownership, Ready,
   SKU and label checks. Also inspect new Node taints; readiness does not validate
   taint propagation or Node schedulability. Template changes do not roll existing workers.
   For removals, wrapper success does not wait for asynchronous cleanup: verify removed
   MachineSets, Machines, Nodes and Azure VMs are absent and retained MachineSet UIDs
   unchanged before declaring deletion complete.
4. **Bootstrap/platform:** `.bootstrap` installs the installer baseline after compute;
   `.platform` publishes contract v1 with non-empty issuer and machine_api_client_id.
   Both extra pools pass labeled-node checks; only np-bgp carries bgp_router=true.
5. **Virt sibling, when requested:** consume this profile's platform.json with
   `ARO_HCP_PROFILE=aro-classic-virt`. Configure CNV placement/tolerations for np-virt
   and verify BGP/FRR and required node agents tolerate np-bgp's taint. Do not claim
   virt/BGP E2E from compute readiness or Helm success alone. Require CNV/Trident,
   BGP readiness and dataplane evidence per the sibling's playbook.
6. **Destroy:** destroy the virt sibling first. Confirm subscription, RG and cluster
   before `DESTROY_CONFIRM=yes make cluster.aro-classic-virt.destroy`. Done when both
   RGs are gone and installer state is empty.
