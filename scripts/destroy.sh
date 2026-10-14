#!/usr/bin/env bash
set -euo pipefail

: "${TFVARS:?Set TFVARS}"
: "${CLUSTER_PROFILE:?Set CLUSTER_PROFILE}"

if [ "${DESTROY_CONFIRM:-}" != "yes" ]; then
  echo "Refusing destroy: set DESTROY_CONFIRM=yes" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
CLUSTER_DIR="$(dirname "$TFVARS")"
export TF_DATA_DIR="${CLUSTER_DIR}/.terraform"

terraform -chdir="$TF_DIR" init -reconfigure -input=false \
  -backend-config="path=${CLUSTER_DIR}/infrastructure.tfstate"

terraform -chdir="$TF_DIR" destroy -target=module.cluster.azapi_resource.aro_cluster \
  -var-file="$TFVARS" -auto-approve

terraform -chdir="$TF_DIR" destroy -var-file="$TFVARS" -auto-approve
