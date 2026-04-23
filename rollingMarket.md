# Rolling markets (RetroPick `MarketEngine`)

Deep reference for **rolling execution mode** — the Pancake-style pipeline where one keeper transaction advances **resolve → lock → open** on a fixed interval. This complements [`.docs/currentSmartContract.md`](.docs/currentSmartContract.md) and the narrative in [`.docs/rolling-rounds.md`](.docs/rolling-rounds.md).

## 1) What “rolling” means here

- **Manual** mode: three discrete calls per epoch — `openEpoch`, `lockEpoch`, `resolveEpoch`.
- **Rolling** mode: overlapping epochs. At steady state there is always:
  - one epoch **Open** (users deposit / switch),
  - the previous epoch **Locked** (waiting for resolve time),
  - an older epoch **Resolved** (claimable).

The keeper’s steady-state heartbeat is **`executeRollingRound(templateId)`** (or `executeRollingRoundBatch`). Each successful tick:

1. **Resolves** the epoch that just hit `resolveAt` (writes `checkpointB`, runs [`SettlementLogic.compute`](src/logic/SettlementLogic.sol), moves reserves).
2. **Locks** the current open epoch at `lockAt` (writes `checkpointA` only when `MarketTypes.requiresCheckpointAOnLock` is true).
3. **Opens** the next epoch with timings anchored to `block.timestamp`: `openAt = now`, `lockAt = now + interval`, `resolveAt = now + 2 * interval`.

Implementation: [`MarketEngineRollingLifecycleModule`](src/engine/modules/MarketEngineRollingLifecycleModule.sol) (`_executeRollingRoundCore` → `_resolveAndLockRound` → `_openRollingEpoch`).

## 2) Why genesis exists

You cannot jump straight to steady state: you need two epochs “in flight” before a single sample can both **close** an old locked round and **lock** the next.

1. **`genesisStartRolling`**: opens epoch `rollingNextEpochId` (starts at 1 after `initializeMarket`), sets `rollingPhase = GenesisOpen`, schedules `lockAt = now + interval`, `resolveAt = now + 2*interval`.
2. **`genesisLockRolling`**: within `[lockAt, lockAt + rollingBufferSeconds]`, locks the genesis epoch (with oracle sample if type needs checkpoint A), opens the **next** epoch, sets `rollingPhase = Live`.

If the keeper misses the buffer on genesis lock, or oracle read fails / confidence fails, the market **halts** (see §5) instead of reverting the outer call in most paths.

## 3) Steady-state tick in detail

### 3.1 Preconditions (`_executeRollingRoundCore`)

- `executionMode == Rolling`, `rollingPhase == Live`, `globalPaused == false`.
- `activeEpochId >= 2` (need `prev = k-1` and current `k`).
- **Resolve window**: `now >= ePrev.resolveAt` and `now <= ePrev.resolveAt + rollingBufferSeconds`. Late → halt `BufferMissOnResolve` on `prev`.
- **Lock window**: `now >= eCur.lockAt` and `now <= eCur.lockAt + rollingBufferSeconds`. Late → halt `BufferMissOnLock` on `k`.
- No unreconciled recovery state (`_requireNoUnreconciledRecovery`).

### 3.2 One oracle sample for two epochs

`_resolveAndLockRound` calls `_tryReadOracleSample` **once** using **`ePrev.oracleFeedId`** and **`_resolveEpochOracle(templateId, prevEpochId, ePrev.oracleClass)`** — i.e. the **previous** (being resolved) epoch’s feed and adapter class.

That single `OracleSample` is used to:

- **`_resolvePreviousEpochFromSample`**: writes `checkpointB` on `prev` and completes resolve (yield withdraw, `SettlementLogic.compute`, accounting).
- **`_applyLockFromSample`**: if the **current** epoch `k` needs checkpoint A, the **same** prices become `checkpointA` for `k`; otherwise lock transitions without an oracle write.

This is the “Pancake link”: resolve price at time T equals lock sample for the round that locks at T (for types that need A).

### 3.3 Feed / adapter alignment (Direction, Velocity, Convergence, Composite)

When `needsCheckpointA` is true for epoch `k`, rolling **requires** the locking epoch to use the **same** Chainlink feed and **same** resolved oracle adapter address as the epoch being resolved:

- `eCur.oracleClass == ePrev.oracleClass`
- `eCur.oracleFeedId == ePrev.oracleFeedId`
- `address(_resolveEpochOracle(templateId, k, eCur.oracleClass)) == address(prevOracle)`

If not, `_haltRolling(..., OracleFailure, lockEpochId)` — the pipeline cannot honestly reuse one read for both legs across different feeds.

**Convergence** and **Composite** remain **rolling-ineligible** at template validation time (`_validateTemplate` reverts `RollingInvalidParams`), so this alignment path is mainly relevant for **Direction** and **Velocity** in practice.

### 3.4 Effective oracle caps when both epochs need tight rules

If `requiresCheckpointAOnLock(eCur)`:

- `maxDelay = min(effectiveDelay(prev), effectiveDelay(cur))`
- `maxConf = min(effectiveConf(prev), effectiveConf(cur))`

So the **stricter** of the two epoch snapshots governs the single read (conservative for linking resolve + lock).

### 3.5 Rolling-specific resolve guard (`rollingLink`)

`_finishResolveEpoch(..., rollingLink: true, ...)` enforces `epochId + 1 == ledger.activeEpochId` instead of `epochId == activeEpochId`. That matches the fact that during rolling, **`activeEpochId` already advanced** to the open epoch `k` before the keeper resolves `prev = k-1`.

If yield router withdraw on resolve fails in a way that triggers rolling halt, resolution may abort mid-path; see `_withdrawResolvePrincipal` and `_isRollingResolveActive`.

## 4) Timing template

For every newly opened rolling epoch (`_openRollingEpoch`):

- `openAt = startTs` (typically `block.timestamp` of the tick)
- `lockAt = startTs + rollingIntervalSeconds`
- `resolveAt = startTs + 2 * rollingIntervalSeconds`

Constants `MIN_ROLLING_INTERVAL_SECONDS` / `MAX_ROLLING_INTERVAL_SECONDS` bound `rollingIntervalSeconds`. Template validation requires `rollingBufferSeconds < rollingIntervalSeconds`.

## 5) Halt reasons and recovery

| Reason | Typical cause |
|--------|----------------|
| `BufferMissOnLock` | `genesisLockRolling` or steady tick after `lockAt + buffer` |
| `BufferMissOnResolve` | steady tick after `resolveAt + buffer` on previous epoch |
| `OracleFailure` | oracle revert, failed sample, feed/adapter mismatch, yield withdraw failure (rolling path) |
| `OracleConfidenceWide` | confidence band exceeds policy |
| `ManualAdmin` | `haltRollingMarket` |

When **halted**:

- **`executeRollingRound`** reverts `RollingWrongPhase` (not live).
- **Users** cannot deposit/switch (`RollingHaltedUserOps` in user module).
- **Claims** for already resolved epochs remain available.

**Recovery** (admin): `pauseProgram(true)` → optional `cancelRollingEpochWhileHalted` for stuck Open/Locked epochs → `resetRollingLifecycle(templateId, nextRollingEpochId)` (strict preconditions: paused, halted, prior epochs “cleared”) → `pauseProgram(false)` → `genesisStartRolling` → `genesisLockRolling` → `executeRollingRound` again. See §10 in `currentSmartContract.md`.

## 6) Eligible market types for rolling

Rolling requires **Chainlink-kind** templates (`templateOracleKind == Chainlink`). TrustedReporter + Rolling always reverts at upsert.

`_validateTemplate` additionally forbids rolling for:

- `Convergence`, `Composite` (multi-feed / multi-checkpoint lock-resolve),
- `Corridor`, `Cascade` (OHLC / trusted reporter paths; not supported in rolling tick).

**Allowed** rolling types in code: `Direction`, `Threshold`, `RangeClose`, `Velocity`, `Ladder`, and any other type that passes validation — practically the single-feed Chainlink markets above. Former product types consolidated into **`Threshold`** (e.g. rate/APR/NAV/macro feeds) roll as **Threshold** with the appropriate `oracleClass` and feed.

## 7) Batching and operations

- **`executeRollingRoundBatch(templateIds)`**: same auth and pause checks; loops `_executeRollingRoundCore` with batch size caps from the engine base.

## 8) Related code map

| Concern | Location |
|---------|----------|
| Genesis / steady / halt | `MarketEngineRollingLifecycleModule.sol` |
| Shared settlement | `SettlementLogic.compute` ← `Resolvers` + `MarketMath` |
| User halt guard | `MarketEngineUserOpsClaimsModule.sol` |
| Template rolling rules | `MarketEngineCoreLifecycleModule._validateTemplate` |
| Epoch field snapshot | `MarketEngineState._snapshotEpochTemplateMarketConfig` |
