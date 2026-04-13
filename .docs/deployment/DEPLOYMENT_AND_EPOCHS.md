# Deployment, epoch maintenance, and market instances

Operational guide for the Foundry [`MarketEngine`](src/MarketEngine.sol) port. For security and threat model, see [AUDIT_SOLIDITY.md](./AUDIT_SOLIDITY.md).

## Architecture: one engine, many markets

- A single **MarketEngine** contract stores **all** templates, per-template ledgers and vaults, epochs, and user positions. There is **no separate contract deployment per market**.
- A **market instance** means: one **template** (identified by `templateId`) + **initialized ledger** (`initializeMarket`) + a **sequence of epochs** opened by the worker/admin.
- **Template id**: `templateId = keccak256(bytes(slug))` from [`templateIdFromSlug`](src/MarketEngine.sol). Choose slugs that are unique in your product; the same slug always maps to the same id.

**Epoch vs round:** in this engine, one **epoch** is one full market cycle: schedule is set at `openEpoch`, betting runs until `lockEpoch`, outcome is fixed at `resolveEpoch`, then users `claim`. Product language often calls that a **round**—here it is the same as **one `epochId`** (strictly sequential per template).

## Rolling execution mode (keeper cost reduction)

Templates can use [`ExecutionMode`](src/types/MarketTypes.sol) **`Manual`** (default, Anchor-style discrete txs) or **`Rolling`** (Pancake-style rolling pipeline). Design reference: [rolling-rounds.md](./rolling-rounds.md).

### Scope (current Solidity)

- **Rolling is supported only for `MarketType.Direction`** with two outcomes (`upsertTemplate` reverts otherwise).
- Set on template: `executionMode = Rolling`, `rollingIntervalSeconds`, `rollingBufferSeconds` with **`buffer < interval`** (same idea as Pancake `bufferSeconds` / `intervalSeconds`).
- [`Ledger.rollingPhase`](src/types/MarketTypes.sol) tracks bootstrap: `Uninitialized` → `GenesisOpen` → `Live` → `Halted` (on missed buffer, oracle failure, wide confidence, or `haltRollingMarket`). [`Ledger.rollingHaltReason`](src/types/MarketTypes.sol) and `haltedAtEpochId` record why / where the pipeline stopped.
- **`rollingNextEpochId`**: next numeric `epochId` used when opening a rolling epoch (starts at `1` in `initializeMarket`). After a halted recovery, [`resetRollingLifecycle`](src/MarketEngine.sol) sets this past all existing epochs so the same template can re-bootstrap without `EpochAlreadyExists`. In steady state, **`rollingNextEpochId == activeEpochId + 1`**.

### Keeper flow

1. **`genesisStartRolling(templateId)`** — opens the current **`rollingNextEpochId`** (first time `1`) with timing `openAt = now`, `lockAt = now + interval`, `resolveAt = now + 2×interval`, then advances `rollingNextEpochId`.
2. After users can bet on that epoch, **`genesisLockRolling(templateId)`** within `[lockAt, lockAt + buffer]` — one oracle read (try/catch: failures **halt**), writes checkpoint **A**, locks it, opens the next rolling epoch (`Live`).
3. **`executeRollingRound(templateId)`** each interval boundary (within buffer on both resolve of `k-1` and lock of `k`) — **one oracle read** for checkpoint **B** on `k-1` and checkpoint **A** on `k`, then opens the next epoch. Missed buffer or oracle issues **set `Halted` and return** (no revert on the outer call); too-early calls still revert.

**`executeRollingRoundBatch`** loops the same logic for many templates in one outer tx (still **non-reentrant**). Use [`getRollingLifecycle(templateId)`](src/MarketEngine.sol) to read phase, halt reason, and cursors.

### Manual API gating

On **`Rolling`** templates, **`openEpoch`**, **`lockEpoch`**, **`resolveEpoch`** (and batches) **`revert ManualModeOnly`**. Use genesis + `executeRollingRound` only.

**`cancelEpoch`** **`reverts`** while `rollingPhase == Live` (same selector for simplicity). While **`Halted`**, use **`cancelRollingEpochWhileHalted`** (admin, protocol paused) to cancel any **`Open`** or **`Locked`** rolling epoch—including the locked predecessor that `cancelEpoch` cannot target.

### Gas (mock oracle)

Measured in [`.gas-snapshot`](.gas-snapshot) ([`MarketEngineRolling.t.sol`](test/MarketEngineRolling.t.sol), mock `IPriceOracle`):

| Call | Snapshot test | Gas (ref.) |
|------|-----------------|------------|
| `genesisStartRolling` | `test_gas_genesis_start_rolling` | **198312** |
| `genesisLockRolling` | `test_gas_genesis_lock_rolling` | **224155** |
| `executeRollingRound` (steady) | `test_gas_rolling_execute_one_tick` | **376754** |

One-time bootstrap (genesis start + lock) ≈ **422467** gas (`198312 + 224155`). Steady-state **execute** is **~377k** gas—same order as **manual Direction** open + lock + resolve (**375907** gas combined from [`EpochGasTest`](test/gas/EpochGas.t.sol)), but rolling uses **one L2 transaction per interval** instead of **three**, which typically **dominates savings** on rollups (L1 data fee × 3 → × 1 for keeper txs).

```bash
forge snapshot --match-contract 'EpochGasTest|MarketEngineRollingTest'
cat .gas-snapshot
```

### Recovery

1. **`pauseProgram(true)`** — stops new user/worker txs that respect pause.
2. Optional: **`haltRollingMarket`** (admin) to halt from `GenesisOpen` / `Live` without waiting for a missed buffer.
3. **`cancelRollingEpochWhileHalted`** — refund stuck **`Open`** / **`Locked`** epochs (typically cancel locked then open, or either order; `lastResolvedEpochId` uses a max rule so ordering is safe).
4. **`resetRollingLifecycle(templateId, nextRollingEpochId)`** — requires **paused** + **`Halted`**; sets phase **`Uninitialized`**, **`activeEpochId = 0`**, and **`nextRollingEpochId` strictly above** `max(activeEpochId, lastResolvedEpochId)` from before the reset (so the next open uses a fresh id).
5. **`pauseProgram(false)`**, then **`genesisStartRolling`** → **`genesisLockRolling`** → steady **`executeRollingRound`**.

Reference Pancake V3 prediction shape (Chainlink, single market): [`reference/PancakePredictionV3.sol`](reference/PancakePredictionV3.sol). See §7–8 in [rolling-rounds.md](./rolling-rounds.md).

**User ops while halted:** `depositToSide` / `switchSide` **`revert RollingHaltedUserOps`** on rolling templates. **`claim`** remains available for resolved / cancelled epochs.

### Cost-conscious operations defaults (recommended)

These defaults **preserve** on-chain logic; they reduce **recurring spend** (especially **L1 data fees** on rollups) and **wasted keeper txs**.

1. **Recurring `Direction` markets → prefer `ExecutionMode.Rolling`**  
   Same cadence as Manual Direction but **one** keeper tx per interval in steady state (`executeRollingRound`) instead of **three** (`openEpoch` + `lockEpoch` + `resolveEpoch`). See [Cost and specification overview](#cost-and-specification-overview).

2. **Several templates in one keeper run → use batch entrypoints**  
   - Rolling: [`executeRollingRoundBatch`](src/MarketEngine.sol)  
   - Manual: [`openEpochsBatch`](src/MarketEngine.sol), [`lockEpochsBatch`](src/MarketEngine.sol), [`resolveEpochsBatch`](src/MarketEngine.sol)  

   Batching amortizes **fixed per-tx overhead**. **L1 calldata** grows with the number of `templateId`s and arrays—on some chains a **single fat tx** is still cheaper than many small txs; on others, split batches—**measure** on your target L2.

3. **Chainlink staleness vs `oracleConfig.maxDelaySeconds` (`initialize`)**  
   [`ChainlinkAdapter`](src/adapters/ChainlinkAdapter.sol) compares `block.timestamp - updatedAt` from the feed’s `latestRoundData()` to `maxAgeSeconds`. If the feed is older than `maxDelaySeconds`, **lock / resolve / rolling execute** revert or (rolling) may **halt** after failed oracle paths—those txs still cost gas/L1. **Ops checklist:**  
   - Set `oracleMaxDelaySeconds` (global and/or per-template) to at least the feed **heartbeat + buffer** for your asset (see [Chainlink data feeds](https://docs.chain.link/data-feeds)).  
   - Set `maxDelaySeconds` **no tighter** than realistic Chainlink update cadence on your chain (tighter = stricter safety, but more **failed** txs if the feed lags).  
   - Align **market interval** with feed heartbeat / deviation thresholds and **engine** keeper windows.

4. **Cadence**  
   Shorter epochs **linearly** increase keeper (and often oracle-update) tx count. Choose product cadence with **budget and feed update frequency** in mind.

### Bytecode size gate (EIP-170) and upgrades

[`MarketEngine`](src/MarketEngine.sol) is a **large** monolith (one **implementation** behind an ERC1967 **proxy**). Production uses **UUPS** ([`UUPSUpgradeable`](https://docs.openzeppelin.com/contracts/)): **`admin`** authorizes upgrades via `_authorizeUpgrade`. Deploy with [`script/Deploy.s.sol`](../script/Deploy.s.sol) (`Upgrades.deployUUPSProxy`); upgrade with [`script/UpgradeMarketEngine.s.sol`](../script/UpgradeMarketEngine.s.sol) (requires `--ffi` for OpenZeppelin validation).

The Ethereum **contract runtime code** limit is **24576** bytes (EIP-170). [`script/check-contract-sizes.sh`](../script/check-contract-sizes.sh) builds **`default`** and **`deploybudget`** and reports `MarketEngine` runtime size. Set **`STRICT_EIP170=1`** to **fail** the script if runtime exceeds **24576** B or headroom is below **`MIN_HEADROOM`** (default **384** B)—recommended before mainnet. With **`STRICT_EIP170=0`** (default in CI), oversize emits a **warning** so work can continue while bytecode is tuned. The **`production`** profile (`optimizer_runs = 1_000_000`) is **informational only** in that script; **do not deploy** that `MarketEngine` artifact if it exceeds EIP-170.

If the implementation is **near or over** the cap, prefer **`FOUNDRY_PROFILE=deploybudget`** (`optimizer_runs = 1`, smaller bytecode, higher runtime gas) and track follow-up (library split, facet, or further optimizer tuning). Do **not** strip safety checks solely to save bytes.

Do **not** inline the Chainlink adapter into `MarketEngine` solely to save one deploy address—it **increases** engine bytecode and worsens the EIP-170 margin.

## Cost and specification overview

**Scope:** one-time deployment through recurring keeper epochs and user claims. Single reference table below. **Gas** figures are from [`.gas-snapshot`](.gas-snapshot) (regenerate with `forge snapshot`): [`test/gas/EpochGas.t.sol`](test/gas/EpochGas.t.sol) for **Manual** paths, [`test/MarketEngineRolling.t.sol`](test/MarketEngineRolling.t.sol) for **Rolling** paths—**mock oracle**, cold `openEpoch`, typical single-position deposits where the gas tests use them. **Measure on your chain** before budgeting. **USD** uses illustrative inputs only: execution gas price **0.05 gwei**, **$3,000** ETH—**execution only**, no L1 data fee.

| Phase | Item | Spec / unit of work | Tx count (typical) | Gas (ref.) | Illustrative USD @ 0.05 gwei & $3k ETH |
|-------|------|---------------------|-------------------|------------|----------------------------------------|
| **Deploy** | Stack deploy + proxy `initialize` | Once per chain / environment (`ChainlinkAdapter`, implementation, proxy) | 2–3 | *not in snapshot—measure (`forge script --dry-run`)* | *e.g. ~$3.75 exec if `G=25M`—see [Deployment cost in USD](#deployment-cost-in-usd-how-to-estimate)* |
| **New instance** | `upsertTemplate` | Once per new `slug` / `templateId` | 1 | *measure* | negligible vs deploy |
| **New instance** | `initializeMarket` | Once per template (after upsert) | 1 | *measure* | negligible vs deploy |
| **Epoch round (Manual)** | `openEpoch` (cold) | First step each **epoch**; `epochId` must be `lastResolved + 1` (starts at `1`) | 1 / epoch | 192308 | ~$0.0288 |
| **Epoch round (Manual)** | `lockEpoch` | **Threshold** / **RangeClose** (no oracle at lock) | 1 / epoch | 10203 | ~$0.0015 |
| **Epoch round (Manual)** | `lockEpoch` | **Direction** (checkpoint **A**, oracle at lock) | 1 / epoch | 56034 | ~$0.0084 |
| **Epoch round (Manual)** | `resolveEpoch` | **Threshold** (checkpoint **B**) | 1 / epoch | 129859 | ~$0.0195 |
| **Epoch round (Manual)** | `resolveEpoch` | **Direction** (checkpoint **B**) | 1 / epoch | 128690 | ~$0.0193 |
| **Subtotal** | Keeper **Threshold / RangeClose** round | `open` + `lock` + `resolve` per epoch | **3** / epoch | **331056** | **~$0.0497** / epoch |
| **Subtotal** | Keeper **Direction** round (Manual) | `open` + `lock` + `resolve` per epoch | **3** / epoch | **375907** | **~$0.0564** / epoch |
| **Rolling (Direction)** | `genesisStartRolling` + `genesisLockRolling` | Once per rolling **session** (or after `resetRollingLifecycle`) | **2** (one-time) | **422467** (sum) | **~$0.063** (one-time, illustration) |
| **Rolling (Direction)** | `executeRollingRound` | Steady state: resolve `k-1`, lock `k`, open `k+1` | **1** / interval | **376754** | **~$0.0565** / tick |
| **User** | `claim` | Per **user** × **epoch** (after resolve / void / cancel payout path) | 1 / claim | 44068 | ~$0.0066 / claim |
| **Scale (Manual)** | Monthly keeper (example) | `E` epochs × `T` templates × **3** txs | `3 × E × T` | Threshold ≈ `E × T × 331056` | `E × T × ~$0.0497` exec-only |
| **Scale (Rolling)** | Monthly keeper (steady) | `E` intervals × `T` templates × **1** tx (+ amortize 2 genesis txs / session) | `E × T` (+2) | ≈ `E × T × 376754` | `E × T × ~$0.0565` exec-only |

**Specification reminders**

- **Rounds per template:** unlimited in business terms; on-chain id limit is `uint64` (max epoch id `2^64 − 1`); see [Maximum epoch id](#maximum-epoch-id).
- **Manual mode:** cannot skip epoch ids—next open must be `activeEpochId + 1` after previous epoch is **resolved** or **cancelled**.
- **Rolling mode:** uses `rollingNextEpochId` for opens; after recovery, the next genesis can start at an id **greater than** prior epochs (see [`resetRollingLifecycle`](src/MarketEngine.sol)).
- **Batching:** `openEpochsBatch`, `lockEpochsBatch`, `resolveEpochsBatch`, `executeRollingRoundBatch` reduce per-template **fixed tx overhead** but do not change total on-chain work per epoch/interval.
- **Chainlink:** `lock` / `resolve` (and rolling keeper calls) revert if the on-chain feed is stale relative to `maxDelaySeconds`; no separate “update” tx is required (push oracle).
- **L2:** add **L1 data fee** per transaction to real USD (often larger than execution at low gwei). Rolling cuts keeper **tx count** by ~**3×** vs Manual for the same cadence.

### Worked example: 200 epochs per month (keeper only)

**Assumption:** one **template** runs **200** full market intervals in a month.

- **Manual:** each interval = `openEpoch` + `lockEpoch` + `resolveEpoch` → **3 keeper txs** × `200` = **600** txs.
- **Rolling (Direction, steady state):** each interval = **`executeRollingRound`** → **1** tx × `200` = **200** txs, **plus** a one-time **2-tx** bootstrap (`genesisStartRolling` + `genesisLockRolling`) per session (ignored in the “200 txs” column below for apples-to-apples steady load; add **~420k** gas once).

User `claim` costs are **excluded** (they depend on how many wallets claim).

| Quantity | Value | Notes |
|----------|--------|--------|
| Intervals per month | `200` | Same product cadence; Manual vs Rolling differs by **tx count** and gas profile. |
| Keeper txs (Manual) | `200 × 3 = 600` | Ignores optional `cancelEpoch`. |
| Keeper txs (Rolling steady) | `200 × 1 = 200` | Plus **2** genesis txs per bootstrap session (~**422467** gas total). |
| Gas / epoch (Threshold / RangeClose, Manual) | `331056` | [`.gas-snapshot`](.gas-snapshot) sum: `192308 + 10514 + 128234`. |
| Gas / epoch (Direction, Manual) | `375907` | Sum: `192308 + 56547 + 127052`. |
| Gas / tick (Direction, Rolling steady) | `376754` | `test_gas_rolling_execute_one_tick`. |
| **Total gas / month (Threshold, Manual)** | `66,211,200` | `200 × 331056`. |
| **Total gas / month (Direction, Manual)** | `75,181,400` | `200 × 375907`. |
| **Total gas / month (Direction, Rolling steady)** | `75,350,800` | `200 × 376754` (exclude one-time genesis). |

**Illustrative execution USD** (same basis: **0.05 gwei**, **$3,000** ETH/USD):

`USD_exec ≈ total_gas × 0.05 × 10⁻⁹ × 3000` (= `total_gas × 1.5×10⁻⁷` in USD when ETH = $3000).

| Market type | Execution-only (illustrative) |
|-------------|-------------------------------|
| **Threshold / RangeClose (Manual)** | **~$9.94** |
| **Direction (Manual)** | **~$11.28** |
| **Direction (Rolling, 200 steady ticks)** | **~$11.19** |

**L1 data fees (rollups):** illustrative **$0.03** per keeper tx: **Manual** `600 × $0.03` = **~$18.00**; **Rolling steady** `200 × $0.03` = **~$6.00** (add **2 × $0.03** if counting genesis txs).

**Scaling:** replace `200` with any `E`; execution USD scales ~linearly: Threshold Manual ≈ `E × $0.0497`, Direction Manual ≈ `E × $0.0564`, Rolling steady ≈ `E × $0.0559` at these inputs (plus L1 and oracle).

### Scenario planner: epochs / month, viral-style market ideas, keeper cost

**Pricing basis** (same as above, **execution only**): **0.05 gwei**, **$3,000** ETH. Per interval: **~$0.0497** (Threshold / RangeClose, **Manual**), **~$0.0564** (Direction **Manual**), **~$0.0559** (Direction **Rolling** steady—one tx per interval). **L1 (Manual)** column: **$0.03** × **`3 × E`** keeper txs. **L1 (Rolling)** column: **$0.03** × **`E`** (steady); add **~$0.06** once per session for **2** genesis txs if you budget bootstrap.

**Reality check:** every example below is a **price** market: you need a live Chainlink data feed on your chain for that asset (with `oracleMaxDelaySeconds` aligned to heartbeat). Narrative is marketing; settlement is always oracle math.

| Scenario | Epochs / month (E) | Illustrative cadence | Example `marketType` | Viral / high-shareable angle (crypto-native) | Viral / high-shareable angle (broader / “normie” news) | Keeper exec (Threshold / Range) | Keeper exec (Direction Manual) | Keeper exec (Direction Rolling) | L1 placeholder Manual (`3×E×$0.03`) | L1 placeholder Rolling (`E×$0.03`) |
|----------|-------------------:|----------------------|----------------------|---------------------------------------------|--------------------------------------------------------|--------------------------------:|-------------------------------:|--------------------------------:|-------------------------------------:|----------------------------------:|
| Weekend creator | 4 | ~1× / week | **RangeClose** or **Threshold** | “Did **SOL** finish the week under / over last week’s high?” | “**Gold** weekly close: which bracket—too low / middle / blow-off?” | ~$0.20 | ~$0.23 | — | ~$0.36 | — |
| DAO / community pulse | 12 | ~3× / week | **Threshold** | “**ETH** above **$X** when this **Layer-2** vote snapshot hits?” | “**Oil (WTI)** above **$Y** before the OPEC headline weekend?” | ~$0.60 | ~$0.68 | — | ~$1.08 | — |
| Daily flagship | 30 | ~1× / day | **Direction** | “**BTC** daily: up or down vs lock?” (classic timeline bait) | “**S&P 500** cash session: green or red day?” | — | ~$1.69 | ~$1.68 | ~$2.70 | ~$0.90 |
| Multi-asset hub | 100 | e.g. 10 templates × 10 epochs | Mix (often **Direction** + **Threshold**) | Basket: **BTC** day + **memecoin** bracket + **perp** proxy if fed | **EUR/USD** week + **NVDA** week range + **gold** Fed-day | ~$4.97 | ~$5.64 | ~$5.59 | ~$9.00 | ~$3.00 |
| Heavy schedule | 200 | e.g. automation / many markets | Mix | Perp desk culture: lots of short cycles on majors | Macro week: overlapping FX + index + commodities | ~$9.94 | ~$11.28 | ~$11.19 | ~$18.00 | ~$6.00 |
| “Always-on” app | 500 | high-frequency templates | Mostly **Direction** | 24/7 crypto “up/down” ladders | Cross-asset “session” markets (London/NY) | — | ~$28.2 | ~$28.0 | ~$45.0 | ~$15.0 |

Rounded Direction Rolling ≈ `E × $0.0559`. Rows without Rolling use “—” where the scenario is not Direction rolling.

**`marketType` quick map** (see [`_validateTemplate`](src/MarketEngine.sol)): **Direction** = open vs close price (two outcomes); **Threshold** = price vs a fixed line at resolve; **RangeClose** = close lands in one of several buckets (great for “pick a bracket” social posts).

**Claims:** if a drop goes viral, user `claim` gas scales with **number of claiming wallets × epochs**, not with `E` alone—budget separately for support / claim bots.

## Deployment cost

### Contracts and initialization

Production flow: [`script/Deploy.s.sol`](script/Deploy.s.sol).

1. `new ChainlinkAdapter(sequencerFeed)` (see `SEQUENCER_FEED` env; `address(0)` on L1)
2. Deploy **`MarketEngine`** **implementation** and an **ERC1967 proxy** whose delegatecall target is that implementation, with **`initialize(...)`** calldata passed in the proxy creation path (`Upgrades.deployUUPSProxy`).

Integrations must use the **proxy** address (not the implementation). **`initialize`** is **`initializer`**-protected and runs once when the proxy is created (atomic deploy+init in Foundry Upgrades). Prefer **`forge script … --ffi`** so upgrade-safety validations run. See [currentSmartContract.md](./currentSmartContract.md) for roles and upgrade policy.

### Measuring bytecode and deploy gas

Deploy cost on a given chain depends on **bytecode size**, **calldata**, and **base fee**. Compiler settings change bytecode:

- Default profile: [`foundry.toml`](foundry.toml) — `optimizer_runs = 200`, `via_ir = true`.
- `FOUNDRY_PROFILE=production` — higher `optimizer_runs` (smaller runtime gas, often **larger** bytecode).
- `FOUNDRY_PROFILE=deploybudget` — tuned for smaller bytecode experiments.

Run:

```bash
forge build --sizes
```

Compare profiles as needed. The repo does **not** pin a single mainnet deploy gas number because it varies by chain and compiler profile.

### Deployment cost in USD (how to estimate)

Gas and ETH/USD move constantly; treat any dollar figure as a **snapshot** only. Use live values from your RPC or block explorer.

**Execution cost (EVM gas)**

Let `G` = total gas used for the transaction (deploy script may be ~2–4 txs: `ChainlinkAdapter`, `MarketEngine` implementation, proxy + `initialize`; sum them).

Let `P_wei` = effective gas price in wei per gas (base fee + priority fee on L1, or L2 gas price).

Let `P_ETH` = ETH price in USD.

**Execution-only USD:** multiply ETH spent on gas by `P_ETH`:

`USD_exec = (G * P_wei / 1e18) * P_ETH`

(in other words: gas units × gas price in ETH × ETH/USD).

**Rollups (OP Stack, Arbitrum, etc.)**

Many L2 transactions also charge an **L1 data fee** (calldata/posting to Ethereum). Explorers often show it as “L1 gas” or “L1 fee.” Add:

`USD_total ≈ USD_exec + (L1_fee_ETH * P_ETH)`

Estimate with `eth_estimateGas` / a dry-run deploy on testnet and the explorer’s fee breakdown for a comparable tx.

**Illustrative deployment (not a guarantee)**

| Assumption | Example value |
|------------|----------------|
| Sum of deploy+init gas | `G = 25_000_000` (placeholder—**measure yours** with `forge script … --dry-run` + chain simulation) |
| Gas price | `0.05 gwei` on a low-cost L2 execution layer |
| ETH/USD | `$3,000` |
| L1 data fee | `$2` total for the bundle (placeholder—**highly chain- and calldata-dependent**) |

Execution only: `25_000_000` gas × `0.05 gwei` ≈ `0.00125` ETH × `$3,000`/ETH ≈ **$3.75**. With the example L1 add-on: **~$5.75** for the bundle. Replace every input with current chain data before budgeting.

### Chainlink (operational notes beyond engine gas)

[`ChainlinkAdapter`](src/adapters/ChainlinkAdapter.sol) reads Chainlink **`latestRoundData()`** (view). If `updatedAt` is **stale** relative to `oracleConfig.maxDelaySeconds` / per-template overrides, **`lockEpoch` / `resolveEpoch` revert** until the feed updates (typically via heartbeat or deviation on Chainlink nodes). On **L2**, the adapter also checks the **sequencer uptime feed** before returning a price—budget operational monitoring separately from `.gas-snapshot` numbers.

## Epoch maintenance

### Lifecycle

Per **template** and **epoch**:

1. **`openEpoch`** — creates epoch state, sets schedule (`openAt`, `lockAt`, `resolveAt`).
2. **Betting** — users `depositToSide` / `switchSide` while status is `Open` and `openAt <= now < lockAt`.
3. **`lockEpoch`** — after `lockAt`; for **Direction** markets, writes **checkpoint A** (oracle at lock); always transitions to `Locked`.
4. **`resolveEpoch`** — after `resolveAt`; reads oracle for **checkpoint B**, runs resolution math, moves reserves (`active` → `claims` / `fees`), sets `claimable`.
5. **Users `claim`** — pull payouts or refunds.

Optional: **`cancelEpoch`** (worker/admin) can end an `Open` or `Locked` epoch with a refund-style liability; it still sets `ledger.lastResolvedEpochId` so sequencing can continue.

[`MarketTypes.requiresCheckpointAOnLock`](src/types/MarketTypes.sol) is true only for **`MarketType.Direction`**. For **Threshold** and **RangeClose**, `lockEpoch` does **not** call the oracle; **`resolveEpoch`** performs the oracle read for checkpoint B.

### Who can call what

- **Admin** and **workerAuthority**: `openEpoch`, `lockEpoch`, `resolveEpoch`, `cancelEpoch`, and batch variants (unless `globalPaused` blocks worker ops).
- **Admin** only: `upsertTemplate`, `initializeMarket`, pause, treasury/worker config.
- **Users**: deposits/switches (when not paused), `claim`.

### Batching

[`openEpochsBatch`](src/MarketEngine.sol), [`lockEpochsBatch`](src/MarketEngine.sol), [`resolveEpochsBatch`](src/MarketEngine.sol) amortize fixed per-transaction overhead when one keeper maintains many templates.

### Reference gas (local snapshot)

Summary table (deploy → instance → epoch rounds → scale): see [Cost and specification overview](#cost-and-specification-overview).

Regenerate after code changes:

```bash
forge snapshot --match-contract 'EpochGasTest|MarketEngineRollingTest'
cat .gas-snapshot
```

Approximate numbers from [`.gas-snapshot`](.gas-snapshot) (environment-dependent):

| Path | Gas (`.gas-snapshot`) | Test / notes |
|------|----------------------|----------------|
| `openEpoch` (cold) | 192308 | `EpochGasTest:test_gas_openEpoch_cold` |
| `lockEpoch` (threshold) | 10203 | `test_gas_lockEpoch_threshold` |
| `lockEpoch` (direction) | 56034 | `test_gas_lockEpoch_direction` |
| `resolveEpoch` (threshold) | 128234 | `test_gas_resolveEpoch_threshold` |
| `resolveEpoch` (direction) | 127052 | `test_gas_resolveEpoch_direction` |
| `claim` | 44068 | `test_gas_claim_afterResolve` |
| `genesisStartRolling` | 198312 | `MarketEngineRollingTest:test_gas_genesis_start_rolling` |
| `genesisLockRolling` | 224155 | `MarketEngineRollingTest:test_gas_genesis_lock_rolling` |
| `executeRollingRound` (steady) | 376754 | `test_gas_rolling_execute_one_tick` |

**Monthly rollup-style estimate (Manual):**

`epochs_per_template_per_month × 3 keeper txs × (execution_gas + L1_data_fee_on_OP_Stack) × effective_gas_price`

**Rolling (Direction):** `intervals_per_month × 1 keeper tx` in steady state, plus **2** bootstrap txs per session.


### Keeper and user costs in USD (epoch maintenance)

Use the same execution formula as deployment.

**Manual:** sum gas for **three** keeper txs per epoch (open + lock + resolve), using the snapshot row that matches your `marketType` (**Direction** lock + resolve differ from **Threshold**).

**Rolling (Direction):** steady state is **one** `executeRollingRound` per interval (~**373k** gas); bootstrap once with **genesisStartRolling** + **genesisLockRolling** (~**420k** gas combined).

Approximate **keeper execution gas per epoch / interval** (mock oracle):

| Mode | Formula (snapshot sums) | ~Gas |
|------|-------------------------|------|
| **Manual — Threshold / RangeClose** | `192308 + 10514 + 128234` | **331056** |
| **Manual — Direction** | `192308 + 56547 + 127052` | **375907** |
| **Rolling — Direction (steady)** | `executeRollingRound` | **376754** |

**Illustrative monthly keeper cost, one template (replace inputs)**

- Intervals per month: `E = 30` (e.g. one per day).
- **Threshold Manual:** `G_month ≈ E × 331056 ≈ 9.93M` gas (execution only).
- Execution gas price: `0.05 gwei`, ETH/USD: `$3,000`.
- Execution USD: ≈ **$1.49** / month **before** L1 data fees (`9.94e6 × 1.5×10⁻⁷`).

**L1 data fees** on OP Stack–style L2s often dominate at low execution gas prices. **Manual:** `3 × E` keeper txs (e.g. 90 × ~`$0.03` ≈ **$2.70**). **Rolling steady:** `E` txs (e.g. 30 × ~`$0.03` ≈ **$0.90**). Measure on your target chain.


**User `claim`**: Per-claim execution cost scales with users, not templates. Example: **44068** gas at `0.05 gwei` and `$3,000` ETH ≈ **$0.0066** per claim (plus L1 fee on L2 rollups), excluding congestion spikes.

Always recompute with: current `G` from [`.gas-snapshot`](.gas-snapshot), live gas price, `ETH/USD`, explorer L1 fee, and `forge snapshot` after contract changes.

## Maximum epoch id

- There is **no** configurable “max epochs” cap in the contract.
- Epoch ids are **`uint64`**. After [`initializeMarket`](src/MarketEngine.sol), `activeEpochId` and `lastResolvedEpochId` start at `0`.

**Manual mode:** the **first** opened epoch uses **`epochId == 1`**. [`_requireCanOpenNextEpoch`](src/MarketEngine.sol) enforces `ledger.activeEpochId == ledger.lastResolvedEpochId` and `epochId == ledger.activeEpochId + 1`.

**Rolling mode:** the first open uses **`ledger.rollingNextEpochId`** (initialized to **`1`**). After a halted recovery, [`resetRollingLifecycle`](src/MarketEngine.sol) can set **`rollingNextEpochId`** to any fresh id **above** existing epochs so re-genesis does not collide with storage.

**Theoretical upper bound:** the last openable epoch id is **`2^64 - 1`**. After that epoch is resolved, `activeEpochId + 1` would be **`2^64`**, which **overflow-reverts** in Solidity 0.8, so **no further epoch can be opened** on that template without an **implementation upgrade** (or new deployment) that extends sequencing. This is a numeric identifier limit, not a practical product ceiling.

**Practical scaling:** each `(templateId, epochId)` retains a full [`MarketTypes.Epoch`](src/types/MarketTypes.sol) in storage; positions are keyed by `(templateId, epochId, user)`. History is **not** pruned on-chain.

## Creating a market instance (checklist)

1. **Deploy stack** (once per chain/environment): `ChainlinkAdapter` + UUPS **proxy** for `MarketEngine` + `initialize` with your `stakeToken`, oracle adapter, `admin`, `treasury`, `workerAuthority`, fee caps, `maxOutcomes` (≤ 8), and oracle limits. See [README.md](./README.md) env table and [`Deploy.s.sol`](script/Deploy.s.sol).

2. **Compute `templateId`**: `bytes32 templateId = engine.templateIdFromSlug("your-slug");` (or `keccak256(bytes("your-slug"))` off-chain).

3. **Admin: `upsertTemplate(UpsertTemplateParams)`**
   - `slug`: non-empty, max length [`SLUG_MAX_LEN`](src/types/MarketTypes.sol) (32 bytes).
   - `assetSymbol`: non-empty, max [`ASSET_SYMBOL_MAX_LEN`](src/types/MarketTypes.sol) (16).
   - `oracleFeedId`: Chainlink feed proxy encoded as `bytes32(uint256(uint160(proxy)))` (must decode to non-zero address).
   - `switchFeeBps` ≤ engine’s `maxSwitchFeeBps`; settlement fee ≤ 10_000 bps.
   - `outcomeCount` between `1` and engine `maxOutcomes` (see validation below).
   - `executionMode`: **`Manual`** (default) or **`Rolling`**; if **`Rolling`**, set `rollingIntervalSeconds` and `rollingBufferSeconds` (`buffer < interval`) and use **Direction** only—see [Rolling execution mode](#rolling-execution-mode-keeper-cost-reduction).
   - On upsert, [`equalPriceVoids`](src/MarketEngine.sol) and [`feeOnLosingPool`](src/MarketEngine.sol) are forced **true** (Anchor parity).

4. **Admin: `initializeMarket(templateId)`** once per template. Reverts if ledger already initialized.

5. **Start epochs (pick one)**  
   - **Manual:** **Worker/admin: `openEpoch(...)`** with `openAt < lockAt < resolveAt`, template **active**, and **`epochId == ledger.activeEpochId + 1`** (first call: `1`). Then **`lockEpoch` / `resolveEpoch`** on schedule.  
   - **Rolling (Direction):** **`genesisStartRolling(templateId)`** → after the betting window for epoch 1, **`genesisLockRolling(templateId)`** inside the lock buffer → repeat **`executeRollingRound(templateId)`** each interval (within buffers). Do **not** call manual `openEpoch` / `lockEpoch` / `resolveEpoch` on that template.

6. **Operate:** manual path as today; rolling path as in [Rolling execution mode](#rolling-execution-mode-keeper-cost-reduction). Oracle must satisfy staleness and confidence ([`_enforceConfidence`](src/MarketEngine.sol)).

7. **Fees**: treasury or admin may `withdrawFees` per template from the fee bucket when reserves allow.

### Template validation rules ([`_validateTemplate`](src/MarketEngine.sol))

| `marketType` | `outcomeCount` | `thresholdRule` | Other |
|--------------|----------------|-----------------|-------|
| **Direction** | Must be **2** | Must be **`None`** | Opening price at lock, close at resolve; equal move can void (`equalPriceVoids` true). |
| **Threshold** | Must be **2** | Must be **`Absolute`** | `absoluteThresholdValueE8` used with `condition` at resolve. |
| **RangeClose** | **≥ 2** | (not restricted the same way) | `rangeBoundsE8[0 .. outcomeCount-2]` must be **strictly increasing**. |

For exact bound indexing, see the validation loop in [`MarketEngine.sol`](src/MarketEngine.sol).

---

## Appendix: PancakePredictionV3-style contracts (Chainlink, one tx per round)

This section is **not** the RetroPick `MarketEngine`; it analyzes a common **binary bull/bear** contract pattern (e.g. [`reference/PancakePredictionV3.sol`](reference/PancakePredictionV3.sol): Chainlink `AggregatorV3Interface`, operator-driven rounds). Use it to sanity-check **cost and oracle feasibility** when cadence is aggressive (e.g. “5‑minute BTC”).

### How operator work differs from RetroPick

| | Pancake-style (pasted reference) | RetroPick `MarketEngine` |
|---|----------------------------------|---------------------------|
| Oracle | Chainlink `latestRoundData`, monotonic `roundId` | Chainlink (normalized to e8) via `IPriceOracle` / [`ChainlinkAdapter`](src/adapters/ChainlinkAdapter.sol) |
| Txs **per closed round** | **1×** `executeRound()` (after genesis: locks one epoch, ends previous, calculates rewards, starts next) | **Manual:** **3×** `openEpoch` + `lockEpoch` + `resolveEpoch`. **Rolling (Direction):** **1×** `executeRollingRound` in steady state (+ **2×** genesis txs per session). |
| User bets | `betBull` / `betBear` on current `currentEpoch` | `depositToSide` / `switchSide` |
| Contract-bound “5 min” | Set `intervalSeconds = 300` (and `bufferSeconds < intervalSeconds`); timing in `_startRound` / `_safeLockRound` | **Manual:** schedule `openAt` / `lockAt` / `resolveAt`. **Rolling:** `rollingIntervalSeconds` / `rollingBufferSeconds` on the template. |

### Rounds per month at ~5‑minute cadence

Using a **30‑day** month:

`30 × 24 × 60 / 5 = 8,640` **operator** calls of `executeRound` (ignoring missed blocks and genesis setup).

One-time genesis: `genesisStartRound` + `genesisLockRound` (operator) before the steady loop—negligible vs monthly volume.

### Oracle risk (often tighter than gas)

`_getPriceFromOracle()` requires **`roundId > oracleLatestRoundId`** on every `executeRound`. So each successful call needs a **new** Chainlink round since the last execution. On many feeds, `roundId` advances on heartbeat / deviation, **not** every wall‑clock minute. **A 5‑minute operator schedule can revert** if Chainlink has not updated yet—budget **fewer effective rounds** or a feed/chain with update frequency that matches your product, not just gas.

Also ensure `oracleUpdateAllowance` is configured consistently with how you interpret Chainlink’s `updatedAt` (the contract checks it against `block.timestamp + oracleUpdateAllowance`).

### Monthly cost illustration (operator only)

Same **illustrative** L2-style inputs as elsewhere: **0.05 gwei** execution, **$3,000** ETH/USD, plus **$0.03** L1-style fee **per operator tx** (placeholder).

Let `G_ex` = gas per `executeRound` (**measure** on your chain; typical complex oracle+storage paths often fall in **~150k–350k** without profiling).

| Quantity | Formula | Example `G_ex = 200k` | Example `G_ex = 300k` |
|----------|---------|----------------------|----------------------|
| Operator txs / month | `8640` | 8640 | 8640 |
| Total execution gas | `8640 × G_ex` | `1.73×10^9` | `2.59×10^9` |
| Execution USD | `gas × 0.05 gwei × $3000/ETH` | **~$259** | **~$389** |
| + L1 placeholder | `8640 × $0.03` | **~$259** | **~$259** |
| **Rough total (illus.)** | exec + L1 | **~$518** | **~$648** |

**RetroPick comparison at same 8,640 intervals (Direction):**

- **Manual** (3 txs / interval): **375907** gas / epoch × `8640` ≈ **3.25×10⁹** execution gas → **~$487** execution-only at 0.05 gwei / $3k ETH (before L1).
- **Rolling** (1 tx / interval in steady state): **376754** gas × `8640` ≈ **3.26×10⁹** execution gas → **~$488** execution-only—similar **per-interval** execution to Manual’s **sum of three txs**, but **one keeper transaction** per tick like Pancake.

Versus a **200k** gas Pancake `executeRound` × `8640` (**1.73×10⁹** gas, **~$259** exec-only), RetroPick Direction paths use **~1.9×** the execution gas per interval in these snapshots (more accounting, oracle adapter call, pro-rata settlement)—**measure your build**.

**L1 placeholders:** RetroPick **Manual** `8640 × 3 × $0.03` ≈ **$777**; **Rolling** `8640 × $0.03` ≈ **$259** (same order as single-tx Pancake cadence for tx count).

**Deployments:** contract + ChainlinkAdapter addresses are extra one-time costs; not included above.

**Users:** `claim` / bets are separate gas paid by players (and `notContract` / `tx.origin` restrictions affect who can participate).

---

## Upgrade runbook (UUPS)

- **Who**: on-chain **`admin`** (authorizes `_authorizeUpgrade` on the implementation when called via the proxy).
- **How**: deploy a new `MarketEngine` implementation, then run [`script/UpgradeMarketEngine.s.sol`](../script/UpgradeMarketEngine.s.sol) with `PROXY_ADDRESS` set to the **proxy** users interact with. Use `--ffi` so OpenZeppelin upgrade checks run; dry-run with `forge script … -vvvv` before `--broadcast`.
- **Smoke checks** (proxy address): `cast call $PROXY "admin()(address)"`, `cast call $PROXY "stakeToken()(address)"`, and a sample `templates` / `epochs` read. Always verify **implementation** changed with `cast call $PROXY "proxiableUUID()(bytes32)"` / explorer “Read as Proxy” if available.

## See also

- [README.md](./README.md) — build, snapshot command, deploy commands.
- [currentSmartContract.md](./currentSmartContract.md) — contract inventory and upgrade policy.
- [AUDIT_SOLIDITY.md](./AUDIT_SOLIDITY.md) — roles, oracle trust, token assumptions.
