# AGENTS.md

Instructions for AI agents working in this repository.

## What this repo is

Customer-side **ARO Classic MIWI** reference deployment. Terraform provisions VNet, nine platform workload identities plus cluster MSI RBAC, AzAPI Classic cluster, Azure Route Server, and BGP Cloud Connector identity (Route Server custom role + federated credentials on BGP MI and `machine-api` after OIDC issuer is known).

This is **not** ARO HCP. Do not use `az aro hcp`, `hcpOpenShiftClusters`, or the [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp) installer.

## Hard rules

- **MIWI only:** no service principal cluster path in this tree.
- **`make` is the interface:** run `make fmt lint test` before claiming work is done.
- **Network privacy:** RFC1918 or Private Endpoints; document exceptions in `docs/architecture.md`.
- **Live Azure:** do not `apply` / `destroy` unless the user asked. See [Live Azure deployments](#live-azure-deployments).
- **Never commit:** operator tfvars except the committed example, state, `platform.json`, kubeconfig, pull secrets.

## Layout

| Path | Purpose |
|------|---------|
| `modules/network/` | RG, VNet, subnets, NSG, `RouteServerSubnet` |
| `modules/identities/` | Nine MIs, federated-credential RBAC, ARO operator roles |
| `modules/cluster/` | AzAPI `openShiftClusters` |
| `modules/routeserver/` | Route Server + management PIP |
| `modules/bgp/` | BGP MI, custom role, federated credentials |
| `terraform/` | Root composition |
| `clusters/<name>/` | Per-cluster tfvars and state |
| `scripts/` | kubeconfig, platform.json, destroy, BGP render |

## Deploy path

See [docs/guides/classic-miwi.md](docs/guides/classic-miwi.md). Profile playbook: [`clusters/aro-classic-miwi/AGENTS.md`](clusters/aro-classic-miwi/AGENTS.md).

## Live Azure deployments

### Long-running operations (tmux)

Prefer tmux for `make cluster.<name>.apply` and `.destroy` (30–90+ minutes).

### Halt vs continue

One mutating ARM operation at a time.

**Halt and ask:** overlapping `terraform apply`/`destroy`, cluster delete hung with no terminal state, destroy order violated (cluster must delete before identities).

**OK without asking:** `terraform plan`, `az aro show`, read-only Azure diagnosis.

### Preflight

1. `az account show` — confirm subscription.
2. `clusters/<name>/terraform.tfvars` exists.
3. `env | grep '^TF_VAR_'` — stop and ask if any are set (A/B/C: unset, align tfvars, abort).
4. `make cluster.<name>.plan` — summarize create/change/destroy.

### Destroy

`make cluster.<name>.destroy` runs `scripts/destroy.sh` (cluster target first). Requires `DESTROY_CONFIRM=yes`.

## Documentation

Operators: MkDocs (`docs/`). Agents: this file + `clusters/*/AGENTS.md`. Guide wins for commands; this file wins for stop-and-ask.

## Changelog

Update `CHANGELOG.md` only at commit time from `git diff --cached`.
