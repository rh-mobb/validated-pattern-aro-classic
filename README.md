# ARO Classic MIWI reference deployment

Terraform and scripts for **Azure Red Hat OpenShift Classic** with **platform workload identities** (MIWI), GitOps bootstrap, and an identity/platform handoff to the sibling [virt/BGP stack](https://github.com/rh-mobb/validated-pattern-openshift-virt).

This is **not** [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp) (ARO HCP). Cluster create uses AzAPI `Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25`. There is no service-principal path and no `az aro hcp`.

## Quick path

```bash
make setup
make cluster.aro-classic-miwi.plan
make cluster.aro-classic-miwi.apply
make cluster.aro-classic-miwi.login
make cluster.aro-classic-miwi.machinesets
make cluster.aro-classic-miwi.bootstrap
make cluster.aro-classic-miwi.platform
```

Operator guide: [Classic MIWI deploy](docs/guides/classic-miwi.md). Agents: [`AGENTS.md`](AGENTS.md) and [`clusters/aro-classic-miwi/AGENTS.md`](clusters/aro-classic-miwi/AGENTS.md).

A greenfield [virt example](docs/guides/virt-example.md) is available at
[`clusters/aro-classic-virt/`](clusters/aro-classic-virt/terraform.tfvars), with separate
labeled and tainted virtualization/BGP pools managed by the local Helm chart.

## Development

```bash
make lint-helm        # strict, offline chart lint; requires Helm 4
make fmt lint test
make docs-build
```

`make lint` includes the Helm chart check using committed fixture values; it needs no
cluster connection or generated profile files. Install TFLint on macOS with
`brew install terraform-linters/tap/tflint` if it is missing.

Prior art: [rh-mobb/terraform-aro](https://github.com/rh-mobb/terraform-aro) (MIWI AzAPI shape), [diana-sari/aro-virt-bgp](https://github.com/diana-sari/aro-virt-bgp) (BGP validation).
