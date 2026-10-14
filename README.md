# ARO Classic MIWI reference deployment

Terraform and scripts for **Azure Red Hat OpenShift Classic** with **platform workload identities** (MIWI), Azure Route Server, and BGP Cloud Connector identity wiring.

This is **not** [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp) (ARO HCP). Cluster create uses AzAPI `Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25`. There is no service-principal path and no `az aro hcp`.

## Quick path

```bash
make setup
make cluster.aro-classic-miwi.plan
make cluster.aro-classic-miwi.apply
make cluster.aro-classic-miwi.kubeconfig
# Set oidc_issuer_url in clusters/aro-classic-miwi/terraform.tfvars from terraform output, then:
make cluster.aro-classic-miwi.apply
make cluster.aro-classic-miwi.platform
```

Operator guide: [Classic MIWI deploy](docs/guides/classic-miwi.md). Agents: [`AGENTS.md`](AGENTS.md) and [`clusters/aro-classic-miwi/AGENTS.md`](clusters/aro-classic-miwi/AGENTS.md).

## Development

```bash
make fmt lint test
make docs-build
```

Prior art: [rh-mobb/terraform-aro](https://github.com/rh-mobb/terraform-aro) (MIWI AzAPI shape), [diana-sari/aro-virt-bgp](https://github.com/diana-sari/aro-virt-bgp) (BGP validation).
