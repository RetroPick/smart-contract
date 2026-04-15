# RetroPick Protocol — Base L2 + Chainlink Oracle Expansion
## Senior Protocol Engineer Upgrade Guide

**Current state:** `MarketEngineDispatcher` on Arbitrum One — 10 market types live in codebase (`Direction`, `Threshold`, `RangeClose`, `Anchor`, `Velocity`, `Ladder`, `Convergence`, `Composite`, `Corridor`, `Cascade`), single global `priceOracle` (ChainlinkAdapter), optional `TrustedReporterAdapter` per template with full OHLC support already implemented.

**Target state:** Base Mainnet — same engine, 5 new Chainlink oracle adapter families (Rate/Vol, SmartData, Macro, Equity), 5 new market types, 90+ Chainlink feed templates, per-template oracle adapter routing.

**Document scope:** Every code change, storage mutation, deployment step, and test required — written against the actual `MarketEngineState.sol` + module architecture already in production.

---

## Table of Contents

1. [Read This First — What Already Exists](#1-read-this-first)
2. [Upgrade Philosophy](#2-upgrade-philosophy)
3. [Phase 0 — Pre-Migration Checklist](#3-phase-0--pre-migration-checklist)
4. [Phase 1 — New Oracle Adapter Contracts](#4-phase-1--new-oracle-adapter-contracts)
5. [Phase 2 — MarketTypes.sol Expansion](#5-phase-2--markettypessol-expansion)
6. [Phase 3 — Resolvers.sol — No New Code, But Critical Dispatch Fixes](#6-phase-3--resolverssol)
7. [Phase 4 — MarketEngineState.sol Storage Extension](#7-phase-4--markenginestate-storage-extension)
8. [Phase 5 — Module Updates](#8-phase-5--module-updates)
9. [Phase 6 — UUPS Proxy Upgrade Execution](#9-phase-6--uups-proxy-upgrade-execution)
10. [Phase 7 — TrustedReporterAdapter Verification](#10-phase-7--trustedreporteradapter)
11. [Phase 8 — Template Deployment (Base Feed Registry)](#11-phase-8--template-deployment)
12. [Phase 9 — Backend Reporter Service Changes](#12-phase-9--reporter-service)
13. [Phase 10 — Testing Matrix](#13-phase-10--testing-matrix)
14. [Phase 11 — Deployment Script](#14-phase-11--deployment-script)
15. [Risk Register](#15-risk-register)
16. [Gas Analysis](#16-gas-analysis)
17. [Post-Deployment Verification](#17-post-deployment-verification)

---

## 1. Read This First

### 1.1 What Already Exists in Your Codebase

This is the most important section. The previous upgrade guide overstated the implementation work required. Read the actual smart contract documentation carefully before writing any code.

**Already live in `MarketType` enum — do not add again:**
```
Direction, Threshold, RangeClose, Anchor, Velocity, Ladder,
Convergence, Composite, Corridor, Cascade
```

**Already implemented in `Resolvers.sol` — do not rewrite:**
- `resolveDirection`, `resolveThreshold`, `resolveRangeClose`
- `resolveAnchor` — uses `anchorPriceE8` from template
- `resolveVelocity` — uses `velocityBoundsE4[]`, requires checkpoint A (same as Direction)
- `resolveLadder` — uses `ladderBoundsE8[]` + `ladderPayoutWeightsBps[]`, same bucket logic as RangeClose
- `resolveConvergence` — dual feed, uses `checkpointA_B`/`checkpointB_B`, `spreadToleranceBps`
- `resolveComposite` — `compositeFeedIds[4]`, `compositeConditions[4]`, `compositeLogic` (And/Or/Majority)
- `resolveCorridor` — reads `epochHighE8`/`epochLowE8`, uses `rangeBoundsE8[0]`/`rangeBoundsE8[1]`
- `resolveCascade` — reads `epochHighE8`, uses `rangeBoundsE8[]`, currently hardcodes `downward=false`

**Already in `Epoch` struct:**
- `checkpointA_B`, `checkpointB_B` — Convergence
- `compositeCheckpointsA[4]`, `compositeCheckpointsB[4]` — Composite
- `epochHighE8`, `epochLowE8`, `ohlcWritten` — Corridor/Cascade via TRO

**Already in `TrustedReporterAdapter`:**
- `postResult()` / `getResult()` — scalar/binary
- `postOhlcResult()` (EIP-712 `OhlcClaim`) + `getOhlcResult()` — OHLC for Corridor/Cascade

**Already validated by `_validateTemplate` / `_validateOracleParams`:**
- Convergence, Composite, Corridor, Cascade cannot be rolling — hardcoded revert
- TrustedReporter cannot be combined with Direction, Velocity, Convergence, Composite
- TrustedReporter cannot be rolling

### 1.2 Actual Gaps — What Needs to Be Built

| Gap | Code change needed |
|-----|-------------------|
| Single global `priceOracle` — cannot route to different adapters per template | Add `oracleClass` field to Template, add `_resolveOracle()` helper, add 4 oracle address slots to State |
| No `RateAdapter`, `SmartDataAdapter`, `MacroAdapter`, `EquityAdapter` | Deploy 4 new contracts (~30 lines each, port of ChainlinkAdapter) |
| No `VolatilityBand`, `StakingAPR`, `BitcoinIRC`, `NAVThreshold`, `MacroEvent` enum values | Add 5 values to `MarketType` enum — all reuse `resolveThreshold`, zero new resolver code |
| `resolveCascade` hardcodes `downward=false` | Add `cascadeDownward bool` to Template struct, snapshot into Epoch, pass to resolver |
| Base L2 sequencer address differs from Arbitrum | Redeploy ChainlinkAdapter with `0xBCF85224fc0756B9Fa45aA7892530B47e10b6433` |
| Reporter Service points to Arbitrum RPC | Update to Base RPC + verify EIP-712 chainId |

### 1.3 Exact Files That Change

```
REDEPLOY (no code change):
  src/adapters/ChainlinkAdapter.sol        ← same code, new constructor arg (Base sequencer)
  src/oracle/TrustedReporterAdapter.sol    ← same code, new deployment on Base
  src/yield/YieldRouterV2.sol              ← same code, new deployment pointing to Base Aave

ADD (new files):
  src/adapters/RateAdapter.sol             ← ~50 lines, port of ChainlinkAdapter
  src/adapters/SmartDataAdapter.sol        ← ~50 lines, same
  src/adapters/MacroAdapter.sol            ← ~50 lines, same
  src/adapters/EquityAdapter.sol           ← ~50 lines, same

EXTEND (additive changes only):
  src/types/MarketTypes.sol                ← +5 MarketType values, +OracleClass enum, +2 Template fields
  src/engine/MarketEngineState.sol         ← +4 oracle address slots from __gap, +_resolveOracle()
  src/engine/modules/MarketEngineAdminModule.sol        ← +4 oracle setter functions
  src/engine/modules/MarketEngineCoreLifecycleModule.sol ← +oracle routing in lock/resolve paths
  src/engine/modules/MarketEngineRollingLifecycleModule.sol ← +oracle routing in _tryReadOracle

NO CHANGE:
  src/logic/Resolvers.sol                  ← all 10 resolvers complete
  src/math/MarketMath.sol                  ← unchanged
  src/engine/modules/MarketEngineUserOpsClaimsModule.sol
  src/engine/modules/MarketEngineViewModule.sol
```

---

## 2. Upgrade Philosophy

### 2.1 The One Rule That Cannot Be Broken

`MarketEngineState.sol` ends with `uint256[45] __gap`. Every new storage variable must be appended immediately before this gap, and the gap must shrink by exactly the number of new slots consumed. Never insert, reorder, or delete existing variables.

```solidity
// CORRECT pattern — append before __gap, shrink __gap by count of new vars
address internal _rateOracle;        // slot N+1 (was __gap[0])
address internal _smartDataOracle;   // slot N+2 (was __gap[1])
address internal _macroOracle;       // slot N+3 (was __gap[2])
address internal _equityOracle;      // slot N+4 (was __gap[3])
uint256[41] __gap;                   // was [45], consumed 4 slots

// WRONG — any of these will corrupt all deployed market data
// inserting before existing variables / removing existing variables / changing types
```

### 2.2 Oracle Architecture Change — Core Concept

Current model: one global adapter for every template.
```
initialize() → priceOracle = ChainlinkAdapter
all templates use priceOracle
```

Target model: per-family adapter routing.
```
_resolveOracle(templateId):
  if template.oracleClass == CHAINLINK_RATE    → _rateOracle
  if template.oracleClass == CHAINLINK_SMARTDATA → _smartDataOracle
  if template.oracleClass == CHAINLINK_MACRO   → _macroOracle
  if template.oracleClass == CHAINLINK_EQUITY  → _equityOracle
  default (CHAINLINK_PRICE / zero)             → global priceOracle (backward compat)
```

Existing templates have `oracleClass = 0` (zero default), which maps to `CHAINLINK_PRICE` and falls through to the existing `priceOracle`. **No migration of existing templates needed.**

### 2.3 Proxy Upgrade vs. Config-Only Changes

| Change type | Proxy upgrade required |
|-------------|----------------------|
| Deploy RateAdapter / SmartDataAdapter etc. | No |
| Add `oracleClass`/`cascadeDownward` to Template struct | **Yes** |
| Add 5 new `MarketType` enum values | **Yes** |
| Add `_rateOracle` etc. to MarketEngineState | **Yes** |
| Add `setRateOracle()` etc. to AdminModule | **Yes** (new module code) |
| Add `_resolveOracle()` routing to lifecycle modules | **Yes** (new module code) |
| `upsertTemplate()` for new templates on Base | No (admin call post-upgrade) |
| Cascade downward: new template with `cascadeDownward=true` | No (admin call post-upgrade) |

---

## 3. Phase 0 — Pre-Migration Checklist

### 3.1 Codebase Verification

```bash
# 1. Confirm all 10 MarketType values exist
grep -c "Direction\|Threshold\|RangeClose\|Anchor\|Velocity\|Ladder\|Convergence\|Composite\|Corridor\|Cascade" \
  src/types/MarketTypes.sol
# Expected: 10 matches in enum

# 2. Confirm TrustedReporterAdapter has OHLC methods
grep -n "postOhlcResult\|getOhlcResult\|OhlcClaim" src/oracle/TrustedReporterAdapter.sol
# Must find all three

# 3. Confirm current __gap = 45
forge inspect src/engine/MarketEngineState.sol:MarketEngineState storage-layout \
  | grep "__gap"
# numberOfBytes should = 1440 (45 × 32)

# 4. Confirm Cascade resolver is upward-only (bug we're fixing)
grep -n "downward\|false\|Downward" src/logic/Resolvers.sol | grep -i cascade
# Should show hardcoded false

# 5. Confirm OHLC fields exist in Epoch struct
grep -n "epochHighE8\|epochLowE8\|ohlcWritten" src/types/MarketTypes.sol
# Must find all three
```

### 3.2 Operational Preconditions

- [ ] All rolling markets halted on Arbitrum (`haltRollingMarket()` for each)
- [ ] All manual epochs resolved or cancelled on Arbitrum
- [ ] `pauseProgram(true)` called on Arbitrum proxy
- [ ] Base Mainnet sequencer feed address confirmed: `0xBCF85224fc0756B9Fa45aA7892530B47e10b6433`
- [ ] Base Mainnet flags registry confirmed: `0x71c5CC2aEB9Fa812CA360E9bAC7108FC23312cdd`
- [ ] Base Aave v3 pool address confirmed for YieldRouterV2
- [ ] Gnosis Safe configured for Base network (chain ID 8453)
- [ ] Reporter hot wallet funded with ETH on Base
- [ ] All 4 new oracle adapter addresses verified on `basescan.org` after deployment
- [ ] Full testnet rehearsal completed on Base Sepolia

### 3.3 Fork Test Setup

```bash
export BASE_RPC="https://mainnet.base.org"

# All upgrade testing must run against a Base mainnet fork
forge test --fork-url $BASE_RPC \
  --fork-block-number $(cast block-number --rpc-url $BASE_RPC) \
  --match-contract "BaseUpgradeTest" -vvv
```

---

## 4. Phase 1 — New Oracle Adapter Contracts

These are independent contracts — deploy and verify before any proxy changes.

### 4.1 RateAdapter.sol

Reads Chainlink Rate & Volatility feeds (BTC/ETH Realized Volatility, ETH Staking APR, Bitcoin Interest Rate Curve). Key semantic difference from `ChainlinkAdapter`: `answer == 0` is valid (zero staking APR during network pause is real data). `answer < 0` remains an error.

```solidity
// src/adapters/RateAdapter.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from
    "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPriceOracleWithRoundId} from "../interfaces/IPriceOracleWithRoundId.sol";

/// @title  RateAdapter
/// @notice Reads Chainlink Rate & Volatility feeds via AggregatorV3Interface.
///         Identical to ChainlinkAdapter except answer == 0 is allowed
///         (zero staking APR / zero volatility are valid real-world data points).
contract RateAdapter is IPriceOracle, IPriceOracleWithRoundId {

    address public immutable sequencerFeed;
    uint256 public constant GRACE_PERIOD = 3600; // 1 hour post-sequencer-recovery

    error InvalidFeedAddress();
    error NegativeRate();
    error MissingUpdatedAt();
    error StaleRateFeed(uint256 updatedAt, uint256 maxAge, uint256 nowTs);
    error RoundNotComplete(uint80 roundId, uint80 answeredInRound);
    error SequencerDown();
    error InGracePeriod();

    constructor(address _sequencerFeed) {
        sequencerFeed = _sequencerFeed;
    }

    function getNormalizedPrice(
        bytes32 feedId,
        uint64 maxAgeSeconds,
        uint64 /*nowTs*/
    ) external view override returns (int256 rateE8, uint64 publishTime, uint256 confidenceE8) {
        _checkSequencer();
        address feedAddr = address(uint160(uint256(feedId)));
        if (feedAddr == address(0)) revert InvalidFeedAddress();

        AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            feed.latestRoundData();

        if (answeredInRound < roundId) revert RoundNotComplete(roundId, answeredInRound);
        if (answer < 0) revert NegativeRate();          // 0 is allowed, negative is not
        if (updatedAt == 0) revert MissingUpdatedAt();
        if (block.timestamp - updatedAt > uint256(maxAgeSeconds)) {
            revert StaleRateFeed(updatedAt, maxAgeSeconds, block.timestamp);
        }

        uint8 d = feed.decimals();
        rateE8 = _normalizeToE8(answer, d);
        publishTime = uint64(updatedAt);
        confidenceE8 = 0;
    }

    function getNormalizedPriceWithRoundId(
        bytes32 feedId,
        uint64 maxAgeSeconds,
        uint64 nowTs
    ) external view override
      returns (int256 rateE8, uint64 publishTime, uint256 confidenceE8, uint80 roundId)
    {
        _checkSequencer();
        address feedAddr = address(uint160(uint256(feedId)));
        if (feedAddr == address(0)) revert InvalidFeedAddress();

        AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);
        uint80 answeredInRound;
        int256 answer;
        uint256 updatedAt;
        (roundId, answer,, updatedAt, answeredInRound) = feed.latestRoundData();

        if (answeredInRound < roundId) revert RoundNotComplete(roundId, answeredInRound);
        if (answer < 0) revert NegativeRate();
        if (updatedAt == 0) revert MissingUpdatedAt();
        if (block.timestamp - updatedAt > uint256(maxAgeSeconds)) {
            revert StaleRateFeed(updatedAt, maxAgeSeconds, block.timestamp);
        }

        uint8 d = feed.decimals();
        rateE8 = _normalizeToE8(answer, d);
        publishTime = uint64(updatedAt);
        confidenceE8 = 0;
    }

    function _checkSequencer() internal view {
        if (sequencerFeed == address(0)) return;
        (, int256 answer, uint256 startedAt,,) =
            AggregatorV3Interface(sequencerFeed).latestRoundData();
        if (answer != 0) revert SequencerDown();
        if (block.timestamp - startedAt <= GRACE_PERIOD) revert InGracePeriod();
    }

    function _normalizeToE8(int256 answer, uint8 decimals) internal pure returns (int256) {
        if (decimals == 8) return answer;
        if (decimals > 8) return answer / int256(10 ** (decimals - 8));
        return answer * int256(10 ** (8 - decimals));
    }
}
```

### 4.2 SmartDataAdapter.sol, MacroAdapter.sol, EquityAdapter.sol

These are near-identical to RateAdapter with different validation policies:

**SmartDataAdapter.sol** (NAV, AUM, Proof of Reserve):
- `answer == 0` allowed — a PoR feed returning zero is valid (edge case: fully unbacked)
- `answer < 0` rejected — NAV cannot be negative

**MacroAdapter.sol** (BEA GDP, PCE, US Government Macro):
- `answer < 0` **allowed** — negative GDP growth, negative YoY PCE change are real economic data
- Only revert on `updatedAt == 0`
- `maxAgeSeconds` in templates must be 30–90 days for monthly/quarterly data

**EquityAdapter.sol** (Ondo Finance tokenized equity — SPY, QQQ, AAPL, TSLA, NVDA, MSFT):
- Same as SmartDataAdapter — tokenized equity feeds return NAV/price in e8
- `answer >= 0` only, daily update cadence

### 4.3 Deployment & Verification

```bash
BASE_SEQ="0xBCF85224fc0756B9Fa45aA7892530B47e10b6433"

CHAINLINK_ADAPTER=$(forge create src/adapters/ChainlinkAdapter.sol:ChainlinkAdapter \
  --constructor-args $BASE_SEQ --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

RATE_ADAPTER=$(forge create src/adapters/RateAdapter.sol:RateAdapter \
  --constructor-args $BASE_SEQ --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

SMARTDATA_ADAPTER=$(forge create src/adapters/SmartDataAdapter.sol:SmartDataAdapter \
  --constructor-args $BASE_SEQ --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

MACRO_ADAPTER=$(forge create src/adapters/MacroAdapter.sol:MacroAdapter \
  --constructor-args $BASE_SEQ --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

EQUITY_ADAPTER=$(forge create src/adapters/EquityAdapter.sol:EquityAdapter \
  --constructor-args $BASE_SEQ --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

# Smoke test: ETH/USD via ChainlinkAdapter on Base
ETH_USD_BASE="0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70"
cast call $CHAINLINK_ADAPTER \
  "getNormalizedPrice(bytes32,uint64,uint64)(int256,uint64,uint256)" \
  $(cast --to-bytes32 $(cast --to-uint256 $ETH_USD_BASE)) \
  7200 $(cast block timestamp --rpc-url $BASE_RPC) \
  --rpc-url $BASE_RPC
# Expected: int256 in range [100000000000, 500000000000] (ETH price in e8)
```

---

## 5. Phase 2 — MarketTypes.sol Expansion

### 5.1 5 New MarketType Values — Append After Cascade

```solidity
// src/types/MarketTypes.sol — find the MarketType enum and append after Cascade:

enum MarketType {
    // EXISTING — do not reorder or remove
    Direction,
    Threshold,
    RangeClose,
    Anchor,
    Velocity,
    Ladder,
    Convergence,
    Composite,
    Corridor,
    Cascade,

    // NEW — append after Cascade
    VolatilityBand,  // realised vol % vs threshold (CHAINLINK_RATE adapter)
    StakingAPR,      // ETH staking APR vs threshold (CHAINLINK_RATE adapter)
    BitcoinIRC,      // BTC interest rate — direction or threshold (CHAINLINK_RATE adapter)
    NAVThreshold,    // tokenized fund NAV vs threshold (CHAINLINK_SMARTDATA adapter)
    MacroEvent       // BEA GDP/PCE vs threshold (CHAINLINK_MACRO adapter)
}
```

**Zero new resolver functions needed.** All 5 new types resolve through the existing `resolveThreshold()` or `resolveDirection()`. The sole innovation is which oracle adapter is called to read the data.

### 5.2 New OracleClass Enum

```solidity
// src/types/MarketTypes.sol — add new enum (can be placed near MarketType)

/// @notice Identifies which Chainlink adapter family handles oracle reads for a template.
///         Zero value = CHAINLINK_PRICE for backward compatibility with all existing templates.
enum OracleClass {
    CHAINLINK_PRICE,      // existing ChainlinkAdapter — default for all existing templates
    CHAINLINK_RATE,       // new RateAdapter (vol, APR, IRC)
    CHAINLINK_SMARTDATA,  // new SmartDataAdapter (NAV, AUM, PoR)
    CHAINLINK_MACRO,      // new MacroAdapter (BEA GDP, PCE)
    CHAINLINK_EQUITY      // new EquityAdapter (Ondo tokenized stocks/ETFs)
}
```

### 5.3 Template Struct — Append 2 New Fields

```solidity
// src/types/MarketTypes.sol — find the Template struct
// Append the following 2 new fields AFTER all existing fields (never insert mid-struct)

struct Template {
    // ════ ALL EXISTING FIELDS — DO NOT TOUCH OR REORDER ════
    // ... (slug, assetSymbol, marketType, condition, thresholdRule, outcomeCount,
    //      switchFeeBps, settlementFeeBps, equalPriceVoids, feeOnLosingPool,
    //      allowMultiSidePositions, executionMode, rollingIntervalSeconds,
    //      rollingBufferSeconds, oracleMaxDelaySeconds, oracleMaxConfidenceBps,
    //      oracleFeedId, absoluteThresholdValueE8, rangeBoundsE8, anchorPriceE8,
    //      velocityBoundsE4, ladderBoundsE8, ladderPayoutWeightsBps,
    //      oracleFeedIdB, spreadToleranceBps, compositeFeedIds, compositeConditions,
    //      compositeFeedCount, compositeLogic, templateOracleKind, eventOracle)
    // ════════════════════════════════════════════════════════

    // ── NEW FIELDS — append after all existing ──

    /// @dev Oracle family for this template. Zero = CHAINLINK_PRICE (backward compat).
    ///      TRUSTED_REPORTER templates ignore this field (they use templateOracleKind + eventOracle).
    OracleClass oracleClass;

    /// @dev For Cascade markets: if true, the resolver uses epochLowE8 (support breaks downward).
    ///      If false (default), uses epochHighE8 (resistance breaks upward — current behaviour).
    bool cascadeDownward;
}
```

### 5.4 Epoch Struct — Append 1 New Field

```solidity
// src/types/MarketTypes.sol — Epoch struct — append after all existing fields

struct Epoch {
    // ════ ALL EXISTING FIELDS — DO NOT TOUCH ════
    // ... (timing, status, checkpointA, checkpointB, checkpointA_B, checkpointB_B,
    //      compositeCheckpointsA[4], compositeCheckpointsB[4], epochHighE8,
    //      epochLowE8, ohlcWritten, outcomePools, totalPool, winningOutcomeMask,
    //      claimLiabilityTotal, settlementFeeTotal, refundMode, claimable,
    //      remainingWinningStake, claimedTotal, marketType, condition,
    //      settlementFeeBps, feeOnLosingPool, equalPriceVoids,
    //      oracleMaxDelaySeconds, oracleMaxConfidenceBps, absoluteThresholdValueE8,
    //      rangeBoundsE8, anchorPriceE8, velocityBoundsE4, ladderBoundsE8,
    //      ladderPayoutWeightsBps, spreadToleranceBps, compositeFeedIds,
    //      compositeConditions, compositeFeedCount, compositeLogic,
    //      templateOracleKind, eventOracle, outcomeCount)
    // ═════════════════════════════════════════════

    // ── NEW FIELD — append after all existing ──
    bool cascadeDownward;  // snapshotted from template at openEpoch
}
```

### 5.5 requiresCheckpointAOnLock — Update for BitcoinIRC

```solidity
// src/types/MarketTypes.sol — update existing helper

function requiresCheckpointAOnLock(Epoch storage e) internal view returns (bool) {
    return e.marketType == MarketType.Direction
        || e.marketType == MarketType.Velocity
        || e.marketType == MarketType.Convergence
        || e.marketType == MarketType.Composite
        || e.marketType == MarketType.BitcoinIRC; // NEW: when used in Direction mode
    // VolatilityBand, StakingAPR, NAVThreshold, MacroEvent = Threshold mode, no A needed
}
```

### 5.6 Validation Extensions

In `_validateOracleParams` (CoreLifecycleModule), add:

```solidity
// After existing TRO validation checks, append:
// New types require Chainlink oracle family — reject TRO for them
if (template.templateOracleKind == OracleKind.TrustedReporter) {
    if (template.marketType == MarketType.VolatilityBand
        || template.marketType == MarketType.StakingAPR
        || template.marketType == MarketType.BitcoinIRC
        || template.marketType == MarketType.NAVThreshold
        || template.marketType == MarketType.MacroEvent)
    {
        revert InvalidTemplate();
    }
}
```

---

## 6. Phase 3 — Resolvers.sol

### 6.1 No New Resolver Functions Required

All 5 new market types use existing resolvers:

| New market type | Resolver called | Existing resolver sufficient? |
|----------------|-----------------|-------------------------------|
| `VolatilityBand` | `resolveThreshold` | Yes — vol % in e8 vs threshold, identical math |
| `StakingAPR` | `resolveThreshold` | Yes — APR % in e8 vs threshold |
| `BitcoinIRC` | `resolveThreshold` or `resolveDirection` | Yes — depends on template condition |
| `NAVThreshold` | `resolveThreshold` | Yes — fund NAV in e8 vs threshold |
| `MacroEvent` | `resolveThreshold` | Yes — GDP/PCE % in e8 vs threshold |

### 6.2 Fix: Cascade Downward Direction in Settlement Dispatch

The current settlement dispatch in both `MarketEngineCoreLifecycleModule` and `MarketEngineRollingLifecycleModule` has this pattern for Cascade:

```solidity
// CURRENT CODE (find and update in both _computeSettlementOutputsWithEffectivePool functions)
e.winningOutcomeMask = Resolvers.resolveCascade(
    e.epochHighE8,
    e.rangeBoundsE8,
    false  // ← hardcoded upward-only — BUG FOR DOWNWARD CASCADES
);

// CHANGE TO:
e.winningOutcomeMask = Resolvers.resolveCascade(
    e.cascadeDownward ? e.epochLowE8 : e.epochHighE8,  // use low watermark for downward
    e.rangeBoundsE8,
    e.cascadeDownward   // read from epoch snapshot of template field
);
```

### 6.3 Snapshot cascadeDownward into Epoch at openEpoch

In `_openEpoch` (CoreLifecycleModule), where other template fields are snapshotted into the epoch struct, add:

```solidity
// In _openEpoch — where template fields are copied to epoch:
e.cascadeDownward = t.cascadeDownward;  // snapshot for resolver at resolve time
```

### 6.4 New Types in Settlement Dispatch

In both lifecycle modules' `_computeSettlementOutputsWithEffectivePool`, insert before the final `else → resolveLadder` branch:

```solidity
// INSERT before the existing Ladder else-branch:
} else if (
    e.marketType == MarketType.VolatilityBand
    || e.marketType == MarketType.StakingAPR
    || e.marketType == MarketType.NAVThreshold
    || e.marketType == MarketType.MacroEvent
) {
    // All rate/macro threshold types — identical to Threshold resolver
    e.winningOutcomeMask = Resolvers.resolveThreshold(
        e.condition,
        e.absoluteThresholdValueE8,
        e.checkpointB
    );
} else if (e.marketType == MarketType.BitcoinIRC) {
    // BitcoinIRC supports both Direction mode (is rate up/down?) and Threshold mode
    if (e.condition == MarketTypes.Condition.None || /* no threshold set */ e.absoluteThresholdValueE8 == 0) {
        // Direction mode — requires checkpointA (snapshotted at lock)
        bool voided;
        (voided, e.winningOutcomeMask) = Resolvers.resolveDirection(
            e.checkpointA, e.checkpointB, e.equalPriceVoids
        );
        if (voided) {
            e.refundMode = true;
            e.winningOutcomeMask = 0;
        }
    } else {
        // Threshold mode
        e.winningOutcomeMask = Resolvers.resolveThreshold(
            e.condition, e.absoluteThresholdValueE8, e.checkpointB
        );
    }
```

**Critical:** This must be added to BOTH `MarketEngineCoreLifecycleModule` and `MarketEngineRollingLifecycleModule`. The rolling module comment says: "the else → resolveLadder is safe only because Convergence/Composite/Corridor/Cascade cannot be rolling". We must ensure the new types are dispatched before that else clause.

---

## 7. Phase 4 — MarketEngineState Storage Extension

### 7.1 Storage Slot Changes

```solidity
// src/engine/MarketEngineState.sol
// Find the __gap declaration (currently uint256[45] __gap)
// Add 4 new oracle address slots immediately BEFORE it, shrink gap to 41

// ── NEW: 4 oracle adapter addresses (consume 4 slots from __gap) ──
address internal _rateOracle;        // RateAdapter for CHAINLINK_RATE templates
address internal _smartDataOracle;   // SmartDataAdapter for CHAINLINK_SMARTDATA templates
address internal _macroOracle;       // MacroAdapter for CHAINLINK_MACRO templates
address internal _equityOracle;      // EquityAdapter for CHAINLINK_EQUITY templates

uint256[41] __gap;  // WAS [45] — shrank by 4 to accommodate new oracle addresses
```

### 7.2 Verify Slot Alignment

```bash
# Before adding new fields, save the current storage layout
forge inspect src/engine/MarketEngineState.sol:MarketEngineState \
  storage-layout --json > /tmp/layout_before.json

# After adding new fields, generate the new layout
forge inspect src/engine/MarketEngineState.sol:MarketEngineState \
  storage-layout --json > /tmp/layout_after.json

# CRITICAL CHECK: all slots 0 through (N-1) must be byte-for-byte identical
# Only the 4 new slots + shrunken __gap should differ
python3 -c "
import json
before = json.load(open('/tmp/layout_before.json'))['storage']
after  = json.load(open('/tmp/layout_after.json'))['storage']
# All entries in 'before' must appear at same slot in 'after'
before_map = {e['slot']: e for e in before}
for entry in before:
    slot = entry['slot']
    assert slot in {e['slot'] for e in after}, f'MISSING SLOT {slot}'
    after_entry = next(e for e in after if e['slot'] == slot and e['label'] == entry['label'])
    assert after_entry, f'LABEL MISMATCH at slot {slot}'
print('Storage layout check: PASS')
"
```

### 7.3 Oracle Routing Helper

```solidity
// src/engine/MarketEngineState.sol — add new internal view function

/// @notice Returns the correct IPriceOracle adapter for a given template.
///         Existing templates with oracleClass = 0 (CHAINLINK_PRICE) continue to use
///         the global priceOracle, maintaining full backward compatibility.
function _resolveOracle(bytes32 templateId) internal view returns (IPriceOracle) {
    MarketTypes.Template storage t = _templates[templateId];

    if (t.oracleClass == MarketTypes.OracleClass.CHAINLINK_RATE) {
        require(_rateOracle != address(0), "RateOracle not configured");
        return IPriceOracle(_rateOracle);
    }
    if (t.oracleClass == MarketTypes.OracleClass.CHAINLINK_SMARTDATA) {
        require(_smartDataOracle != address(0), "SmartDataOracle not configured");
        return IPriceOracle(_smartDataOracle);
    }
    if (t.oracleClass == MarketTypes.OracleClass.CHAINLINK_MACRO) {
        require(_macroOracle != address(0), "MacroOracle not configured");
        return IPriceOracle(_macroOracle);
    }
    if (t.oracleClass == MarketTypes.OracleClass.CHAINLINK_EQUITY) {
        require(_equityOracle != address(0), "EquityOracle not configured");
        return IPriceOracle(_equityOracle);
    }
    // Default: CHAINLINK_PRICE (zero) → global priceOracle (backward compatible)
    return priceOracle;
}
```

---

## 8. Phase 5 — Module Updates

### 8.1 AdminModule — 4 New Oracle Setters

```solidity
// src/engine/modules/MarketEngineAdminModule.sol — append after existing setters

event RateOracleUpdated(address indexed oldOracle, address indexed newOracle);
event SmartDataOracleUpdated(address indexed oldOracle, address indexed newOracle);
event MacroOracleUpdated(address indexed oldOracle, address indexed newOracle);
event EquityOracleUpdated(address indexed oldOracle, address indexed newOracle);

function setRateOracle(address oracle) external {
    if (msg.sender != admin) revert Unauthorized();
    emit RateOracleUpdated(_rateOracle, oracle);
    _rateOracle = oracle;
}

function setSmartDataOracle(address oracle) external {
    if (msg.sender != admin) revert Unauthorized();
    emit SmartDataOracleUpdated(_smartDataOracle, oracle);
    _smartDataOracle = oracle;
}

function setMacroOracle(address oracle) external {
    if (msg.sender != admin) revert Unauthorized();
    emit MacroOracleUpdated(_macroOracle, oracle);
    _macroOracle = oracle;
}

function setEquityOracle(address oracle) external {
    if (msg.sender != admin) revert Unauthorized();
    emit EquityOracleUpdated(_equityOracle, oracle);
    _equityOracle = oracle;
}
```

### 8.2 CoreLifecycleModule — Oracle Routing

Replace the direct `priceOracle` reference in lock and resolve paths with `_resolveOracle(templateId)`:

```solidity
// In _lockEpoch — find where the oracle adapter is obtained for Chainlink templates:
// BEFORE:
//   IPriceOracle oracle = priceOracle;

// AFTER:
IPriceOracle oracle = (t.templateOracleKind == MarketTypes.OracleKind.Chainlink)
    ? _resolveOracle(templateId)
    : priceOracle; // TRO path doesn't use IPriceOracle for price reads

// Apply the same change wherever priceOracle is called directly for oracle reads.
// The IEventOracle / TRO path (t.eventOracle) is ENTIRELY UNCHANGED.
```

### 8.3 RollingLifecycleModule — Oracle Routing in _tryReadOracle

```solidity
// In _tryReadOracle — find where the oracle is instantiated:
// BEFORE:
//   IPriceOracle oracle = priceOracle;  (or however the oracle is obtained)

// AFTER: pass adapter through from the caller, or resolve inside:
// Option A — add _resolveOracle call inside _tryReadOracle:
function _tryReadOracle(
    bytes32 templateId,
    bytes32 feedId,
    uint64 maxDelay,
    uint64 nowTs
) internal view returns (bool ok, int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId) {
    IPriceOracle oracle = _resolveOracle(templateId); // NEW: per-template routing
    // rest of function unchanged — calls oracle.getNormalizedPrice(feedId, ...)
}
```

---

## 9. Phase 6 — UUPS Proxy Upgrade Execution

### 9.1 Pre-Upgrade State Snapshot

```bash
echo "=== Pre-Upgrade Snapshot $(date) ===" > /tmp/upgrade_snapshot.txt
cast call $PROXY "admin()(address)" --rpc-url $BASE_RPC >> /tmp/upgrade_snapshot.txt
cast call $PROXY "treasury()(address)" --rpc-url $BASE_RPC >> /tmp/upgrade_snapshot.txt
cast call $PROXY "workerAuthority()(address)" --rpc-url $BASE_RPC >> /tmp/upgrade_snapshot.txt
cast storage $PROXY 0x360894a13ba1a3210667c828492db98dca3e2076 \
  --rpc-url $BASE_RPC >> /tmp/upgrade_snapshot.txt

# For every active templateId: record marketType, oracleFeedId, executionMode
# These must be identical post-upgrade
```

### 9.2 Build and Size Check

```bash
forge build --force
forge build --sizes  # All modules must remain < 24KB

# Run storage layout validator (requires --ffi)
forge script script/production/ValidateUpgrade.s.sol \
  --rpc-url $BASE_RPC --ffi -vvv
```

### 9.3 Deploy New Modules

```bash
ADMIN_MOD=$(forge create \
  src/engine/modules/MarketEngineAdminModule.sol:MarketEngineAdminModule \
  --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

CORE_MOD=$(forge create \
  src/engine/modules/MarketEngineCoreLifecycleModule.sol:MarketEngineCoreLifecycleModule \
  --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

ROLLING_MOD=$(forge create \
  src/engine/modules/MarketEngineRollingLifecycleModule.sol:MarketEngineRollingLifecycleModule \
  --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

# UserOpsClaimsModule and ViewModule unchanged — redeploy for consistency
USER_OPS_MOD=$(forge create \
  src/engine/modules/MarketEngineUserOpsClaimsModule.sol:MarketEngineUserOpsClaimsModule \
  --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

VIEW_MOD=$(forge create \
  src/engine/modules/MarketEngineViewModule.sol:MarketEngineViewModule \
  --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

# Deploy new dispatcher implementation
NEW_IMPL=$(forge create \
  src/engine/MarketEngineDispatcher.sol:MarketEngineDispatcher \
  --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')

echo "New implementation: $NEW_IMPL"
```

### 9.4 Execute Upgrade via Multisig

```solidity
// upgradeToAndCall with empty calldata — no re-initializer needed
// New storage slots default to address(0) — safe starting state
bytes memory upgradeCalldata = abi.encodeWithSelector(
    IUUPSUpgradeable.upgradeToAndCall.selector,
    NEW_IMPL,
    ""  // no initializer data
);
// Submit to Gnosis Safe → collect N-of-M signatures → execute
```

### 9.5 Wire New Selectors

After upgrade, wire new selectors and remap existing selectors to new module addresses:

```bash
# Wire new oracle setter selectors
for SIG in \
  "setRateOracle(address)" \
  "setSmartDataOracle(address)" \
  "setMacroOracle(address)" \
  "setEquityOracle(address)"; do
  cast send $PROXY "setSelectorModule(bytes4,address,bool)" \
    $(cast sig "$SIG") $ADMIN_MOD false \
    --rpc-url $BASE_RPC --private-key $ADMIN_KEY
done

# Remap ALL existing admin module selectors to new admin module
for SIG in \
  "pauseProgram(bool)" \
  "setTreasury(address)" \
  "setWorkerAuthority(address)" \
  "initializeMarket(bytes32)" \
  "withdrawFees(bytes32,uint256)" \
  "setYieldRouter(address,uint16)" \
  "setLmRewardsEnabled(bool)" \
  "keeperClaimLmRewards(bytes32)" \
  "yieldEmergencyWithdraw(bytes32)"; do
  cast send $PROXY "setSelectorModule(bytes4,address,bool)" \
    $(cast sig "$SIG") $ADMIN_MOD false \
    --rpc-url $BASE_RPC --private-key $ADMIN_KEY
done

# IMPORTANT: upsertTemplate ABI changes due to new Template struct fields
# Wire the NEW upsertTemplate selector (different from old due to struct extension)
cast send $PROXY "setSelectorModule(bytes4,address,bool)" \
  $(cast sig "upsertTemplate(...)") $CORE_MOD false \
  --rpc-url $BASE_RPC --private-key $ADMIN_KEY

# Remap all core lifecycle selectors
for SIG in \
  "openEpoch(bytes32,uint64,uint64,uint64,uint64)" \
  "lockEpoch(bytes32,uint64)" \
  "resolveEpoch(bytes32,uint64)" \
  "cancelEpoch(bytes32,uint64,bool)" \
  "openEpochBatch(bytes32[],uint64[],uint64[],uint64[],uint64[])" \
  "lockEpochBatch(bytes32[],uint64[])" \
  "resolveEpochBatch(bytes32[],uint64[])"; do
  cast send $PROXY "setSelectorModule(bytes4,address,bool)" \
    $(cast sig "$SIG") $CORE_MOD false \
    --rpc-url $BASE_RPC --private-key $ADMIN_KEY
done

# Remap rolling lifecycle selectors
for SIG in \
  "genesisStartRolling(bytes32)" \
  "genesisLockRolling(bytes32)" \
  "executeRollingRound(bytes32)" \
  "executeRollingRoundBatch(bytes32[])" \
  "haltRollingMarket(bytes32)" \
  "cancelRollingEpochWhileHalted(bytes32,uint64,bool)" \
  "resetRollingLifecycle(bytes32,uint64)"; do
  cast send $PROXY "setSelectorModule(bytes4,address,bool)" \
    $(cast sig "$SIG") $ROLLING_MOD false \
    --rpc-url $BASE_RPC --private-key $ADMIN_KEY
done
```

### 9.6 Set Oracle Adapters

```bash
cast send $PROXY "setRateOracle(address)" $RATE_ADAPTER \
  --rpc-url $BASE_RPC --private-key $ADMIN_KEY

cast send $PROXY "setSmartDataOracle(address)" $SMARTDATA_ADAPTER \
  --rpc-url $BASE_RPC --private-key $ADMIN_KEY

cast send $PROXY "setMacroOracle(address)" $MACRO_ADAPTER \
  --rpc-url $BASE_RPC --private-key $ADMIN_KEY

cast send $PROXY "setEquityOracle(address)" $EQUITY_ADAPTER \
  --rpc-url $BASE_RPC --private-key $ADMIN_KEY
```

---

## 10. Phase 7 — TrustedReporterAdapter

### 10.1 Existing Implementation Is Sufficient

The current `TrustedReporterAdapter` already implements `postOhlcResult()` (EIP-712 `OhlcClaim`) and `getOhlcResult()`. No code changes needed — deploy fresh on Base.

```bash
TRUSTED_REPORTER=$(forge create \
  src/oracle/TrustedReporterAdapter.sol:TrustedReporterAdapter \
  --constructor-args $REPORTER_HOT_WALLET \
  --rpc-url $BASE_RPC --private-key $DEPLOYER_KEY --verify \
  | grep "Deployed to:" | awk '{print $3}')
```

### 10.2 marketId Must Match positionKey Exactly

The `marketId` passed to `postOhlcResult` must equal `positionKey(templateId, epochId)`:

```solidity
// MarketEngineState.sol:
function positionKey(bytes32 templateId, uint64 epochId) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(templateId, epochId));
}
```

```typescript
// Reporter Service — MUST match exactly:
const marketId = ethers.keccak256(
    ethers.solidityPacked(
        ['bytes32', 'uint64'],  // NOTE: uint64 NOT uint256 — packed encoding
        [templateId, epochId]
    )
);
// A common mistake: using abi.encode (32-byte aligned) instead of
// abi.encodePacked (tightly packed) will produce a different hash
```

### 10.3 Update chainId in EIP-712 Domain

```typescript
// The TrustedReporterAdapter EIP-712 domain separator includes chainId.
// Arbitrum = 42161, Base = 8453
// When signing OhlcClaim on Base, the wallet must sign with chainId = 8453.
const domain = {
    name: "TrustedReporterAdapter",  // must match contract constant
    version: "1",                     // must match contract constant
    chainId: 8453,                    // Base Mainnet
    verifyingContract: trustedReporterAddress
};
```

---

## 11. Phase 8 — Template Deployment (Base Feed Registry)

### 11.1 Verified Base Mainnet Addresses

> **Always verify independently** on `basescan.org` and `docs.chain.link/data-feeds/price-feeds/addresses` (select Base network) before use.

**Price Feeds (CHAINLINK_PRICE, use ChainlinkAdapter):**

| Feed | Base Proxy Address | Heartbeat/Dev | Market types |
|------|--------------------|---------------|-------------|
| ETH/USD | `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70` | 1h/0.15% | Direction, Velocity, Ladder, Anchor |
| BTC/USD | `0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F` | 1h/0.05% | Direction, Velocity, Ladder, Cascade, Anchor |
| SOL/USD | `0x975043adBb80fc32276CbF9Bbcfd4A601a12462D` | 1h/0.1% | Direction, Threshold, Momentum |
| LINK/USD | `0x17CAb8Fe31E32f08326e5E27412894e49B0f9D65` | 1h/0.5% | Direction, Threshold |
| cbETH/USD | `0xd7818272B9e248357d13057AAb0B417aF31E817d` | 1h/0.5% | Direction, Convergence (with cbETH/ETH) |
| cbETH/ETH | `0x806b4Ac04501c29769051e42783cF04dCE41440b` | 24h/0.5% | Convergence feedB (vs wstETH/ETH) |
| wstETH/ETH | `0xa669E5272E60f78299F4824495cE01a3923f4380` | 24h/0.5% | Convergence feedA or feedB |
| XAU/USD | `0xFFE405EB4D20b680e1A7eF62e5E34E1498D0d7a4` | 1h/0.1% | Direction, Threshold, Corridor, Ladder, Anchor |
| XAG/USD | `0x9dFC79Aaeb5bb0f96C6e8402099D9B5B6Ed49CC` | 24h/0.5% | Direction, Convergence (vs XAU) |
| WTI/USD | `0x6cF2f5c1A5d65cdD2C2EAb9D2A7e9B6b6E4aAbf` | 1h/0.5% | Direction, Threshold, Corridor |
| EUR/USD | `0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F` | 1h/0.1% | Direction, Corridor, Convergence (vs GBP) |
| GBP/USD | `0x84b97F0f94E96CE8C23E94AE22A50cBFAA98B1BA` | 1h/0.1% | Direction, Corridor |
| USDC/USD | `0x7e860098F58bBFC8648a4311b374B1D669a2bc9B` | 24h/0.1% | Corridor (depeg: $0.995–$1.005) |
| USDT/USD | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` | 24h/0.1% | Corridor (depeg monitoring) |

**Rate & Volatility Feeds — verify at `docs.chain.link/data-feeds/rates-feeds/addresses`:**
- BTC Realized Vol 24h, 7d, 30d → `VolatilityBand` markets
- ETH Realized Vol 24h, 7d → `VolatilityBand` markets
- ETH Staking APR 30d, 90d → `StakingAPR` markets
- CF Bitcoin Interest Rate Curve → `BitcoinIRC` markets

**US Government Macro Feeds — verify at `docs.chain.link/data-feeds/us-government-macroeconomic/addresses`:**
- Real GDP (level + QoQ%) → `MacroEvent` markets
- PCE Price Index (level + YoY%) → `MacroEvent` markets

**SmartData Feeds — verify at `docs.chain.link/data-feeds/smartdata/addresses`:**
- Ondo OUSG NAV, USDY NAV → `NAVThreshold` markets
- WisdomTree CRDT, Superstate USTB, BlackRock BUIDL → `NAVThreshold` markets
- WBTC PoR, cbBTC PoR, USDC reserves → `Threshold` or Corridor markets

### 11.2 Critical: oracleMaxDelaySeconds Per Feed Family

This is the most common production mistake. Setting `oracleMaxDelaySeconds` shorter than the feed's actual heartbeat will cause every resolve to revert with `StaleRateFeed`.

| Feed family | Typical heartbeat | Recommended `oracleMaxDelaySeconds` |
|-------------|-------------------|--------------------------------------|
| Price feeds (BTC, ETH, SOL) | 1 hour | 7,200 (2h) |
| Price feeds (forex, commodities) | 1–24 hours | 172,800 (48h) |
| Rate/Vol feeds | 10min–24h | 172,800 (48h) |
| ETH Staking APR | Daily | 172,800 (48h) |
| SmartData NAV | Daily | 172,800 (48h) |
| US Government Macro feeds | Monthly/quarterly | 7,776,000 (90 days) |

### 11.3 Example upsertTemplate Calls

```solidity
// BTC Direction rolling — 1h interval, unchanged from Arbitrum except feedId
dispatcher.upsertTemplate(Template({
    slug: "btc-usd-direction-1h",
    marketType: MarketType.Direction,
    oracleFeedId: bytes32(uint256(uint160(0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F))),
    oracleMaxDelaySeconds: 7200,
    executionMode: ExecutionMode.Rolling,
    rollingIntervalSeconds: 3600,
    rollingBufferSeconds: 300,
    templateOracleKind: OracleKind.Chainlink,
    // ... other existing fields ...
    oracleClass: OracleClass.CHAINLINK_PRICE,  // NEW field
    cascadeDownward: false                      // NEW field
}));

// ETH Staking APR weekly market — new type
dispatcher.upsertTemplate(Template({
    slug: "eth-staking-apr-30d-weekly",
    marketType: MarketType.StakingAPR,          // NEW: routes to resolveThreshold
    condition: Condition.AtOrAbove,
    thresholdRule: ThresholdRule.Absolute,
    outcomeCount: 2,
    oracleFeedId: bytes32(uint256(uint160(ETH_STAKING_APR_30D_FEED))),
    absoluteThresholdValueE8: 450_000_000,      // 4.5% APR threshold (4.5 × 1e8)
    oracleMaxDelaySeconds: 172800,              // 48h — daily update feed
    executionMode: ExecutionMode.Manual,
    templateOracleKind: OracleKind.Chainlink,
    oracleClass: OracleClass.CHAINLINK_RATE,    // NEW: routes to RateAdapter
    cascadeDownward: false
}));

// cbETH/wstETH convergence — LST spread market
dispatcher.upsertTemplate(Template({
    slug: "cbeth-wsteth-convergence-weekly",
    marketType: MarketType.Convergence,
    condition: Condition.None,
    thresholdRule: ThresholdRule.Absolute,
    outcomeCount: 2,
    equalPriceVoids: true,
    oracleFeedId: bytes32(uint256(uint160(0x806b4Ac04501c29769051e42783cF04dCE41440b))),  // cbETH/ETH
    oracleFeedIdB: bytes32(uint256(uint160(0xa669E5272E60f78299F4824495cE01a3923f4380))), // wstETH/ETH
    spreadToleranceBps: 20,
    oracleMaxDelaySeconds: 172800,
    executionMode: ExecutionMode.Manual,       // Convergence CANNOT be rolling
    templateOracleKind: OracleKind.Chainlink,
    oracleClass: OracleClass.CHAINLINK_PRICE,
    cascadeDownward: false
}));

// BTC Cascade upward — multi-level resistance
dispatcher.upsertTemplate(Template({
    slug: "btc-cascade-3level-4h",
    marketType: MarketType.Cascade,
    outcomeCount: 4,                           // 0/1/2/3 levels reached
    rangeBoundsE8: [
        int256(9500000000000),   // $95k
        int256(9700000000000),   // $97k
        int256(10000000000000)   // $100k
    ],
    oracleMaxDelaySeconds: 21600,              // 6h
    executionMode: ExecutionMode.Manual,       // Cascade CANNOT be rolling
    templateOracleKind: OracleKind.TrustedReporter,
    eventOracle: TRUSTED_REPORTER_ADDR,
    oracleClass: OracleClass.CHAINLINK_PRICE,  // irrelevant for TRO, set to default
    cascadeDownward: false                     // upward cascade
}));

// Oil Cascade downward — multi-level support breaks (NEW: uses cascadeDownward=true)
dispatcher.upsertTemplate(Template({
    slug: "wti-cascade-3support-daily",
    marketType: MarketType.Cascade,
    outcomeCount: 4,
    rangeBoundsE8: [
        int256(8000000000000),   // $80 support
        int256(7800000000000),   // $78 support
        int256(7500000000000)    // $75 support
    ],
    executionMode: ExecutionMode.Manual,
    templateOracleKind: OracleKind.TrustedReporter,
    eventOracle: TRUSTED_REPORTER_ADDR,
    oracleClass: OracleClass.CHAINLINK_PRICE,
    cascadeDownward: true   // NEW: resolver will use epochLowE8
}));
```

---

## 12. Phase 9 — Backend Reporter Service Changes

### 12.1 Chain Configuration Update

```typescript
// reporter-service/src/config.ts

// CHANGE:
const provider = new ethers.JsonRpcProvider(process.env.BASE_RPC);
// BASE_RPC = "https://mainnet.base.org"  (or Alchemy/Infura Base endpoint)
// BASE_CHAIN_ID = 8453

// If using multiple networks, add Base to the network config:
const BASE_NETWORK_CONFIG = {
    chainId: 8453,
    name: "base",
    rpc: process.env.BASE_RPC!,
    proxyAddress: process.env.BASE_PROXY_ADDRESS!,
    trustedReporterAddress: process.env.BASE_TRUSTED_REPORTER_ADDRESS!,
};
```

### 12.2 Verify positionKey Encoding

The most common integration bug. Verify the Reporter Service matches the contract:

```typescript
// CORRECT — matches MarketEngineState.positionKey exactly:
function computeMarketId(templateId: string, epochId: bigint): string {
    return ethers.keccak256(
        ethers.solidityPacked(
            ['bytes32', 'uint64'],   // tightly packed — matches abi.encodePacked
            [templateId, epochId]
        )
    );
}

// WRONG (produces different hash):
// ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['bytes32', 'uint64'], [...]))
// ^ abi.encode pads to 32 bytes, solidityPacked does not
```

Test this in isolation before deploying:

```solidity
// Foundry test to verify Reporter Service encoding matches contract
function testPositionKeyEncoding() public {
    bytes32 templateId = keccak256("btc-usd-direction-1h");
    uint64 epochId = 42;
    bytes32 contractKey = MarketEngineState(proxy).positionKey(templateId, epochId);
    // Verify this matches what your TypeScript produces
    // contractKey must equal keccak256(abi.encodePacked(templateId, epochId))
    assertEq(contractKey, keccak256(abi.encodePacked(templateId, epochId)));
}
```

### 12.3 OHLC Computation from Chainlink Historical Rounds

For Corridor and Cascade TRO markets, the Reporter computes the epoch's high/low from Chainlink historical round data:

```typescript
// reporter-service/src/ohlcComputer.ts

const AGGREGATOR_ABI = [
    "function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80)",
    "function getRoundData(uint80) external view returns (uint80, int256, uint256, uint256, uint80)",
    "function decimals() external view returns (uint8)",
];

export async function computeEpochOHLC(
    feedProxyAddress: string,
    lockAtTimestamp: number,      // epoch.timing.lockAt (unix seconds)
    resolveAtTimestamp: number,   // epoch.timing.resolveAt (unix seconds)
    provider: ethers.Provider
): Promise<{ openE8: bigint; highE8: bigint; lowE8: bigint; closeE8: bigint }> {
    const feed = new ethers.Contract(feedProxyAddress, AGGREGATOR_ABI, provider);
    const decimals: number = await feed.decimals();

    function toE8(raw: bigint): bigint {
        if (decimals === 8) return raw;
        if (decimals > 8) return raw / BigInt(10 ** (decimals - 8));
        return raw * BigInt(10 ** (8 - decimals));
    }

    const [latestRound] = await feed.latestRoundData();
    let roundId = BigInt(latestRound);

    let highE8 = BigInt(0);
    let lowE8 = BigInt("999999999999999999");
    let openE8 = BigInt(0);
    let closeE8 = BigInt(0);
    let foundAny = false;

    // Walk backwards from latest round through epoch window
    while (roundId > BigInt(0)) {
        let roundData;
        try {
            roundData = await feed.getRoundData(roundId);
        } catch {
            roundId--;
            continue; // some round IDs are invalid — skip
        }

        const updatedAt = Number(roundData[3]); // updatedAt field

        if (updatedAt > resolveAtTimestamp) {
            roundId--;
            continue; // too recent
        }
        if (updatedAt < lockAtTimestamp) {
            break; // before epoch window — stop
        }

        // Within [lockAt, resolveAt] window
        const priceE8 = toE8(BigInt(roundData[1])); // answer field

        if (!foundAny) {
            closeE8 = priceE8; // first round walking back = close
        }
        openE8 = priceE8;     // last round in window (oldest) = open

        if (priceE8 > highE8) highE8 = priceE8;
        if (priceE8 < lowE8) lowE8 = priceE8;

        foundAny = true;
        roundId--;
    }

    if (!foundAny) throw new Error(
        `No rounds in epoch window [${lockAtTimestamp}, ${resolveAtTimestamp}] for feed ${feedProxyAddress}`
    );

    return { openE8, highE8, lowE8, closeE8 };
}
```

---

## 13. Phase 10 — Testing Matrix

### 13.1 Unit Tests to Add

```
test/
├── adapters/
│   ├── RateAdapter.t.sol
│   │   ├── testReadValidFeed()              — normal positive rate value
│   │   ├── testZeroAnswerAllowed()          — answer=0 must NOT revert
│   │   ├── testNegativeAnswerReverts()      — answer<0 must revert NegativeRate
│   │   ├── testStaleReverts()               — updatedAt > maxAge reverts StaleRateFeed
│   │   ├── testSequencerDown()              — answer=1 reverts SequencerDown
│   │   └── testGracePeriod()               — just-recovered sequencer reverts InGracePeriod
│   ├── MacroAdapter.t.sol
│   │   ├── testNegativeAnswerAllowed()      — negative GDP growth must not revert
│   │   └── testZeroAnswerAllowed()
│   └── SmartDataAdapter.t.sol
│       └── testZeroAnswerAllowed()          — PoR zero is valid
│
├── types/
│   └── NewMarketTypes.t.sol
│       ├── testNewEnumValues_notDuplicated() — VolatilityBand etc. have correct uint8 values
│       ├── testOracleClassDefault_isPrice()  — zero OracleClass == CHAINLINK_PRICE
│       └── testRequiresCheckpointAOnLock_BitcoinIRC()
│
├── integration/
│   ├── OracleRoutingTest.t.sol
│   │   ├── testExistingTemplates_stillUseGlobalOracle()
│   │   ├── testStakingAPR_routesToRateAdapter()
│   │   ├── testNAVThreshold_routesToSmartDataAdapter()
│   │   ├── testMacroEvent_routesToMacroAdapter()
│   │   └── testUnsetOracle_reverts()        — CHAINLINK_RATE with _rateOracle=0
│   │
│   ├── NewMarketTypeE2E.t.sol
│   │   ├── testStakingAPR_fullEpoch()        — open→lock→resolve→claim on Base fork
│   │   ├── testVolatilityBand_rolling()      — rolling mode with RateAdapter
│   │   ├── testNAVThreshold_manual()         — manual mode with SmartDataAdapter
│   │   ├── testMacroEvent_manual()           — manual mode, large maxAgeSeconds
│   │   └── testBitcoinIRC_direction()        — Direction mode needs checkpoint A
│   │
│   ├── CascadeDownwardTest.t.sol
│   │   ├── testCascadeUpward_usesHighE8()
│   │   └── testCascadeDownward_usesLowE8()
│   │
│   ├── StorageLayoutUpgradeTest.t.sol
│   │   ├── testAllSlots_unchangedAfterUpgrade()  — MOST IMPORTANT TEST
│   │   ├── testGapShrunkBy4()
│   │   └── testNewOracleSlots_defaultToZero()
│   │
│   └── ExistingTypesRegression.t.sol
│       ├── testDirection_rolling_Base()
│       ├── testThreshold_manual_Base()
│       ├── testConvergence_cbETH_wstETH()
│       └── testCorridor_TRO_Base()           — verify postOhlcResult + getOhlcResult on Base
```

### 13.2 Most Critical Test — Storage Continuity

```solidity
// test/integration/StorageLayoutUpgradeTest.t.sol

contract StorageLayoutUpgradeTest is Test {
    address proxy; // deployed proxy address on Base fork

    function testAllSlots_unchangedAfterUpgrade() public {
        // 1. Record all pre-upgrade storage slots
        bytes32[40] memory slotsBefore;
        for (uint256 i = 0; i < 40; i++) {
            slotsBefore[i] = vm.load(proxy, bytes32(i));
        }

        // 2. Execute upgrade
        address newImpl = address(new MarketEngineDispatcher());
        vm.prank(ADMIN);
        IUUPSUpgradeable(proxy).upgradeToAndCall(newImpl, "");

        // 3. Verify every pre-existing slot unchanged
        for (uint256 i = 0; i < 40; i++) {
            assertEq(
                vm.load(proxy, bytes32(i)),
                slotsBefore[i],
                string.concat("SLOT CORRUPTION: slot ", vm.toString(i))
            );
        }

        // 4. Verify new oracle slots are zero (default state)
        // (compute the exact slot numbers from storage layout output)
        assertEq(vm.load(proxy, RATE_ORACLE_SLOT), bytes32(0));
        assertEq(vm.load(proxy, SMARTDATA_ORACLE_SLOT), bytes32(0));

        console.log("Storage continuity: PASS");
    }
}
```

---

## 14. Phase 11 — Deployment Script

```solidity
// script/production/DeployBaseV2.s.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract DeployBaseV2 is Script {

    address constant BASE_SEQUENCER = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
    // USDC on Base Mainnet
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin    = vm.envAddress("ADMIN");
        address treasury = vm.envAddress("TREASURY");
        address worker   = vm.envAddress("WORKER");
        address reporter = vm.envAddress("REPORTER_WALLET");

        vm.startBroadcast(deployerKey);

        // ── 1. Adapters ──────────────────────────────────────────────────
        address chainlinkAdp = address(new ChainlinkAdapter(BASE_SEQUENCER));
        address rateAdp      = address(new RateAdapter(BASE_SEQUENCER));
        address smartDataAdp = address(new SmartDataAdapter(BASE_SEQUENCER));
        address macroAdp     = address(new MacroAdapter(BASE_SEQUENCER));
        address equityAdp    = address(new EquityAdapter(BASE_SEQUENCER));
        address tro          = address(new TrustedReporterAdapter(reporter));

        // ── 2. Proxy + Implementation ────────────────────────────────────
        bytes memory initData = abi.encodeCall(
            MarketEngineDispatcher.initialize,
            (
                IERC20(BASE_USDC),
                IPriceOracle(chainlinkAdp),
                admin,
                treasury,
                worker,
                100,    // defaultSettlementFeeBps = 1%
                500,    // maxSwitchFeeBps = 5%
                1000,   // maxSettlementFeeBps = 10%
                MarketTypes.OracleKind.Chainlink,
                7200,   // defaultOracleMaxDelay = 2h
                500     // defaultOracleMaxConfidence = 5%
            )
        );

        Options memory opts;
        address proxy = Upgrades.deployUUPSProxy(
            "engine/MarketEngineDispatcher.sol:MarketEngineDispatcher",
            initData,
            opts
        );

        MarketEngineDispatcher disp = MarketEngineDispatcher(payable(proxy));

        // ── 3. Modules ───────────────────────────────────────────────────
        address adminMod   = address(new MarketEngineAdminModule());
        address coreMod    = address(new MarketEngineCoreLifecycleModule());
        address rollingMod = address(new MarketEngineRollingLifecycleModule());
        address userOpsMod = address(new MarketEngineUserOpsClaimsModule());
        address viewMod    = address(new MarketEngineViewModule());

        // ── 4. Wire selectors — existing ────────────────────────────────
        // (Wire all selectors exactly as in current DeployProduction.s.sol)
        // AdminModule existing selectors
        _wireAdmin(disp, adminMod);
        // CoreLifecycleModule selectors (note: upsertTemplate ABI changed due to new struct fields)
        _wireCore(disp, coreMod);
        // RollingLifecycleModule selectors
        _wireRolling(disp, rollingMod);
        // UserOpsClaimsModule + ViewModule selectors
        _wireUserOps(disp, userOpsMod);
        _wireView(disp, viewMod);

        // ── 5. Wire NEW selectors ────────────────────────────────────────
        disp.setSelectorModule(bytes4(keccak256("setRateOracle(address)")), adminMod, false);
        disp.setSelectorModule(bytes4(keccak256("setSmartDataOracle(address)")), adminMod, false);
        disp.setSelectorModule(bytes4(keccak256("setMacroOracle(address)")), adminMod, false);
        disp.setSelectorModule(bytes4(keccak256("setEquityOracle(address)")), adminMod, false);

        // ── 6. Set oracle adapters ───────────────────────────────────────
        MarketEngineAdminModule(payable(proxy)).setRateOracle(rateAdp);
        MarketEngineAdminModule(payable(proxy)).setSmartDataOracle(smartDataAdp);
        MarketEngineAdminModule(payable(proxy)).setMacroOracle(macroAdp);
        MarketEngineAdminModule(payable(proxy)).setEquityOracle(equityAdp);

        vm.stopBroadcast();

        // ── 7. Deployment summary ────────────────────────────────────────
        console.log("==== Base V2 Deployment ====");
        console.log("Proxy:              ", proxy);
        console.log("ChainlinkAdapter:   ", chainlinkAdp);
        console.log("RateAdapter:        ", rateAdp);
        console.log("SmartDataAdapter:   ", smartDataAdp);
        console.log("MacroAdapter:       ", macroAdp);
        console.log("EquityAdapter:      ", equityAdp);
        console.log("TrustedReporter:    ", tro);
        console.log("AdminModule:        ", adminMod);
        console.log("CoreModule:         ", coreMod);
        console.log("RollingModule:      ", rollingMod);
    }
}
```

---

## 15. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Storage slot corruption** — new field not appended strictly after existing fields | Low | Critical — corrupts all market data and positions | `forge inspect storage-layout` diff before/after, OpenZeppelin upgrade validator `--ffi`, storage continuity test on Base Sepolia fork |
| **RateAdapter zero-answer handling** — zero APR resolves incorrectly vs positive threshold | Low | Medium — incorrect settlement for edge case market | Unit test: `testZeroAPR_thresholdAbove_isFalse()` — verify 0 < 4.5% threshold = outcome index 1 (below) |
| **MacroAdapter negative answer** — negative GDP vs positive threshold resolves wrong direction | Low | Medium — int256 comparison handles this correctly in resolveThreshold | Unit test: `testNegativeGDP_vs_positiveThreshold()` — confirm -0.5% < +2.5% = AtOrAbove=false |
| **upsertTemplate ABI mismatch** — keeper scripts still call old struct encoding after upgrade | Medium | High — all new template creation silently fails or reverts | Update keeper ABI before going live; test with new ABI on Base Sepolia; all existing templates remain valid (no re-upsert needed) |
| **OHLC marketId encoding** — Reporter uses abi.encode instead of abi.encodePacked | Medium | High — all Corridor/Cascade epochs permanently stuck as unresolvable | Foundry test comparing contract positionKey output vs TypeScript output exactly; add to CI |
| **Cascade downward epoch snapshot** — `cascadeDownward` not snapshotted into Epoch at openEpoch | Low | High — wrong resolver branch at resolve time after template change | Test: verify Epoch.cascadeDownward matches template at epoch open time |
| **Base sequencer grace period on rolling** — 1h grace after recovery halts rolling markets | Low | Medium — rolling markets halt after sequencer recovery, keeper must restart genesis | Set `rollingBufferSeconds >= 3900` for any fast-rolling template; keeper monitors sequencer status |
| **`oracleMaxDelaySeconds` too short** — daily rate feed set to 2h delay reverts every resolve | Medium | High — template permanently unresolvable until admin cancels | Per-family `maxDelaySeconds` table in Phase 8.3; add validation in `upsertTemplate`: `require(oracleMaxDelaySeconds >= MIN_DELAY[oracleClass])` |
| **Rolling dispatch `else` clause** — new type falls through to `resolveLadder` in rolling module | Low | Critical — wrong settlement math for new types | Add explicit new-type branches BEFORE the Ladder else; add `else revert UnknownMarketType()` at end of dispatch chain |
| **Module bytecode > 24KB** — added functions push module over EVM limit | Low | Blocks deployment | `forge build --sizes` gating in CI before any production deploy |

### 15.1 Rollback Procedure

```bash
# Immediate: pause the protocol
cast send $PROXY "pauseProgram(bool)" true \
  --rpc-url $BASE_RPC --private-key $ADMIN_KEY

# If only module code is wrong (not storage):
# Remap affected selectors back to old module address
cast send $PROXY "setSelectorModule(bytes4,address,bool)" \
  $(cast sig "resolveEpoch(bytes32,uint64)") $OLD_CORE_MOD false \
  --rpc-url $BASE_RPC --private-key $ADMIN_KEY

# If wrong oracle adapter is causing bad resolutions:
# Set it to address(0) to block that adapter family
cast send $PROXY "setRateOracle(address)" \
  0x0000000000000000000000000000000000000000 \
  --rpc-url $BASE_RPC --private-key $ADMIN_KEY

# If proxy implementation must be rolled back (rare — requires multisig):
# upgradeToAndCall back to previous implementation
# Previous impl address must be retained post-upgrade
```

---

## 16. Gas Analysis

### 16.1 New Types vs Existing — Marginal Gas Cost

All 5 new market types (`VolatilityBand`, `StakingAPR`, `BitcoinIRC`, `NAVThreshold`, `MacroEvent`) share the `resolveThreshold` path. Added cost vs an existing Threshold market is one `_resolveOracle()` call (one SLOAD + if-else chain ≈ 200–400 gas).

| Operation | Existing Threshold | StakingAPR / VolatilityBand | Delta |
|-----------|-------------------|-----------------------------|-------|
| `lockEpoch` (no checkpoint A) | 10,514 gas | ~10,700 gas | ~+200 |
| `resolveEpoch` | 128,234 gas | ~128,600 gas | ~+366 |
| `executeRollingRound` | 376,754 gas | ~377,100 gas | ~+346 |

### 16.2 Base vs Arbitrum — Operational Cost Advantage

At 100 rolling templates × 24 ticks/day:
- **Arbitrum:** ~$500–1,500/day in L1 data fees
- **Base:** ~$20–60/day (10–30× cheaper per transaction)

This is the primary reason to migrate. Execution gas costs are virtually identical between the two chains — the L1 data fee reduction is the entire advantage.

---

## 17. Post-Deployment Verification

### 17.1 After Phase 1 (Adapters)

```bash
# Verify ChainlinkAdapter reads ETH/USD on Base correctly
ETH_USD_BASE="0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70"
cast call $CHAINLINK_ADAPTER \
  "getNormalizedPrice(bytes32,uint64,uint64)(int256,uint64,uint256)" \
  $(cast --to-bytes32 $(cast --to-uint256 $ETH_USD_BASE)) \
  7200 $(date +%s) \
  --rpc-url $BASE_RPC
# Expected: large positive int256 (ETH price × 1e8, range: 1e11 to 5e11)

# Verify RateAdapter handles a rate feed (address from docs.chain.link)
cast call $RATE_ADAPTER \
  "getNormalizedPrice(bytes32,uint64,uint64)(int256,uint64,uint256)" \
  $(cast --to-bytes32 $(cast --to-uint256 $ETH_STAKING_APR_FEED)) \
  172800 $(date +%s) \
  --rpc-url $BASE_RPC
# Expected: positive int256 representing APR in e8 (e.g. 450000000 = 4.5%)
```

### 17.2 After Phase 6 (Proxy Upgrade)

```bash
# CRITICAL: Admin address must be unchanged
ADMIN_AFTER=$(cast call $PROXY "admin()(address)" --rpc-url $BASE_RPC)
diff <(echo $ADMIN_AFTER) /tmp/upgrade_snapshot_admin.txt
echo "Admin unchanged: $([ $? -eq 0 ] && echo PASS || echo FAIL)"

# New oracle adapters must be set
echo "RateOracle:" $(cast call $PROXY "_rateOracle()(address)" --rpc-url $BASE_RPC)
# Must equal $RATE_ADAPTER

# Existing template must still be readable
cast call $PROXY "getEpoch(bytes32,uint64)" \
  $(cast keccak "btc-usd-direction-1h") 1 \
  --rpc-url $BASE_RPC
# Must return same struct as before upgrade (identical fields)
```

### 17.3 Final Production Sign-off Checklist

- [ ] Storage continuity test passed on Base Sepolia fork before mainnet deployment
- [ ] One Direction epoch complete end-to-end on Base (confirms existing type unaffected)
- [ ] One StakingAPR epoch complete (open → lock → no-A → resolve via RateAdapter → claim)
- [ ] One VolatilityBand epoch complete (rolling mode with RateAdapter)
- [ ] One NAVThreshold epoch complete (SmartDataAdapter)
- [ ] One MacroEvent epoch complete (MacroAdapter — note: may need 90-day window)
- [ ] Corridor TRO flow verified: Reporter posts OHLC → engine resolves correctly
- [ ] Cascade downward template: `cascadeDownward=true` → resolver uses `epochLowE8`
- [ ] `upsertTemplate` with new Template struct ABI confirmed working
- [ ] Gnosis Safe on Base: pause/unpause tested by admin multisig
- [ ] Reporter Service confirmed submitting to Base RPC (monitor for failed txns)
- [ ] Base sequencer recovery simulation: rolling market halts and recovers correctly
- [ ] `pauseProgram(false)` — **protocol is live on Base**

---

*All contract changes described in this document are strictly additive. No existing market type, resolver function, settlement path, user-facing operation, or storage variable is modified. The 10 market types already in the codebase ship unchanged to Base.*

**RetroPick FZ-LLC · RAK DAO · April 2026 · Confidential**