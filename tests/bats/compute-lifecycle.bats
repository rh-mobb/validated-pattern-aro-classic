#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # Match the Make test environment and avoid a caller's live backend selection.
  unset TF_DATA_DIR TF_WORKSPACE TF_CLI_ARGS TF_CLI_ARGS_test
}

@test "root ARM plan uses day-0 sizing even when day-2 intent exists" {
  local plan="${BATS_TEST_TMPDIR}/root-plan.jsonl"
  run bash -c 'terraform -chdir="$1/terraform" test -filter=root.tftest.hcl -json -verbose >"$2"' _ "${REPO_ROOT}" "${plan}"
  if [ "$status" -ne 0 ]; then cat "${plan}"; return 1; fi

  jq -s -e '
    [.[] | select(.type == "test_plan" and .["@testrun"] == "day2_intent_with_distinct_day0_sizing") |
      .test_plan.resource_changes[] |
      select(.address == "module.cluster.azapi_resource.aro_cluster") |
      .change.after.body.properties.workerProfiles] |
    length == 1 and (.[0] | length == 1 and
      .[0].name == "worker" and .[0].count == 4 and
      .[0].vmSize == "Standard_D8s_v5" and .[0].diskSizeGB == 256 and
      (.[0] | has("labels") | not))
  ' "${plan}"
}

@test "post-install worker edits plan no cluster update or replacement" {
  local plan="${BATS_TEST_TMPDIR}/cluster-plan.jsonl"
  run bash -c 'terraform -chdir="$1/modules/cluster" test -filter=cluster.tftest.hcl -json -verbose >"$2"' _ "${REPO_ROOT}" "${plan}"
  if [ "$status" -ne 0 ]; then cat "${plan}"; return 1; fi

  jq -s -e '
    [.[] | select(.type == "test_plan" and .["@testrun"] == "post_install_worker_edits_are_ignored") |
      .test_plan.resource_changes[] |
      select(.address == "azapi_resource.aro_cluster") | .change.actions] == [["no-op"]]
  ' "${plan}"
}

@test "committed virt example plans only default workers in ARM and exports extra pool taints" {
  local plan="${BATS_TEST_TMPDIR}/virt-example-plan.jsonl"
  run bash -c 'terraform -chdir="$1/terraform" test -test-directory=profile-tests -filter=profile-tests/virt-example.tftest.hcl -var-file=../clusters/aro-classic-virt/terraform.tfvars -json -verbose >"$2"' _ "${REPO_ROOT}" "${plan}"
  if [ "$status" -ne 0 ]; then cat "${plan}"; return 1; fi
  jq -s -e '
    [.[] | select(.type == "test_plan") | .test_plan.resource_changes[] |
      select(.address == "module.cluster.azapi_resource.aro_cluster") |
      .change.after.body.properties.workerProfiles] |
    length == 1 and (.[0] | length == 1 and .[0].name == "worker" and
      .[0].count == 3 and .[0].vmSize == "Standard_D4s_v5")
  ' "${plan}"
}
