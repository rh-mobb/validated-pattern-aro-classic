# Classic MIWI deploy

This guide is the operator command path. Agents use [`clusters/aro-classic-miwi/AGENTS.md`](../../clusters/aro-classic-miwi/AGENTS.md) for done-when gates.

## 0. Unset `TF_VAR_*`

```bash
env | grep '^TF_VAR_' || true
```

If any are set, unset them or align `clusters/aro-classic-miwi/terraform.tfvars` before `make cluster.*`.

## 1. Plan and apply

```bash
make setup
cp clusters/aro-classic-miwi/terraform.tfvars clusters/aro-classic-miwi/terraform.tfvars.local
# Edit location, domain, pull_secret_path

make cluster.aro-classic-miwi.plan
make cluster.aro-classic-miwi.apply
```

Apply is long-running (often 60–90 minutes). Prefer tmux.

## 2. Cluster access (kubeadmin)

Same **make** shape as [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp); Classic uses `az aro list-credentials` (not `az aro hcp request-credential`).

```bash
make cluster.aro-classic-miwi.kubeconfig        # write .kube/config
make cluster.aro-classic-miwi.show-credentials  # API/console URLs + kubeadmin password
make cluster.aro-classic-miwi.login             # oc login into .kube/config
```

Entra console / htpasswd hardening is out of scope here (see OpenShift identity provider docs).

## 3. Federated credentials (if needed)

Same as HCP: Terraform reads `module.cluster.oidc_issuer_url` — **no issuer in tfvars**. After the cluster is **Succeeded**, if `make cluster.aro-classic-miwi.plan` still shows ESO or BGP `azurerm_federated_identity_credential` to add, run **apply** again before bootstrap.

## 4. MachineSets and GitOps bootstrap

Requires `pull_secret_path` on apply (Key Vault). See [GitOps bootstrap](gitops.md).

```bash
make cluster.aro-classic-miwi.machinesets-render # preview local chart
make cluster.aro-classic-miwi.machinesets        # adopt/create workers before workloads
make cluster.aro-classic-miwi.bootstrap
make cluster.aro-classic-miwi.platform
```

`platform.json` is gitignored under `clusters/aro-classic-miwi/`. It uses **contract_version 1** (same shape as [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp)) plus `machine_api_client_id` for the virt sibling.

## 5. OpenShift Virtualization stack (optional)

ANF, Trident, CNV, Azure Route Server, and bgp-cloud-connector live in sibling [`validated-pattern-openshift-virt`](https://github.com/rh-mobb/validated-pattern-openshift-virt) — not in this repo. Operator path mirrors [ARO HCP virt stack](https://rh-mobb.github.io/validated-pattern-aro-hcp/guides/virt-stack/).

1. Add the desired pool to `node_pools`, retaining the named initial pool. For example, add `np-virt` with `labels.bgp_router = "true"`. Run plan/apply to generate Helm values, then the `machinesets` target before bootstrap. See [Compute machine pools](compute-machine-pools.md) for zone distribution, default-pool adoption, previews and confirmed deletions.
2. Run `make cluster.aro-classic-miwi.platform`; it verifies labeled pools against Ready nodes, VM size, and replica count. A failure leaves the previous file intact; fix the workers and regenerate it before using the sibling.
3. In the virt checkout, set its profile `platform_json` to the installer’s generated file, then run:

```bash
export KUBECONFIG_PATH=/path/to/validated-pattern-aro-classic/.kube/config
ARO_HCP_ROOT=/path/to/validated-pattern-aro-classic ARO_HCP_PROFILE=aro-classic-miwi \
  make cluster.aro-classic-miwi.apply
make cluster.aro-classic-miwi.bootstrap
```

Destroy **sibling first** (cleanup + `destroy`), then `DESTROY_CONFIRM=yes make cluster.aro-classic-miwi.destroy`.

## 6. Destroy

```bash
DESTROY_CONFIRM=yes make cluster.aro-classic-miwi.destroy
```

Destroy deletes the AzAPI cluster first, then the remaining Terraform resources.

### Azure Policy tags

Terraform ignores Azure resource tag changes after creation so policy-added tags are preserved. Changes to `tags` in tfvars affect creation only; update existing tags through Azure Policy or your Azure tagging workflow. MachineSet VM tags use the separate Helm pool configuration.

The cluster lifecycle rules were audited on 2026-10-20 and retained unchanged;
no change was needed for the install-only cluster body, including version, workers,
pull secret and MIWI mappings. See the [audit decision](../architecture.md#cluster-lifecycle-audit-2026-10-20)
for scope and validation limits.
