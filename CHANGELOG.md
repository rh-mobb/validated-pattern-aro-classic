# Changelog

Notable **committed** changes to this reference deployment.

Entries are added at **commit time** from that commit’s diff. Do not log in-progress, debug, or reverted work.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- ARO Classic MIWI Terraform root: VNet (`10.0.0.0/16`), nine platform identities, AzAPI `openShiftClusters@2025-07-25`, Azure Route Server, BGP identity with `machine-api` federated credential (audience `openshift`)
- `make cluster.aro-classic-miwi.{plan,apply,destroy,kubeconfig,platform}` with per-cluster state under `clusters/aro-classic-miwi/`
- BGP manifest render script, MkDocs site, CI (`make fmt lint test`), and agent playbooks
