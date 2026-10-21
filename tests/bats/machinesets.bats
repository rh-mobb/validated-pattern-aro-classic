#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export TFVARS="${BATS_TEST_TMPDIR}/terraform.tfvars"
  echo 'cluster_name = "demo"' >"$TFVARS"
  export CLUSTER_NAME=demo RESOURCE_GROUP=demo-rg
  export TERRAFORM_BIN="${BATS_TEST_TMPDIR}/bin/terraform"
  export CALLS="${BATS_TEST_TMPDIR}/calls"
  export FIXTURES="${BATS_TEST_TMPDIR}"
  export MACHINESETS_WAIT_SECONDS=0
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  export PATH="${BATS_TEST_TMPDIR}/bin:$PATH"
  cat >"${TERRAFORM_BIN}" <<'SH'
#!/bin/bash
case "$*" in
  *'output -json platform') echo '{"api_url":"https://api.demo:6443","cluster_name":"demo"}' ;;
  *'output -json machinesets_values') cat "$FIXTURES/desired.json" ;;
  *'output -json machinesets_values_yaml') jq -Rs . "$FIXTURES/desired.json" ;;
  *) exit 1 ;;
esac
SH
  cat >"${BATS_TEST_TMPDIR}/bin/oc" <<'SH'
#!/bin/bash
printf 'oc %s\n' "$*" >>"$CALLS"
case "$*" in
  'whoami --show-server') echo "${TEST_SERVER:-https://api.demo:6443}" ;;
  'get infrastructure cluster -o json') echo '{"status":{"infrastructureName":"demo-abc"}}' ;;
  'get machinesets -n openshift-machine-api -o json') cat "$FIXTURES/live.json" ;;
  'get machines -n openshift-machine-api -o json') cat "$FIXTURES/machines.json" ;;
  'get nodes -o json') cat "$FIXTURES/nodes.json" ;;
  *) exit 1 ;;
esac
SH
  # Use real Helm for offline chart rendering, stub cluster operations only.
  export REAL_HELM="$(PATH="${PATH#*:}" command -v helm)"
  cat >"${BATS_TEST_TMPDIR}/bin/helm" <<'SH'
#!/bin/bash
printf 'helm %s\n' "$*" >>"$CALLS"
case "$1" in
  version) echo "${TEST_HELM_VERSION:-v4.2.0}" ;;
  list) "$REAL_HELM" "$@" --help >/dev/null || exit 1
        [[ "${HELM_LIST_FAIL:-}" != 1 ]] || exit 1
        if [[ -f "$FIXTURES/previous.json" ]]; then printf '[{"name":"machinesets","status":"%s"}]\n' "${TEST_RELEASE_STATUS:-deployed}"; else echo '[]'; fi ;;
  get) cat "$FIXTURES/previous.json" ;;
  upgrade) [[ "${HELM_UPGRADE_FAIL:-}" != 1 ]] ;;
  template|lint) exec "$REAL_HELM" "$@" ;;
  *) exit 1 ;;
esac
SH
  chmod +x "${BATS_TEST_TMPDIR}/bin/"*
  cat >"${FIXTURES}/desired.json" <<'JSON'
{"initialWorkerPool":"worker","nodePools":{"worker":{"vm_size":"Standard_D4s_v5","replicas":1,"disk_size_gb":128,"labels":{},"tags":{},"taints":[],"zones":[]},"virt":{"vm_size":"Standard_D8s_v6","replicas":0,"disk_size_gb":256,"labels":{"bgp_router":"true"},"tags":{},"taints":[],"zones":["1"]}}}
JSON
  cat >"${FIXTURES}/live.json" <<'JSON'
{"items":[{"apiVersion":"machine.openshift.io/v1beta1","kind":"MachineSet","metadata":{"name":"demo-abc-worker-eastus1","uid":"existing-uid","resourceVersion":"111","labels":{"machine.openshift.io/cluster-api-cluster":"demo-abc"}},"spec":{"replicas":1,"selector":{"matchLabels":{"machine.openshift.io/cluster-api-machineset":"demo-abc-worker-eastus1"}},"template":{"metadata":{"labels":{"machine.openshift.io/cluster-api-machineset":"demo-abc-worker-eastus1"}},"spec":{"metadata":{"labels":{}},"providerSpec":{"value":{"apiVersion":"machine.openshift.io/v1beta1","kind":"AzureMachineProviderSpec","zone":"1","vmSize":"Standard_D4s_v5","osDisk":{"diskSizeGB":128},"image":{"resourceID":"live-image"},"managedIdentity":{"id":"live-miwi"},"credentialsSecret":{"name":"live-creds"},"securityProfile":{"encryptionAtHost":true}}}}}},"status":{"readyReplicas":1}}]}
JSON
  echo '{"items":[{"metadata":{"name":"m1","ownerReferences":[{"kind":"MachineSet","name":"demo-abc-worker-eastus1","uid":"existing-uid"}]},"status":{"nodeRef":{"name":"node1"}}}]}' >"${FIXTURES}/machines.json"
  echo '{"items":[{"metadata":{"name":"node1","labels":{"node.kubernetes.io/instance-type":"Standard_D4s_v5"}},"status":{"conditions":[{"type":"Ready","status":"True"}]}}]}' >"${FIXTURES}/nodes.json"
}

@test "adopts defaults with stable selectors and preserves the full MIWI provider spec" {
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -eq 0 ]
  jq -e '.machineSets[0] | .metadata.name == "demo-abc-worker-eastus1" and (.metadata | has("uid") | not) and .spec.template.spec.providerSpec.value.managedIdentity.id == "live-miwi" and .spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"] == "demo-abc-worker-eastus1"' "${FIXTURES}/machinesets/discovered.yaml"
  rg -- '--take-ownership' "$CALLS"
  [ -f "${FIXTURES}/machinesets/rendered.yaml" ]
}

@test "rejects Helm 2 and 3 before cluster mutations" {
  local version
  for version in v2.17.0 v3.19.0; do
    export TEST_HELM_VERSION="$version"
    run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"Helm 4"* ]]
  done
  ! rg 'helm upgrade' "$CALLS"
}

@test "rejects the wrong cluster" {
  export TEST_SERVER=https://wrong:6443
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  ! rg 'helm upgrade' "$CALLS"
}

@test "release lookup errors never trigger first-time adoption" {
  export HELM_LIST_FAIL=1
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  ! rg 'helm upgrade' "$CALLS"
}

@test "refuses to take resources owned by a different Helm release" {
  jq '.items[0].metadata.annotations["meta.helm.sh/release-name"] = "other"' "${FIXTURES}/live.json" >"${FIXTURES}/new.json"
  mv "${FIXTURES}/new.json" "${FIXTURES}/live.json"
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"another release"* ]]
  ! rg 'helm upgrade' "$CALLS"
}

@test "preview does not adopt or upgrade and reports template changes" {
  jq '.nodePools.worker.labels.team = "infra"' "${FIXTURES}/desired.json" >"${FIXTURES}/new.json"
  mv "${FIXTURES}/new.json" "${FIXTURES}/desired.json"
  run bash "${REPO_ROOT}/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  [[ "$output" == *"not roll"* ]]
  ! rg 'helm upgrade' "$CALLS"
}

@test "removals require confirmation and desired workers Ready before Helm upgrade" {
  run bash "${REPO_ROOT}/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  jq '.machineSets += [.machineSets[1] | .metadata.name = "old-pool" | .spec.replicas = 2]' "${FIXTURES}/machinesets/discovered.yaml" >"${FIXTURES}/previous.json"
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"old-pool"* ]]
  ! rg 'helm upgrade' "$CALLS"
  export MACHINESETS_CONFIRM=demo
  echo '{"items":[]}' >"${FIXTURES}/nodes.json"
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  ! rg 'helm upgrade' "$CALLS"
}

@test "replica reductions require confirmation even with no deleted MachineSet" {
  run bash "${REPO_ROOT}/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  jq '.machineSets[0].spec.replicas = 3' "${FIXTURES}/machinesets/discovered.yaml" >"${FIXTURES}/previous.json"
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"MACHINESETS_CONFIRM"* ]]
  export MACHINESETS_CONFIRM=demo
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -eq 0 ]
  ! rg -- '--take-ownership' "$CALLS"
}

@test "Helm failure propagates and workers that are not Ready fail the operation" {
  export HELM_UPGRADE_FAIL=1
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  unset HELM_UPGRADE_FAIL
  echo '{"items":[]}' >"${FIXTURES}/nodes.json"
  run bash "${REPO_ROOT}/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"Ready"* ]]
}

@test "multi-zone pools distribute total replicas and render distinct identities" {
  jq '.items += [.items[0] | .metadata.name = "demo-abc-worker-eastus2" | .metadata.uid = "uid2" | .spec.template.spec.providerSpec.value.zone = "2" | .spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"] = .metadata.name | .spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"] = .metadata.name]' "$FIXTURES/live.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/live.json"
  jq '.nodePools.worker.replicas = 3 | .nodePools.virt.replicas = 5 | .nodePools.virt.zones = ["1", "2"]' "$FIXTURES/desired.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/desired.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  jq -e '[.machineSets[] | select(.metadata.labels["aro-classic.validated-pattern.io/pool"] == "virt") | .spec.replicas] == [3,2]' "$FIXTURES/machinesets/discovered.yaml"
  jq -e 'all(.machineSets[]; .spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"] == .metadata.name)' "$FIXTURES/machinesets/discovered.yaml"
}

@test "default ownership uses Machine UID and ignores terminating nodes" {
  jq '.items[0].metadata.ownerReferences[0].uid = "stale-uid"' "$FIXTURES/machines.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/machines.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"Ready"* ]]
  jq '.items[0].metadata.ownerReferences[0].uid = "existing-uid"' "$FIXTURES/machines.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/machines.json"
  jq '.items[0].metadata.deletionTimestamp = "2026-10-16T00:00:00Z"' "$FIXTURES/nodes.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/nodes.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
}

@test "wrong-sized nodes cannot satisfy worker readiness" {
  jq '.items[0].metadata.labels["node.kubernetes.io/instance-type"] = "Standard_D8s_v6"' "$FIXTURES/nodes.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/nodes.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"Ready"* ]]
}

@test "empty desired population and initial pool rename are rejected" {
  jq '.nodePools.worker.replicas = 0' "$FIXTURES/desired.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/desired.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  ! rg 'helm upgrade' "$CALLS"
}

@test "successful confirmed removals are delegated to Helm without a custom delete" {
  run bash "$REPO_ROOT/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  jq '.machineSets += [.machineSets[1] | .metadata.name = "old-pool" | .spec.replicas = 2]' "$FIXTURES/machinesets/discovered.yaml" >"$FIXTURES/previous.json"
  export MACHINESETS_CONFIRM=demo
  run bash "$REPO_ROOT/scripts/machinesets.sh" apply
  [ "$status" -eq 0 ]
  rg 'helm upgrade' "$CALLS"
  ! rg 'oc delete|--force|--rollback' "$CALLS"
}

@test "repeat upgrades use the Helm discovery baseline, preserving declarative label removal" {
  run bash "$REPO_ROOT/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  cp "$FIXTURES/machinesets/discovered.yaml" "$FIXTURES/previous.json"
  jq '.items[0].spec.template.spec.metadata.labels.old = "remove-me"' "$FIXTURES/live.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/live.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  jq -e '.machineSets[0].spec.template.spec.metadata.labels | has("old") | not' "$FIXTURES/machinesets/discovered.yaml"
  jq '.initialWorkerPool = "virt"' "$FIXTURES/desired.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/desired.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot be renamed"* ]]
}

@test "initial pool zone remapping is rejected" {
  jq '.nodePools.worker.zones = ["2"]' "$FIXTURES/desired.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/desired.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"zones must match"* ]]
  ! rg 'helm upgrade' "$CALLS"
}

@test "failed and pending Helm releases require recovery before any upgrade" {
  run bash "$REPO_ROOT/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  cp "$FIXTURES/machinesets/discovered.yaml" "$FIXTURES/previous.json"
  local release_status
  for release_status in failed pending-upgrade pending-install pending-rollback uninstalling; do
    export TEST_RELEASE_STATUS="$release_status"
    run bash "$REPO_ROOT/scripts/machinesets.sh" apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"recovery"* ]]
  done
  ! rg 'helm upgrade' "$CALLS"
}

@test "renders two extra pools with independent node labels and taints" {
  jq '.nodePools.virt.labels = {pool:"np-virt",workload:"virtualization"} |
      .nodePools.virt.taints = [{key:"workload",value:"virtualization",effect:"NoSchedule"}] |
      .nodePools["np-bgp"] = .nodePools.virt |
      .nodePools["np-bgp"].labels = {pool:"np-bgp",workload:"bgp",bgp_router:"true"} |
      .nodePools["np-bgp"].taints[0].value = "bgp"' "$FIXTURES/desired.json" >"$FIXTURES/new.json"
  mv "$FIXTURES/new.json" "$FIXTURES/desired.json"
  run bash "$REPO_ROOT/scripts/machinesets.sh" render
  [ "$status" -eq 0 ]
  jq -e '
    [.machineSets[] | select(.metadata.labels["aro-classic.validated-pattern.io/pool"] != "worker")] |
    length == 2 and all(.[];
      .spec.template.spec.metadata.labels.workload == .spec.template.spec.taints[0].value and
      .spec.template.spec.taints[0].effect == "NoSchedule")
  ' "$FIXTURES/machinesets/discovered.yaml"
}
