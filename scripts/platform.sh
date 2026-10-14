#!/usr/bin/env bash
set -euo pipefail

: "${TFVARS:?Set TFVARS}"
: "${CLUSTER_PROFILE:?Set CLUSTER_PROFILE}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
OUT="${ROOT_DIR}/clusters/${CLUSTER_PROFILE}/platform.json"
CLUSTER_DIR="$(dirname "$TFVARS")"
export TF_DATA_DIR="${CLUSTER_DIR}/.terraform"

terraform_bin="${TERRAFORM_BIN:-terraform}"
json="$("$terraform_bin" -chdir="$TF_DIR" output -json)"
oidc="$(echo "$json" | jq -r '.oidc_issuer_url.value // empty')"
if [ -z "$oidc" ]; then
  echo "oidc_issuer_url is empty; second apply required after cluster create." >&2
  exit 1
fi

machine_api="$(echo "$json" | jq -r '.machine_api_client_id.value')"
bgp="$(echo "$json" | jq -r '.bgp_client_id.value')"
rg="$(echo "$json" | jq -r '.resource_group_name.value')"
rs="$(echo "$json" | jq -r '.route_server_name.value')"

jq -n \
  --arg machine_api_client_id "$machine_api" \
  --arg bgp_client_id "$bgp" \
  --arg network_interface_client_id "$machine_api" \
  --arg resource_group_name "$rg" \
  --arg route_server_name "$rs" \
  --arg oidc_issuer_url "$oidc" \
  '{
    machine_api_client_id: $machine_api_client_id,
    bgp_client_id: $bgp_client_id,
    network_interface_client_id: $network_interface_client_id,
    resource_group_name: $resource_group_name,
    route_server_name: $route_server_name,
    oidc_issuer_url: $oidc_issuer_url
  }' >"$OUT"

echo "Wrote $OUT"
