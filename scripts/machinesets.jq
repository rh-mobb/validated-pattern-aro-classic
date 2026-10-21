# Input: desired Terraform values; --slurpfile discovery: live default templates.
# Cluster identity and selectors are copied for adoption, generated for extra pools.
def zone: (.spec.template.spec.providerSpec.value.zone // "");
def fail($message): error($message);
. as $desired |
$discovery[0] as $d |
($d.defaults | sort_by(zone, .metadata.name)) as $defaults |
if ($defaults | length) == 0 then fail("No default worker MachineSets discovered") else . end |
if $d.initialWorkerPool != .initialWorkerPool then fail("initial_worker_pool cannot be renamed after adoption") else . end |
{
  initialWorkerPool: .initialWorkerPool,
  defaults: $defaults,
  infraId: $d.infraId,
  machineSets: [
    .nodePools | to_entries[] | .key as $pool | .value as $p |
    (if $pool == $desired.initialWorkerPool then
      if (($p.zones // []) | length) > 0 and (($p.zones | sort) != ([$defaults[] | zone] | sort))
      then fail("Initial pool zones must match the discovered default MachineSets") else $defaults end
    else
      (if (($p.zones // []) | length) > 0 then $p.zones else [$defaults[] | zone] | unique end) |
      map(. as $zone | ($defaults | map(select(zone == $zone)) | .[0] // $defaults[0]) |
        (if $zone == "" then del(.spec.template.spec.providerSpec.value.zone) else .spec.template.spec.providerSpec.value.zone = $zone end) |
        .metadata.name = ($d.infraId + "-" + $pool + "-" + (if $zone == "" then "0" else $zone end)) |
        .spec.selector.matchLabels = {
          "machine.openshift.io/cluster-api-cluster": $d.infraId,
          "machine.openshift.io/cluster-api-machineset": .metadata.name
        } |
        .spec.template.metadata.labels = (.spec.template.metadata.labels // {}) |
        .spec.template.metadata.labels["machine.openshift.io/cluster-api-cluster"] = $d.infraId |
        .spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"] = .metadata.name)
    end) as $bases |
    range(0; $bases | length) as $i |
    $bases[$i] |
    if (.metadata.name | length) > 63 then fail("Generated MachineSet name exceeds 63 characters") else . end |
    .metadata = {name: .metadata.name, namespace: "openshift-machine-api", labels: (.metadata.labels // {})} |
    .metadata.labels["aro-classic.validated-pattern.io/pool"] = $pool |
    .metadata.labels["machine.openshift.io/cluster-api-machineset"] = .metadata.name |
    .spec.replicas = (($p.replicas / ($bases | length) | floor) + (if $i < ($p.replicas % ($bases | length)) then 1 else 0 end)) |
    .spec.template.spec.metadata.labels = ((.spec.template.spec.metadata.labels // {}) + ($p.labels // {})) |
    .spec.template.spec.taints = ($p.taints // []) |
    .spec.template.spec.providerSpec.value.vmSize = $p.vm_size |
    .spec.template.spec.providerSpec.value.osDisk.diskSizeGB = $p.disk_size_gb |
    .spec.template.spec.providerSpec.value.tags = ((.spec.template.spec.providerSpec.value.tags // {}) + ($p.tags // {})) |
    if $p.subnet_id != null then
      .spec.template.spec.providerSpec.value.subnet = ($p.subnet_id | split("/") | last) |
      .spec.template.spec.providerSpec.value.vnet = ($p.subnet_id | split("/") | .[-3]) |
      .spec.template.spec.providerSpec.value.networkResourceGroup = ($p.subnet_id | split("/") | .[4])
    else . end |
    {apiVersion: "machine.openshift.io/v1beta1", kind: "MachineSet", metadata: .metadata, spec: .spec}
  ]
}
