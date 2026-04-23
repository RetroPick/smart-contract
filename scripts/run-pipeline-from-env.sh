#!/usr/bin/env bash
# Run full Base Sepolia pipeline using repo root .env (same as manual steps).
# Usage: ./scripts/run-pipeline-from-env.sh
# Optional: export ETH_PASSWORD before run for non-interactive keystore.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.foundry/bin:${PATH}"
if [[ -d "$ROOT/.tools/node/bin" ]]; then
  export PATH="$ROOT/.tools/node/bin:${PATH}"
fi
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not in PATH; install Node.js so OpenZeppelin upgrades validation can run" >&2
  exit 1
fi

export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-upgrades}"
forge build
./scripts/deploy-testnet.sh --broadcast --verify
# RPC for implementation slot in address.md
RPC_URL="${RPC_URL:-}" ./scripts/update-abi-address-md.sh
./scripts/export-abi.sh
./scripts/verify-base-sepolia-contracts.sh
echo "Pipeline finished. See abi/address.md (and abi/*.json)"
