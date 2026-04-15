#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# mainnet wrapper should reject non-mainnet chain id when EXPECTED_CHAIN_ID=1.
if RPC_URL="http://127.0.0.1:8545" EXPECTED_CHAIN_ID=1 ./scripts/deploy-mainnet.sh >/tmp/mainnet_guard.out 2>&1; then
  fail "deploy-mainnet.sh must fail on wrong chain id"
fi
grep -q "does not match EXPECTED_CHAIN_ID" /tmp/mainnet_guard.out && pass "mainnet chain-id guard"

# testnet wrapper requires EXPECTED_CHAIN_ID.
if RPC_URL="http://127.0.0.1:8545" ./scripts/deploy-testnet.sh >/tmp/testnet_expected.out 2>&1; then
  fail "deploy-testnet.sh must fail when EXPECTED_CHAIN_ID missing"
fi
grep -q "missing required env var: EXPECTED_CHAIN_ID" /tmp/testnet_expected.out && pass "testnet expected chain id required"

# testnet wrapper should fail if STAKE_TOKEN missing and faucet disabled.
if RPC_URL="http://127.0.0.1:8545" EXPECTED_CHAIN_ID=31337 SEQUENCER_FEED=0x0000000000000000000000000000000000000000 ADMIN=0x0000000000000000000000000000000000000001 TREASURY=0x0000000000000000000000000000000000000002 WORKER=0x0000000000000000000000000000000000000003 DEFAULT_SETTLEMENT_FEE_BPS=100 MAX_SWITCH_FEE_BPS=200 MAX_OUTCOMES=8 ORACLE_MAX_DELAY_SECONDS=3600 ORACLE_MAX_CONFIDENCE_BPS=0 ./scripts/deploy-testnet.sh >/tmp/testnet_stake.out 2>&1; then
  fail "deploy-testnet.sh must fail when STAKE_TOKEN missing and DEPLOY_FAUCET!=1"
fi
grep -q "missing required env var: STAKE_TOKEN" /tmp/testnet_stake.out && pass "testnet stake token requirement"

echo "All wrapper guard checks passed."
