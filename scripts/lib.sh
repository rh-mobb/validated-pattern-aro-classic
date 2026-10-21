#!/usr/bin/env bash
# Shared helpers for ARO Classic deployment scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
CLUSTER="${CLUSTER:-}"
TFVARS="${TFVARS:-}"

if [[ -z "${TFVARS}" && -n "${CLUSTER}" ]]; then
  TFVARS="${ROOT_DIR}/clusters/${CLUSTER}/terraform.tfvars"
fi

if [[ -z "${TFVARS}" ]]; then
  TFVARS="${ROOT_DIR}/clusters/aro-classic-miwi/terraform.tfvars"
fi

if [[ -n "${CLUSTER:-}" ]]; then
  export TF_DATA_DIR="${ROOT_DIR}/clusters/${CLUSTER}/.terraform"
elif [[ -f "${TFVARS}" ]]; then
  TF_DATA_DIR="${ROOT_DIR}/clusters/$(basename "$(dirname "${TFVARS}")")/.terraform"
  export TF_DATA_DIR
fi

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
  log "ERROR: $*"
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || die "Required command not found: ${cmd}"
}

tfvars_get() {
  local key="$1"
  [[ -f "${TFVARS}" ]] || return 1
  awk -v k="${key}" '
    $1 == k && $2 == "=" {
      val = $3
      for (i = 4; i <= NF; i++) val = val " " $i
      gsub(/^[ \t"]+|[ \t",]+$/, "", val)
      print val
      exit
    }
  ' "${TFVARS}"
}

resolve_tf() {
  local name="$1"
  local val=""
  local terraform_bin="${TERRAFORM_BIN:-terraform}"
  val="$("${terraform_bin}" -chdir="${TF_DIR}" output -raw "${name}" 2>/dev/null || true)"
  if [[ -n "${val}" && "${val}" != "null" ]]; then
    printf '%s\n' "${val}"
    return 0
  fi
  tfvars_get "${name}"
}

tf_output_json() {
  local name="${1:-}"
  local terraform_bin="${TERRAFORM_BIN:-terraform}"
  if [[ -n "${name}" ]]; then
    "${terraform_bin}" -chdir="${TF_DIR}" output -json "${name}"
  else
    "${terraform_bin}" -chdir="${TF_DIR}" output -json
  fi
}

load_tf() {
  if [[ -n "${CLUSTER:-}" && "${CLUSTER_NAME:-}" == "${CLUSTER}" ]]; then
    unset CLUSTER_NAME
  fi

  CLUSTER_NAME="${CLUSTER_NAME:-$(resolve_tf cluster_name || true)}"
  RESOURCE_GROUP="${RESOURCE_GROUP:-$(resolve_tf resource_group_name || true)}"
  LOCATION="${LOCATION:-$(resolve_tf location || tfvars_get location || true)}"
  API_SERVER_URL="${API_SERVER_URL:-$(resolve_tf api_server_url || true)}"
  CONSOLE_URL="${CONSOLE_URL:-$(resolve_tf console_url || true)}"
  API_VISIBILITY="${API_VISIBILITY:-$(resolve_tf api_visibility || tfvars_get api_visibility || true)}"
  TENANT_ID="${TENANT_ID:-$(resolve_tf tenant_id || true)}"
  KEY_VAULT_NAME="${KEY_VAULT_NAME:-$(resolve_tf key_vault_name || true)}"
  KEY_VAULT_URI="${KEY_VAULT_URI:-$(resolve_tf key_vault_uri || true)}"
  ESO_CLIENT_ID="${ESO_CLIENT_ID:-$(resolve_tf eso_client_id || true)}"
  PULL_SECRET_KV_NAME="${PULL_SECRET_KV_NAME:-$(resolve_tf pull_secret_key_vault_secret_name || true)}"

  : "${CLUSTER_NAME:?cluster_name required (terraform output or clusters/<name>/terraform.tfvars)}"
  : "${RESOURCE_GROUP:=${CLUSTER_NAME}-rg}"
  : "${KUBECONFIG_PATH:=${ROOT_DIR}/.kube/config}"
  : "${API_VISIBILITY:=Public}"
  : "${PULL_SECRET_KV_NAME:=redhat-pull-secret}"
}

export_tf_var_pull_secret_path() {
  local p="${PULL_SECRET_PATH:-}"
  if [[ -z "${p}" ]]; then
    p="$(tfvars_get pull_secret_path || true)"
  fi
  [[ -n "${p}" ]] || return 0
  p="${p/#\~/${HOME}}"
  [[ -f "${p}" ]] || die "Missing pull secret file ${p} (pull_secret_path / PULL_SECRET_PATH)"
  TF_VAR_pull_secret_path="$(cd "$(dirname "${p}")" && pwd)/$(basename "${p}")"
  export TF_VAR_pull_secret_path
}

# Classic clusters expose in-cluster OAuth; Argo CD uses openShiftOAuth (not HCP Entra oidcConfig).
configure_gitops_oidc() {
  log "Classic: skipping Entra Argo CD oidcConfig (use OpenShift OAuth / kubeadmin on the GitOps route)"
}

ensure_kubeconfig_dir() {
  mkdir -p "$(dirname "${KUBECONFIG_PATH}")"
}

cluster_exists() {
  az aro show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    >/dev/null 2>&1
}

# Sets KUBEADMIN_USERNAME and KUBEADMIN_PASSWORD (caller must load_tf first).
fetch_kubeadmin_credentials() {
  local creds_json
  creds_json="$(az aro list-credentials \
    --name "${CLUSTER_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --output json)" || die "Could not get cluster credentials (az aro list-credentials)"

  if command -v jq >/dev/null 2>&1; then
    KUBEADMIN_USERNAME="$(echo "${creds_json}" | jq -r '.kubeadminUsername')"
    KUBEADMIN_PASSWORD="$(echo "${creds_json}" | jq -r '.kubeadminPassword')"
  else
    KUBEADMIN_USERNAME="$(echo "${creds_json}" | grep -o '"kubeadminUsername": "[^"]*"' | cut -d'"' -f4)"
    KUBEADMIN_PASSWORD="$(echo "${creds_json}" | grep -o '"kubeadminPassword": "[^"]*"' | cut -d'"' -f4)"
  fi

  if [[ -z "${KUBEADMIN_USERNAME}" || -z "${KUBEADMIN_PASSWORD}" ]]; then
    die "Could not parse kubeadmin credentials from az aro list-credentials"
  fi
}

export_kubeconfig_env() {
  export KUBECONFIG="${KUBECONFIG_PATH}"
}
