#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID}"
: "${AZURE_RESOURCE_GROUP:?Set AZURE_RESOURCE_GROUP}"
: "${AZURE_ROUTE_SERVER_NAME:?Set AZURE_ROUTE_SERVER_NAME}"
: "${MACHINE_API_CLIENT_ID:?Set MACHINE_API_CLIENT_ID}"

export BGP_ROUTING_NAME="${BGP_ROUTING_NAME:-virt}"
export CUDN_NAMESPACE="${CUDN_NAMESPACE:-virt}"
export CUDN_NETWORK_NAME="${CUDN_NETWORK_NAME:-virt}"
export CUDN_SUBNET="${CUDN_SUBNET:-10.100.0.0/16}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

envsubst <"${ROOT_DIR}/manifests/bgp-cloud-configuration.yaml"
echo "---"
envsubst <"${ROOT_DIR}/manifests/bgp-routing.yaml"
