#!/usr/bin/env bash
# Write clusters/<profile>/platform.json from terraform output -json platform.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_tf
require_cmd terraform
require_cmd jq

: "${TFVARS:?TFVARS is required}"
out_dir="$(cd "$(dirname "${TFVARS}")" && pwd)"
out_file="${out_dir}/platform.json"

json="$(tf_output_json platform)" || die "terraform output -json platform failed. Run make cluster.${CLUSTER:-<profile>}.apply first."

contract="$(printf '%s' "${json}" | jq -r '.contract_version // empty')"
[[ "${contract}" == "1" ]] || die "platform.contract_version must be 1 (got '${contract:-empty}'). Re-apply this installer."

# Labeled day-2 pools are intent in Terraform, not ARM-managed node pools.
# Verify them before handing that intent to the virt sibling.
pools="$(printf '%s' "${json}" | jq -c '.node_pools | to_entries[] | select((.value.labels // {} | length) > 0)')"
if [[ -n "${pools}" ]]; then
  require_cmd oc
  export_kubeconfig_env
  expected_server="$(printf '%s' "${json}" | jq -r '.api_url // empty')"
  actual_server="$(oc whoami --show-server)" || die "Cannot inspect the cluster API. Run the installer login target first."
  [[ -n "${expected_server}" && "${actual_server%/}" == "${expected_server%/}" ]] || die "Kubeconfig API does not match platform.api_url. Log in to this installer profile before publishing platform.json."
  nodes="$(oc get nodes -o json)" || die "Cannot inspect workers. Run make cluster.${CLUSTER:-${CLUSTER_PROFILE:-<profile>}}.login first."
  used_nodes='[]'
  while IFS= read -r pool; do
    name="$(printf '%s' "${pool}" | jq -r '.key')"
    matching_nodes="$(printf '%s' "${nodes}" | jq -c --argjson pool "${pool}" '
      [.items[] |
        select(.metadata.labels as $labels |
          all($pool.value.labels | to_entries[]; $labels[.key] == .value)) |
        select(.metadata.labels["node.kubernetes.io/instance-type"] == $pool.value.vm_size) |
        select(any(.status.conditions[]?; .type == "Ready" and .status == "True")) |
        .metadata.name
      ]
    ')"
    if ! printf '%s' "${matching_nodes}" | jq -e --argjson pool "${pool}" '
      ($pool.value.replicas >= 1) and
      ($pool.value.replicas == ($pool.value.replicas | floor)) and
      (length >= $pool.value.replicas)
    ' >/dev/null; then
      die "Pool ${name} needs its requested replicas, node labels, and VM size on Ready nodes. Reconcile the installer MachineSets before publishing platform.json."
    fi
    if printf '%s' "${matching_nodes}" | jq -e --argjson used "${used_nodes}" 'any(.[]; . as $node | $used | index($node) != null)' >/dev/null; then
      die "Pool ${name} matches workers already counted in another pool. Use distinct node labels for each day-2 pool."
    fi
    used_nodes="$(printf '%s' "${matching_nodes}" | jq -c --argjson used "${used_nodes}" '. + $used')"
  done <<<"${pools}"
fi

printf '%s\n' "${json}" | jq . >"${out_file}"
log "Wrote ${out_file}"
