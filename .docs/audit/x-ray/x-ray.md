# X-Ray Report

> RetroPick MarketEngine | 1777 nSLOC | ec0bb56 (`main`) | foundry | 08/04/26

---

## 1. Protocol Overview

**What it does:** Runs epoch-based markets where users stake an ERC20 into outcomes, then a keeper locks/resolves epochs using an oracle price checkpoint and users claim payouts/refunds.

- **Users**: deposit stake into an outcome, optionally switch sides during the open window, then claim after resolution/cancel.
- **Core flow**: `openEpoch` → `depositToSide`/`switchSide` → `lockEpoch` → `resolveEpoch` → `claim`.
- **Key mechanism**: pooled-outcome accounting per epoch + oracle checkpoint(s) used to derive winning outcome(s).
- **Token model**: single `stakeToken` (ERC20) held by `MarketEngine`; per-template vault splits `active` / `claims` / `fees`.
- **Admin model**: `admin` can upgrade (UUPS), configure templates, pause, and manage rolling lifecycle; `workerAuthority` (or admin) performs keeper actions; `treasury` (or admin) withdraws fees.

For a visual overview of the protocol's architecture, see the [architecture diagram](architecture.svg).

### Contracts in Scope

| Subsystem | Key Contracts | nSLOC | Role |
|-----------|--------------|------:|------|
| Core engine | `MarketEngine` | 1231 | Market lifecycle, accounting, payouts, access control, upgrades |
| Oracle adapter | `ChainlinkAdapter` | 93 | `IPriceOracle` implementation over Chainlink, optional L2 sequencer gate |
| Settlement helpers | `MarketMath`, `Resolvers`, `MarketTypes` | 439 | Math, outcome resolution rules, packed types/helpers |

### How It Fits Together

The core trick: each epoch holds pooled stakes per outcome, and resolution converts `active` collateral into `claims` (winners/refunds) and `fees` (treasury) based on oracle checkpoints.

### Manual epoch lifecycle

```text
Worker/Admin
├─ openEpoch(templateId, epochId, openAt, lockAt, resolveAt)
│  └─ epochs[templateId][epochId] created + ledger.activeEpochId set
├─ lockEpoch(templateId, epochId)
│  └─ (Direction markets) read oracle checkpoint A
└─ resolveEpoch(templateId, epochId)
   ├─ read oracle checkpoint B
   ├─ compute winning outcome mask / refund mode
   └─ move funds: vault.active → vault.claims (+ vault.fees)
```

### Rolling lifecycle (keeper pipeline)

```text
Worker/Admin
├─ genesisStartRolling(templateId)
│  └─ opens epoch k (from rollingNextEpochId)
├─ genesisLockRolling(templateId)
│  ├─ read oracle for lock A
│  └─ opens epoch k+1
└─ executeRollingRound(templateId) / executeRollingRoundBatch([templateIds])
   ├─ resolve epoch k-1 (uses oracle sample as checkpoint B)
   ├─ lock epoch k (uses oracle sample as checkpoint A)
   └─ open epoch k+1
```

### User participation + claim

```text
User
├─ depositToSide(templateId, epochId, outcome, amount)
│  └─ transferFrom(user → engine), update pools + position
├─ switchSide(templateId, epochId, from, to, gross)
│  └─ reallocates stake + charges switch fee into fees reserve
└─ claim(templateId, epochId) / claimMany(templateId, [epochIds])
   └─ compute entitlement and transfer(engine → user)
```

---

## 2. Threat & Trust Model

### Protocol Threat Profile

> Protocol classified as: **Derivatives/Perps** with **Oracle-dependent market** characteristics

The protocol’s primary settlement input is an external price oracle checkpoint and epoch timing; most critical failure modes flow from oracle correctness/freshness and privileged keeper/admin execution of lock/resolve windows.

### Actors & Adversary Model

| Actor | Trust Level | Capabilities |
|-------|-------------|-------------|
| `admin` | Trusted | Upgrades (UUPS), template configuration, pause, rolling halt/recovery, set allowlists |
| `workerAuthority` | Bounded (keeper actions only) | Open/lock/resolve epochs, rolling execution; can affect settlement timing and oracle sampling |
| `treasury` | Bounded (fees only) | Withdraws accrued fee reserves |
| `isDepositExecutor` | Bounded (allowlisted contracts) | Can pull stake from itself and credit a user via `depositToSideFor` |

**Adversary Ranking**:

1. **Oracle manipulator / stale-data exploiter** — settlement depends on oracle price freshness and correctness.
2. **Compromised worker/keeper key** — can decide when lock/resolve execute within allowed windows and can cancel epochs.
3. **Compromised admin** — can upgrade logic and change templates/parameters; highest-impact single-key compromise.
4. **Economic attacker** — attempts to game rounding/edge cases in payout math and pool accounting.

See [entry-points.md](entry-points.md) for the full entry point map.

### Trust Boundaries

- **`MarketEngine` ↔ Oracle (`IPriceOracle` / Chainlink feeds)**: settlement depends on `latestRoundData()` values and configured staleness (`maxDelaySeconds`) checks. L2 deployments may add a sequencer uptime gate (in `ChainlinkAdapter`).
- **Admin boundary (UUPS)**: `_authorizeUpgrade` is `onlyAdmin`, so admin compromise = full control.
- **Worker boundary**: `onlyWorkerOrAdmin` gates epoch lifecycle and rolling execution; no timelock/delay is evident in onchain access control.

### Key Attack Surfaces

- **Oracle checkpoint integrity** — `lockEpoch` / `resolveEpoch` / rolling execution read oracle samples; incorrect feeds, staleness windows, or L2 sequencer handling can invalidate settlement.
- **Keeper timing & epoch state machine** — keeper executes lock/resolve windows; buffer misses can halt rolling markets; cancellation paths move funds to refund mode.
- **Funds accounting between `active` / `claims` / `fees`** — resolution and switches move balances between reserves; errors here can strand funds or allow over-claims.
- **Upgradeable core** — any upgrade bug or uninitialized state risk is high impact due to TVL custody in `MarketEngine`.

### Upgrade Architecture Concerns

- **UUPS upgrade authority** — `admin` controls upgrades; security posture depends on operational controls (multisig/timelock) outside this codebase.

### Protocol-Type Concerns

**As an oracle-dependent market:**
- `MarketEngine._readOracleOrRevert()` and `_tryReadOracle()` have two paths (with/without roundId). Verify both paths enforce the intended freshness/confidence policy for every market type.

### Temporal Risk Profile

**Deployment & Initialization:**
- `initialize(...)` is `external initializer` with parameter validation; deployment safety depends on proxy being initialized atomically in the deployment transaction.

### Composability & Dependency Risks

**Dependency Risk Map:**

> **Chainlink AggregatorV3 feed** — via `ChainlinkAdapter.getNormalizedPrice*()`
> - Assumes: `latestRoundData()` returns a positive `answer` and a valid `updatedAt`
> - Validates: round completion (`answeredInRound >= roundId`), `answer > 0`, `updatedAt != 0`, staleness window
> - Mutability: external feed behavior/availability
> - On failure: reverts

> **Sequencer uptime feed (L2)** — via `ChainlinkAdapter._checkSequencer()`
> - Assumes: answer `0` means up; `startedAt` is meaningful
> - Validates: `startedAt != 0` and enforces a post-recovery grace period
> - Mutability: external feed availability
> - On failure: reverts

> **ERC20 stake token** — via `SafeERC20.safeTransfer*`
> - Assumes: token follows ERC20 transfer semantics (SafeERC20 mitigates non-standard return values)
> - Validates: SafeERC20 wrappers
> - Mutability: depends on token (upgradeable/pausable/blacklistable tokens introduce liveness risk)
> - On failure: reverts

---

## 3. Invariants

### Stated Invariants

- Oracle round monotonicity per template: `lastOracleRoundIdByTemplate[templateId]` must strictly increase when roundId is available.

### Inferred Invariants

- **Reserve conservation**: on resolution/cancel, funds move from `vaults[templateId].active` into `vaults[templateId].claims` and/or `vaults[templateId].fees`, and later `claim/withdrawFees` release those reserves and decrement the corresponding vault bucket.
- **Epoch status monotonicity**: an epoch must progress `Open → Locked → Resolved` (or into refund/cancel modes) and must not be resolved twice (`CheckpointAlreadyWritten` guards B writes).

---

## 4. Documentation Quality

| Aspect | Status | Notes |
|--------|--------|-------|
| README | Present | `README.md` |
| NatSpec | ~8 annotations | Sparse vs. 1777 nSLOC |
| Spec/Whitepaper | Missing | No protocol spec detected |
| Inline Comments | Adequate | Some intent is documented around rolling lifecycle and oracle checks |

---

## 5. Test Analysis

| Metric | Value | Source |
|--------|-------|--------|
| Test files | 28 | File scan (always reliable) |
| Test functions | 86 | File scan (always reliable) |
| Line coverage | Unavailable — compiler error (stack too deep / Yul exception) | `forge coverage` |
| Branch coverage | Unavailable — compiler error (stack too deep / Yul exception) | `forge coverage` |

### Test Depth

| Category | Count | Contracts Covered |
|----------|-------|-------------------|
| Unit | 86 | broad (per file scan count) |
| Stateless Fuzz | 2 | unknown (per file scan count) |
| Stateful Fuzz (Foundry) | 0 | none detected |
| Formal Verification (Halmos) | 1 | unknown (no config detected) |

### Gaps

- No detected invariant/stateful fuzzing (`foundry_invariant = 0`).
- No detected fork testing signals.
- No detected Echidna/Medusa/Certora/Scribble signals.

---

## 6. Developer & Git History

> Repo shape: squashed_import — development history is minimal and does not show meaningful source evolution.

### Contributors

| Author | Commits | Source Lines (+/-) | % of Source Changes |
|--------|--------:|--------------------|--------------------:|
| Asyam Jayanegara | 4 | unknown | unknown |

### Review & Process Signals

| Signal | Value | Assessment |
|--------|-------|------------|
| Unique contributors | 1 | Single-dev |
| Merge commits | 0 of 4 (0%) | No merge commits — likely no peer review visible |
| Repo age | 2026-03-19 → 2026-03-30 | ~11 days |
| Recent source activity (30d) | 0 commits | Quiet |
| Test co-change rate | 0% | Measures file co-modification only |

### Forked Dependencies

| Library | Path | Upstream | Status | Notes |
|---------|------|----------|--------|-------|
| openzeppelin-contracts | `lib/openzeppelin-contracts` | OpenZeppelin | Submodule | pragma diversity in dependency tree |
| openzeppelin-contracts-upgradeable | `lib/openzeppelin-contracts-upgradeable` | OpenZeppelin | Internalized | upstream fixes won’t auto-propagate |
| openzeppelin-foundry-upgrades | `lib/openzeppelin-foundry-upgrades` | OpenZeppelin | Internalized | upstream fixes won’t auto-propagate |
| chainlink-brownie-contracts | `lib/chainlink-brownie-contracts` | Chainlink | Internalized | large vendored surface |

### Security Observations

- Single-developer codebase with no visible merge/review signals.
- Large internalized dependency surface (OZ-upgradeable, OZ-foundry-upgrades, Chainlink) increases supply-chain review scope.

### Cross-Reference Synthesis

- Oracle reliance is a top threat surface (Section 2) and is implemented across `MarketEngine` and `ChainlinkAdapter`; prioritize the entire oracle read → checkpoint validation → settlement path.

---

## X-Ray Verdict

**FRAGILE** — good unit-test presence, but limited formal/stateful fuzz signals, sparse NatSpec/spec coverage, and high-trust single-key admin/keeper surfaces.

**Structural facts:**

1. 1777 nSLOC across 3 subsystems (core engine + oracle adapter + math/types).
2. UUPS upgradeable core with `admin`-gated `_authorizeUpgrade`.
3. 28 test files / 86 test functions detected, but coverage could not be produced due to compiler errors.

