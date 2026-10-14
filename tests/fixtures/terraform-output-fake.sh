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
echo "terraform-fake: unhandled args: $*" >&2
exit 1
