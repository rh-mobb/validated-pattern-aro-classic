# Changelog

Notable **committed** changes to this reference deployment.

Entries are added at **commit time** from that commit’s diff. Do not log in-progress, debug, or reverted work.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Classic installer and worker lifecycle

- Add the GitOps/ESO baseline, Key Vault integration and versioned virt-sibling platform contract, including the Classic `machine-api` federated credential.
- Manage default and additional worker pools through Terraform-generated per-profile values and a local Helm 4 MachineSet chart, with guarded adoption, deletion and scale-down.
- Keep Route Server, ANF and workload BGP configuration in the virt sibling; ignore Azure policy tag changes and validate reserved subnet ranges, including control-plane overlap.
- Add the tainted three-pool virt example, lifecycle and Helm lint gates, operator documentation, lifecycle audit decision, and clean boot, migration, CUDN and teardown validation records.

### Added
- ARO Classic MIWI Terraform root: VNet (`10.0.0.0/16`), nine platform identities, AzAPI `openShiftClusters@2025-07-25`, Azure Route Server, BGP identity with `machine-api` federated credential (audience `openshift`)
- `make cluster.aro-classic-miwi.{plan,apply,destroy,kubeconfig,platform}` with per-cluster state under `clusters/aro-classic-miwi/`
- BGP manifest render script, MkDocs site, CI (`make fmt lint test`), and agent playbooks
- Expanded root and profile `AGENTS.md` (Live Azure preflight, halt, steps 0–8), `docs/prerequisites/full-stack.md`, quick start
