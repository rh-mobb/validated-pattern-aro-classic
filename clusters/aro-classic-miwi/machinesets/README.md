# Generated MachineSet configuration

Terraform writes `values.yaml` from the profile's `node_pools`. The MachineSet wrapper
adds `discovered.yaml` and `rendered.yaml` and applies the local Helm 4 chart.
These generated files are ignored; edit `../terraform.tfvars` and use the Make targets.

See [the compute guide](../../../docs/guides/compute-machine-pools.md).
