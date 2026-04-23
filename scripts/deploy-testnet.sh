#!/usr/bin/env bash
# Deploy RetroPick MarketEngine (ChainlinkAdapter + UUPS MarketEngineDispatcher + modules) on a testnet.
#
# Prerequisites:
#   - forge, cast (Foundry)
#   - `FOUNDRY_PROFILE=upgrades forge build` (required for OZ upgrades AST/build-info validation)
#   - Node.js / `npx` available for the OpenZeppelin upgrades validator
#   - Run script with `--ffi` (required by OpenZeppelin upgrades plugin)
#
# Block explorer verify (--verify):
#   - Set ETHERSCAN_API_KEY. On Base Sepolia and other L2s, if verification fails, use chain-specific
#     `forge verify-contract --verifier-url` or add [etherscan] entries in foundry.toml for that chain.
#
# Environment (required for broadcast; simulation still needs RPC):
#   RPC_URL                 HTTPS RPC for the testnet
#   EXPECTED_CHAIN_ID       expected testnet chain id (required)
#   DEPLOY_ACCOUNT | KEYSTORE_NAME   Foundry keystore name (passed as --account; DEPLOY_ACCOUNT wins)
#   SEQUENCER_FEED          Chainlink L2 sequencer uptime feed, or 0x000... on L1 testnets
#   ADMIN, TREASURY, WORKER addresses
#   STAKE_TOKEN             stake ERC20, unless DEPLOY_FAUCET=1 (see script/test/DeployTestnet.s.sol)
#   DEFAULT_SETTLEMENT_FEE_BPS, MAX_SWITCH_FEE_BPS, MAX_OUTCOMES
#   ORACLE_MAX_DELAY_SECONDS, ORACLE_MAX_CONFIDENCE_BPS
#
# Optional:
#   DEPLOY_FAUCET, SMOKE_FEED_ADDRESS, SMOKE_MAX_AGE_SECONDS, GAS_LIMIT, FOUNDRY_ETH_RPC_URL (alias)
#   ETH_PASSWORD            If set, exported for non-interactive unlock of the Foundry keystore used with --account
#                         (if your password contains $ ( ) ` or ;, do not put it in .env — set ETH_PASSWORD in the shell)
#
# Usage (from repo root):
#   ./scripts/deploy-testnet.sh              # dry-run (simulation only)
#   ./scripts/deploy-testnet.sh --broadcast  # send transactions (needs DEPLOY_ACCOUNT or KEYSTORE_NAME)
#   ./scripts/deploy-testnet.sh --broadcast --verify  # broadcast + explorer verify (needs ETHERSCAN_API_KEY)
#   DEPLOY_FAUCET=1 ./scripts/deploy-testnet.sh --broadcast  # faucet + demo token as STAKE_TOKEN

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/foundry.toml" ]]; then
  ROOT="$SCRIPT_DIR"
else
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$ROOT"

if [[ -d "$ROOT/.tools/node/bin" ]]; then
  export PATH="$ROOT/.tools/node/bin:${PATH}"
fi

if [[ -f .env ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; then
      echo "error: invalid .env line: $line" >&2
      exit 1
    fi
    key="${line%%=*}"
    value="${line#*=}"
    if [[ "$value" =~ [\`\$\(\)\;] ]]; then
      echo "error: unsafe value in .env for key: $key" >&2
      exit 1
    fi
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi
    export "$key=$value"
  done < .env
fi

# Non-interactive keystore: Foundry/cast use ETH_PASSWORD when --account is set.
if [[ -n "${ETH_PASSWORD:-}" ]]; then
  export ETH_PASSWORD
fi

RPC_URL="${RPC_URL:-${FOUNDRY_ETH_RPC_URL:-}}"
ACCOUNT="${DEPLOY_ACCOUNT:-${KEYSTORE_NAME:-}}"
GAS_LIMIT="${GAS_LIMIT:-50000000}"
EXPECTED_CHAIN_ID="${EXPECTED_CHAIN_ID:-}"
MAINNET_CHAIN_ID="${MAINNET_CHAIN_ID:-1}"
SCRIPT_PATH="script/test/DeployTestnet.s.sol:DeployTestnet"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "error: missing required env var: $name" >&2
    exit 1
  fi
}

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
if ! command -v npx &>/dev/null; then
  echo "error: npx not in PATH; install Node.js so OpenZeppelin upgrades validation can run" >&2
  exit 1
fi

require_env EXPECTED_CHAIN_ID
CHAIN_ID="$(cast chain-id --rpc-url "$RPC_URL")"
if [[ "$CHAIN_ID" != "$EXPECTED_CHAIN_ID" ]]; then
  echo "error: RPC chain id ($CHAIN_ID) does not match EXPECTED_CHAIN_ID ($EXPECTED_CHAIN_ID)" >&2
  exit 1
fi
if [[ "$EXPECTED_CHAIN_ID" == "$MAINNET_CHAIN_ID" ]]; then
  echo "error: testnet script refuses mainnet chain id ($MAINNET_CHAIN_ID)" >&2
  exit 1
fi
if [[ "$EXPECTED_CHAIN_ID" == "1" || "$EXPECTED_CHAIN_ID" == "8453" || "$EXPECTED_CHAIN_ID" == "42161" || "$EXPECTED_CHAIN_ID" == "10" ]]; then
  echo "error: testnet script refuses known mainnet chain id ($EXPECTED_CHAIN_ID)" >&2
  exit 1
fi
export EXPECTED_CHAIN_ID MAINNET_CHAIN_ID

for var in SEQUENCER_FEED ADMIN TREASURY WORKER DEFAULT_SETTLEMENT_FEE_BPS MAX_SWITCH_FEE_BPS MAX_OUTCOMES ORACLE_MAX_DELAY_SECONDS ORACLE_MAX_CONFIDENCE_BPS; do
  require_env "$var"
done
if [[ "${DEPLOY_FAUCET:-0}" != "1" ]]; then
  require_env STAKE_TOKEN
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
    echo "error: set DEPLOY_ACCOUNT or KEYSTORE_NAME (Foundry keystore name) for --broadcast" >&2
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
