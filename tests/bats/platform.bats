#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export CLUSTER_PROFILE=aro-classic-miwi
  export TFVARS="${REPO_ROOT}/clusters/aro-classic-miwi/terraform.tfvars"
  export TERRAFORM_BIN="${REPO_ROOT}/tests/fixtures/terraform-output-fake.sh"
  mkdir -p "${REPO_ROOT}/clusters/aro-classic-miwi"
  rm -f "${REPO_ROOT}/clusters/aro-classic-miwi/platform.json"
}

@test "platform.json uses machine-api for network_interface_client_id" {
  run bash "${REPO_ROOT}/scripts/platform.sh"
  [ "$status" -eq 0 ]

  jq -e '.network_interface_client_id == .machine_api_client_id' \
    "${REPO_ROOT}/clusters/aro-classic-miwi/platform.json"
  jq -e '.network_interface_client_id != .bgp_client_id' \
    "${REPO_ROOT}/clusters/aro-classic-miwi/platform.json"
}
