#!/usr/bin/env bash
if [ "$1" = "output" ] && [ "$2" = "-json" ]; then
  cat <<'JSON'
{
  "oidc_issuer_url": {"value": "https://issuer.example"},
  "machine_api_client_id": {"value": "machine-api-client"},
  "bgp_client_id": {"value": "bgp-client"},
  "resource_group_name": {"value": "aro-classic-miwi-rg"},
  "route_server_name": {"value": "aro-classic-miwi-routeserver"}
}
JSON
  exit 0
fi
exit 1
