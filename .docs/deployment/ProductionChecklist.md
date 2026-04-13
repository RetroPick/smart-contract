## Production Checklist (MarketEngine)

This checklist is for deploying and operating `MarketEngine` (`UUPSUpgradeable`) with a Chainlink-style push oracle (`IPriceOracle`) and optional rolling execution mode (Direction-only).

It is written to prevent the highest-impact real-world failures:

- Mis-deployment (uninitialized proxy / wrong roles)
- Admin/keeper key compromise
- Oracle/staleness misconfiguration
- Rolling liveness failures
- ERC20 behavior mismatches

---

## 0) Preconditions (must be true before any deployment)

- **Stake token is standard ERC20**
  - No fee-on-transfer / deflationary transfers
  - No rebasing
  - No blacklist/pausable transfer restrictions
  - Rationale: deposits enforce exact balance delta equality; non-standard tokens revert.

- **Oracle feed quality**
  - Confirm Chainlink feed heartbeat (update frequency) and typical staleness behavior.
  - Confirm whether the target chain is **L1** or **L2** and (on L2) identify the correct **sequencer uptime feed**.

- **Role ownership model**
  - **`admin`**: MUST be a multisig (recommended 2/3 or 3/5). If possible, put it behind a timelock for upgrades/config.
  - **`workerAuthority`**: keeper EOA(s) or keeper multisig (rotateable).
  - **`treasury`**: multisig (separate from `admin` if you want operational separation).

---

## 1) Deployment checklist (UUPS proxy safety)

### 1.1 Deploy sequence (non-negotiable)

- Deploy `MarketEngine` implementation.
- Deploy ERC1967 proxy **with atomic initialization calldata** (initializer runs in the proxy constructor).
  - The initializer is `external initializer onlyProxy` and sets `admin/treasury/workerAuthority` once.
  - Never deploy a proxy and “initialize later”.

### 1.2 Initialization parameters sanity checks

Before broadcasting:

- **Addresses**
  - `stakeToken != 0`
  - `priceOracle != 0`
  - `admin != 0`, `treasury != 0`, `workerAuthority != 0`

- **Fees**
  - `defaultSettlementFeeBps <= 10_000`
  - `maxSwitchFeeBps <= 10_000`
  - Ensure `maxSwitchFeeBps` is not lower than any template you plan to create.

- **Limits**
  - `maxOutcomes <= 8` (hard-coded bound)

- **Oracle config**
  - `oracleKind == Chainlink`
  - `oracleMaxDelaySeconds`: set to (heartbeat + buffer) that matches your operational cadence.
  - `oracleMaxConfidenceBps`: Chainlink adapter returns `confidenceE8 = 0`, so set this to `0` unless you swap to an oracle that provides confidence.

### 1.3 Post-deploy verification (on-chain reads)

Immediately after deploy, verify (via RPC or block explorer reads):

- `configInitialized == true`
- `admin`, `treasury`, `workerAuthority` match intended addresses
- `stakeToken`, `priceOracle` match intended addresses
- `oracleConfig` fields match intended values
- `ConfigInitialized(admin, treasury, workerAuthority)` event emitted

### 1.4 Upgrade safety posture (admin key risk)

Because `admin` can upgrade the implementation (`_authorizeUpgrade` is `onlyAdmin`):

- Use a multisig for `admin`.
- Prefer a timelock for upgrade transactions.
- Maintain an “upgrade runbook” (see Section 7).

---

## 2) Template + market setup checklist

### 2.1 Template creation (`upsertTemplate`)

For each template, confirm:

- `slug` and `assetSymbol` are within length bounds.
- `oracleFeedId != 0` and points to the correct feed for this template.
- Template `executionMode` is correct:
  - **Manual**: discrete `openEpoch`/`lockEpoch`/`resolveEpoch`
  - **Rolling**: Direction-only; uses keeper pipeline

Rolling-specific:

- `marketType == Direction` (required)
- `rollingIntervalSeconds > 0`
- `rollingBufferSeconds < rollingIntervalSeconds`

Oracle per-template overrides:

- `oracleMaxDelaySeconds` and `oracleMaxConfidenceBps` can override global defaults.
- Ensure overrides are consistent with keeper cadence and feed heartbeat.

### 2.2 Initialize per-template ledger (`initializeMarket`)

After `initializeMarket(templateId)`:

- Verify `ledgers[templateId].initialized == true`
- Rolling templates: `rollingPhase` starts `Uninitialized` until genesis is started.

---

## 3) Keeper operations (Manual mode)

### 3.1 Manual lifecycle

For each epoch:

- `openEpoch(templateId, epochId, openAt, lockAt, resolveAt)` by `workerAuthority/admin`
- `lockEpoch(templateId, epochId)` by `workerAuthority/admin`
- `resolveEpoch(templateId, epochId)` by `workerAuthority/admin`

### 3.2 Timing + oracle constraints

Operationally ensure:

- Calls land within the desired windows.
- Oracle is fresh within `maxDelaySeconds` at lock/resolve.

---

## 4) Keeper operations (Rolling mode)

Rolling is Direction-only and is a liveness system. Treat it like infrastructure.

### 4.1 Genesis bootstrap

- `genesisStartRolling(templateId)` by `workerAuthority/admin`
- `genesisLockRolling(templateId)` by `workerAuthority/admin` at `lockAt`

### 4.2 Steady-state tick

- `executeRollingRound(templateId)` or `executeRollingRoundBatch([templateIds])`
- Every tick bundles: resolve (k-1), lock (k), open (k+1).

### 4.3 Halt conditions and response

Rolling halts on:

- Buffer misses (`BufferMissOnLock` / `BufferMissOnResolve`)
- Oracle failure
- Confidence wide (if used)
- Manual admin halt

When halted:

- User deposits/switches revert for rolling templates.
- Users can still claim for already-claimable epochs.

Response playbook (recommended):

- Inspect `getRollingLifecycle(templateId)`
- Decide: recover (reset) or cancel stuck epochs
- Use the documented recovery flow:
  - `pauseProgram(true)`
  - `cancelRollingEpochWhileHalted(...)` as needed
  - `resetRollingLifecycle(...)`
  - restart genesis sequence

Reference: `ROLLING_SECURITY.md`.

---

## 5) Pause / emergency controls

### 5.1 What pause does

- `pauseProgram(true)` blocks:
  - user ops guarded by `notPausedUserOps`
  - worker ops guarded by `notPausedWorkerOps`

Important: while paused, **`workerAuthority` cannot `cancelEpoch`**; only `admin` can cancel while paused.

### 5.2 When to pause (examples)

- Oracle issues (stale feed / sequencer down)
- Keeper compromise suspected
- Unexpected invariant break (vault totals vs token balance monitoring)

---

## 6) Monitoring (must-have for production)

### 6.1 Event monitoring

Alert on these events from `MarketEngine`:

- `ConfigInitialized`
- `TemplateUpserted`
- `MarketInitialized`
- `EpochOpened`, `EpochLocked`, `EpochResolved`, `EpochCancelled`
- `RollingGenesisStarted`, `RollingGenesisLocked`, `RollingRoundExecuted`, `RollingHalted`, `RollingLifecycleReset`
- `DepositExecutorSet`
- `WorkerAuthorityUpdated`, `TreasuryUpdated`

### 6.2 Invariant monitoring (recommended)

Per templateId, continuously check:

- `stakeToken.balanceOf(MarketEngine)` remains consistent with aggregate vault state.
  - At minimum: monitor unexpected divergence between `getVaultBalances(templateId)` sums and token balance.
  - Investigate any mismatch as an incident.

### 6.3 Oracle health monitoring

- Track oracle publish times and verify they stay within configured staleness windows.
- On L2, track sequencer feed status and grace periods.

---

## 7) Upgrade runbook (UUPS)

Because `admin` can upgrade, treat upgrades as high-risk operations.

- **Pre-upgrade**
  - Announce freeze window
  - `pauseProgram(true)` (recommended)
  - Confirm current implementation + storage layout expectations

- **Upgrade**
  - Multisig transaction only
  - If using timelock: queue + wait + execute

- **Post-upgrade**
  - Validate critical reads unchanged (`admin`, `stakeToken`, `priceOracle`, ledgers)
  - Run a canary market lifecycle on a low-stakes template
  - Unpause

---

## 8) Pre-mainnet checklist (final gate)

- `forge test -vvv` passes on the exact commit being deployed.
- Deploy on a public testnet with real Chainlink feeds and rehearse:
  - manual lifecycle
  - rolling genesis + several ticks
  - halt + reset recovery
  - pause + emergency cancel while paused (admin only)
- Multisigs configured and tested (signing, nonce mgmt, emergency access).
- Monitoring + alerting configured and tested with a drill.

