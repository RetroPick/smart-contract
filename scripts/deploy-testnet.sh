#!/usr/bin/env bash
# Deploy RetroPick MarketEngine (ChainlinkAdapter + UUPS MarketEngineDispatcher + modules) on a testnet.
#
# Prerequisites:
#   - forge, cast (Foundry)
#   - `forge build` succeeds; run with `--ffi` (required by OpenZeppelin upgrades plugin)
#
# Environment (required for broadcast; simulation still needs RPC):
#   RPC_URL                 HTTPS RPC for the testnet
#   DEPLOY_ACCOUNT          Foundry keystore account name (passed as --account)
#   SEQUENCER_FEED          Chainlink L2 sequencer uptime feed, or 0x000... on L1 testnets
#   ADMIN, TREASURY, WORKER addresses
#   STAKE_TOKEN             stake ERC20, unless DEPLOY_FAUCET=1 (see script/test/DeployTestnet.s.sol)
#   DEFAULT_SETTLEMENT_FEE_BPS, MAX_SWITCH_FEE_BPS, MAX_OUTCOMES
#   ORACLE_MAX_DELAY_SECONDS, ORACLE_MAX_CONFIDENCE_BPS
#
# Optional:
#   DEPLOY_FAUCET, SMOKE_FEED_ADDRESS, SMOKE_MAX_AGE_SECONDS, GAS_LIMIT, FOUNDRY_ETH_RPC_URL (alias)
#
# Usage:
#   ./deploy-testnet.sh              # dry-run (simulation only)
#   ./deploy-testnet.sh --broadcast  # send transactions (needs DEPLOY_ACCOUNT + unlocked keystore)
#   ./deploy-testnet.sh --broadcast --verify  # broadcast + explorer verify (needs ETHERSCAN_API_KEY)

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
SCRIPT_PATH="script/test/DeployTestnet.s.sol:DeployTestnet"

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

FORGE_ARGS=(
  script "$SCRIPT_PATH"
  --rpc-url "$RPC_URL"
  --ffi
  --gas-limit "$GAS_LIMIT"
  -vvvv
)

if [[ "$BROADCAST" -eq 1 ]]; then
  if [[ -z "$ACCOUNT" ]]; then
    echo "error: set DEPLOY_ACCOUNT (Foundry keystore name) for --broadcast" >&2
    exit 1
  fi
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
