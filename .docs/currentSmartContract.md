# RetroPick `MarketEngine` (rolling rounds prediction markets) — technical reference

## Breaking Migration Notice (Threshold-Type Consolidation)

The market taxonomy has been simplified with a **breaking change**:

- Removed enum variants: `Anchor`, `VolatilityBand`, `StakingAPR`, `BitcoinIRC`, `NAVThreshold`, `MacroEvent`
- Consolidated into canonical types:
  - `Threshold` absorbs threshold-style variants
  - `Direction` absorbs direction-style BitcoinIRC behavior
  - Specialized non-threshold families remain separate (`Velocity`, `Ladder`, `Convergence`, `Composite`, `Corridor`, `Cascade`, `RangeClose`)

Old-to-new mapping:
- `Anchor` -> `Threshold` (`anchorPriceE8` used as effective threshold when set)
- `VolatilityBand` / `StakingAPR` -> `Threshold` + `oracleClass=CHAINLINK_RATE`
- `NAVThreshold` -> `Threshold` + `oracleClass=CHAINLINK_SMARTDATA`
- `MacroEvent` -> `Threshold` + `oracleClass=CHAINLINK_MACRO`
- `BitcoinIRC` threshold mode -> `Threshold` + `oracleClass=CHAINLINK_RATE`
- `BitcoinIRC` direction mode -> `Direction` + `oracleClass=CHAINLINK_RATE`

This is the deep, code-accurate documentation for the current Solidity implementation under the modular dispatcher architecture in [`src/engine/MarketEngineDispatcher.sol`](../src/engine/MarketEngineDispatcher.sol) and [`src/engine/modules/`](../src/engine/modules/). It focuses on: storage model, epoch/round lifecycle, rolling execution, oracle checkpoints (Chainlink + trusted reporter), **all `MarketType` variants**, keeper behavior, deployment topology, and measured gas from [`.gas-snapshot`](../.gas-snapshot). File paths in code references are relative to the **repository root** (the `contract/` package). For a **rolling-only** deep dive (genesis, single-sample resolve+lock link, feed alignment, halt reasons), see [`rollingMarket.md`](../rollingMarket.md).

> Migration note: the historical monolith lives under [`.docs/legacyEngine.sol`](./legacyEngine.sol) for diff/reference only. Production paths use [`MarketEngineDispatcher`](../src/engine/MarketEngineDispatcher.sol) + [`src/engine/modules/`](../src/engine/modules/).

## Glossary

- **Template**: A market definition keyed by `templateId`.
- **Epoch**: One full market cycle (open → lock → resolve → claim). In product language this is often called a “round.”
- **Ledger**: Per-template cursor + reserve accounting + rolling lifecycle state.
- **Checkpoint A**: Oracle sample at **lock** when `MarketTypes.requiresCheckpointAOnLock` is true (Direction, Velocity, Convergence, Composite on **Chainlink** paths).
- **Checkpoint B**: Primary oracle sample at **resolve** (close / settlement scalar in `checkpointB.valueE8` for most types).
- **Checkpoint A\_B / B\_B**: Second-feed lock/resolve samples for **Convergence** (Chainlink).
- **Composite checkpoints**: Per-feed A/B arrays for **Composite** (Chainlink).
- **OHLC fields**: `epochHighE8`, `epochLowE8`, `ohlcWritten` for **Corridor** / **Cascade** when resolved via **TrustedReporter** + `IEventOracle.getOhlcResult`.
- **Manual**: Keeper runs discrete `openEpoch` / `lockEpoch` / `resolveEpoch`.
- **Rolling**: Pancake-style pipeline: one keeper call advances resolve + lock + open per interval.

## 0) End-to-end operations: deploy → new template → settlement → treasury

This is the **operator narrative** for the current codebase. Every call uses the **same UUPS proxy address**; the proxy’s `fallback` `delegatecall`s into a **module** chosen by `msg.sig` ([`MarketEngineDispatcher`](../src/engine/MarketEngineDispatcher.sol)). Shared storage is defined once in [`MarketEngineState`](../src/engine/MarketEngineState.sol); modules only supply code.

### 0.1 Cold deploy (one protocol instance on a chain)

1. Deploy [`ChainlinkAdapter`](../src/adapters/ChainlinkAdapter.sol) (sequencer feed address or `address(0)` on L1).
2. Optionally deploy [`TrustedReporterAdapter`](../src/oracle/TrustedReporterAdapter.sol) for templates with `templateOracleKind == TrustedReporter` (`eventOracle` on the template points here; not used as `priceOracle` on `initialize`).
3. Deploy **`MarketEngineDispatcher`** behind an ERC-1967 UUPS proxy with `initialize(...)` in the initializer path ([`script/production/DeployProduction.s.sol`](../script/production/DeployProduction.s.sol) for production and [`script/test/DeployTestnet.s.sol`](../script/test/DeployTestnet.s.sol) for testnet, both using OpenZeppelin Foundry Upgrades with **`--ffi`** validation).
4. In the same broadcast, deploy **five module contracts** and register each public entrypoint with `setSelectorModule(selector, module, immutableFlag)` on the **proxy**:
   - [`MarketEngineAdminModule`](../src/engine/modules/MarketEngineAdminModule.sol) — `pauseProgram`, `setTreasury` / `setWorkerAuthority`, `setDepositExecutor`, `setYieldRouter` / `setLmRewardsEnabled`, `setRateOracle` / `setSmartDataOracle` / `setMacroOracle` / `setEquityOracle`, `keeperClaimLmRewards`, `yieldEmergencyWithdraw`, `initializeMarket`, `withdrawFees`
   - [`MarketEngineCoreLifecycleModule`](../src/engine/modules/MarketEngineCoreLifecycleModule.sol) — `upsertTemplate`, manual `openEpoch` / `lockEpoch` / `resolveEpoch` (+ batches), `cancelEpoch` (when rolling is not `Live`)
   - [`MarketEngineRollingLifecycleModule`](../src/engine/modules/MarketEngineRollingLifecycleModule.sol) — `genesisStartRolling`, `genesisLockRolling`, `executeRollingRound` (+ batch), `haltRollingMarket`, `cancelRollingEpochWhileHalted`, `resetRollingLifecycle`
   - [`MarketEngineUserOpsClaimsModule`](../src/engine/modules/MarketEngineUserOpsClaimsModule.sol) — `depositToSide`, `depositToSideFor`, `switchSide`, `claim`, `claimMany`
   - [`MarketEngineViewModule`](../src/engine/modules/MarketEngineViewModule.sol) — `getUserEpochs`, `getVaultBalances`, `getRollingLifecycle`, `getEpoch`

Selectors not mapped revert with `ModuleNotSet(selector)`. The dispatcher **keeps** `initialize`, `upgradeToAndCall`, `proxiableUUID`, and `setSelectorModule` on the root contract (not delegated).

A full selector matrix lives in [`.docs/migrations/marketengine_selector_matrix.md`](./migrations/marketengine_selector_matrix.md).

### 0.2 Optional: Aave yield router

1. Deploy [`YieldRouterV2`](../src/yield/YieldRouterV2.sol) (or [`YieldRouterAaveV3`](../src/yield/YieldRouterAaveV3.sol) implementing the same [`IYieldRouterV2`](../src/interfaces/IYieldRouterV2.sol)).
2. **`admin`** on the engine: `setYieldRouter(router, yieldFeeBps)`. Clearing the router zeroes `yieldFeeBps` and disables LM claims.
3. **Router owner** (separate from engine admin): register each `templateId` and optional Stata path per router docs.

### 0.3 Launching a new market (template)

| Step | Actor | Call | Result |
|------|-------|------|--------|
| 1 | `admin` | `upsertTemplate` | Writes `_templates[templateId]` with type, oracle `feedId`, fees, execution mode, rolling timings, etc. `templateId = keccak256(bytes(slug))`. |
| 2 | `admin` | `initializeMarket(templateId)` | Sets `ledger.initialized = true`, `rollingNextEpochId = 1`, rolling phase `Uninitialized`. No epochs yet. |

Then either **manual** `openEpoch(...)` or **rolling** `genesisStartRolling` begins user-facing rounds.

### 0.4 Where protocol revenue accumulates

- **`ledger.feeReserveTotal`** and **`_vaults[templateId].fees`** track amounts reserved for the protocol (switch fees, settlement fees, yield fee slice, and certain yield surpluses — see §13.5).
- **`withdrawFees(templateId, amount)`** ([`MarketEngineAdminModule`](../src/engine/modules/MarketEngineAdminModule.sol)): **`treasury` or `admin`** may pull `stakeToken` to the configured **`treasury`** address; accounting uses [`MarketMath.releaseFeeOnWithdraw`](../src/math/MarketMath.sol).

Claims draw from **`claimsReserveTotal`** / `vaults.claims`, not from fee reserves.

### 0.5 Flow diagram (high level)

```mermaid
flowchart LR
  subgraph d [Deploy]
    AD[ChainlinkAdapter]
    PX[Dispatcher proxy]
    MD[Module wireup]
  end
  subgraph m [Market]
    T[upsertTemplate]
    I[initializeMarket]
  end
  subgraph e [Epochs]
    K[keeper: open or rolling tick]
    U[users: deposit / switch]
  end
  subgraph s [Settlement]
    R[resolve + oracle]
    CL[claims]
  end
  subgraph rev [Treasury]
    FR[feeReserveTotal]
    WF[withdrawFees to treasury]
  end
  AD --> PX
  MD --> PX
  PX --> T --> I --> K
  U --> K
  K --> R --> CL
  R --> FR --> WF
```

## 1) What is deployed

### 1.1 One engine, many markets

RetroPick deploys **one** UUPS proxy whose implementation is [`MarketEngineDispatcher`](../src/engine/MarketEngineDispatcher.sol). The **proxy address** is the engine; execution is delegated to modules, but **all storage** is the single layout in [`MarketEngineState`](../src/engine/MarketEngineState.sol) (templates, ledgers, epochs, positions, vault mirrors, yield router pointer, selector routing).

The engine computes:

- `templateId = keccak256(bytes(slug))`
- `positionKey = keccak256(abi.encodePacked(templateId, epochId))`

```190:196:src/engine/MarketEngineState.sol
    function templateIdFromSlug(string memory slug) public pure returns (bytes32) {
        return keccak256(bytes(slug));
    }

    function positionKey(bytes32 templateId, uint64 epochId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(templateId, epochId));
    }
```

### 1.2 Oracle adapters and routing

The engine supports a multi-adapter Chainlink family:

- [`ChainlinkAdapter`](../src/adapters/ChainlinkAdapter.sol) (`CHAINLINK_PRICE`)
- [`RateAdapter`](../src/oracle/RateAdapter.sol) (`CHAINLINK_RATE`)
- [`SmartDataAdapter`](../src/oracle/SmartDataAdapter.sol) (`CHAINLINK_SMARTDATA`)
- [`MacroAdapter`](../src/oracle/MacroAdapter.sol) (`CHAINLINK_MACRO`)
- [`EquityAdapter`](../src/oracle/EquityAdapter.sol) (`CHAINLINK_EQUITY`)

At template level, `oracleClass` selects which adapter is used for reads. Routing is resolved by [`MarketEngineState._resolveOracle`](../src/engine/MarketEngineState.sol):

- `CHAINLINK_RATE` → `rateOracle` (must be configured)
- `CHAINLINK_SMARTDATA` → `smartDataOracle` (must be configured)
- `CHAINLINK_MACRO` → `macroOracle` (must be configured)
- `CHAINLINK_EQUITY` → `equityOracle` (must be configured)
- otherwise defaults to `priceOracle` (`CHAINLINK_PRICE`)

Admin configures non-default adapters through `setRateOracle`, `setSmartDataOracle`, `setMacroOracle`, and `setEquityOracle` on [`MarketEngineAdminModule`](../src/engine/modules/MarketEngineAdminModule.sol).

The common price-feed behavior is inherited from the Chainlink adapter surface implementing [`IPriceOracle`](../src/interfaces/IPriceOracle.sol) over Chainlink [`AggregatorV3Interface`](../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol). For [`ChainlinkAdapter`](../src/adapters/ChainlinkAdapter.sol):

- Decodes `feedId` as a Chainlink **proxy address**: `address(uint160(uint256(feedId)))`.
- Reads `latestRoundData()`, enforces round completeness, positive `answer`, and staleness against `maxAgeSeconds` using `updatedAt`.
- Normalizes `answer` with `decimals()` to **e8** (same scale as the rest of the engine).
- Returns `confidenceE8 = 0` (no Chainlink confidence band).
- On **L2**, checks the Chainlink **sequencer uptime feed** passed in the adapter constructor; on **L1** pass `sequencerFeed = address(0)` to skip. Grace-period behavior follows [Chainlink L2 sequencer feeds](https://docs.chain.link/data-feeds/l2-sequencer-feeds) (`timeSinceUp <= 3600` reverts until strictly after the grace window).
- **Optional round ID surface**: the adapter also implements [`IPriceOracleWithRoundId`](../src/interfaces/IPriceOracleWithRoundId.sol) with `getNormalizedPriceWithRoundId(...)`, returning the Chainlink `roundId` from `latestRoundData()` alongside the normalized price. The engine uses this (when the cast succeeds) for **monotonic oracle cursor** checks per `(templateId, feedId)` plus `EpochLockedV2` / `EpochResolvedV2` events (see §9.4). If the oracle does not implement the extension, the engine falls back to `getNormalizedPrice` only.

```32:60:src/adapters/ChainlinkAdapter.sol
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64)
        external
        view
        override
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8)
    {
        _checkSequencer();

        address feedAddr = address(uint160(uint256(feedId)));
        if (feedAddr == address(0)) revert InvalidFeedAddress();

        AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();

        if (answeredInRound < roundId) revert RoundNotComplete(roundId, answeredInRound);
        if (answer <= 0) revert InvalidPrice();
        if (updatedAt == 0) revert InvalidPrice();

        if (block.timestamp - updatedAt > uint256(maxAgeSeconds)) {
            revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), block.timestamp);
        }

        uint8 d = feed.decimals();
        priceE8 = _normalizeToE8(answer, d);
        publishTime = uint64(updatedAt);
        confidenceE8 = 0;
    }
```

### 1.3 Deployment topology (UUPS proxy + modules)

Canonical deploy scripts (both with **`--ffi`** for OpenZeppelin upgrades checks):
- production: [`script/production/DeployProduction.s.sol`](../script/production/DeployProduction.s.sol)
- testnet: [`script/test/DeployTestnet.s.sol`](../script/test/DeployTestnet.s.sol) (supports optional faucet deployment via `DEPLOY_FAUCET=1`)

1. Reads env: `STAKE_TOKEN`, `SEQUENCER_FEED` (`address(0)` on L1), `ADMIN`, `TREASURY`, `WORKER`, fee caps, oracle globals.
2. Deploys `ChainlinkAdapter(sequencerFeed)` plus `RateAdapter`, `SmartDataAdapter`, `MacroAdapter`, and `EquityAdapter`.
3. Deploys a **UUPS proxy** for **`MarketEngineDispatcher`** with `initialize(IERC20,IPriceOracle,admin,treasury,worker,...)` (`OracleKind.Chainlink`).
4. Deploys the five module contracts and calls `setSelectorModule` on the proxy for each routed function selector (admin / core lifecycle / rolling / user+claims / view).
5. Sets non-default oracle adapters via `setRateOracle`, `setSmartDataOracle`, `setMacroOracle`, and `setEquityOracle`.
6. Optionally deploys [`TrustedReporterAdapter`](../src/oracle/TrustedReporterAdapter.sol) when `TRUSTED_REPORTER` is provided; TrustedReporter is selected later per template (`templateOracleKind=TrustedReporter` + `eventOracle`).

Core fragment:

```70:98:script/production/DeployProduction.s.sol
        ChainlinkAdapter adapter = new ChainlinkAdapter(sequencerFeed);

        bytes memory initData = abi.encodeCall(
            MarketEngineDispatcher.initialize,
            (
                IERC20(stakeToken),
                IPriceOracle(address(adapter)),
                admin,
                treasury,
                worker,
                defFee,
                maxSw,
                maxOut,
                MarketTypes.OracleKind.Chainlink,
                delay,
                conf
            )
        );

        Options memory opts;
        address proxy =
            Upgrades.deployUUPSProxy("engine/MarketEngineDispatcher.sol:MarketEngineDispatcher", initData, opts);

        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));
        address adminModule = address(new MarketEngineAdminModule());
        address viewModule = address(new MarketEngineViewModule());
        address userOpsClaimsModule = address(new MarketEngineUserOpsClaimsModule());
        address coreLifecycleModule = address(new MarketEngineCoreLifecycleModule());
        address rollingLifecycleModule = address(new MarketEngineRollingLifecycleModule());
```

The script continues with `dispatcher.setSelectorModule(...)` for every entrypoint (see §0.1). Modular wiring-only scripts: [`script/modular/`](../script/modular/).

## 2) Roles and pause model

The engine has three operational roles:

- **`admin`**: governance / multisig. Can upsert templates, initialize markets, pause/unpause, set treasury/worker, and authorize upgrades.
- **`workerAuthority`**: keeper/operator. Can open/lock/resolve/cancel (manual) or run rolling keepers (rolling) when not paused.
- **`treasury`**: fee receiver. Can withdraw accrued fees.

User-facing operations (`depositToSide`, `depositToSideFor`, `switchSide`, `claim`, `claimMany`) are separate from worker ops (`openEpoch`/`lockEpoch`/`resolveEpoch`/rolling keepers) and are gated by `globalPaused` checks in the relevant modules (same storage on the proxy).

## 3) Storage model (Template / Ledger / Epoch / Position)

The engine’s core structs are in [`src/types/MarketTypes.sol`](../src/types/MarketTypes.sol).

### 3.1 Template

Canonical struct: [`src/types/MarketTypes.sol`](../src/types/MarketTypes.sol) (`Template`).

**Identity & fees**

- `slug`, `assetSymbol` (length limits `SLUG_MAX_LEN`, `ASSET_SYMBOL_MAX_LEN`)
- `marketType` (canonical enum in code): `Direction`, `Threshold`, `RangeClose`, `Velocity`, `Ladder`, `Convergence`, `Composite`, `Corridor`, `Cascade` — see §1 breaking notice for how legacy names map onto **`Threshold`** + `oracleClass` / **`Direction`**, and **`anchorPriceE8`** on Threshold
- `condition` (`AtOrAbove` / `Below`), `thresholdRule` (`None` / `Absolute`) — validated per type
- `outcomeCount` (≤ `MAX_OUTCOMES` = 8)
- `switchFeeBps`, `settlementFeeBps`
- `equalPriceVoids`, `feeOnLosingPool` — **currently forced** in `upsertTemplate` to `true` / `true` for all templates ([`MarketEngineCoreLifecycleModule`](../src/engine/modules/MarketEngineCoreLifecycleModule.sol))
- `allowMultiSidePositions`

**Execution mode**

- `executionMode`: `Manual` or `Rolling`
- If `Rolling`: `rollingIntervalSeconds`, `rollingBufferSeconds` (must satisfy `buffer < interval`)

**Oracle routing (per template)**

- `templateOracleKind`: `Chainlink` or `TrustedReporter`
- `oracleClass`: `CHAINLINK_PRICE`, `CHAINLINK_RATE`, `CHAINLINK_SMARTDATA`, `CHAINLINK_MACRO`, `CHAINLINK_EQUITY` (only meaningful on Chainlink templates; TrustedReporter templates route via `eventOracle`)
- `oracleFeedId`: for **Chainlink**, feed id passed to `IPriceOracle` (typically `bytes32(uint256(uint160(proxy)))`). For **TrustedReporter**, must be **zero** at upsert.
- `eventOracle`: for **TrustedReporter**, address of [`IEventOracle`](../src/interfaces/IEventOracle.sol) (e.g. [`TrustedReporterAdapter`](../src/oracle/TrustedReporterAdapter.sol)). For **Chainlink**, must be **zero**.

**Type-specific parameters**

- `absoluteThresholdValueE8`: **Threshold** (scalar vs `checkpointB`); also copied onto **Composite** epochs as legacy default for per-feed thresholds
- `anchorPriceE8`: on **Threshold** templates, if non-zero at open, settlement uses this as the effective threshold instead of `absoluteThresholdValueE8` ([`SettlementLogic.compute`](../src/logic/SettlementLogic.sol)); snapshots only when non-zero ([`_snapshotEpochTemplateMarketConfig`](../src/engine/MarketEngineState.sol))
- `rangeBoundsE8[RANGE_BOUNDS_LEN]`: strictly increasing interior bounds for bucketed types (`RangeClose`, `Ladder`, `Corridor`, `Cascade`, etc.)
- `cascadeDownward`: **Cascade** direction flag (`false` = upward breaks via high watermark, `true` = downward breaks via low watermark)
- `velocityBoundsE4[RANGE_BOUNDS_LEN]`: **Velocity** (bps-style bins; see §4)
- `ladderBoundsE8[]`, `ladderPayoutWeightsBps[MAX_OUTCOMES]`: **Ladder**
- `oracleFeedIdB`, `spreadToleranceBps`: **Convergence**
- `compositeFeedIds[4]`, `compositeConditions[4]`, `compositeFeedCount`, `compositeLogic` (`And` / `Or` / `Majority`), `compositeAbsoluteThresholdsE8[4]`: **Composite** — per-feed thresholds when any leg non-zero; if **all** legs zero for `i < compositeFeedCount`, every leg uses `absoluteThresholdValueE8` ([`SettlementLogic.compute`](../src/logic/SettlementLogic.sol))

**Oracle tuning (epoch snapshot)**

- `oracleMaxDelaySeconds`, `oracleMaxConfidenceBps` — `0` means inherit global `oracleConfig` at effective time

### 3.2 Ledger

Important ledger fields:

- `activeEpochId`: “current” epoch for deposits/switches
- `lastResolvedEpochId`: last epoch id that has completed (resolved/cancelled/voided)
- rolling state: `rollingPhase`, `rollingHaltReason`, `rollingNextEpochId`, `haltedAtEpochId`
- reserve totals tracked by `MarketMath` (active collateral vs claims/fees reserves)

Rolling lifecycle enums:

```106:122:src/types/MarketTypes.sol
    enum RollingPhase {
        Uninitialized,
        GenesisOpen,
        Live,
        Halted
    }

    enum RollingHaltReason {
        NoneReason,
        BufferMissOnLock,
        BufferMissOnResolve,
        OracleFailure,
        OracleConfidenceWide,
        ManualAdmin
    }
```

### 3.3 Epoch

Each `(templateId, epochId)` stores one `MarketTypes.Epoch` struct with:

- timings: `openAt`, `lockAt`, `resolveAt` (in `timing`)
- status: `Open` → `Locked` → `Resolved` (or `Cancelled` / `Voided`)
- oracle checkpoints: `checkpointA`, `checkpointB`; plus `checkpointA_B`, `checkpointB_B` (Convergence); `compositeCheckpointsA[4]`, `compositeCheckpointsB[4]` (Composite)
- OHLC: `epochHighE8`, `epochLowE8`, `ohlcWritten` (Corridor / Cascade with TRO)
- pools: `outcomePools[]`, `totalPool`
- settlement outputs: `winningOutcomeMask`, `claimLiabilityTotal`, `settlementFeeTotal`, `refundMode`, `claimable`, `remainingWinningStake`, `claimedTotal`
- snapshot of template fields needed for resolve: `marketType`, `condition`, fees, bounds, anchor/velocity/ladder/composite fields, `templateOracleKind`, `oracleClass`, `eventOracle`, `cascadeDownward`, etc.

Status enum:

```76:83:src/types/MarketTypes.sol
    enum EpochStatus {
        Scheduled,
        Open,
        Locked,
        Resolved,
        Cancelled,
        Voided
    }
```

### 3.4 Position

Positions are stored as:

- `positions[positionKey(templateId, epochId)][user]`

Each position holds per-outcome stakes (`stakes[8]`) and `totalStake`, plus fees paid, claimed amount, and claimed flag.

### 3.5 User participation index and oracle round tracking (engine-only)

Beyond `MarketTypes` structs, the engine keeps:

- **`_userEpochs`**: `mapping(bytes32 templateId => mapping(address user => uint64[] epochIds))` — Pancake-style **on-chain** list of epoch ids in which a user has ever opened a position (first successful `_depositToSide` that initializes their position for that epoch). Subsequent deposits in the same epoch do **not** append a duplicate id. The beneficiary of `depositToSideFor` is indexed, not `msg.sender`.
- **`lastOracleRoundIdByTemplate`** and **`lastOracleCursorByTemplateFeed`**: when using [`IPriceOracleWithRoundId`](../src/interfaces/IPriceOracleWithRoundId.sol), lifecycle modules enforce **monotonic oracle progression** (see §9.4). Round ids are **not** stored inside `OracleCheckpoint`.
- **Dispatcher routing**: `selectorToModule`, `selectorImmutable` (after yield-router fields in [`MarketEngineState`](../src/engine/MarketEngineState.sol)).
- **UUPS storage gap**: `uint256[45] __gap` at the end of `MarketEngineState` (append-only discipline for upgrades).

View helper for UIs/indexers without an off-chain indexer:

- `getUserEpochs(templateId, user, cursor, size)` returns a slice of `epochIds` and `nextCursor` for pagination.

Event emitted once per `(templateId, epochId, user)` when the user is first indexed: `UserEpochIndexed`.

## 4) Market types and settlement semantics

After `checkpointB` is written and routed yield is netted into the epoch pool, both lifecycles call **`SettlementLogic.compute`** ([`src/logic/SettlementLogic.sol`](../src/logic/SettlementLogic.sol)) from the respective `_finishResolveEpoch` implementations in [`MarketEngineCoreLifecycleModule`](../src/engine/modules/MarketEngineCoreLifecycleModule.sol) and [`MarketEngineRollingLifecycleModule`](../src/engine/modules/MarketEngineRollingLifecycleModule.sol). That keeps manual and rolling settlement **identical** at the math layer.

Pure outcome selection lives in [`src/logic/Resolvers.sol`](../src/logic/Resolvers.sol). Liability and per-user claims use [`src/math/MarketMath.sol`](../src/math/MarketMath.sol) (`computeClaimLiabilityComponents`, and **`computeLadderLiabilityComponents`** + claim helpers for **Ladder**).

**Rolling markets** (pipeline, genesis, halt, feed alignment): see [§6](#6-rolling-mode-pipeline-design-keeper-cost-reduction) and the dedicated [`rollingMarket.md`](../rollingMarket.md).

### 4.0 Checkpoint A on lock

Lock-time oracle sampling is gated by `MarketTypes.requiresCheckpointAOnLock`:

```317:322:src/types/MarketTypes.sol
    function requiresCheckpointAOnLock(Epoch storage e) internal view returns (bool) {
        return e.marketType == MarketType.Direction || e.marketType == MarketType.Velocity
            || e.marketType == MarketType.Convergence || e.marketType == MarketType.Composite;
    }
```

**Chainlink only for A:** manual `_lockEpoch` **reverts** if `requiresCheckpointAOnLock(e)` and `templateOracleKind == TrustedReporter` (`InvalidTemplate`), because Convergence/Composite lock samples are read from Chainlink adapters, and Direction/Velocity need a numeric lock sample.

### 4.1 Direction

- **Lock:** writes `checkpointA`. **Resolve:** writes `checkpointB`.
- **Resolver:** `Resolvers.resolveDirection`; equal price can **void** (`refundMode`) when `equalPriceVoids` (forced `true` on upsert for this type).
- **Oracle:** **Chainlink only** at template level (`TrustedReporter` rejected in `_validateOracleParams`).

### 4.2 Threshold (includes legacy anchor + rate/fund/macro-style binaries)

- **Lock:** no checkpoint A. **Resolve:** `checkpointB` vs **effective threshold** × `condition`:
  - `effectiveThreshold = anchorPriceE8` if the epoch snapshot has non-zero `anchorPriceE8`, else `absoluteThresholdValueE8` ([`SettlementLogic.compute`](../src/logic/SettlementLogic.sol)).
- **Resolver:** `Resolvers.resolveThreshold` (same math as the standalone `resolveAnchor` helper in `Resolvers`, which is unused by `SettlementLogic` today).
- **Oracle:** Chainlink (pick feed + `oracleClass` for PRICE / RATE / SMARTDATA / MACRO / EQUITY) or **TrustedReporter** (scalar `getResult` for resolve).
- **Product migration:** former **Anchor** markets → `Threshold` + set `anchorPriceE8`. Former **VolatilityBand / StakingAPR / NAVThreshold / MacroEvent** → `Threshold` + appropriate `oracleClass` and feed. Former **BitcoinIRC** “direction vs level” → use **`Direction`** (up/down from A vs B) or **`Threshold`** (level test); there is no combined enum variant.

### 4.3 RangeClose

- **Lock:** no A. **Resolve:** bucket `checkpointB.valueE8` with strictly increasing `rangeBoundsE8[]`.
- **Resolver:** `Resolvers.resolveRangeClose`.

### 4.4 Velocity

- **Lock:** `checkpointA`; **Resolve:** `checkpointB`. Move vs `abs(A)` scaled by `10_000` in `Resolvers.resolveVelocity` over `velocityBoundsE4[]`.
- **Oracle:** **Chainlink only** at template level.

### 4.5 Ladder

- **Lock:** no A. **Resolve:** bucket `checkpointB.valueE8` with `ladderBoundsE8[]`.
- **Liability:** `MarketMath.computeLadderLiabilityComponents` + `ladderPayoutWeightsBps[winnerIndex]` (see §8).

### 4.6 Convergence

- **Lock:** `checkpointA` / `checkpointA_B` from two feeds. **Resolve:** `checkpointB` / `checkpointB_B`.
- **Resolver:** `Resolvers.resolveConvergence` — spread tolerance band; can **void**.
- **Rolling:** **not allowed**. **Oracle:** **Chainlink only** at template level.

### 4.7 Composite

- **Lock / resolve:** per-feed `compositeCheckpointsA[i]` / `compositeCheckpointsB[i]`.
- **Resolver:** `Resolvers.resolveComposite` with **And / Or / Majority**; each leg uses `compositeAbsoluteThresholdsE8[i]` when any per-feed slot is non-zero, otherwise falls back to **`absoluteThresholdValueE8`** for all legs ([`SettlementLogic.compute`](../src/logic/SettlementLogic.sol)).
- **Rolling:** **not allowed**. **Oracle:** **Chainlink only** at template level.

### 4.8 Corridor

- **Resolve:** needs **high/low** for the epoch (`epochHighE8` / `epochLowE8` from OHLC).
- **TrustedReporter path:** `IEventOracle.getOhlcResult(positionKey)` after scalar result.
- **Resolver:** `Resolvers.resolveCorridor` with `rangeBoundsE8[0]` = lower, `[1]` = upper.
- **Chainlink-only template:** OHLC not populated — **do not use** for settlement.
- **Rolling:** **not allowed**.

### 4.9 Cascade

- Same OHLC / TRO vs Chainlink caveats as **Corridor**.
- **Resolver:** `Resolvers.resolveCascade(..., cascadeDownward)`.

### 4.10 Execution mode × oracle (summary)

| Market type | Manual + Chainlink | Manual + TrustedReporter | Rolling + Chainlink | Rolling + TrustedReporter |
|-------------|-------------------|---------------------------|---------------------|---------------------------|
| Direction | Yes | **No** (upsert) | Yes | **No** (TRO rejects rolling) |
| Threshold | Yes | Yes | Yes | **No** |
| RangeClose | Yes | Yes | Yes | **No** |
| Velocity | Yes | **No** (upsert) | Yes | **No** |
| Ladder | Yes | Yes | Yes | **No** |
| Convergence | Yes | **No** (upsert) | **No** (rolling blocked) | **No** |
| Composite | Yes | **No** (upsert) | **No** | **No** |
| Corridor | **Unsafe** (OHLC not filled on Chainlink path) | **Intended** (TRO + `getOhlcResult`) | **No** | **No** |
| Cascade | **Unsafe** (same as Corridor) | **Intended** | **No** | **No** |

**Global rules**

- `_validateOracleParams`: **TrustedReporter + Rolling** always reverts; **Direction / Velocity / Convergence / Composite** cannot use TrustedReporter.
- `_validateTemplate`: **Rolling +** (`Convergence` | `Composite` | `Corridor` | `Cascade`) reverts.

## 5) Manual mode: epoch lifecycle (keeper and users)

Manual mode is the classic discrete 3-tx epoch lifecycle per template:

1. **`openEpoch`**: create epoch `epochId` with schedule; sets `ledger.activeEpochId = epochId`.
2. **User ops**: `depositToSide`, `switchSide` during `[openAt, lockAt)`.
3. **`lockEpoch`**: after `lockAt`. If `requiresCheckpointAOnLock`, samples **Chainlink** (`priceOracle`) and writes `checkpointA` (and extra A checkpoints for Convergence/Composite); TrustedReporter templates that need A **cannot** use this path (revert). Otherwise transitions to `Locked` without A.
4. **`resolveEpoch`**: after `resolveAt`. Writes `checkpointB` (and B\_B / composite B / OHLC as needed); runs settlement; reserves claims/fees; sets `claimable`.
5. **`claim` / `claimMany`**: users pull payouts or refunds (batch claim uses one token transfer).

Manual sequencing is strict: the engine enforces `epochId == activeEpochId + 1` and cannot open the next epoch until the previous has completed.

```581:584:src/engine/modules/MarketEngineCoreLifecycleModule.sol
    function _requireCanOpenNextEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (ledger.activeEpochId != ledger.lastResolvedEpochId) revert PreviousEpochUnresolved();
        if (epochId != ledger.activeEpochId + 1) revert EpochAlreadyExists();
    }
```

### 5.1 Manual flow: sequence diagram

```mermaid
sequenceDiagram
  autonumber
  participant K as Keeper(workerAuthority_or_admin)
  participant U as User
  participant E as Engine_proxy
  participant O as Oracle(IPriceOracle)

  K->>E: openEpoch(templateId,epochId,openAt,lockAt,resolveAt)
  U->>E: depositToSide(templateId,epochId,outcome,amount)
  U->>E: switchSide(templateId,epochId,from,to,grossAmount)
  K->>E: lockEpoch(templateId,epochId)
  E->>O: getNormalizedPrice / multi-feed (if requiresCheckpointAOnLock, Chainlink)
  K->>E: resolveEpoch(templateId,epochId)
  E->>O: Chainlink and/or IEventOracle (TRO, OHLC for Corridor/Cascade)
  U->>E: claim(templateId,epochId) / claimMany
```

## 6) Rolling mode: pipeline design (keeper cost reduction)

Rolling mode reduces keeper transactions by chaining **resolve → lock → open** in one call during steady state. It is only available when `executionMode == Rolling` and **`templateOracleKind == Chainlink`** (TrustedReporter templates **cannot** be rolling: `_validateOracleParams`).

**Market types allowed to use rolling** are those that pass `_validateTemplate`. The engine **reverts** `RollingInvalidParams` if rolling is combined with **`Convergence`, `Composite`, `Corridor`, or `Cascade`** — those four are **manual-only** (multi-feed lock/resolve or OHLC / TRO paths the rolling tick does not implement).

**Practical rolling + Chainlink set:** `Direction`, `Threshold`, `RangeClose`, `Velocity`, `Ladder`, plus any **`Threshold`** configuration that replaces legacy **`Anchor` / rate / fund / macro** binaries (appropriate `oracleClass` + feed). Same settlement path as manual: **`SettlementLogic.compute`** after `_finishResolveEpoch` in [`MarketEngineRollingLifecycleModule`](../src/engine/modules/MarketEngineRollingLifecycleModule.sol).

**Oracle reads in steady state:** `_resolveAndLockRound` performs **one** `_tryReadOracleSample` using the **previous** epoch’s `oracleFeedId` and `_resolveEpochOracle(..., ePrev.oracleClass)` (the epoch being **resolved**). That sample fills `checkpointB` on `prev` and, when the **current** open epoch needs checkpoint A, reuses the **same** values for `checkpointA` on `k` (Pancake-style link). If `requiresCheckpointAOnLock(eCur)`, the code **requires** matching `oracleClass`, `oracleFeedId`, and resolved adapter address between `ePrev` and `eCur`; mismatch **halts** with oracle failure semantics rather than silently reusing a wrong feed. **Secondary feeds for Convergence/Composite are never used in rolling** (those types cannot be rolling templates).

**Deeper narrative + halt/recovery tables:** [`rollingMarket.md`](../rollingMarket.md).

Rolling invariants in steady state (`k = activeEpochId`):

- epoch `k` is **Open** (accepting bets)
- epoch `k-1` is **Locked**
- epoch `k-2` is **Resolved**

### 6.1 Rolling lifecycle phases (ledger)

The ledger tracks the rolling lifecycle:

- `Uninitialized`: no rolling epochs yet
- `GenesisOpen`: genesis epoch opened; must be locked to become live
- `Live`: steady-state pipeline; keepers call `executeRollingRound`
- `Halted`: pipeline stopped due to missed buffer or oracle conditions (or admin halt)

Rolling state machine:

```mermaid
stateDiagram-v2
  [*] --> Uninitialized
  Uninitialized --> GenesisOpen: genesisStartRolling
  GenesisOpen --> Live: genesisLockRolling
  GenesisOpen --> Halted: buffer_miss_or_oracle_issue
  Live --> Halted: buffer_miss_or_oracle_issue_or_admin_halt
  Halted --> Uninitialized: pauseProgram(true)+resetRollingLifecycle
```

### 6.2 Genesis bootstrap

Rolling cannot start directly in steady-state; it needs genesis to create the initial overlap.

1. `genesisStartRolling(templateId)`
   - opens epoch `rollingNextEpochId` (starts at 1)
   - sets `openAt = now`, `lockAt = now + interval`, `resolveAt = now + 2*interval`
   - sets `rollingPhase = GenesisOpen`

2. `genesisLockRolling(templateId)` (must be within the lock window + buffer)
   - locks epoch `k = activeEpochId` — if `requiresCheckpointAOnLock`, `_applyGenesisLockWithOracle` reads **`t.oracleFeedId`** once and writes `checkpointA` (same pattern as steady state: **primary feed only**)
   - opens the next epoch
   - sets `rollingPhase = Live`
   - if oracle fails / confidence too wide / buffer missed: sets `Halted` and **returns** (no revert)

### 6.3 Steady-state tick (`executeRollingRound`)

One tick (`_executeRollingRoundCore` → `_resolveAndLockRound`):

- resolve epoch `prev = k-1` (writes `checkpointB` on `prev` from the shared oracle sample)
- lock epoch `k` (writes `checkpointA` when `requiresCheckpointAOnLock(eCur)` using the **same** sample; otherwise empty lock)
- open epoch `k+1`

Steady-state wiring (effective `maxDelay` / `maxConf` may be the **intersection** of prev + current epochs when both need tight oracle rules; single sample, then resolve + conditional lock + open):

```222:226:src/engine/modules/MarketEngineRollingLifecycleModule.sol
        if (!_resolveAndLockRound(templateId, prev, k, maxDelay, maxConf, nowTs)) {
            return;
        }
        uint64 newOpen = _openRollingEpoch(templateId, nowTs, t);
        emit RollingRoundExecuted(templateId, prev, k, newOpen);
```

`_resolveAndLockRound` calls `_tryReadOracleSample` on **`ePrev`’s feed**, then `_resolvePreviousEpochFromSample` → `_finishResolveEpoch(..., rollingLink: true, ...)` and `_applyLockFromSample` for epoch `k`. Rolling resolve uses `rollingLink` so `epochId + 1 == activeEpochId` while `activeEpochId` already points at the open epoch `k`.

### 6.4 User operations under rolling

User ops (`depositToSide`, `switchSide`) are allowed only when:

- the epoch is the current active epoch, and
- the epoch is open, and
- the template is not halted (rolling templates block deposits/switches while halted).

[`MarketEngineUserOpsClaimsModule`](../src/engine/modules/MarketEngineUserOpsClaimsModule.sol) / deposit path:

```129:141:src/engine/modules/MarketEngineUserOpsClaimsModule.sol
        if (
            t.executionMode == MarketTypes.ExecutionMode.Rolling
                && ledger.rollingPhase == MarketTypes.RollingPhase.Halted
        ) {
            revert RollingHaltedUserOps();
        }
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!(uint256(outcomeIndex) < uint256(e.outcomeCount))) revert InvalidOutcome();
        uint64 nowTs = uint64(block.timestamp);
        if (!e.isEpochOpen(nowTs)) revert BettingClosed();
```

Claims remain available for any epoch that is `claimable` (resolved/cancelled/voided), even if rolling is halted.

### 6.5 Rolling mechanics (code-level)

- **Buffer windows:** `_executeRollingRoundCore` halts if `now > ePrev.resolveAt + rollingBufferSeconds` (missed resolve) or `now > eCur.lockAt + rollingBufferSeconds` (missed lock). Genesis lock uses the same style on `e1.lockAt + buffer`.
- **`rollingLink` resolve guard:** in `_finishResolveEpoch`, when `rollingLink` is true, the engine requires `epochId + 1 == ledger.activeEpochId` so the resolved epoch is always the one **just before** the currently open active epoch.
- **Yield router:** `_withdrawResolvePrincipal` in the rolling module may **halt** (rather than revert the whole tx) on router disable, shortfall, or repeated failures — see inline `rollingLink` branches in [`MarketEngineRollingLifecycleModule`](../src/engine/modules/MarketEngineRollingLifecycleModule.sol).
- **Batching:** `executeRollingRoundBatch` loops `_executeRollingRoundCore` with shared pause/auth checks.

## 7) Epoch status transitions (state machine)

This diagram is the conceptual on-chain lifecycle (note: `Scheduled` exists in the enum, but the engine’s current open path writes `Open` directly).

```mermaid
stateDiagram-v2
  [*] --> Open
  Open --> Locked: lockEpoch_or_genesisLock_or_executeRollingRound
  Locked --> Resolved: resolveEpoch_or_executeRollingRound
  Open --> Cancelled: cancelEpoch_or_cancelRollingEpochWhileHalted
  Locked --> Cancelled: cancelEpoch_or_cancelRollingEpochWhileHalted
  Open --> Voided: cancelEpoch(voided=true)
  Locked --> Voided: cancelEpoch(voided=true)
  Resolved --> [*]
  Cancelled --> [*]
  Voided --> [*]
```

## 8) Settlement, reserves, and payouts

At resolve:

- Checkpoints are written per type (see §4): at minimum `checkpointB`; types needing lock-time data must already have `checkpointA` (and extras) before resolve.
- **`SettlementLogic.compute`** (via `Resolvers`) computes `winningOutcomeMask` / `refundMode` (Direction equal-price void, Convergence band void, etc.).
- Liability: `MarketMath.computeClaimLiabilityComponents` for most types; **`computeLadderLiabilityComponents`** for **Ladder** (tier `ladderPayoutWeightsBps[winnerIndex]` scales how much of the post-fee losing pool is distributable; the remainder stays as fee-side accounting).
- Effective pool for settlement includes **net routed yield** added at resolve when a yield router is configured (see §13.5).
- Reserves: `claimLiabilityTotal` and `settlementFeeTotal` move from active → claims / fee reserves; epoch becomes `claimable`.

At claim:

- **`claim(templateId, epochId)`** — single-epoch claim: computes payout via internal `_claimOne`, transfers tokens once, then emits `Claimed`.
- **`claimMany(templateId, epochIds[])`** — batch UX: loops `_claimOne` for each epoch id, emits **`Claimed` per epoch** with that epoch’s amount, then performs **one** `safeTransfer` of the **sum** of all successful claims. Reverts with `NothingToClaim()` if the sum is zero (e.g. empty array or every epoch reverted internally—each `_claimOne` still enforces per-epoch rules).
- if `refundMode`, user gets back `pos.totalStake` (subject to engine’s refund math).
- otherwise user gets a pro-rata payout from the epoch’s claim liability based on their stake in winning outcomes.

**Last-claimer “dust” sweep (per epoch, not global):** when the last winner in an epoch claims, `MarketMath.computeClaimPayoutStorage` pays out the **remaining unclaimed tokens reserved for that epoch** (`claimLiabilityTotal - claimedTotal` passed in as `remainingClaimsForEpoch`), not the full ledger `claimsReserveTotal`. That keeps accounting correct when multiple epochs are claimable (including after `claimMany`), and prevents sweeping reserves belonging to other epochs.

Claim and fee withdrawal (core paths) live in [`MarketEngineUserOpsClaimsModule`](../src/engine/modules/MarketEngineUserOpsClaimsModule.sol) / [`MarketEngineAdminModule`](../src/engine/modules/MarketEngineAdminModule.sol):

```100:115:src/engine/modules/MarketEngineUserOpsClaimsModule.sol
    function claim(bytes32 templateId, uint64 epochId) external nonReentrant {
        uint256 amount = _claimOne(templateId, epochId, msg.sender);
        stakeToken.safeTransfer(msg.sender, amount);
        emit Claimed(templateId, epochId, msg.sender, amount);
    }

    function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
        uint256 total = 0;
        for (uint256 i = 0; i < epochIds.length; i++) {
            uint256 amt = _claimOne(templateId, epochIds[i], msg.sender);
            total += amt;
            emit Claimed(templateId, epochIds[i], msg.sender, amt);
        }
        if (total == 0) revert NothingToClaim();
        stakeToken.safeTransfer(msg.sender, total);
    }
```

`MarketMath.computeClaimPayoutStorage` (third argument is **remaining** claim pool for that epoch). For **Ladder**, `distributableLosing` follows the same weighted ladder liability as at resolve (`_distributableLosingPoolForClaimsStorage`).

```227:250:src/math/MarketMath.sol
    function computeClaimPayoutStorage(
        MarketTypes.Epoch storage epoch,
        uint256[8] memory stakes,
        uint256 remainingClaimsForEpoch
    ) internal view returns (uint256 payout, uint256 userWinningStake_) {
        userWinningStake_ = totalWinningStake(epoch.winningOutcomeMask, epoch.outcomeCount, stakes);
        if (userWinningStake_ == 0) return (0, 0);

        uint256 winningPool = 0;
        for (uint256 i = 0; i < epoch.outcomeCount; i++) {
            if ((epoch.winningOutcomeMask >> i) & 1 == 1) {
                winningPool += epoch.outcomePools[i];
            }
        }
        uint256 distributableLosing = _distributableLosingPoolForClaimsStorage(epoch, winningPool);
        uint256 entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool;

        if (epoch.remainingWinningStake == userWinningStake_) {
            payout = remainingClaimsForEpoch;
        } else {
            payout = entitlement;
        }
        return (payout, userWinningStake_);
    }
```

```100:112:src/engine/modules/MarketEngineAdminModule.sol
    function withdrawFees(bytes32 templateId, uint256 amount) external {
        if (msg.sender != treasury && msg.sender != admin) revert Unauthorized();
        if (!configInitialized) revert Unauthorized();
        if (amount == 0) revert NothingToClaim();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.feeReserveTotal < amount) revert NothingToClaim();

        stakeToken.safeTransfer(treasury, amount);
        MarketMath.releaseFeeOnWithdraw(ledger, amount);
        _vaults[templateId].fees -= amount;
        emit FeesWithdrawn(templateId, amount);
    }
```

## 9) Oracle correctness and operational constraints

### 9.1 Staleness window (maxDelaySeconds)

The oracle adapter enforces max age via `getNormalizedPrice` / `getNormalizedPriceWithRoundId` (`maxAgeSeconds` / `maxDelay`). The engine computes the effective staleness window from:

- epoch snapshot override (`epoch.oracleMaxDelaySeconds`) if non-zero, else
- global `oracleConfig.maxDelaySeconds`.

Helper:

```384:387:src/types/MarketTypes.sol
    function effectiveOracleMaxDelaySeconds(Epoch storage e, uint64 globalDelaySeconds) internal view returns (uint64) {
        if (e.oracleMaxDelaySeconds > 0) return e.oracleMaxDelaySeconds;
        return globalDelaySeconds;
    }
```

### 9.2 Confidence filter (maxConfidenceBps)

The engine rejects oracle samples when `confidenceE8` exceeds a **hybrid** limit: the larger of (a) a **relative** cap \(|priceE8| \times maxConfidenceBps / 10_000\) and (b) an **absolute floor** `MarketTypes.MIN_ABSOLUTE_CONFIDENCE_E8` (so tiny prices are not dominated by rounding). Implemented in [`MarketTypes.confidenceLimitE8`](../src/types/MarketTypes.sol); manual and rolling modules call `_confidenceWithinBand` → `confidenceLimitE8(priceE8, maxConfidenceBps, MIN_ABSOLUTE_CONFIDENCE_E8)`.

`type(int256).min` is rejected as `InvalidOraclePrice()` (no well-defined absolute value in `int256`).

```600:607:src/engine/modules/MarketEngineCoreLifecycleModule.sol
    function _confidenceWithinBand(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps)
        internal
        pure
        returns (bool)
    {
        if (priceE8 == type(int256).min) revert InvalidOraclePrice();
        uint256 limit = MarketTypes.confidenceLimitE8(priceE8, maxConfidenceBps, MarketTypes.MIN_ABSOLUTE_CONFIDENCE_E8);
        return confidenceE8 <= limit;
    }
```

[`_enforceConfidence`](../src/engine/modules/MarketEngineCoreLifecycleModule.sol) wraps the same check and reverts `OracleConfidenceTooWide`. [`MarketEngineRollingLifecycleModule`](../src/engine/modules/MarketEngineRollingLifecycleModule.sol) duplicates `_confidenceWithinBand` / `_enforceConfidence` for rolling-local reads.

In rolling mode, oracle failure or confidence-wide conditions cause the engine to **halt** the rolling lifecycle instead of reverting the entire outer keeper call.

### 9.3 Publish time semantics (push oracles)

For Chainlink, the oracle adapter returns `publishTime = updatedAt` from `latestRoundData()`. This timestamp can be **earlier** than the on-chain `lockAt` / `resolveAt` while still being a safe settlement input.

The engine’s acceptance rule is therefore:

- `publishTime != 0`
- `publishTime <= nowTs` (defensive: no future timestamps)
- `nowTs - publishTime <= maxDelaySeconds` (freshness window)
- For checkpoint B: if checkpoint A exists, `publishTime >= checkpointA.publishTime` (monotonicity)

Operational implication: choose `oracleMaxDelaySeconds` based on the feed heartbeat (plus buffer), especially for rolling templates.

### 9.4 Chainlink round ID (optional) and V2 events

When `priceOracle` implements [`IPriceOracleWithRoundId`](../src/interfaces/IPriceOracleWithRoundId.sol) (the deployed [`ChainlinkAdapter`](../src/adapters/ChainlinkAdapter.sol) does), manual lock/resolve paths call `getNormalizedPriceWithRoundId` and update [`MarketEngineState.lastOracleCursorByTemplateFeed`](../src/engine/MarketEngineState.sol) via `_enforceAndUpdateOracleCursor`:

- Reject samples that move **backwards** in `(roundId, publishTime)` vs the last stored cursor for that `(templateId, feedId)` (`OracleSampleNotMonotonic`).
- Additionally track `lastOracleRoundIdByTemplate[templateId]` when `oracleRoundId` increases (used together with the per-feed cursor in the implementation).

Augmented events (ABI-stable alongside legacy emits):

- `EpochLockedV2(..., oracleRoundId)` when checkpoint A is written (any type with `requiresCheckpointAOnLock` on paths that emit it — e.g. manual/rolling lock with oracle).
- `EpochResolvedV2(..., oracleRoundId, checkpointB, publishTime)` after checkpoint B is written.

If the optional interface call **reverts**, the engine **falls back** to `IPriceOracle.getNormalizedPrice` and records `oracleRoundId = 0` for that read path.

Rolling genesis / `executeRollingRound` use `_tryReadOracle` (no revert on oracle failure—**halt** instead) with the same cursor rules when the extended interface succeeds.

### 9.5 Trusted reporter oracle (`IEventOracle`)

Per-template **`templateOracleKind == TrustedReporter`** routes resolve (and optional lock samples) through [`IEventOracle`](../src/interfaces/IEventOracle.sol) at `eventOracle`, not through `priceOracle` for the scalar result.

- **`getResult(marketId)`** / **`getResolveObservedAt`**: `marketId` MUST equal `positionKey(templateId, epochId)` ([`MarketEngineState.positionKey`](../src/engine/MarketEngineState.sol)).
- **Lock sample** (`getLockSample`): used only where the product would post a lock price on the adapter; engine manual lock still **reverts** for types that need numeric Chainlink `checkpointA` from feeds (§4.0).
- **OHLC** (`getOhlcResult`): required for **Corridor** / **Cascade** on the TRO path; adapter implementation is [`TrustedReporterAdapter`](../src/oracle/TrustedReporterAdapter.sol) with `postOhlcResult` (EIP-712 `OhlcClaim`).

**Upsert constraints** ([`_validateOracleParams`](../src/engine/modules/MarketEngineCoreLifecycleModule.sol)):

- TRO **cannot** be combined with **`Direction`, `Velocity`, `Convergence`, `Composite`**.
- TRO **cannot** be combined with **`Rolling`** (any market type).

Operational note: **`initialize`** on the dispatcher still sets the **global** `oracleConfig.oracleKind` to **Chainlink**; per-template `templateOracleKind` selects the settlement path for that market.

## 10) Rolling halt and recovery

### 10.1 How rolling halts

Rolling keepers halt (set `rollingPhase = Halted`) when:

- resolve buffer missed (`BufferMissOnResolve`)
- lock buffer missed (`BufferMissOnLock`)
- oracle call fails (`OracleFailure`)
- confidence too wide (`OracleConfidenceWide`)
- admin halts (`ManualAdmin`)

```702:712:src/engine/modules/MarketEngineRollingLifecycleModule.sol
    function _haltRolling(
        bytes32 templateId,
        MarketTypes.Ledger storage ledger,
        MarketTypes.RollingHaltReason reason,
        uint64 atEpoch
    ) internal {
        ledger.rollingPhase = MarketTypes.RollingPhase.Halted;
        ledger.rollingHaltReason = reason;
        ledger.haltedAtEpochId = atEpoch;
        emit RollingHalted(templateId, uint8(reason), atEpoch);
    }
```

### 10.2 Recovery checklist

Recovery is an explicit admin flow:

1. `pauseProgram(true)` (blocks user ops and worker ops that use the pause modifiers).
2. If needed, `haltRollingMarket(templateId)` to stop a live pipeline proactively.
3. While halted and paused, cancel stuck `Open`/`Locked` epochs with `cancelRollingEpochWhileHalted(...)`.
4. While halted and paused, reset rolling cursors with `resetRollingLifecycle(templateId, nextRollingEpochId)`.
5. `pauseProgram(false)`.
6. Restart with `genesisStartRolling` → `genesisLockRolling` → steady `executeRollingRound`.

## 11) Gas and cost model

### 11.1 Snapshot gas numbers (reference only)

This repository tracks gas in [`.gas-snapshot`](../.gas-snapshot) (mock oracle; local test harness). The snapshot is meant for *relative* comparisons and regression checks, not as a mainnet cost quote.

From the current snapshot:

| Operation | Gas |
|----------|-----:|
| `openEpoch` (cold) | 192308 |
| `lockEpoch` (Direction) | 56547 |
| `lockEpoch` (Threshold) | 10514 |
| `resolveEpoch` (Direction) | 127052 |
| `resolveEpoch` (Threshold) | 128234 |
| `claim` | 42146 |
| `genesisStartRolling` | 198312 |
| `genesisLockRolling` | 224155 |
| `executeRollingRound` (steady) | 376754 |

### 11.2 Manual vs rolling keeper economics (the important part)

For Direction markets at a given cadence:

- **Manual** requires **3 keeper txs per epoch**: `openEpoch` + `lockEpoch` + `resolveEpoch`.
- **Rolling** requires **1 keeper tx per interval** in steady state: `executeRollingRound` (plus 2 genesis txs per rolling session).

Using the snapshot numbers above (execution gas only):

- Manual Direction per epoch \(\approx 192308 + 56547 + 127052 = 375907\) gas.
- Rolling Direction steady per interval \(\approx 376754\) gas (similar execution gas), but **1 tx instead of 3**.

On rollups, the **L1 data fee per transaction** often dominates execution gas at low L2 gas prices. That makes rolling materially cheaper at scale even when execution gas is similar.

### 11.3 What is not included in these gas numbers

- L1 data fees (rollup posting costs).
- Chainlink push feeds do not require a separate “update” tx before `lock`/`resolve`; budget **heartbeat-aligned** `oracleMaxDelaySeconds` instead.
- Congestion spikes and priority fees.

## 12) Deployment cost (how to measure)

There is no single stable “deployment gas cost” committed to this repo because it depends on compiler profile, bytecode size, chain rules, and base fee.

To measure on your target chain/environment:

- Use `forge build --sizes` to see runtime size.
- Use `forge script script/test/DeployTestnet.s.sol:DeployTestnet --rpc-url ... --ffi --broadcast --slow` on testnet (set `DEPLOY_FAUCET=1` if you want faucet + demo token).
- Use `forge script script/DeployLocal.s.sol:DeployLocal --rpc-url ... --broadcast` for local development.
- Use `--dry-run` / simulation to get `eth_estimateGas` style totals before broadcasting.

## 13) Limits and scaling notes

- Epoch ids are `uint64`. Manual mode increments sequentially; rolling mode uses `rollingNextEpochId` and can be reset to a higher id after a halt.
- Storage is not pruned. Each epoch retains pools, checkpoints, and accounting fields; each user position remains addressable forever.

## 13.5) Yield routing (Aave — `IYieldRouterV2`)

This subsection ties **§0** to the concrete call sites in modules.

### Engine integration

- **State**: `yieldRouter`, `yieldFeeBps`, `lmRewardsEnabled`, and `YIELD_BUFFER_BPS = 500` (5% kept on-engine) in [`MarketEngineState`](../src/engine/MarketEngineState.sol).
- **Deposits** ([`MarketEngineUserOpsClaimsModule`](../src/engine/modules/MarketEngineUserOpsClaimsModule.sol)): after pulling `stakeToken` from the user, \((10000 - 500) / 10000\) of the deposit is `forceApprove` + `depositScaled(templateId, routeAmount)` inside a **try/catch**. Failure emits `YieldRouterDepositFailed` and leaves funds in the engine (no revert).
- **Switch fees**: when `switchSide` moves value into `feeReserveTotal`, the module may `withdrawScaled` the fee’s routed principal; **grossReturned − principal** is added to **`feeReserveTotal`** / `vaults.fees` (surplus yield on the fee slice).
- **Manual resolve** ([`_finishResolveEpochManual`](../src/engine/modules/MarketEngineCoreLifecycleModule.sol)): `withdrawScaled` for the epoch’s routed principal; **gross yield** is added to the epoch’s effective pool; **`yieldFeeBps`** of gross is moved to fee reserves; **net** yield participates in settlement. If the epoch ends in **refundMode** after yield (e.g. Direction void), **net yield** is swept to fee reserves instead of participants (`EpochYieldAccrued` still records gross / fee / net).
- **Cancel (manual)** ([`cancelEpoch`](../src/engine/modules/MarketEngineCoreLifecycleModule.sol)) and **rolling cancel-while-halted**: withdraw routed principal; surplus yield to fee reserves; then refund liabilities to claims reserve.
- **Rolling resolve** uses the same yield accounting pattern inside [`MarketEngineRollingLifecycleModule`](../src/engine/modules/MarketEngineRollingLifecycleModule.sol) (`_finishResolveEpochRolling`).

### Routers

- **Preferred**: [`YieldRouterV2`](../src/yield/YieldRouterV2.sol) — scaled aToken accounting per `templateId`, optional ERC-4626 **Stata** path (`setTemplateYieldPath`, **router owner**), reserve health checks, `claimLmRewards` / `claimAllRewardsTo` for liquidity-mining sweeps.
- **Legacy**: [`YieldRouterAaveV3`](../src/yield/YieldRouterAaveV3.sol) — same [`IYieldRouterV2`](../src/interfaces/IYieldRouterV2.sol) surface with simpler internal accounting.

Full router withdrawals for a template use **template-scoped** amounts (scaled balance math), not `type(uint256).max` on Aave, so multiple templates sharing one router cannot drain each other’s positions.

### Liquidity mining (LM)

- **`admin`**: `setLmRewardsEnabled(true)` requires a non-zero router.
- **`admin` or `workerAuthority`**: `keeperClaimLmRewards(templateId)` → `yieldRouter.claimLmRewards(templateId)`; reward ERC20s land on the **engine** address (`LMRewardReceived`). They are **not** auto-accounted into `feeReserveTotal`; treasury/Ops handles them separately (swap, forward, or off-chain policy).

### Admin escape hatch

- **`yieldEmergencyWithdraw(templateId)`** (`admin` only): router pulls collateral for that template back to the engine via router `emergencyWithdraw`.

### Deploy / upgrade docs

- [`script/DeployYieldRouterV2.s.sol`](../script/DeployYieldRouterV2.s.sol), [`script/UpgradeMarketEngine_YieldRouting.s.sol`](../script/UpgradeMarketEngine_YieldRouting.s.sol), [`.docs/migrations/yieldRoutingV2.md`](./migrations/yieldRoutingV2.md).

## 14) Toolchain, artifacts, and references

- **Solidity 0.8.24**, **Cancun** EVM; [`MarketEngineDispatcher`](../src/engine/MarketEngineDispatcher.sol) inherits `ReentrancyGuardTransient` (transient storage). **Resolve** entrypoints on lifecycle modules use `nonReentrant` where reentrancy risk exists.
- **Core bytecode**: proxy → `MarketEngineDispatcher` + delegatecall modules (§0.1). **Not** a monolithic `src/MarketEngine.sol` in this package.
- **Tests**: harness in [`test/MarketEngineBase.t.sol`](../test/MarketEngineBase.t.sol); mocks often under [`src/test/`](../src/test/) (e.g. `MockPriceOracle`, `MockAavePool`).
- [`.docs/migrations/marketengine_selector_matrix.md`](./migrations/marketengine_selector_matrix.md) — selector → module map.
- [`deployment/DEPLOYMENT_AND_EPOCHS.md`](./deployment/DEPLOYMENT_AND_EPOCHS.md) — operational guide (verify against this doc + code).
- [`.docs/rolling-rounds.md`](./rolling-rounds.md) — rolling pattern narrative.
- [`rollingMarket.md`](../rollingMarket.md) — rolling markets technical reference (pipeline, oracle reuse, recovery).
- [`src/types/MarketTypes.sol`](../src/types/MarketTypes.sol) — canonical structs and enums.
