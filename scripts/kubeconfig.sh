#!/usr/bin/env bash
# Admin kubeconfig for ARO Classic (not az aro hcp).
set -euo pipefail

: "${TFVARS:?Set TFVARS to clusters/<profile>/terraform.tfvars}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
CLUSTER_DIR="$(dirname "$TFVARS")"
export TF_DATA_DIR="${CLUSTER_DIR}/.terraform"

cluster_name="$(grep -E '^[[:space:]]*cluster_name[[:space:]]*=' "$TFVARS" | head -1 | sed -E 's/.*=[[:space:]]*"([^"]+)".*/\1/')"
resource_group="$(terraform -chdir="$TF_DIR" output -raw resource_group_name 2>/dev/null || true)"
if [ -z "$resource_group" ]; then
  resource_group="${cluster_name}-rg"
fi

mkdir -p "${ROOT_DIR}/.kube"
out="${ROOT_DIR}/.kube/config"

az aro list-admin-credentials \
  --name "$cluster_name" \
  --resource-group "$resource_group" \
  --file "$out"

echo "Wrote admin kubeconfig to $out"
