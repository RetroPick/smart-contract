#!/usr/bin/env bash
set -euo pipefail

# Estimate deployment cost on Base (L2) in USD.
#
# Usage:
#   BASE_RPC_URL="https://mainnet.base.org" ./scripts/estimate_base_deploy_usd.sh
#
# Optional env vars:
#   RPC_URL             RPC endpoint (default: BASE_RPC_URL)
#   DEPLOY_GAS          Estimated gas units (default: 45000000)
#   GAS_MULTIPLIER      Safety multiplier for gas units (default: 1.15)
#   ETH_PRICE_USD       Override ETH/USD price manually
#   ETH_PRICE_API_URL   Override price API URL

RPC_URL="${RPC_URL:-${BASE_RPC_URL:-}}"
DEPLOY_GAS="${DEPLOY_GAS:-45000000}"
GAS_MULTIPLIER="${GAS_MULTIPLIER:-1.15}"
ETH_PRICE_USD="${ETH_PRICE_USD:-}"
ETH_PRICE_API_URL="${ETH_PRICE_API_URL:-https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd}"

if [[ -z "${RPC_URL}" ]]; then
  echo "ERROR: set RPC_URL or BASE_RPC_URL"
  exit 1
fi

if ! command -v cast >/dev/null 2>&1; then
  echo "ERROR: 'cast' not found. Install Foundry first."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: 'curl' not found."
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: 'python3' not found."
  exit 1
fi

if ! [[ "${DEPLOY_GAS}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: DEPLOY_GAS must be an integer. Got: ${DEPLOY_GAS}"
  exit 1
fi

raw_gas_price_wei="$(cast gas-price --rpc-url "${RPC_URL}")"
if ! [[ "${raw_gas_price_wei}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: failed to read gas price from RPC. Got: ${raw_gas_price_wei}"
  exit 1
fi

if [[ -z "${ETH_PRICE_USD}" ]]; then
  price_json="$(curl -sS --fail "${ETH_PRICE_API_URL}")"
  ETH_PRICE_USD="$(
    python3 - <<'PY' "${price_json}"
import json, sys
obj = json.loads(sys.argv[1])
print(obj["ethereum"]["usd"])
PY
  )"
fi

if ! [[ "${ETH_PRICE_USD}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "ERROR: ETH_PRICE_USD is invalid: ${ETH_PRICE_USD}"
  exit 1
fi

python3 - <<'PY' "${raw_gas_price_wei}" "${DEPLOY_GAS}" "${GAS_MULTIPLIER}" "${ETH_PRICE_USD}"
from decimal import Decimal, getcontext
import sys

getcontext().prec = 40

gas_price_wei = Decimal(sys.argv[1])
deploy_gas = Decimal(sys.argv[2])
gas_multiplier = Decimal(sys.argv[3])
eth_price_usd = Decimal(sys.argv[4])

gwei = gas_price_wei / Decimal(10**9)
effective_gas = deploy_gas * gas_multiplier
eth_cost = (effective_gas * gas_price_wei) / Decimal(10**18)
usd_cost = eth_cost * eth_price_usd

# Show a conservative range around live gas conditions.
low_gwei = gwei * Decimal("0.75")
high_gwei = gwei * Decimal("1.25")
low_usd = usd_cost * Decimal("0.75")
high_usd = usd_cost * Decimal("1.25")

print("=== Base Deployment Cost Estimate ===")
print(f"Gas price (live):         {gwei:.3f} gwei")
print(f"ETH price:                ${eth_price_usd:.2f}")
print(f"Deployment gas (input):   {deploy_gas:,.0f}")
print(f"Gas safety multiplier:    x{gas_multiplier}")
print(f"Effective gas used:       {effective_gas:,.0f}")
print("")
print(f"Estimated cost:           {eth_cost:.6f} ETH")
print(f"Estimated USD:            ${usd_cost:,.2f}")
print("")
print(f"Sensitivity (±25% gas):   ${low_usd:,.2f} .. ${high_usd:,.2f}")
print(f"Gwei band:                {low_gwei:.3f} .. {high_gwei:.3f}")
PY
