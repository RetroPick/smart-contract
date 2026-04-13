#!/usr/bin/env bash
# Deploy RetroPick MarketEngine (ChainlinkAdapter + UUPS MarketEngineDispatcher + modules) on mainnet.
#
# Uses: script/production/DeployProduction.s.sol (requires STAKE_TOKEN; no faucet path).
#
# Prerequisites:
#   - forge, cast (Foundry)
#   - `forge test` green; storage/layout checks for upgrades as per your checklist
#
# Environment (required):
#   RPC_URL                 HTTPS RPC for the chain
#   DEPLOY_ACCOUNT          Foundry keystore account name
#   STAKE_TOKEN
#   SEQUENCER_FEED          0x000... on L1; Chainlink sequencer uptime feed on L2
#   ADMIN, TREASURY, WORKER
#   DEFAULT_SETTLEMENT_FEE_BPS, MAX_SWITCH_FEE_BPS, MAX_OUTCOMES
#   ORACLE_MAX_DELAY_SECONDS, ORACLE_MAX_CONFIDENCE_BPS
#
# Optional: GAS_LIMIT, ETHERSCAN_API_KEY (for --verify)
#
# Usage:
#   ./deploy-mainnet.sh # dry-run only (default)
#   ALLOW_MAINNET_BROADCAST=yes ./deploy-mainnet.sh --broadcast
#   ALLOW_MAINNET_BROADCAST=yes ./deploy-mainnet.sh --broadcast --verify
#
# Mainnet broadcasts are blocked unless ALLOW_MAINNET_BROADCAST=yes to reduce accidents.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/foundry.toml" ]]; then
  ROOT="$SCRIPT_DIR"
else
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

RPC_URL="${RPC_URL:-${FOUNDRY_ETH_RPC_URL:-}}"
ACCOUNT="${DEPLOY_ACCOUNT:-}"
GAS_LIMIT="${GAS_LIMIT:-50000000}"
SCRIPT_PATH="script/production/DeployProduction.s.sol:DeployProduction"

BROADCAST=0
VERIFY=()
for arg in "$@"; do
  case "$arg" in
    --broadcast) BROADCAST=1 ;;
    --verify) VERIFY=(--verify --etherscan-api-key "${ETHERSCAN_API_KEY:?Set ETHERSCAN_API_KEY for --verify}") ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

if [[ -z "$RPC_URL" ]]; then
  echo "error: set RPC_URL (or FOUNDRY_ETH_RPC_URL) in the environment or .env" >&2
  exit 1
fi

if [[ "$BROADCAST" -eq 1 ]]; then
  if [[ "${ALLOW_MAINNET_BROADCAST:-}" != "yes" ]]; then
    echo "error: mainnet broadcast refused. Set ALLOW_MAINNET_BROADCAST=yes after double-checking RPC, params, and keystore." >&2
    exit 1
  fi
  if [[ -z "$ACCOUNT" ]]; then
    echo "error: set DEPLOY_ACCOUNT (Foundry keystore name) for --broadcast" >&2
    exit 1
  fi
fi

FORGE_ARGS=(
  script "$SCRIPT_PATH"
  --rpc-url "$RPC_URL"
  --ffi
  --gas-limit "$GAS_LIMIT"
  -vvvv
)

if [[ "$BROADCAST" -eq 1 ]]; then
  FORGE_ARGS+=(--account "$ACCOUNT" --broadcast --slow)
fi

if [[ ${#VERIFY[@]} -gt 0 ]]; then
  if [[ "$BROADCAST" -ne 1 ]]; then
    echo "error: --verify requires --broadcast" >&2
    exit 1
  fi
  FORGE_ARGS+=("${VERIFY[@]}")
fi

echo "Running: forge ${FORGE_ARGS[*]}"
exec forge "${FORGE_ARGS[@]}"
