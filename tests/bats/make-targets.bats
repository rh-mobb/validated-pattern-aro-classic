#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "cluster profile must exist" {
  run make -C "$REPO_ROOT" cluster.missing.plan
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "help lists classic profile example" {
  run make -C "$REPO_ROOT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"cluster.aro-classic-miwi.plan"* ]]
}
