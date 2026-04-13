# RetroPick Market Engine (Solidity)

Foundry port of the Anchor program [`retropick_market_engine_v5`](../retropick_market_engine_v5/) with matching math, epoch lifecycle, oracle normalization (e8), and three-bucket vault accounting (`active`, `claims`, `fees`) per market template.

For deployment economics, keeper gas, epoch limits, and standing up a new market instance, see [DEPLOYMENT_AND_EPOCHS.md](./DEPLOYMENT_AND_EPOCHS.md).

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Submodules: `git submodule update --init --recursive` (OpenZeppelin + `forge-std`)
- Chainlink interfaces: vendored under `lib/chainlink-brownie-contracts` (clone or `forge install` if you manage `lib` via git submodules)

## Build and test

```bash
forge build
forge test -vvv
```

## Solhint

This repo keeps Solidity under `src/` (not `contracts/`). With [Solhint](https://protofire.github.io/solhint/) installed globally (`npm install -g solhint`), run:

```bash
solhint 'src/**/*.sol'
```

Configuration: [`.solhint.json`](./.solhint.json).

## Operations budget (rollups / L2)

Recurring **keeper** work depends on **execution mode**:

- **Manual:** **three** txs per epoch per template: `openEpoch`, `lockEpoch`, `resolveEpoch`.
- **Rolling (Direction):** **one** tx per interval in steady state (`executeRollingRound`), plus a **two-tx** genesis bootstrap per session.

Monthly cost is approximately:

`keeper_txs_per_month × (L2_execution_gas + L1_data_fee_on_OP_Stack) × gas_price × ETH_USD`

**Measure locally** (relative gas, before chain-specific fees):

```bash
forge snapshot --match-contract 'EpochGasTest|MarketEngineRollingTest'
cat .gas-snapshot
```

Use `EpochGasTest:test_gas_*` for Manual paths and `MarketEngineRollingTest:test_gas_*` for Rolling; multiply by your sequencer’s gas price and (on OP Stack) the L1 fee from `eth_estimateGas` / block explorer “L1 gas used” fields.

**Also batch**: `openEpochsBatch`, `lockEpochsBatch`, and `resolveEpochsBatch` amortize fixed per-tx overhead when one keeper maintains many templates in one block; rolling templates use `executeRollingRoundBatch`.

**Rolling mode** (Direction-only): `genesisStartRolling` → `genesisLockRolling` → repeating `executeRollingRound` bundles resolve + lock + open into **one keeper tx** per tick—see [DEPLOYMENT_AND_EPOCHS.md](./DEPLOYMENT_AND_EPOCHS.md#rolling-execution-mode-keeper-cost-reduction).

**Ops defaults for lower cost:** recurring **Direction** → prefer **Rolling**; multi-template keepers → **batch** APIs; set per-feed **`oracleMaxDelaySeconds`** (and global defaults) to the Chainlink feed **heartbeat + buffer** so keeper txs do not revert on stale prices—see [Cost-conscious operations defaults](./DEPLOYMENT_AND_EPOCHS.md#cost-conscious-operations-defaults-recommended).

**Compiler profiles**: [`foundry.toml`](foundry.toml) defines **`default`** (200 runs), **`production`** (1M runs — often **better runtime gas**, but `MarketEngine` typically **fails EIP-170** at that setting), and **`deploybudget`** (`optimizer_runs = 1` — smaller bytecode, higher runtime gas). **Deploy** `MarketEngine` **implementation** with **`default`** or **`deploybudget`**, not `production`. CI runs [`script/check-contract-sizes.sh`](script/check-contract-sizes.sh) (set **`STRICT_EIP170=1`** for a hard EIP-170 gate before mainnet). Production deploy uses a **UUPS** proxy via [`script/Deploy.s.sol`](script/Deploy.s.sol) (`--ffi` recommended).

## Deploy (chain-agnostic)

### Production-style (`ChainlinkAdapter` + env)

Set:

| Variable | Meaning |
|----------|---------|
| `PRIVATE_KEY` | Broadcast wallet (deploys adapter + implementation + proxy; no persistent deployer role after `initialize`) |
| `STAKE_TOKEN` | ERC20 used as collateral |
| `SEQUENCER_FEED` | Chainlink **L2 sequencer uptime** proxy on the target rollup; use `0x0000000000000000000000000000000000000000` on **L1** to disable the check |
| `ADMIN` | Admin pubkey |
| `TREASURY` | Treasury pubkey (fee withdrawals) |
| `WORKER` | Worker pubkey |
| `DEFAULT_SETTLEMENT_FEE_BPS` | Protocol default (bps), e.g. `100` |
| `MAX_SWITCH_FEE_BPS` | Cap for template switch fee |
| `MAX_OUTCOMES` | Max outcomes (≤ 8) |
| `ORACLE_MAX_DELAY_SECONDS` | Global default max staleness (seconds); templates can override via `oracleMaxDelaySeconds` |
| `ORACLE_MAX_CONFIDENCE_BPS` | Global confidence cap; Chainlink adapter returns zero confidence — use `0` for clarity |

**Dependency:** [`lib/chainlink-brownie-contracts`](./lib/chainlink-brownie-contracts) (Chainlink `AggregatorV3Interface`; pin tag `1.3.0` or newer).

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC_URL" --ffi --broadcast
```

### Local / mock oracle

```bash
forge script script/DeployLocal.s.sol:DeployLocal --rpc-url http://127.0.0.1:8545 --broadcast
```

## Security notes

See [AUDIT_SOLIDITY.md](./AUDIT_SOLIDITY.md). Optional Slither run: `.github/workflows/slither.yml` (`workflow_dispatch`).

## Layout

- `src/MarketEngine.sol` — core protocol
- `src/math/MarketMath.sol`, `src/logic/Resolvers.sol`
- `src/adapters/ChainlinkAdapter.sol`, `src/interfaces/IPriceOracle.sol`
