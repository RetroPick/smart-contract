#!/usr/bin/env bash
# Verify Base Sepolia (chain id 84532) deploys on Basescan using ETHERSCAN_API_KEY from the environment
# (same API key as Etherscan for Base; create at https://basescan.org/apis).
#
# Prereq: a real broadcast, not a dry run:
#   broadcast/DeployTestnet.s.sol/84532/run-latest.json
#
# Usage (repo root, after FOUNDRY_PROFILE=production forge build):
#   source .env   # or: export ETHERSCAN_API_KEY=...
#   ./scripts/verify-base-sepolia-contracts.sh
#   BROADCAST_JSON=path/to/run-latest.json ./scripts/verify-base-sepolia-contracts.sh
#
# Optional:
#   VERIFY_SKIP="ERC1967Proxy"  space-separated contract names to skip
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

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

BROADCAST_JSON="${BROADCAST_JSON:-$ROOT/broadcast/DeployTestnet.s.sol/84532/run-latest.json}"
export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-production}"

if ! command -v forge &>/dev/null; then
  echo "error: forge not in PATH" >&2
  exit 1
fi
if ! command -v cast &>/dev/null; then
  echo "error: cast not in PATH" >&2
  exit 1
fi
if ! command -v jq &>/dev/null; then
  echo "error: jq not in PATH (install jq to parse the broadcast file)" >&2
  exit 1
fi

if [[ ! -f "$BROADCAST_JSON" ]]; then
  echo "error: missing broadcast file: $BROADCAST_JSON" >&2
  echo "  Deploy first: FOUNDRY_PROFILE=production ./scripts/deploy-testnet.sh --broadcast" >&2
  exit 1
fi
if echo "$BROADCAST_JSON" | grep -q 'dry-run'; then
  echo "error: do not use a dry-run broadcast; run a real --broadcast to produce run-latest.json" >&2
  exit 1
fi
if [[ -z "${ETHERSCAN_API_KEY:-}" ]]; then
  echo "error: set ETHERSCAN_API_KEY (Basescan v2 API key)" >&2
  exit 1
fi

contract_path() {
  case "$1" in
  ChainlinkAdapter) echo "src/adapters/ChainlinkAdapter.sol:ChainlinkAdapter" ;;
  RateAdapter) echo "src/oracle/RateAdapter.sol:RateAdapter" ;;
  SmartDataAdapter) echo "src/oracle/SmartDataAdapter.sol:SmartDataAdapter" ;;
  MacroAdapter) echo "src/oracle/MacroAdapter.sol:MacroAdapter" ;;
  EquityAdapter) echo "src/oracle/EquityAdapter.sol:EquityAdapter" ;;
  TrustedReporterAdapter) echo "src/oracle/TrustedReporterAdapter.sol:TrustedReporterAdapter" ;;
  TokenFaucet) echo "src/test/faucet/TokenFaucet.sol:TokenFaucet" ;;
  MockERC20) echo "src/test/MockERC20.sol:MockERC20" ;;
  MarketEngineDispatcher) echo "src/engine/MarketEngineDispatcher.sol:MarketEngineDispatcher" ;;
  MarketEngineAdminModule) echo "src/engine/modules/MarketEngineAdminModule.sol:MarketEngineAdminModule" ;;
  MarketEngineViewModule) echo "src/engine/modules/MarketEngineViewModule.sol:MarketEngineViewModule" ;;
  MarketEngineUserOpsClaimsModule) echo "src/engine/modules/MarketEngineUserOpsClaimsModule.sol:MarketEngineUserOpsClaimsModule" ;;
  MarketEngineCoreLifecycleModule) echo "src/engine/modules/MarketEngineCoreLifecycleModule.sol:MarketEngineCoreLifecycleModule" ;;
  MarketEngineRollingLifecycleModule) echo "src/engine/modules/MarketEngineRollingLifecycleModule.sol:MarketEngineRollingLifecycleModule" ;;
  ERC1967Proxy)
    echo "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy"
    ;;
  *) echo "" ;;
  esac
}

encode_ctor_args() {
  local cname="$1"
  local args_json
  args_json="$2"
  local n
  n="$(echo "$args_json" | jq 'length' 2>/dev/null || echo 0)"
  if [[ "$n" == "0" || "$n" == "null" ]]; then
    echo ""
    return 0
  fi
  case "$cname" in
  ChainlinkAdapter | RateAdapter | SmartDataAdapter | MacroAdapter | EquityAdapter)
    cast abi-encode "constructor(address)" "$(echo "$args_json" | jq -r '.[0]')"
    ;;
  TrustedReporterAdapter)
    cast abi-encode "constructor(address,address,uint256)" \
      "$(echo "$args_json" | jq -r '.[0]')" \
      "$(echo "$args_json" | jq -r '.[1]')" \
      "$(echo "$args_json" | jq -r '.[2]')"
    ;;
  TokenFaucet)
    local n0 n1
    n0="$(echo "$args_json" | jq -r '.[0]')"
    n1="$(echo "$args_json" | jq -r '.[1]')"
    local nlen
    nlen="$(echo "$args_json" | jq 'length')"
    if [[ "$nlen" -ge 4 ]]; then
      cast abi-encode "constructor(string,string,(uint64,uint256))" \
        "$n0" "$n1" \
        "$(echo "$args_json" | jq -r '.[2]')" \
        "$(echo "$args_json" | jq -r '.[3]')"
    else
      local t2 cd max
      t2="$(echo "$args_json" | jq -r '.[2]')"
      if echo "$t2" | grep -qE '^\('; then
        t2="${t2#(}"
        t2="${t2%)}"
        t2="${t2//[[:space:]]/}"
        IFS=',' read -r cd max <<< "$t2"
      else
        echo "error: could not parse TokenFaucet args (need 4 JSON args or tuple string in .[2]): $args_json" >&2
        return 1
      fi
      cast abi-encode "constructor(string,string,(uint64,uint256))" "$n0" "$n1" "$cd" "$max"
    fi
    ;;
  ERC1967Proxy)
    cast abi-encode "constructor(address,bytes)" \
      "$(echo "$args_json" | jq -r '.[0]')" \
      "$(echo "$args_json" | jq -r '.[1]')"
    ;;
  MarketEngineDispatcher | MarketEngineAdminModule | MarketEngineViewModule | MarketEngineUserOpsClaimsModule | MarketEngineCoreLifecycleModule | MarketEngineRollingLifecycleModule | MockERC20)
    echo ""
    ;;
  *)
    echo "error: unknown contract for automatic ctor encoding: $cname" >&2
    return 1
    ;;
  esac
}

SKIP_SET="${VERIFY_SKIP:-}"
should_skip() {
  local c="$1"
  for s in $SKIP_SET; do
    [[ "$c" == "$s" ]] && return 0
  done
  return 1
}

# Prefer implementations first, proxy last.
mapfile -t ROWS < <(jq -c '.transactions[] | select(.transactionType == "CREATE") | {c: .contractName, a: .contractAddress, args: .arguments}' "$BROADCAST_JSON")

# Two-pass: non-ERC1967Proxy first
verify_one() {
  local row="$1"
  local cname addr args_json
  cname="$(echo "$row" | jq -r '.c')"
  addr="$(echo "$row" | jq -r '.a')"
  args_json="$(echo "$row" | jq -c '.args // []')"
  [[ -z "$cname" || "$cname" == "null" ]] && return 0
  if should_skip "$cname"; then
    echo "skip $cname $addr (VERIFY_SKIP)"
    return 0
  fi
  local cpath
  cpath="$(contract_path "$cname")"
  if [[ -z "$cpath" ]]; then
    echo "warning: no source mapping for $cname at $addr — verify manually" >&2
    return 0
  fi
  local enc
  if ! enc="$(encode_ctor_args "$cname" "$args_json" 2>/dev/null)"; then
    echo "error: constructor encoding failed for $cname $addr" >&2
    return 1
  fi
  set +e
  if [[ -z "$enc" ]]; then
    echo "verifying $cname at $addr (no constructor args)..."
    forge verify-contract "$addr" "$cpath" --chain 84532 --etherscan-api-key "$ETHERSCAN_API_KEY" --verifier-url "https://api-sepolia.basescan.org/api"
  else
    echo "verifying $cname at $addr..."
    forge verify-contract "$addr" "$cpath" --chain 84532 --etherscan-api-key "$ETHERSCAN_API_KEY" --verifier-url "https://api-sepolia.basescan.org/api" --constructor-args "$enc"
  fi
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "error: verify failed for $cname at $addr (rc=$rc)" >&2
    return "$rc"
  fi
  echo "ok: $cname"
}

for row in "${ROWS[@]}"; do
  c="$(echo "$row" | jq -r '.c')"
  [[ "$c" == "ERC1967Proxy" ]] && continue
  verify_one "$row"
done
for row in "${ROWS[@]}"; do
  c="$(echo "$row" | jq -r '.c')"
  [[ "$c" != "ERC1967Proxy" ]] && continue
  verify_one "$row"
done

echo "All listed contracts submitted for verification. Confirm on Basescan (indexing can take a minute)."
