#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# Run the real Make recipes with isolated tools, without providers or cluster access.
stub_tools() {
  export TOOL_LOG="${BATS_TEST_TMPDIR}/tools.log"
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  local tool
  for tool in terraform tflint shellcheck shfmt oc bats helm; do
    cat >"${BATS_TEST_TMPDIR}/bin/${tool}" <<'SH'
#!/bin/bash
tool="${0##*/}"
printf '%s %s\n' "$tool" "$*" >>"${TOOL_LOG}"
if [[ "$tool $*" == "${FAIL_COMMAND:-}" || "$tool" == "${FAIL_COMMAND:-}" ]]; then
  echo "injected failure: $tool $*" >&2
  exit 42
fi
if [[ "$tool $*" == "helm version --short" ]]; then echo "${TEST_HELM_VERSION:-v4.2.0}"; fi
SH
    chmod +x "${BATS_TEST_TMPDIR}/bin/${tool}"
  done
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "test stops at any failing Terraform suite" {
  stub_tools
  local suite
  for suite in modules/network modules/identities modules/cluster modules/platform-secrets terraform; do
    : >"${TOOL_LOG}"
    export FAIL_COMMAND="terraform -chdir=${REPO_ROOT}/${suite} test"
    run make -C "${REPO_ROOT}" -o lint test
    [ "$status" -ne 0 ]
    [[ "$output" == *"injected failure:"* ]]
    # No subsequent Terraform suite, Kustomize, or Bats should run.
    [ "$(tail -n 1 "${TOOL_LOG}")" = "${FAIL_COMMAND}" ]
  done
}

@test "lint propagates failures from installed optional tools" {
  stub_tools
  local command
  for command in \
    'tflint --init' \
    'tflint ' \
    'shellcheck' \
    "shfmt -d -i 2 -ci -bn ${REPO_ROOT}/scripts"; do
    export FAIL_COMMAND="$command"
    run make -C "${REPO_ROOT}" lint
    [ "$status" -ne 0 ]
    [[ "$output" == *"injected failure:"* ]]
    [[ "$output" != *"not installed; skipping"* ]]
  done
}

@test "fmt propagates an installed formatter failure" {
  stub_tools
  export FAIL_COMMAND="shfmt -w -i 2 -ci -bn ${REPO_ROOT}/scripts"
  run make -C "${REPO_ROOT}" fmt
  [ "$status" -ne 0 ]
  [[ "$output" == *"injected failure:"* ]]
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
  [[ "$output" == *"show-credentials"* ]]
  [[ "$output" == *"login"* ]]
  [[ "$output" == *"bootstrap"* ]]
  [[ "$output" == *"machinesets"* ]]
}

@test "bootstrap orders login and MachineSets before workloads" {
  run make -n -C "$REPO_ROOT" cluster.aro-classic-miwi.bootstrap
  [ "$status" -eq 0 ]
  local login_line machinesets_line bootstrap_line
  login_line="$(printf '%s\n' "$output" | rg -n 'credentials.sh login' | cut -d: -f1)"
  machinesets_line="$(printf '%s\n' "$output" | rg -n 'machinesets.sh apply' | cut -d: -f1)"
  bootstrap_line="$(printf '%s\n' "$output" | rg -n 'gitops-bootstrap.sh bootstrap' | cut -d: -f1)"
  [ "$login_line" -lt "$machinesets_line" ]
  [ "$machinesets_line" -lt "$bootstrap_line" ]
}

@test "lint-helm runs strict offline lint with fixture values" {
  stub_tools
  run make -C "$REPO_ROOT" lint-helm
  [ "$status" -eq 0 ]
  rg -F "helm lint --strict $REPO_ROOT/helm/machinesets --values $REPO_ROOT/tests/fixtures/machinesets-values.yaml" "$TOOL_LOG"
}

@test "lint-helm rejects Helm 2 and 3" {
  stub_tools
  local version
  for version in v2.17.0 v3.19.0; do
    export TEST_HELM_VERSION="$version"
    run make -C "$REPO_ROOT" lint-helm
    [ "$status" -ne 0 ]
    [[ "$output" == *"Helm 4"* ]]
  done
  ! rg 'helm lint ' "$TOOL_LOG"
}

@test "lint propagates strict Helm lint failures" {
  stub_tools
  export FAIL_COMMAND="helm lint --strict $REPO_ROOT/helm/machinesets --values $REPO_ROOT/tests/fixtures/machinesets-values.yaml"
  run make -C "$REPO_ROOT" lint
  [ "$status" -ne 0 ]
  [[ "$output" == *"injected failure:"* ]]
}
