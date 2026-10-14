#!/usr/bin/env bats

setup() {
  export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "rendered BGP config uses machine-api client id" {
  export AZURE_SUBSCRIPTION_ID=sub
  export AZURE_RESOURCE_GROUP=aro-classic-miwi-rg
  export AZURE_ROUTE_SERVER_NAME=aro-classic-miwi-routeserver
  export MACHINE_API_CLIENT_ID=machine-api-client
  run "$REPO_ROOT/scripts/render-bgp.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"networkInterfaceClientID: machine-api-client"* ]]
  [[ "$output" == *"localASN: 65001"* ]]
  [[ "$output" != *"10.0.12.4"* ]]
}
