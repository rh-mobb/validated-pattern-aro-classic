# ARO Classic MIWI reference deployment

Terraform reference for **Azure Red Hat OpenShift Classic** with platform workload identities (MIWI), GitOps baseline, and a `platform.json` contract for [`validated-pattern-openshift-virt`](https://github.com/rh-mobb/validated-pattern-openshift-virt) (ANF, Route Server, BGP).

| I want to… | Start here |
|------------|------------|
| Deploy my first cluster | [Quick start](getting-started/quick-start.md) |
| Verify subscription and tools | [Account prerequisites](prerequisites/account.md) |
| Permissions per `make` step | [Full-stack deployment](prerequisites/full-stack.md) |
| Deploy the example profile | [Classic MIWI deploy](guides/classic-miwi.md) |
| Define virt and BGP pools with labels and taints | [Virt example](guides/virt-example.md) |
| Inspect identities, CIDRs, and RBAC | [Architecture](architecture.md) |
| Run an agent E2E (done-when) | [`AGENTS.md`](../AGENTS.md) → [`clusters/aro-classic-miwi/AGENTS.md`](../clusters/aro-classic-miwi/AGENTS.md) |

Sister pattern for HCP: [validated-pattern-aro-hcp](https://github.com/rh-mobb/validated-pattern-aro-hcp).
