#!/usr/bin/env bash
case "$1" in
  -chdir)
    shift 2
    ;;
  -chdir=*)
    shift 1
    ;;
esac
if [ "$1" = "output" ] && [ "$2" = "-json" ]; then
  if [ "${3:-}" = "platform" ]; then
    if [[ -n "${PLATFORM_FIXTURE:-}" ]]; then
      cat "${PLATFORM_FIXTURE}"
      exit 0
    fi
    cat <<'JSON'
{
  "contract_version": 1,
  "installer": "classic",
  "api_url": "https://api.example:6443",
  "machine_api_client_id": "machine-api-client",
  "network": {
    "reserved": {
      "netapp_subnet_prefix": "10.0.3.0/24",
      "route_server_subnet_prefix": "10.0.4.0/26"
    }
  },
  "node_pools": {
    "worker": { "labels": {} },
    "np-virt": { "vm_size": "Standard_D8s_v6", "replicas": 1, "labels": { "bgp_router": "true", "workload": "virtualization" } }
  }
}
JSON
    exit 0
  fi
  cat <<'JSON'
{
  "oidc_issuer_url": {"value": "https://issuer.example"},
  "machine_api_client_id": {"value": "machine-api-client"}
}
JSON
  exit 0
fi
echo "terraform-fake: unhandled args: $*" >&2
exit 1
