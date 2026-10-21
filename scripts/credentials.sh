#!/usr/bin/env bash
# Kubeadmin credentials for ARO Classic (az aro list-credentials; not az aro hcp).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <request|show|login>

  request  Write kubeadmin kubeconfig to KUBECONFIG_PATH (default: .kube/config)
  show     Print API/console URLs and kubeadmin username/password
  login    oc login as kubeadmin (uses KUBECONFIG_PATH)
EOF
}

cmd_request() {
  load_tf
  cluster_exists || die "Cluster ${CLUSTER_NAME} does not exist in ${RESOURCE_GROUP}"
  [[ -n "${API_SERVER_URL}" ]] || die "api_server_url missing; run apply first"

  fetch_kubeadmin_credentials
  ensure_kubeconfig_dir

  oc login "${API_SERVER_URL}" \
    --username="${KUBEADMIN_USERNAME}" \
    --password="${KUBEADMIN_PASSWORD}" \
    --insecure-skip-tls-verify=true \
    --kubeconfig="${KUBECONFIG_PATH}"

  log "Kubeconfig written to ${KUBECONFIG_PATH}"
}

cmd_show() {
  load_tf
  cluster_exists || die "Cluster ${CLUSTER_NAME} does not exist in ${RESOURCE_GROUP}"
  [[ -n "${API_SERVER_URL}" ]] || die "api_server_url missing; run apply first"

  echo "Cluster: ${CLUSTER_NAME}"
  echo "Resource group: ${RESOURCE_GROUP}"
  echo "API URL: ${API_SERVER_URL}"
  echo "Console URL: ${CONSOLE_URL:-unknown}"
  echo ""

  fetch_kubeadmin_credentials
  echo "Username: ${KUBEADMIN_USERNAME}"
  echo "Password: ${KUBEADMIN_PASSWORD}"
  echo ""
  local profile="${CLUSTER:-$(basename "$(dirname "${TFVARS}")")}"
  echo "To login, run: make cluster.${profile}.login"
  echo "Or: oc login ${API_SERVER_URL} --username=${KUBEADMIN_USERNAME} --password=<from above> --insecure-skip-tls-verify=true"
}

cmd_login() {
  load_tf
  cluster_exists || die "Cluster ${CLUSTER_NAME} does not exist in ${RESOURCE_GROUP}"
  [[ -n "${API_SERVER_URL}" ]] || die "api_server_url missing; run apply first"

  fetch_kubeadmin_credentials
  ensure_kubeconfig_dir

  log "Logging in as kubeadmin..."
  oc login "${API_SERVER_URL}" \
    --username="${KUBEADMIN_USERNAME}" \
    --password="${KUBEADMIN_PASSWORD}" \
    --insecure-skip-tls-verify=true \
    --kubeconfig="${KUBECONFIG_PATH}"

  export_kubeconfig_env
  log "Logged in; KUBECONFIG=${KUBECONFIG_PATH}"
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    request) cmd_request ;;
    show) cmd_show ;;
    login) cmd_login ;;
    -h | --help | help) usage ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "${1:-}"
