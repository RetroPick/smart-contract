# Deploy Setup (Local → Testnet → Mainnet) — RetroPick MarketEngine

This document is the **end-to-end deployment and operations guide** for:

- `MarketEngine` (UUPS proxy)
- `ChainlinkAdapter` (Chainlink AggregatorV3 + optional L2 sequencer uptime check)

It complements:

- `.docs/ProductionChecklist.md` (production gate checklist)
- `.docs/ROLLING_SECURITY.md` (rolling mode threat model + recovery)

---

## Prerequisites

### Tooling

```bash
git submodule update --init --recursive
forge --version
```

### Pre-deploy gate (always)

```bash
forge fmt
forge test -vvv
```

---

## Key management (recommended)

Use Foundry keystore instead of raw private keys in env vars.

```bash
cast wallet import <KEYSTORE_NAME> --interactive
cast wallet address --account <KEYSTORE_NAME>
```

---

## Role model (control plane)

`MarketEngine` roles:

- **`admin`**: upgrades + configuration (`onlyAdmin`)
- **`workerAuthority`**: keeper actions (`onlyWorkerOrAdmin`)
- **`treasury`**: fee withdrawal (`onlyTreasuryOrAdmin`)

**Production recommendation:**

- `admin` = **Safe** (multisig)
- `treasury` = **Safe** (separate Safe if desired)
- `workerAuthority` = keeper EOA(s) (rotateable via `setWorkerAuthority`)

**Important:** `admin` is set at `initialize(...)`. v1 has no admin transfer, so set this correctly on first deploy.

---

## Script classification

### Local (dev)

- `script/DeployLocal.s.sol:DeployLocal`

### Testnet

- Deploy: `script/test/DeployTestnet.s.sol:DeployTestnet`
- Upgrade: `script/test/UpgradeTestnet.s.sol:UpgradeTestnet`

### Production

- Deploy: `script/production/DeployProduction.s.sol:DeployProduction`
- Upgrade: `script/production/UpgradeProduction.s.sol:UpgradeProduction`

---

## Environment variables (deploy)

Used by both `DeployTestnet` and `DeployProduction`:

- `STAKE_TOKEN`
- `SEQUENCER_FEED`
  - L1: `0x0000000000000000000000000000000000000000`
  - L2: Chainlink sequencer uptime feed for that L2
- `ADMIN` (Safe recommended)
- `TREASURY` (Safe recommended)
- `WORKER`
- `DEFAULT_SETTLEMENT_FEE_BPS` (≤ 10000)
- `MAX_SWITCH_FEE_BPS` (≤ 10000)
- `MAX_OUTCOMES` (≤ 8)
- `ORACLE_MAX_DELAY_SECONDS`
- `ORACLE_MAX_CONFIDENCE_BPS` (≤ 10000)

Testnet-only optional smoke check:

- `SMOKE_FEED_ADDRESS` (AggregatorV3 proxy address)
- `SMOKE_MAX_AGE_SECONDS` (defaults to `ORACLE_MAX_DELAY_SECONDS`)

---

## Local from zero

```bash
forge script script/DeployLocal.s.sol:DeployLocal -vvvv
```

---

## Testnet deploy

Dry-run:

```bash
forge script script/test/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url "$RPC_URL" \
  --ffi \
  --gas-limit 5000000 \
  -vvvv
```

Broadcast:

```bash
forge script script/test/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url "$RPC_URL" \
  --ffi \
  --gas-limit 5000000 \
  --account <KEYSTORE_NAME> \
  --broadcast
```

Post-deploy (required):

- Verify `configInitialized() == true`
- Verify `admin/treasury/workerAuthority`
- Verify `stakeToken` + `priceOracle` addresses

---

## Production deploy

Pre-flight requirements are in `.docs/ProductionChecklist.md`.

Dry-run:

```bash
forge script script/production/DeployProduction.s.sol:DeployProduction \
  --rpc-url "$RPC_URL" \
  --ffi \
  --gas-limit 5000000 \
  -vvvv
```

Broadcast:

```bash
forge script script/production/DeployProduction.s.sol:DeployProduction \
  --rpc-url "$RPC_URL" \
  --ffi \
  --gas-limit 5000000 \
  --account <KEYSTORE_NAME> \
  --broadcast
```

---

## Upgrades

### Script-based upgrade (only if sender is `admin`)

```bash
PROXY_ADDRESS=0x... forge script script/production/UpgradeProduction.s.sol:UpgradeProduction \
  --rpc-url "$RPC_URL" \
  --ffi \
  --gas-limit 5000000 \
  -vvvv
```

### Safe-based upgrade (recommended)

If `admin` is a Safe:

1. Deploy new implementation (EOA/CI).
2. Safe executes proxy call `upgradeToAndCall(newImplementation, "")`.

Runbook recommendation: pause → upgrade → validate reads → unpause.

---

## Maintenance & monitoring (must-have)

Alert on:

- ERC1967 `Upgraded(implementation)` events
- `TemplateUpserted`, `DepositExecutorSet`
- `pauseProgram(true)`
- `WorkerAuthorityUpdated`, `TreasuryUpdated`
- Rolling: `RollingHalted` (page), `RollingLifecycleReset`

Reference: `.docs/ProductionChecklist.md` and `.docs/ROLLING_SECURITY.md`.