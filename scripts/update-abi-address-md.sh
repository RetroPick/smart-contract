#!/usr/bin/env bash
# Write abi/address.md from broadcast/DeployTestnet.s.sol/84532/run-latest.json
# and optional RPC (for UUPS implementation address via Basescan / cast if RPC_URL set).
#
# Usage (repo root):
#   ./scripts/update-abi-address-md.sh
#   BROADCAST_JSON=... RPC_URL=... ./scripts/update-abi-address-md.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

BROADCAST_JSON="${BROADCAST_JSON:-$ROOT/broadcast/DeployTestnet.s.sol/84532/run-latest.json}"
OUT="${OUT:-$ROOT/abi/address.md}"

if ! command -v jq &>/dev/null; then
  echo "error: jq not in PATH" >&2
  exit 1
fi
if [[ ! -f "$BROADCAST_JSON" ]]; then
  echo "error: missing $BROADCAST_JSON" >&2
  exit 1
fi
if echo "$BROADCAST_JSON" | grep -q 'dry-run'; then
  echo "error: use a real broadcast, not dry-run" >&2
  exit 1
fi

PROXY_ADDR="$(jq -r '.transactions[] | select(.contractName == "ERC1967Proxy") | .contractAddress' "$BROADCAST_JSON" | head -1)"
IMPL_HINT=""
if [[ -n "${RPC_URL:-}" && -n "$PROXY_ADDR" && "$PROXY_ADDR" != "null" && "$PROXY_ADDR" != "" ]]; then
  if command -v cast &>/dev/null; then
    IMPL_RAW="$(cast storage "$PROXY_ADDR" 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url "$RPC_URL" 2>/dev/null || true)"
    if [[ -n "$IMPL_RAW" && ${#IMPL_RAW} -ge 42 ]]; then
      # EIP-1967 implementation slot: address in last 20 bytes
      IMPL_HINT="0x${IMPL_RAW: -40}"
    fi
  fi
fi

{
  echo "# Base Sepolia deployment addresses (chain id 84532)"
  echo ""
  echo "Explorer: <https://sepolia.basescan.org/>"
  echo ""
  echo "Regenerate this file with \`./scripts/update-abi-address-md.sh\` after each deploy (uses \`$BROADCAST_JSON\`)."
  echo ""
  if [[ -n "$IMPL_HINT" ]]; then
    echo "**UUPS implementation (EIP-1967 slot, via cast):** \`$IMPL_HINT\`"
    echo ""
  else
    echo "*(Set \`RPC_URL\` when running this script to fill the UUPS implementation address from chain storage.)*"
    echo ""
  fi
  echo "| Contract | Address |"
  echo "|----------|---------|"
  jq -r '.transactions[] | select(.transactionType == "CREATE") | "| \(.contractName) | `\(.contractAddress)` |"' "$BROADCAST_JSON"
  echo ""
  echo "User-facing **MarketEngine** is the UUPS **proxy** row (\`ERC1967Proxy\`) unless you call the implementation directly (not typical)."
  echo ""
  echo "ABIs: run \`./scripts/export-abi.sh\` (or \`SKIP_BUILD=1 ./scripts/export-abi.sh\`) to refresh JSON under \`abi/\`."
} > "$OUT"

echo "Wrote $OUT"
