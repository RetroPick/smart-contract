#!/usr/bin/env bash
# Export contract ABIs to repo root abi/ (JSON) for frontends and tooling.
# Run from repo root: ./scripts/export-abi.sh
#
# Uses FOUNDRY_PROFILE=production to match testnet/mainnet deploy bytecode profile.
#
# First run is slow (full compile with via_ir + optimizer). To only refresh JSON after a build:
#   SKIP_BUILD=1 ./scripts/export-abi.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/foundry.toml" ]]; then
  ROOT="$SCRIPT_DIR"
else
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$ROOT"

export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-production}"
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  forge build
else
  echo "SKIP_BUILD=1: skipping forge build (use after a fresh production build)"
fi

ABI_DIR="${ROOT}/abi"
mkdir -p "$ABI_DIR"

# Args: "path:ContractName" "output_basename"
emit_abi() {
  local spec="$1"
  local out="$2"
  forge inspect "$spec" abi > "${ABI_DIR}/${out}.json"
  echo "wrote abi/${out}.json"
}

emit_abi "src/engine/IMarketEngine.sol:IMarketEngine" "IMarketEngine"
emit_abi "src/engine/MarketEngineDispatcher.sol:MarketEngineDispatcher" "MarketEngineDispatcher"
emit_abi "src/adapters/ChainlinkAdapter.sol:ChainlinkAdapter" "ChainlinkAdapter"
emit_abi "src/oracle/RateAdapter.sol:RateAdapter" "RateAdapter"
emit_abi "src/oracle/SmartDataAdapter.sol:SmartDataAdapter" "SmartDataAdapter"
emit_abi "src/oracle/MacroAdapter.sol:MacroAdapter" "MacroAdapter"
emit_abi "src/oracle/EquityAdapter.sol:EquityAdapter" "EquityAdapter"
emit_abi "src/oracle/TrustedReporterAdapter.sol:TrustedReporterAdapter" "TrustedReporterAdapter"
emit_abi "src/test/faucet/TokenFaucet.sol:TokenFaucet" "TokenFaucet"
emit_abi "src/test/MockERC20.sol:MockERC20" "MockERC20"

echo "Done. ABI count: $(find "${ABI_DIR}" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')"
