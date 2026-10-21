#!/usr/bin/env bash
set -euo pipefail

missing=0
for cmd in az terraform oc jq helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    missing=1
  fi
done

if command -v helm >/dev/null 2>&1 && [[ "$(helm version --short)" != v4.* ]]; then
  echo "Helm 4 is required; Helm 2/3 are unsupported." >&2
  missing=1
fi

if ! az aro -h >/dev/null 2>&1; then
  echo "Azure CLI 'az aro' extension is required for Classic clusters." >&2
  missing=1
fi

if command -v az >/dev/null 2>&1 && az aro hcp -h >/dev/null 2>&1; then
  echo "Note: this repo uses Classic 'az aro', not 'az aro hcp'." >&2
fi

if [ "$missing" -ne 0 ]; then
  exit 1
fi

echo "Tooling OK for ARO Classic MIWI."
