#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export CLUSTER=aro-classic-virt
  export TFVARS="${BATS_TEST_TMPDIR}/terraform.tfvars"
  export TERRAFORM_BIN="${BATS_TEST_TMPDIR}/terraform"
  export KUBECONFIG_PATH="${BATS_TEST_TMPDIR}/kubeconfig"
  export CALLS="${BATS_TEST_TMPDIR}/calls"
  touch "$TFVARS" "$KUBECONFIG_PATH"
  cat >"$TERRAFORM_BIN" <<'SH'
#!/bin/bash
# Offline metadata only; no credentials or Terraform/provider access.
echo fixture
SH
  chmod +x "$TERRAFORM_BIN"
}

@test "local-only bootstrap dry run retains baseline and metadata but omits root Application" {
  export GITOPS_DRY_RUN=1 GITOPS_LOCAL_ONLY=1
  run bash "$REPO_ROOT/scripts/gitops-bootstrap.sh" bootstrap
  [ "$status" -eq 0 ]
  [[ "$output" == *"kind: Subscription"* ]]
  [[ "$output" == *"name: aro-platform-metadata"* ]]
  [[ "$output" != *"kind: Application"* ]]
}

@test "normal bootstrap dry run retains the published-source Application" {
  export GITOPS_DRY_RUN=1 GITOPS_LOCAL_ONLY=0
  run bash "$REPO_ROOT/scripts/gitops-bootstrap.sh" bootstrap
  [ "$status" -eq 0 ]
  [[ "$output" == *"kind: Application"* ]]
  [[ "$output" == *"path: gitops/overlays/aro-classic-virt"* ]]
}

@test "local-only live path applies baseline without submitting an Application" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat >"$BATS_TEST_TMPDIR/bin/oc" <<'SH'
#!/bin/bash
printf 'oc %s\n' "$*" >>"$CALLS"
case "$*" in
  'apply -f -') cat >>"$CALLS" ;;
  *'get subscription '*'-o jsonpath='*) echo fixture-csv ;;
  *'get csv '*'-o jsonpath='*) echo Succeeded ;;
esac
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/oc"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  export GITOPS_LOCAL_ONLY=1 GITOPS_WAIT_SECONDS=2
  unset GITOPS_DRY_RUN
  run bash "$REPO_ROOT/scripts/gitops-bootstrap.sh" bootstrap
  [ "$status" -eq 0 ]
  [[ "$output" == *"deferred"* ]]
  rg 'apply -k .*gitops/overlays/aro-classic-virt' "$CALLS"
  ! rg 'kind: Application' "$CALLS"
}
