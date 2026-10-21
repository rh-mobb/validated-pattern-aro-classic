# AGENTS.md

Instructions for AI agents working in this repository.

## What this repo is

Customer-side **ARO Classic MIWI** reference deployment. Terraform provisions VNet, Key Vault + ESO, eight operator identities plus cluster MSI and their RBAC, AzAPI Classic cluster (`Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25`), and a federated credential on **`machine-api`** for bgp-cloud-connector NIC work (issuer from cluster output). **Azure Route Server, BGP MI, ANF, and Trident** are sibling [`validated-pattern-openshift-virt`](https://github.com/rh-mobb/validated-pattern-openshift-virt) — same split as [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp).

This is **not** ARO HCP. Do not use `az aro hcp` or `hcpOpenShiftClusters`.

## Human docs vs agent docs

Operators follow MkDocs (`docs/`). Agents follow this file plus per-profile [`clusters/<name>/AGENTS.md`](clusters/) when it exists.

| Topic | Human | Agent |
|-------|--------|--------|
| Deploy commands, architecture | [Classic MIWI guide](docs/guides/classic-miwi.md), [full-stack](docs/prerequisites/full-stack.md), `README.md` | Step **done-when** in `clusters/*/AGENTS.md` |
| Live Azure (`TF_VAR_*`, tmux, destroy order) | Short warnings in guides | This file, [Live Azure](#live-azure-deployments) |
| Virt / ANF / Route Server / BGP | [Classic MIWI §5](docs/guides/classic-miwi.md) + HCP [virt-stack](https://rh-mobb.github.io/validated-pattern-aro-hcp/guides/virt-stack/) | Profile `AGENTS.md` virt steps |
| Facts (CIDRs, identity names) | `docs/architecture.md`, example tfvars | Link those; do not invent pins |

If agent and human instructions disagree: **the operator guide wins for command names**; **this file / `clusters/*/AGENTS.md` wins for stop-and-ask**. Fix the loser in the same PR.

## Source precedence

For repository shape and shared behavior, consult **`references/validated-pattern-aro-hcp/` first**. This is the original pattern this Classic repo follows. Match its layout, Make interface, scripts, bootstrap, platform contract, documentation, and operator experience wherever the platforms allow. Differences should be justified by **Classic vs HCP requirements**, not independent design preferences; document the platform reason for a divergence.

For platform-specific implementation details, use these authorities:

1. **rh-mobb/terraform-aro** — MIWI AzAPI cluster shape, nine identities, built-in ARO operator RBAC (`enable_managed_identities` path).
2. **validated-pattern-openshift-virt** — Route Server, sibling BGP MI, Trident/CNV GitOps (ingests `platform.json` `machine_api_client_id` on Classic).
3. **This repo’s** `docs/architecture.md` and committed example `clusters/aro-classic-miwi/terraform.tfvars`.

## Reference map

Consult these sources before changing provisioning, bootstrap, the platform contract, or virt/BGP integration. `references/` contains gitignored local checkouts and notes, not deployed code or dependencies. Local snapshots may differ from upstream; verify the relevant implementation and version before copying examples. Keep the source precedence above when references disagree.

### Primary references

- **[rh-mobb/validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp)** — local **`references/validated-pattern-aro-hcp/`**. **First reference for how this repo should be shaped:** it is the original implementation this Classic pattern is built to match. Start with its corresponding module, script, Make target, test, or guide before designing a change here. Key entry points: `Makefile.cluster`, `scripts/gitops-bootstrap.sh`, `terraform/outputs.tf`, `terraform/bgp.tf`, `terraform/eso.tf`, and `docs/guides/virt-stack.md`. Preserve its per-cluster state isolation, Make interface, GitOps/ESO metadata, versioned `platform.json`, and installer/sibling split. Change only what Classic requires: kubeadmin access, `openShiftClusters`, eight operator identities plus cluster MSI, Classic subnet topology, `machine-api` NIC identity, and day-2 MachineSets instead of HCP external-auth and ARM `nodePools`.
- **[rh-mobb/terraform-aro](https://github.com/rh-mobb/terraform-aro)** — local `references/terraform-aro/`. Authority for **Classic MIWI** provisioning: `50-cluster.tf`, `20-iam.tf`, and `modules/aro-cluster-azapi/`, `modules/aro-managed-identity/`, `modules/aro-mi-rbac/`. Consult for the AzAPI request, eight operator identities plus cluster MSI, built-in operator RBAC, NSG handling, and cluster-first teardown. Use the `enable_managed_identities` path; service-principal and legacy RBAC examples are not this pattern. Some upstream examples require a separately populated `reference/aro-azapi` snapshot; do not assume it is present locally.
- **[rh-mobb/validated-pattern-openshift-virt](https://github.com/rh-mobb/validated-pattern-openshift-virt)** — local `references/validated-pattern-openshift-virt/`; also available as sibling `../validated-pattern-openshift-virt/`. Integration authority for ANF, Trident, CNV, Route Server, the dedicated BGP MI, and virt cleanup. Start with `terraform/main.tf`, `modules/azure/`, GitOps manifests, and profile playbooks. Its platform consumer accepts Classic `machine_api_client_id` or HCP `cluster_api_azure_client_id` for `networkInterfaceClientID`. Keep these resources in the sibling; destroy the sibling before the installer and reuse the installer’s Argo CD.
- **[diana-sari/aro-virt-bgp](https://github.com/diana-sari/aro-virt-bgp)** — local `references/aro-virt-bgp/`. Classic-specific functional evidence, especially `docs/06-aro-classic-miwi-validation.md`, BGP manifests, and validation scripts. Consult for CCO credentials, separate Route Server/NIC identities, activity-log attribution, router MachineSet labels, and worker replacement. Distinguish recorded dataplane tests from reconciliation-only results. The lab does not establish support policy for adding BGP federation to the ARO `machine-api` identity; its service-principal path is outside this repo’s scope.
- **[openshift/bgp-cloud-connector](https://github.com/openshift/bgp-cloud-connector)** — local `references/bgp-cloud-connector/`. Implementation reference for `BGPCloudConfiguration`, `BGPRouting`, `networkInterfaceClientID`, projected tokens/CCO, cloud peer reconciliation, and FRR/route advertisements. Read `api/`, `internal/`, and deployment manifests at the operator revision being consumed; do not infer behavior solely from lab notes.

### Supporting references

- `references/arovirt-public/` — Azure/CUDN routing and guest connectivity demonstrations; useful for dataplane checks, not a provisioning or support-policy authority.
- `references/cudn-non-speaker-egress.md` and `references/ovn-bug.md` — troubleshooting evidence for NIC forwarding on non-speaker workload nodes and missing CUDN `br-ex` flows. These notes describe HCP environments; adapt identity names and verify applicability to the target operator/OpenShift versions.
- `references/validated-pattern-aro-hcp-cluster-config/` and `references/rosa-cluster-config/` — tenant overlay and Argo application patterns. Adapt remote bases and authentication/RBAC rather than pointing Classic at an HCP baseline unchanged.
- `references/validated-pattern-terraform-rosa/`, `references/rosa-bgp/`, and `references/osd-gcp-cudn-routing/` — reusable module layout, GitOps, routing, and node lifecycle ideas. AWS IAM/Route Server and GCP WIF/NCC resources are not Azure implementation examples.
- `references/terraform-aro-hcp/`, `references/ARO-HCP/`, `references/bennerv-ARO-HCP/`, and HCP hackathon guides — secondary HCP API/history or service-side implementation context. Prefer the HCP validated pattern for customer workflow and `terraform-aro` for Classic provisioning.
- `references/validated-pattern-aro-classic/` — another local snapshot of this repo, not independent corroboration. PCA repos and notes are workload-specific references only when that workload is in scope.

### Checks when applying reference examples

- **BGP token audience:** the Classic MIWI lab records `openshift`, and the local connector deployment projects that audience; installer and virt-sibling Terraform currently configure `api://AzureADTokenExchange`. Check the actual consumed operator manifests and token path against both BGP federated credentials before deployment. Do not copy ESO’s audience into BGP wiring by analogy.
- **Identity boundaries:** Classic NIC operations use `machine-api`; HCP uses `cluster-api-azure`. The sibling BGP MI handles Route Server operations. A successful BGP session does not prove guest connectivity, non-speaker-node forwarding, or worker replacement behavior.
- **Local paths:** sibling checkout names are workspace conveniences. If absent, locate the named repository or use upstream; never treat `references/` as a required deployment layout.

## Hard rules

- **MIWI only:** no `azurerm_redhat_openshift_cluster`, no service principal resources, no client secrets in Terraform.
- **Cluster create:** AzAPI `azapi_resource` only — no Terraform `local-exec` for `az aro create`.
- **Network privacy:** RFC1918 or Private Endpoints; document exceptions in [`docs/architecture.md`](docs/architecture.md#network-privacy).
- **`make` is the interface:** run `make fmt lint test` before claiming work is done.
- **Never commit:** operator tfvars except committed examples, state, `platform.json`, `clusters/*/logs/`, kubeconfig, pull secrets.
- **Live Azure:** do not `apply` / `destroy` unless the user asked. Follow [Live Azure deployments](#live-azure-deployments).
- **Git:** feature branches only; Conventional Commits; no `Co-authored-by: Cursor` or AI trailers.

## Layout

| Path | Purpose |
|------|---------|
| `modules/network/` | RG, VNet, CP/worker subnets, NSG (reserved ANF/RS CIDRs validated in root `platform.tf`) |
| `modules/identities/` | Nine MIs, cluster MSI federated-credential RBAC, ARO operator roles |
| `modules/cluster/` | AzAPI `openShiftClusters` |
| `terraform/` | Root composition, `machine-api` BGP federation, `platform` output |
| `clusters/<name>/` | Per-cluster tfvars + local state; optional `AGENTS.md` |
| `scripts/` | credentials (kubeconfig/show/login), platform.json, destroy |
| `docs/` | MkDocs operator guides |
| `tests/` | `terraform test` + bats |

## Deploy path

```bash
make setup
make cluster.aro-classic-miwi.plan
make cluster.aro-classic-miwi.apply              # cluster + identities + KV/ESO; FICs once issuer exists (same apply or re-apply)
make cluster.aro-classic-miwi.login
make cluster.aro-classic-miwi.machinesets        # Helm 4 adopts defaults + reconciles pools before workloads
# If plan still shows eso/bgp federated credentials to add, run apply again before bootstrap (HCP parity — no tfvars issuer)
make cluster.aro-classic-miwi.bootstrap          # GitOps + operators + ESO (see docs/guides/gitops.md)
make cluster.aro-classic-miwi.platform           # clusters/aro-classic-miwi/platform.json
# Optional virt: validated-pattern-openshift-virt with ARO_HCP_ROOT=this checkout
```

Classic compute uses the local `helm/machinesets/` chart, wrapped by
`scripts/machinesets.sh`; do not put these MachineSets in Argo overlays. Terraform
writes profile-local values from `node_pools`. The named initial pool supplies ARM
sizing at creation, then all pools use the MachineSets target. Deletions and scale-down
stop unless the operator explicitly authorizes `MACHINESETS_CONFIRM=<cluster-name>`;
never set it automatically. Failed/pending Helm releases require recovery before retry.
Template changes warn but do not roll Machines. See the compute operator guide.

Agent done-when: [`clusters/aro-classic-miwi/AGENTS.md`](clusters/aro-classic-miwi/AGENTS.md).

A **deploy / create cluster** request means: preflight → apply → login → machinesets → bootstrap → platform (re-`apply` only when plan shows pending federated credentials). Process matches [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp) except Classic uses kubeadmin (not `external-auth`). Full virt/BGP E2E uses the **virt sibling** after `platform`.

## Live Azure deployments

Use this when the user asks to create, apply, verify, or destroy a real cluster. Apply is **60–90+ minutes**. Destroy is irreversible for the customer RG.

### Long-running operations (tmux)

1. Prefer tmux for `make cluster.<name>.apply` and `.destroy`. Tee to `clusters/<name>/logs/<utc>-<phase>.log` (gitignored).
2. Fallback: background shell with the same log path if tmux is unavailable.

### Halt vs continue

One **mutating** ARM operation at a time (Terraform apply/destroy, `az aro` delete if used manually).

**Halt and ask:**

- Terraform apply/destroy hung with no terminal state in Azure activity log.
- You would start a **second** apply/destroy while the first is in flight.
- Cluster delete failed but identities/RG teardown would leave orphans — confirm with operator before forcing.

**OK without asking:**

- Read-only: `terraform plan`, `az aro show`, `az group show`, activity log GET.
- Tiny IaC/docs that do not touch the subscription.
- Documented same-command retry (e.g. subnet `409 AnotherOperationInProgress` → retry the same `make cluster.<name>.apply` once).

On halt: paste evidence (operation name, timestamps, provisioning state). Wait for operator choice. Resume **that** step only.

### Preflight (every apply or destroy)

1. **Azure identity.** `az account show` — confirm subscription and user. Stop if unexpected.
2. **`clusters/<name>/terraform.tfvars`.** Must exist. `make cluster.<name>.plan|apply|destroy` always passes `-var-file=clusters/<name>/terraform.tfvars`.
3. **`TF_VAR_*` leftovers — mandatory.**

   ```bash
   env | grep '^TF_VAR_' || true
   ```

   If any `TF_VAR_*` is set: print each next to the tfvars value (or “not in cluster tfvars”). **Stop and ask** A) unset, B) align tfvars, C) abort. Do not apply until they pick.

4. **Existing resources.** `az group show` for `${cluster_name}-rg`, `az aro show` for cluster name. `terraform -chdir=terraform state list` with `TF_DATA_DIR=clusters/<name>/.terraform`. If cluster or non-empty state exists, stop and ask (apply vs destroy vs leave).
5. **Plan first.** `make cluster.<name>.plan` — summarize create/change/destroy counts.

### After first apply

- `az aro show -g <rg> -n <cluster>` — provisioning state `Succeeded`.
- Workers Ready in Azure portal or after kubeconfig: `oc get nodes`.
- Issuer comes from cluster output, never tfvars. Re-apply only when plan shows pending ESO or machine-api federated credentials.

### After second apply

- Installer federated credentials exist on ESO and `machine-api` (Azure portal or `az identity federated-credential list`). The BGP MI and its credential are created later by the virt sibling.
- `make cluster.<name>.platform` — `platform.json` has non-empty `oidc_issuer_url` and `machine_api_client_id`; labeled day-2 pools pass the platform script’s live Ready-node, VM-size, label, and replica checks. The sibling maps `machine_api_client_id` to its `network_interface_client_id`.

### Destroy

`DESTROY_CONFIRM=yes make cluster.<name>.destroy` — targets AzAPI cluster first, then full destroy. Confirm subscription, RG, and cluster name with the user first.

### Do not

- Call `terraform apply` / `destroy` outside Make (skips `-var-file`).
- Use `az aro hcp` or HCP kubeconfig flows.
- Set `networkInterfaceClientID` to the BGP identity client id.

## Documentation

When behavior changes: update `docs/architecture.md` and the operator guide in the same work. Profile `AGENTS.md` when done-when gates change.

- [`docs/index.md`](docs/index.md) — doc map
- [`docs/prerequisites/full-stack.md`](docs/prerequisites/full-stack.md) — workflow + permissions by step
- [`docs/guides/classic-miwi.md`](docs/guides/classic-miwi.md) — operator commands
- [`docs/architecture.md`](docs/architecture.md) — resources, identities, network privacy

## Changelog

Update [`CHANGELOG.md`](CHANGELOG.md) only at commit time from `git diff --cached`.

## Testing (agents)

| Tier | Command | When |
|------|---------|------|
| CI / local | `make fmt lint test` | Every PR; before claiming implementation done |
| Docs | `make docs-build` | Doc or nav changes |
| Live Azure E2E | Profile `AGENTS.md` steps 0–8 | Only when user explicitly requests deploy/verify in a subscription |

Do not claim live E2E without evidence (`az aro show`, `platform.json`, optional BGP Ready).
