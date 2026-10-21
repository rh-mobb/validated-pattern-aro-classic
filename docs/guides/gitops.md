# GitOps bootstrap

Optional post-deploy path aligned with [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp): OpenShift GitOps, Web Terminal, Compliance Operator, and External Secrets Operator with Key Vault workload identity.

## When to run

After cluster **Succeeded**, kubeadmin login works, and Terraform has written the pull secret to Key Vault (set `pull_secret_path` in tfvars before apply).

```bash
make cluster.aro-classic-miwi.login
make cluster.aro-classic-miwi.bootstrap
```

`bootstrap` depends on `machinesets`, which depends on `login`. The local Helm 4 release reconciles workers and waits for readiness before GitOps workloads are installed.

## Prerequisites (Terraform)

| Output | Purpose |
|--------|---------|
| `key_vault_name`, `key_vault_uri` | ESO `ClusterSecretStore` |
| `eso_client_id`, `tenant_id` | ConfigMap `openshift-gitops/aro-platform-metadata` |
| `pull_secret_key_vault_secret_name` | ExternalSecret remote ref (default `redhat-pull-secret`) |
| `oidc_issuer_url` (output) | ESO and BGP federated credentials (`terraform/eso.tf`, `terraform/bgp.tf`) |

Re-run **`make cluster.<name>.apply`** if plan still shows federated credentials to create (same as HCP). No issuer in tfvars.

## Differences from ARO HCP

| Topic | HCP | Classic (this repo) |
|-------|-----|---------------------|
| Admin `oc` | `requestAdminCredential` | kubeadmin (`login` / `kubeconfig`) |
| Console / GitOps UI | Entra `external-auth` + Argo `oidcConfig` | **OpenShift OAuth** on GitOps route (kubeadmin or future IdP) |
| Pull secret merge | HCCO `global-pull-secret` wait | `additional-pull-secret` + ESO from Key Vault |
| Compliance operator | HyperShift `PLATFORM` env | Standard Classic (masters present) |

## Make and env

Same variables as HCP where applicable (`GITOPS_REPO`, `GITOPS_REVISION`, `GITOPS_OVERLAY`, `PULL_SECRET_PATH`, `GITOPS_DRY_RUN=1`).

Default overlay: `gitops/overlays/aro-classic-miwi` when the profile directory exists.

Local dev before the repo is published:

```bash
GITOPS_REPO=https://github.com/<you>/validated-pattern-aro-classic.git GITOPS_REVISION=<branch> \
  make cluster.aro-classic-miwi.bootstrap
```

## Local baseline before publishing a Git source

For a greenfield test from an unpublished checkout, explicitly defer the root
Argo Application while installing the local baseline:

```bash
GITOPS_LOCAL_ONLY=1 make cluster.aro-classic-virt.bootstrap
```

This still reconciles MachineSets, installs GitOps, publishes platform metadata and
applies operator manifests. It does not configure continuous Git reconciliation or
remove an existing Application. Once a reachable repository/ref contains the overlay,
run bootstrap without this flag and set `GITOPS_REPO`/`GITOPS_REVISION` as needed.

## What gets installed

See [gitops/README.md](../../gitops/README.md) and the HCP [GitOps guide](https://github.com/rh-mobb/validated-pattern-aro-hcp/blob/main/docs/guides/gitops.md) for operator channels and Argo sync policy (`prune: false` on the root Application).

## Day-2 worker pools

Operator subscriptions live under `gitops/base`. Compute is managed separately by the
installer's local `helm/machinesets/` chart, driven by `node_pools` in the profile tfvars.
Do not also enable MachineSets in an Argo overlay. Guide: [Compute machine pools](compute-machine-pools.md).
