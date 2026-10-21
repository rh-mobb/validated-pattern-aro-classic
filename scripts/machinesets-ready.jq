# Check actual MachineSet-owned, non-deleting Machines and their Ready Nodes.
$live[0].items as $sets |
$machines[0].items as $machines |
$nodes[0].items as $nodes |
all(.machineSets[]; . as $want |
  ($sets | map(select(.metadata.name == $want.metadata.name)) | .[0]) as $set |
  ([ $machines[] |
      select(.metadata.deletionTimestamp == null) |
      select(any(.metadata.ownerReferences[]?; .kind == "MachineSet" and .uid == $set.metadata.uid)) |
      .status.nodeRef.name as $name |
      $nodes[] | select(.metadata.name == $name and .metadata.deletionTimestamp == null) |
      select(any(.status.conditions[]?; .type == "Ready" and .status == "True")) |
      select(.metadata.labels["node.kubernetes.io/instance-type"] == $want.spec.template.spec.providerSpec.value.vmSize) |
      select(.metadata.labels as $labels | all($want.spec.template.spec.metadata.labels | to_entries[]; $labels[.key] == .value)) |
      .metadata.name
    ] | unique | length) >= $want.spec.replicas
)
