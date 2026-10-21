#!/usr/bin/env bash
# Alias for credentials request (parity with validated-pattern-aro-hcp cluster.<name>.kubeconfig).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/credentials.sh" request
