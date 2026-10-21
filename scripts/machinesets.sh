#!/usr/bin/env bash
# ARO-specific discovery and checks around a local Helm 4 release.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

mode="${1:-apply}"
[[ "$mode" == apply || "$mode" == render ]] || die "Usage: machinesets.sh [render|apply]"
for cmd in helm oc jq; do require_cmd "$cmd"; done
[[ "$(helm version --short)" == v4.* ]] || die "Helm 4 is required; Helm 2/3 are unsupported."
timeout="${MACHINESETS_WAIT_SECONDS:-1800}"
[[ "$timeout" =~ ^[0-9]+$ ]] || die "MACHINESETS_WAIT_SECONDS must be an integer."
load_tf
export_kubeconfig_env
platform="$(tf_output_json platform)" || die "Read Terraform platform output failed; run the profile apply target."
expected="$(jq -r '.api_url // empty' <<<"$platform")"
actual="$(oc whoami --show-server)"
[[ -n "$expected" && "${actual%/}" == "${expected%/}" ]] || die "Kubeconfig does not match this profile's cluster API."
[[ "$(jq -r '.cluster_name' <<<"$platform")" == "$CLUSTER_NAME" ]] || die "Terraform cluster identity does not match this profile."

out_dir="$(cd "$(dirname "$TFVARS")" && pwd)/machinesets"
mkdir -p "$out_dir"
# Restore the exact Terraform-authored YAML without introducing local_file drift.
desired="$(tf_output_json machinesets_values)" || die "Missing MachineSet values; run the profile apply target."
jq -e '.initialWorkerPool as $initial | .nodePools |
  has($initial) and length > 0 and
  all(.[]; .replicas >= 0 and .replicas == (.replicas | floor) and
      (.vm_size | type) == "string" and (.vm_size | length) > 0 and .disk_size_gb > 0) and
  ([.[].replicas] | add) > 0' <<<"$desired" >/dev/null || die "Invalid or empty desired worker configuration."
tf_output_json machinesets_values_yaml | jq -jr '.' >"$out_dir/values.yaml"

# Helm is the authoritative inventory. Permission/connectivity failures are fatal.
# Helm 4 lists every status by default (the Helm 3 --all flag was removed).
releases="$(helm list -n openshift-machine-api --filter '^machinesets$' -o json)" || die "Cannot inspect Helm releases."
previous='{}'
first_install=true
if [[ "$(jq 'length' <<<"$releases")" -gt 0 ]]; then
  jq -e 'length == 1 and .[0].status == "deployed"' <<<"$releases" >/dev/null \
    || die "Helm release recovery required: inspect helm status/history machinesets in openshift-machine-api before retrying a failed or pending operation."
  previous="$(helm get values machinesets -n openshift-machine-api -o json)" || die "Cannot read the existing Helm release."
  first_install=false
fi
live="$(oc get machinesets -n openshift-machine-api -o json)"
infra="$(oc get infrastructure cluster -o json | jq -er '.status.infrastructureName')"
initial="$(jq -r '.initialWorkerPool' <<<"$desired")"
# Persist the original provider templates in Helm values, so template edits do not
# turn into discovery input on later upgrades. Local files are disposable.
if [[ "$first_install" == false ]]; then
  discovery="$(jq -e --arg infra "$infra" '. | select(.infraId == $infra and (.defaults | length) > 0)' <<<"$previous")" || die "Existing release has no matching discovery baseline."
else
  discovery="$(jq --arg infra "$infra" --arg initial "$initial" '{infraId: $infra, initialWorkerPool: $initial, defaults:
    [.items[] | select(.metadata.labels["machine.openshift.io/cluster-api-cluster"] == $infra) |
      select(.metadata.name == ($infra + "-worker") or (.metadata.name | startswith($infra + "-worker-")))]}' <<<"$live")"
fi
resolved="$(jq --slurpfile discovery <(printf '%s' "$discovery") -f "$SCRIPT_DIR/machinesets.jq" <<<"$desired")" || die "Cannot resolve MachineSet templates."
jq -e '[.machineSets[].metadata.name] | length == (unique | length)' <<<"$resolved" >/dev/null || die "MachineSet names collide."
# Take ownership only of discovered defaults. Refuse arbitrary existing resources.
jq -e --argjson live "$live" --argjson previous "$previous" --argjson first "$first_install" '
  [.machineSets[].metadata.name] as $wanted |
  [.defaults[].metadata.name] as $defaults |
  [($previous.machineSets // [])[].metadata.name] as $owned |
  all($live.items[] | select(.metadata.name as $name | $wanted | index($name));
    . as $set |
    ((.metadata.annotations["meta.helm.sh/release-name"] // "machinesets") == "machinesets") and
    ((.metadata.annotations["meta.helm.sh/release-namespace"] // "openshift-machine-api") == "openshift-machine-api") and
    (.metadata.name as $name | (if $first then $defaults else $owned end) | index($name) != null))
' <<<"$resolved" >/dev/null || die "A desired MachineSet is unmanaged or owned by another release."
printf '%s\n' "$resolved" >"$out_dir/discovered.yaml"
chart="$ROOT_DIR/helm/machinesets"
helm lint "$chart" -f "$out_dir/discovered.yaml" -f "$out_dir/values.yaml" >/dev/null
helm template machinesets "$chart" -n openshift-machine-api -f "$out_dir/discovered.yaml" -f "$out_dir/values.yaml" >"$out_dir/rendered.yaml"

# Compare live replicas as well as the last release, covering out-of-band scaling.
changes="$(jq -n --argjson want "$resolved" --argjson live "$live" --argjson old "$previous" '
  ($want.machineSets | map({key: .metadata.name, value: .}) | from_entries) as $wanted |
  (($old.machineSets // []) + $live.items | group_by(.metadata.name) | map(max_by(.spec.replicas))) |
  [.[] | . as $before | $wanted[.metadata.name] as $after |
    if $after == null then
      if any(($old.machineSets // [])[]; .metadata.name == $before.metadata.name)
      then {name: .metadata.name, action: "DELETE", from: .spec.replicas, to: 0} else empty end
    elif $after.spec.replicas < .spec.replicas then
      {name: .metadata.name, action: "SCALE DOWN", from: .spec.replicas, to: $after.spec.replicas}
    else empty end]
')"
jq -r '.[] | "\(.action) \(.name): \(.from) -> \(.to) replicas"' <<<"$changes"
# Template changes update future Machines; they do not perform a worker rollout.
jq -n -r --argjson want "$resolved" --argjson live "$live" '
  $want.machineSets[] as $w | $live.items[] | select(.metadata.name == $w.metadata.name) |
  select(.spec.template.spec != $w.spec.template.spec) |
  "WARNING: \(.metadata.name) template changed. Existing Machines/Nodes may retain old settings; this command does not roll workers."
'
[[ "$mode" == apply ]] || {
  log "Rendered $out_dir/rendered.yaml"
  exit 0
}

ready() {
  local current machines nodes
  current="$(oc get machinesets -n openshift-machine-api -o json)" || return 1
  machines="$(oc get machines -n openshift-machine-api -o json)" || return 1
  nodes="$(oc get nodes -o json)" || return 1
  jq -e --slurpfile live <(printf '%s' "$current") \
    --slurpfile machines <(printf '%s' "$machines") \
    --slurpfile nodes <(printf '%s' "$nodes") \
    -f "$SCRIPT_DIR/machinesets-ready.jq" <<<"$resolved" >/dev/null
}
if [[ "$(jq 'length' <<<"$changes")" -gt 0 ]]; then
  [[ "${MACHINESETS_CONFIRM:-}" == "$CLUSTER_NAME" ]] || die "Destructive changes require MACHINESETS_CONFIRM=$CLUSTER_NAME. Review render output first."
  ready || die "Desired replacement workers must already be Ready before deletion or scale-down. Add capacity in a separate run first."
fi
args=()
if [[ "$first_install" == true ]]; then args+=(--take-ownership); fi
# Client-side patches preserve compatibility with ARO-created field managers.
# Do not force replacement/conflicts or automatically roll back infrastructure deletions.
helm upgrade --install machinesets "$chart" -n openshift-machine-api \
  --reset-values --server-side=false "${args[@]}" \
  -f "$out_dir/discovered.yaml" -f "$out_dir/values.yaml"
deadline=$((SECONDS + timeout))
until ready; do
  ((SECONDS < deadline)) || die "Timed out waiting for requested MachineSet-owned workers to be Ready with the desired VM size and labels. Template updates do not roll existing workers."
  sleep 10
done
log "MachineSets reconciled; requested workers are Ready."
