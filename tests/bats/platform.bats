#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export CLUSTER_PROFILE=aro-classic-miwi
  export CLUSTER_NAME=aro-classic-miwi
  export TFVARS="${BATS_TEST_TMPDIR}/terraform.tfvars"
  touch "${TFVARS}"
  export TERRAFORM_BIN="${REPO_ROOT}/tests/fixtures/terraform-output-fake.sh"
  export PLATFORM_FILE="${BATS_TEST_TMPDIR}/platform.json"
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
  export NODES_FILE="${BATS_TEST_TMPDIR}/nodes.json"
  cat >"${BATS_TEST_TMPDIR}/bin/oc" <<'SH'
#!/usr/bin/env bash
case "$*" in
  'whoami --show-server') echo "${TEST_API_SERVER:-https://api.example:6443}" ;;
  'get nodes -o json') cat "${NODES_FILE}" ;;
  *) exit 1 ;;
esac
SH
  chmod +x "${BATS_TEST_TMPDIR}/bin/oc"
  cat >"${NODES_FILE}" <<'JSON'
{"items":[{"metadata":{"name":"worker-a","labels":{"bgp_router":"true","workload":"virtualization","node.kubernetes.io/instance-type":"Standard_D8s_v6"}},"status":{"conditions":[{"type":"Ready","status":"True"}]}}]}
JSON
  export PLATFORM_FIXTURE="${BATS_TEST_TMPDIR}/intent.json"
  env -u PLATFORM_FIXTURE "${TERRAFORM_BIN}" output -json platform >"${PLATFORM_FIXTURE}"
}

@test "platform.json uses HCP-compatible contract_version 1" {
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -eq 0 ]

  jq -e '.contract_version == 1' "${PLATFORM_FILE}"
  jq -e '.machine_api_client_id == "machine-api-client"' \
    "${PLATFORM_FILE}"
  jq -e '.network.reserved.netapp_subnet_prefix == "10.0.3.0/24"' \
    "${PLATFORM_FILE}"
}

@test "platform rejects a labeled pool with no matching nodes" {
  echo '{"items":[]}' >"${NODES_FILE}"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"np-virt"* ]]
  [ ! -e "${PLATFORM_FILE}" ]
}

@test "platform rejects wrong VM size and preserves the previous contract" {
  echo 'previous-contract' >"${PLATFORM_FILE}"
  sed 's/Standard_D8s_v6/Standard_D4s_v5/' "${NODES_FILE}" >"${NODES_FILE}.new"
  mv "${NODES_FILE}.new" "${NODES_FILE}"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -ne 0 ]
  [ "$(cat "${PLATFORM_FILE}")" = previous-contract ]
}

@test "platform rejects nodes that are not Ready" {
  sed 's/"status":"True"/"status":"False"/' "${NODES_FILE}" >"${NODES_FILE}.new"
  mv "${NODES_FILE}.new" "${NODES_FILE}"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -ne 0 ]
  [ ! -e "${PLATFORM_FILE}" ]
}

@test "platform requires all pool labels on nodes" {
  sed 's/"workload":"virtualization"/"workload":"general"/' "${NODES_FILE}" >"${NODES_FILE}.new"
  mv "${NODES_FILE}.new" "${NODES_FILE}"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -ne 0 ]
  [ ! -e "${PLATFORM_FILE}" ]
}

@test "platform requires the requested number of Ready nodes" {
  jq '.node_pools["np-virt"].replicas = 2' "${PLATFORM_FIXTURE}" >"${PLATFORM_FIXTURE}.new"
  mv "${PLATFORM_FIXTURE}.new" "${PLATFORM_FIXTURE}"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -ne 0 ]
  [ ! -e "${PLATFORM_FILE}" ]
}

@test "base platform without labeled pools does not require cluster access" {
  jq '.node_pools |= del(.["np-virt"])' "${PLATFORM_FIXTURE}" >"${PLATFORM_FIXTURE}.new"
  mv "${PLATFORM_FIXTURE}.new" "${PLATFORM_FIXTURE}"
  echo '#!/usr/bin/env bash' >"${BATS_TEST_TMPDIR}/bin/oc"
  echo 'exit 1' >>"${BATS_TEST_TMPDIR}/bin/oc"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -eq 0 ]
  jq -e '.node_pools | has("np-virt") | not' "${PLATFORM_FILE}"
}

@test "platform fails closed when cluster access is unavailable" {
  echo '#!/usr/bin/env bash' >"${BATS_TEST_TMPDIR}/bin/oc"
  echo 'exit 1' >>"${BATS_TEST_TMPDIR}/bin/oc"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot inspect"* ]]
  [ ! -e "${PLATFORM_FILE}" ]
}

@test "platform rejects workers from a different cluster" {
  export TEST_API_SERVER=https://wrong.example:6443
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -ne 0 ]
  [ ! -e "${PLATFORM_FILE}" ]
}

@test "platform does not count the same workers for two pools" {
  jq '.node_pools["np-second"] = .node_pools["np-virt"]' "${PLATFORM_FIXTURE}" >"${PLATFORM_FIXTURE}.new"
  mv "${PLATFORM_FIXTURE}.new" "${PLATFORM_FIXTURE}"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -ne 0 ]
  [ ! -e "${PLATFORM_FILE}" ]
}

@test "platform accepts distinct labeled pools with enough Ready workers" {
  jq '.node_pools["np-second"] = .node_pools["np-virt"] |
      .node_pools["np-second"].labels.workload = "second"' \
    "${PLATFORM_FIXTURE}" >"${PLATFORM_FIXTURE}.new"
  mv "${PLATFORM_FIXTURE}.new" "${PLATFORM_FIXTURE}"
  jq '.items += [.items[0] | .metadata.name = "worker-b" | .metadata.labels.workload = "second"]' \
    "${NODES_FILE}" >"${NODES_FILE}.new"
  mv "${NODES_FILE}.new" "${NODES_FILE}"
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -eq 0 ]
  jq -e '.node_pools | has("np-second")' "${PLATFORM_FILE}"
}
