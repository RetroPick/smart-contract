# RetropPick — Chainlink Oracle Migration
## Technical Specification: Replace `PythAdapter` with `ChainlinkAdapter`

**Author:** Protocol Engineering  
**Target:** `src/adapters/PythAdapter.sol` → `src/adapters/ChainlinkAdapter.sol`  
**Interface preserved:** `IPriceOracle` (no signature changes)  
**Solidity:** ^0.8.20  
**Dependency:** `@chainlink/contracts` ≥ 1.3.0  

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Deep Diff: Pyth vs Chainlink Data Model](#2-deep-diff-pyth-vs-chainlink-data-model)
3. [Critical L2 Concern: Sequencer Uptime Feed](#3-critical-l2-concern-sequencer-uptime-feed)
4. [IPriceOracle Interface Analysis](#4-ipriceoracle-interface-analysis)
5. [ChainlinkAdapter — Full Implementation](#5-chainlinkadapter--full-implementation)
6. [OracleNormalize — Chainlink Edition](#6-oraclenormalize--chainlink-edition)
7. [MockChainlinkOracle — Test Replacement](#7-mockchainlinkpriceoracle--test-replacement)
8. [MarketEngine Configuration Changes](#8-marketengine-configuration-changes)
9. [Template Feed ID Mapping](#9-template-feed-id-mapping)
10. [Staleness & Confidence: Behavioral Mapping](#10-staleness--confidence-behavioral-mapping)
11. [Rolling Round Implications](#11-rolling-round-implications)
12. [Deploy Script Changes](#12-deploy-script-changes)
13. [Test Suite Migration](#13-test-suite-migration)
14. [Feed Address Reference](#14-feed-address-reference)
15. [Migration Checklist](#15-migration-checklist)

---

## 1. Executive Summary

The current `MarketEngine` reads prices via `IPriceOracle`, implemented by `PythAdapter`. Pyth is a **pull oracle** — the keeper must post a signed price update on-chain before calling `lockEpoch` / `resolveEpoch`. This adds cost and complexity per keeper transaction.

Chainlink is a **push oracle** — price data is already on-chain at all times, updated by Chainlink node operators on a heartbeat + deviation schedule. Your keeper simply reads it. No update transaction required.

**What changes:**

| Layer | Change Required |
|---|---|
| `PythAdapter.sol` | Replace entirely → `ChainlinkAdapter.sol` |
| `OracleNormalize.sol` | Add Chainlink normalization path (different decimals) |
| `IPriceOracle.sol` | No change — interface is preserved |
| `MarketEngine.sol` | **Small logic change required**: accept Chainlink-style `updatedAt` that may be **before** `lockAt/resolveAt` as long as it is **fresh** (within `maxDelaySeconds`) and monotonic (checkpoint B ≥ checkpoint A). |
| `MarketTypes.OracleKind` | Add `Chainlink` variant |
| Template `oracleFeedId` | Was Pyth `bytes32` feed ID → becomes feed **address** cast to `bytes32` |
| `script/production/DeployProduction.s.sol` | Deploy `ChainlinkAdapter` instead of `PythAdapter` |
| `MockPriceOracle.sol` | Unchanged (mock still implements `IPriceOracle`) |

**What does NOT change:**
- All epoch lifecycle logic (`openEpoch`, `lockEpoch`, `resolveEpoch`, rolling)
- All market type resolvers (`Direction`, `Threshold`, `RangeClose`)
- `MarketMath`, `Resolvers`, position/claim/fee accounting
- `IPriceOracle` interface signature
- Keeper call patterns (no pre-update tx needed anymore)

**One important semantic change:** the engine must not require `publishTime >= lockAt/resolveAt` for push oracles (Chainlink). Instead, safety comes from `maxDelaySeconds` freshness plus checkpoint-time monotonicity.

---

## 2. Deep Diff: Pyth vs Chainlink Data Model

Understanding the model difference is the prerequisite to everything else.

### 2.1 Pyth Model (current)

```
Off-chain signed VAA (price attestation)
           │
           ▼ (keeper posts this on-chain before calling lock/resolve)
   IPyth.updatePriceFeeds(updateData)
           │
           ▼
   IPyth.getPriceNoOlderThan(feedId, maxAge)
   returns:
     - price  int64   (raw, with exponent)
     - conf   uint64  (confidence interval, same exponent)
     - expo   int32   (e.g. -8 means value / 1e8)
     - publishTime uint64
```

Key Pyth properties relevant to MarketEngine:
- `feedId` is a `bytes32` hash (e.g. `0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43` for BTC/USD)
- Returns a **confidence interval** (`conf`) — the engine uses this as a manipulation filter (`oracleMaxConfidenceBps`)
- `expo` can be any negative integer; `OracleNormalize.normalize()` adjusts to e8
- Staleness is enforced by `getPriceNoOlderThan` reverting if `block.timestamp - publishTime > maxAge`

### 2.2 Chainlink Model (target)

```
Chainlink node operators aggregate off-chain (OCR2)
           │
           ▼ (automatic, on heartbeat ~1hr or >0.5% deviation)
   AggregatorV3Interface.latestRoundData()
   returns:
     - roundId        uint80
     - answer         int256  (price, already scaled)
     - startedAt      uint256 (when round started)
     - updatedAt      uint256 (when answer was written — use THIS for staleness)
     - answeredInRound uint80
```

Key Chainlink properties:
- Feed is identified by its **proxy contract address** (not a `bytes32` hash)
- `answer` is an `int256` already scaled by `10**decimals()` (typically 8 for crypto, 18 for some feeds)
- **No confidence interval** — Chainlink does not expose one in `AggregatorV3Interface`
- Staleness is checked by comparing `block.timestamp - updatedAt` to your `maxDelaySeconds`
- `answeredInRound` ≥ `roundId` must hold — stale round detection

### 2.3 Confidence Interval Gap

This is the most significant behavioral difference. Your `MarketEngine` has:

```solidity
function _confidenceWithinBand(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps)
```

Chainlink has **no confidence interval**. Your adapter must handle this.

**Strategy options:**

| Option | Description | Recommendation |
|---|---|---|
| A. Return `confidenceE8 = 0` | Always passes confidence check | Safe — confidence check becomes no-op |
| B. Return derived spread | Compute from `(answer - minAnswer) / answer` if aggregator exposes `minAnswer`/`maxAnswer` | Brittle — these fields are circuit breakers, not confidence |
| C. Remove confidence filter for Chainlink | Add `OracleKind`-aware bypass in MarketEngine | Clean but requires MarketEngine edit |
| **D. Return `0`, set `oracleMaxConfidenceBps = 0` in Chainlink templates** | `0 bps` effectively disables the check (see `_enforceConfidence`) | **Recommended — zero code change to engine** |

**Chosen approach: Option D.** Set `oracleMaxConfidenceBps = 0` in all Chainlink-backed templates. Inspect `_enforceConfidence`:

```solidity
// Current engine logic
function _enforceConfidence(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps) internal pure {
    if (!_confidenceWithinBand(priceE8, confidenceE8, maxConfidenceBps)) revert OracleConfidenceTooWide();
}

function _confidenceWithinBand(...) internal pure returns (bool) {
    uint256 limit = (abs * uint256(maxConfidenceBps)) / 10_000;
    return confidenceE8 <= limit;
}
```

When `maxConfidenceBps = 0`, `limit = 0`. The adapter must return `confidenceE8 = 0` for `0 <= 0` to pass. ✓

---

## 3. Critical L2 Concern: Sequencer Uptime Feed

**This is non-negotiable on all L2 targets.** Chainlink explicitly requires it in their docs.

### The Problem

On L2s (Arbitrum, Base, Optimism, zkSync), if the **sequencer goes down**:
- The Chainlink oracle price on L2 **freezes** at the last pushed value
- `updatedAt` stops advancing
- Your `maxDelaySeconds` staleness check will eventually catch it — BUT only after the delay window expires
- During that window, a keeper could lock/resolve a market at a stale price
- In a prediction market context: users who know the sequencer is down could exploit the frozen price

### The Solution: L2 Sequencer Uptime Feed

Chainlink maintains a dedicated feed per L2 that reports sequencer liveness. Your adapter **must** check this before returning any price.

**Sequencer feed addresses (mainnet):**

| Network | Uptime Feed Address |
|---|---|
| Arbitrum One | `0xFdB631F5EE196F0ed6FAa767959853A9F217697D` |
| Base | `0xBCF85224fc0756B9Fa45aA7892530B47e10b6433` |
| OP Mainnet | `0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389` |
| zkSync Era | `0x0E6AC8B967393dcD3D36677c126976157F993940` |
| Scroll | `0x45c2b8C204568A03Dc7A2E32B71D67Fe97F908A9` |

**Sequencer feed semantics:**
- `answer = 0` → sequencer is **UP**
- `answer = 1` → sequencer is **DOWN**
- `startedAt` → timestamp when the current status began

**Grace period pattern:** Even when the sequencer comes back up (`answer = 0`), you should enforce a grace period (e.g. 3600 seconds = 1 hour) before trusting prices again. This prevents immediate exploitation after recovery.

```solidity
// Check pattern — must be in getNormalizedPrice()
(, int256 answer, uint256 startedAt,,) = sequencerFeed.latestRoundData();
bool isDown = answer == 1;
bool inGracePeriod = block.timestamp - startedAt < GRACE_PERIOD;
if (isDown || inGracePeriod) revert SequencerDown();
```

---

## 4. IPriceOracle Interface Analysis

Your current interface (unchanged):

```solidity
// src/interfaces/IPriceOracle.sol
interface IPriceOracle {
    function getNormalizedPrice(
        bytes32 feedId,       // Chainlink: cast of feed proxy address to bytes32
        uint64 maxAgeSeconds, // Chainlink: staleness window in seconds
        uint64 nowTs          // Chainlink: pass block.timestamp (used for staleness)
    )
        external
        view
        returns (
            int256  priceE8,       // Price normalized to 8 decimals
            uint64  publishTime,   // updatedAt from latestRoundData
            uint256 confidenceE8   // Return 0 for Chainlink (no confidence)
        );
}
```

**`feedId` reinterpretation for Chainlink:**

Pyth uses `feedId` as a `bytes32` content hash. Chainlink uses a contract address. The mapping:

```solidity
// In ChainlinkAdapter:
address feedAddress = address(uint160(uint256(feedId)));
AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);
```

This is the only casting needed. Template configuration sets `oracleFeedId` to the Chainlink proxy address padded to `bytes32`.

---

## 5. ChainlinkAdapter — Full Implementation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from
    "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/**
 * @title ChainlinkAdapter
 * @notice IPriceOracle implementation backed by Chainlink AggregatorV3Interface.
 *
 * Key differences from PythAdapter:
 *   1. Push oracle — no pre-update tx required from keeper.
 *   2. No confidence interval — returns confidenceE8 = 0.
 *      Set oracleMaxConfidenceBps = 0 on all Chainlink templates.
 *   3. L2 sequencer uptime feed check — MANDATORY on all L2 deployments.
 *   4. feedId = address(uint160(uint256(feedId))) — feed identified by proxy address.
 *
 * @dev Deploy one ChainlinkAdapter per chain. All templates on that chain share
 *      this adapter. Different feeds are selected via feedId (= proxy address).
 *
 * @author RetropPick Protocol Engineering
 */
contract ChainlinkAdapter is IPriceOracle {

    // =========================================================
    // Constants
    // =========================================================

    /// @notice Grace period after sequencer recovery before prices are trusted
    uint256 public constant GRACE_PERIOD_SECONDS = 3600; // 1 hour

    /// @notice Chainlink prices are typically 8 decimals for crypto feeds
    uint8 public constant TARGET_DECIMALS = 8;

    // =========================================================
    // Immutables
    // =========================================================

    /// @notice L2 sequencer uptime feed.
    ///         Set to address(0) on L1 (Ethereum mainnet) — check is skipped.
    AggregatorV3Interface public immutable sequencerFeed;

    // =========================================================
    // Errors
    // =========================================================

    error SequencerDown();
    error SequencerInGracePeriod(uint256 recoveredAt, uint256 gracePeriodEndsAt);
    error StalePriceFeed(uint256 updatedAt, uint256 maxAge, uint256 blockTs);
    error InvalidPrice();
    error RoundNotComplete(uint80 roundId, uint80 answeredInRound);
    error InvalidFeedAddress();

    // =========================================================
    // Constructor
    // =========================================================

    /**
     * @param sequencerFeed_ L2 sequencer uptime feed proxy address.
     *                        Pass address(0) on Ethereum mainnet (check disabled).
     *
     * Arbitrum:  0xFdB631F5EE196F0ed6FAa767959853A9F217697D
     * Base:      0xBCF85224fc0756B9Fa45aA7892530B47e10b6433
     * Optimism:  0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389
     * zkSync:    0x0E6AC8B967393dcD3D36677c126976157F993940
     * Scroll:    0x45c2b8C204568A03Dc7A2E32B71D67Fe97F908A9
     */
    constructor(address sequencerFeed_) {
        // address(0) is valid on L1 — sequencer check simply skipped
        sequencerFeed = AggregatorV3Interface(sequencerFeed_);
    }

    // =========================================================
    // IPriceOracle Implementation
    // =========================================================

    /**
     * @notice Get normalized price from a Chainlink feed.
     *
     * @param feedId      Chainlink proxy address cast to bytes32.
     *                    Cast back: address(uint160(uint256(feedId)))
     * @param maxAgeSeconds Maximum acceptable staleness in seconds.
     *                    Maps directly to MarketEngine's oracleMaxDelaySeconds.
     * @param             Third param (nowTs) unused — we use block.timestamp.
     *
     * @return priceE8      Price normalized to 8 decimal places (int256).
     * @return publishTime  updatedAt from latestRoundData (uint64).
     * @return confidenceE8 Always 0 — Chainlink has no confidence interval.
     *                      Set oracleMaxConfidenceBps=0 on all Chainlink templates.
     *
     * @dev Reverts on:
     *   - Sequencer down or in grace period (L2 only)
     *   - Round not complete (answeredInRound < roundId)
     *   - answer <= 0 (invalid price)
     *   - updatedAt == 0 (round not started)
     *   - block.timestamp - updatedAt > maxAgeSeconds (stale)
     */
    function getNormalizedPrice(
        bytes32 feedId,
        uint64  maxAgeSeconds,
        uint64  /* nowTs — unused, use block.timestamp */
    )
        external
        view
        override
        returns (
            int256  priceE8,
            uint64  publishTime,
            uint256 confidenceE8
        )
    {
        // --- Step 1: L2 Sequencer check (skipped on L1) ---
        _checkSequencer();

        // --- Step 2: Decode feed address ---
        address feedAddress = address(uint160(uint256(feedId)));
        if (feedAddress == address(0)) revert InvalidFeedAddress();
        AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);

        // --- Step 3: Read latest round ---
        (
            uint80  roundId,
            int256  answer,
            ,        // startedAt — not used
            uint256 updatedAt,
            uint80  answeredInRound
        ) = feed.latestRoundData();

        // --- Step 4: Validate round completeness ---
        // answeredInRound < roundId means the round is in progress and not yet answered
        if (answeredInRound < roundId) revert RoundNotComplete(roundId, answeredInRound);

        // --- Step 5: Validate price sanity ---
        if (answer <= 0)   revert InvalidPrice();
        if (updatedAt == 0) revert InvalidPrice();

        // --- Step 6: Staleness check ---
        // updatedAt is the timestamp of the last on-chain update by Chainlink nodes
        if (block.timestamp - updatedAt > uint256(maxAgeSeconds)) {
            revert StalePriceFeed(updatedAt, maxAgeSeconds, block.timestamp);
        }

        // --- Step 7: Normalize decimals to e8 ---
        uint8 feedDecimals = feed.decimals();
        priceE8 = _normalizeToE8(answer, feedDecimals);

        // --- Step 8: Return ---
        publishTime   = uint64(updatedAt);
        confidenceE8  = 0; // Chainlink has no confidence interval
    }

    // =========================================================
    // Internal
    // =========================================================

    /**
     * @dev Check L2 sequencer uptime. Skipped if sequencerFeed == address(0).
     */
    function _checkSequencer() internal view {
        if (address(sequencerFeed) == address(0)) return; // L1 — skip

        (
            ,
            int256  answer,
            uint256 startedAt,
            ,

        ) = sequencerFeed.latestRoundData();

        // answer == 1 means sequencer is DOWN
        if (answer == 1) revert SequencerDown();

        // Even if answer == 0 (UP), enforce grace period after recovery
        uint256 gracePeriodEndsAt = startedAt + GRACE_PERIOD_SECONDS;
        if (block.timestamp < gracePeriodEndsAt) {
            revert SequencerInGracePeriod(startedAt, gracePeriodEndsAt);
        }
    }

    /**
     * @dev Normalize Chainlink answer to 8 decimal places.
     *
     * Most crypto/USD feeds: decimals = 8  → no adjustment
     * Some feeds: decimals = 18            → scale down by 1e10
     * Rare: decimals < 8                   → scale up
     *
     * @param answer    Raw answer from latestRoundData
     * @param decimals  Feed's decimals() value
     * @return          Price scaled to e8
     */
    function _normalizeToE8(int256 answer, uint8 decimals) internal pure returns (int256) {
        if (decimals == TARGET_DECIMALS) {
            return answer;
        } else if (decimals > TARGET_DECIMALS) {
            // Scale down: divide by 10^(decimals - 8)
            uint256 factor = 10 ** uint256(decimals - TARGET_DECIMALS);
            return answer / int256(factor);
        } else {
            // Scale up: multiply by 10^(8 - decimals)
            uint256 factor = 10 ** uint256(TARGET_DECIMALS - decimals);
            return answer * int256(factor);
        }
    }

    // =========================================================
    // View helpers (for off-chain monitoring / testing)
    // =========================================================

    /**
     * @notice Decode a feedId back to a Chainlink proxy address.
     */
    function feedIdToAddress(bytes32 feedId) external pure returns (address) {
        return address(uint160(uint256(feedId)));
    }

    /**
     * @notice Encode a Chainlink proxy address to feedId format.
     */
    function addressToFeedId(address feedAddress) external pure returns (bytes32) {
        return bytes32(uint256(uint160(feedAddress)));
    }

    /**
     * @notice Check sequencer status externally (for monitoring scripts).
     * @return isUp true if sequencer is up AND past grace period
     * @return recoveredAt block.timestamp when sequencer came back up
     */
    function sequencerStatus()
        external
        view
        returns (bool isUp, uint256 recoveredAt, uint256 gracePeriodEndsAt)
    {
        if (address(sequencerFeed) == address(0)) return (true, 0, 0);

        (, int256 answer, uint256 startedAt,,) = sequencerFeed.latestRoundData();
        recoveredAt      = startedAt;
        gracePeriodEndsAt = startedAt + GRACE_PERIOD_SECONDS;
        isUp             = (answer == 0) && (block.timestamp >= gracePeriodEndsAt);
    }
}
```

---

## 6. OracleNormalize — Chainlink Edition

Your existing `OracleNormalize.sol` handles Pyth's raw signed integer + exponent format. The Chainlink normalization is simpler and is handled entirely inside `ChainlinkAdapter._normalizeToE8()` above. You do not need to modify `OracleNormalize.sol`.

However, for documentation clarity, here is the comparison:

**Pyth normalization (existing `OracleNormalize.sol`):**
```solidity
// Pyth: price=12345678, expo=-8  → priceE8 = 12345678
// Pyth: price=12345678, expo=-6  → priceE8 = 1234567800 (×100)
// Handles negative exponents by multiplying/dividing by 10^|expo|
(priceE8, confidenceE8) = OracleNormalize.normalize(p.price, p.conf, p.expo);
```

**Chainlink normalization (new, inline in adapter):**
```solidity
// Chainlink BTC/USD: answer=4523100000000, decimals=8 → priceE8 = 4523100000000 (no change)
// Chainlink ETH/USD: answer=300000000000,  decimals=8 → priceE8 = 300000000000
// Chainlink some RWA: answer=1000000000000000000, decimals=18 → priceE8 = 100000000
int256 priceE8 = _normalizeToE8(answer, feed.decimals());
```

The `decimals()` call costs ~700 gas. For production you may wish to cache it per feed address in a mapping, though on L2 this is negligible.

---

## 7. MockChainlinkPriceOracle — Test Replacement

Your existing `test/mocks/MockPriceOracle.sol` already implements `IPriceOracle` directly and is unaffected. However, you may want a mock that simulates Chainlink's `AggregatorV3Interface` for integration-style tests:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from
    "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockAggregatorV3
 * @notice Drop-in AggregatorV3Interface mock for Foundry tests.
 *         Replaces Pyth's MockPriceOracle at the AggregatorV3 level.
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    uint8   private _decimals;
    int256  private _answer;
    uint256 private _updatedAt;
    uint80  private _roundId;
    bool    private _shouldRevert;
    string  private _revertMsg;

    constructor(uint8 decimals_, int256 initialAnswer) {
        _decimals  = decimals_;
        _answer    = initialAnswer;
        _updatedAt = block.timestamp;
        _roundId   = 1;
    }

    // --- AggregatorV3Interface ---

    function decimals() external view override returns (uint8) { return _decimals; }
    function description() external pure override returns (string memory) { return "MOCK"; }
    function version() external pure override returns (uint256) { return 1; }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (_shouldRevert) revert(_revertMsg);
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }

    function getRoundData(uint80 _rid)
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_rid, _answer, _updatedAt, _updatedAt, _rid);
    }

    // --- Test helpers ---

    function setAnswer(int256 answer) external { _answer = answer; }
    function setUpdatedAt(uint256 ts) external { _updatedAt = ts; }
    function setRoundId(uint80 rid) external { _roundId = rid; }

    /// @notice Simulate a stale feed
    function makeStale(uint256 secondsAgo) external {
        _updatedAt = block.timestamp - secondsAgo;
    }

    /// @notice Simulate a round in progress (answeredInRound < roundId)
    function makeIncompleteRound() external { _roundId += 1; } // answeredInRound stays at old roundId

    /// @notice Simulate revert (e.g. no data)
    function setShouldRevert(bool v, string calldata msg_) external {
        _shouldRevert = v;
        _revertMsg = msg_;
    }
}

/**
 * @title MockSequencerFeed
 * @notice Simulates Chainlink L2 Sequencer Uptime Feed for tests.
 */
contract MockSequencerFeed is AggregatorV3Interface {
    int256  private _answer;   // 0 = up, 1 = down
    uint256 private _startedAt;

    constructor() {
        _answer    = 0;      // up by default
        _startedAt = block.timestamp - 7200; // started 2h ago — past grace period
    }

    function decimals() external pure override returns (uint8) { return 0; }
    function description() external pure override returns (string memory) { return "SEQ"; }
    function version() external pure override returns (uint256) { return 1; }

    function latestRoundData() external view override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, _answer, _startedAt, _startedAt, 1);
    }

    function getRoundData(uint80) external view override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, _answer, _startedAt, _startedAt, 1);
    }

    function setDown() external { _answer = 1; _startedAt = block.timestamp; }
    function setUp(uint256 startedAt_) external { _answer = 0; _startedAt = startedAt_; }

    /// @notice Set sequencer as recovered but still in grace period
    function setRecoveringInGracePeriod() external {
        _answer    = 0;
        _startedAt = block.timestamp - 30; // only 30s ago, grace period = 3600s
    }
}
```

---

## 8. MarketEngine Configuration Changes

### 8.1 OracleKind Enum

In `MarketTypes.sol`, add a `Chainlink` variant:

```solidity
// src/types/MarketTypes.sol

enum OracleKind {
    Pyth,      // existing
    Chainlink  // new
}
```

In `MarketEngine.initialize()`, pass `OracleKind.Chainlink` instead of `OracleKind.Pyth`.

### 8.2 Template `oracleFeedId` — New Encoding

When calling `upsertTemplate`, the `oracleFeedId` field changes meaning:

```solidity
// Pyth (old): feedId = bytes32 content hash
bytes32 btcFeedId = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

// Chainlink (new): feedId = proxy address padded to bytes32
// Arbitrum One BTC/USD proxy: 0x6ce185539ab4640a9b2c674e3d1f8e34b69d1dc2
bytes32 btcFeedId = bytes32(uint256(uint160(0x6ce185539ab4640a9b2c674e3d1f8e34b69d1dc2)));
```

Helper in your deploy/config scripts:

```typescript
// TypeScript helper
function addressToFeedId(address: string): string {
    return ethers.utils.hexZeroPad(address, 32);
}
```

### 8.3 `oracleMaxConfidenceBps` — Must be 0

For all Chainlink-backed templates, set `oracleMaxConfidenceBps = 0`. This disables the confidence band check (which is a no-op for Chainlink since `confidenceE8` is always returned as 0).

### 8.4 `oracleMaxDelaySeconds` — Heartbeat-aware values

Chainlink feeds have a **heartbeat** (maximum time between updates) and a **deviation threshold** (minimum price movement that triggers an update). You must set `maxDelaySeconds` ≥ heartbeat to avoid spurious staleness reverts.

Common feed heartbeats:

| Feed | Heartbeat | Deviation |
|---|---|---|
| BTC/USD (Arbitrum) | 86400s (24h) | 0.15% |
| ETH/USD (Arbitrum) | 86400s (24h) | 0.15% |
| BTC/USD (Base) | 1200s (20min) | 0.5% |
| ETH/USD (Base) | 1200s (20min) | 0.5% |
| BTC/USD (Optimism) | 1200s (20min) | 0.5% |

**Rule:** Set `oracleMaxDelaySeconds` to `heartbeat + 300` (5-minute buffer) at minimum. For daily heartbeat feeds, `90000` (25h) is safe.

---

## 9. Template Feed ID Mapping

Feed proxy addresses for major L2 networks. Always verify on [docs.chain.link/data-feeds/price-feeds/addresses](https://docs.chain.link/data-feeds/price-feeds/addresses) before deployment.

### Arbitrum One

| Asset | Proxy Address | Decimals | Heartbeat |
|---|---|---|---|
| BTC/USD | `0x6ce185539ab4640a9b2c674e3d1f8e34b69d1dc2` | 8 | 86400s |
| ETH/USD | `0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612` | 8 | 86400s |
| LINK/USD | `0x86E53CF1B873786aC51F49cB4F4A5e8Bf8b9e3C9` | 8 | 86400s |
| ARB/USD | `0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6` | 8 | 86400s |
| USDC/USD | `0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3` | 8 | 86400s |

### Base

| Asset | Proxy Address | Decimals | Heartbeat |
|---|---|---|---|
| BTC/USD | `0x64c911996D3c6aC71f9b455B1E8E7266BcfBB449` | 8 | 1200s |
| ETH/USD | `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70` | 8 | 1200s |
| LINK/USD | `0x17CAb8FE31E32f08326e5E27412894e49B0f9D65` | 8 | 1200s |

### OP Mainnet

| Asset | Proxy Address | Decimals | Heartbeat |
|---|---|---|---|
| BTC/USD | `0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593` | 8 | 1200s |
| ETH/USD | `0x13e3Ee699D1909E989722E753853AE30b17e08c5` | 8 | 1200s |
| OP/USD | `0x0D276FC14719f9292D5C1eA2198673d1f4269246` | 8 | 86400s |

### zkSync Era

| Asset | Proxy Address | Decimals | Heartbeat |
|---|---|---|---|
| BTC/USD | `0x703b52F2b28fEbcB60E1372858AF5b18849FE867` | 8 | 86400s |
| ETH/USD | `0x6D41d1dc818112880b40e26BD6FD347E41008eDA` | 8 | 86400s |

> ⚠️ Always verify addresses on the official Chainlink docs before mainnet deployment. Feed addresses can change when Chainlink rotates aggregator contracts.

---

## 10. Staleness & Confidence: Behavioral Mapping

This section maps every oracle-sensitive code path in `MarketEngine` to its Chainlink behavior.

### 10.1 `lockEpoch` (Direction markets only)

```
Current (Pyth):
  keeper calls IPyth.updatePriceFeeds{value: fee}(updateData)  ← extra tx
  keeper calls MarketEngine.lockEpoch(...)
  engine calls adapter.getNormalizedPrice(feedId, maxDelay, nowTs)
  Pyth adapter: getPriceNoOlderThan reverts if stale
  OracleNormalize: adjusts expo → priceE8, confidenceE8
  engine: _enforceConfidence(priceE8, confidenceE8, maxConf)
  engine: writes checkpointA

New (Chainlink):
  keeper calls MarketEngine.lockEpoch(...)  ← ONE call, no pre-update
  engine calls adapter.getNormalizedPrice(feedId, maxDelay, nowTs)
  Chainlink adapter:
    - checks sequencer uptime (L2)
    - reads latestRoundData()
    - checks answeredInRound >= roundId
    - checks answer > 0
    - checks block.timestamp - updatedAt <= maxDelaySeconds
    - normalizes to e8
    - returns confidenceE8 = 0
  engine: _enforceConfidence(priceE8, 0, 0) → passes (0 <= 0) ✓
  engine: writes checkpointA
```

### 10.2 `resolveEpoch` and `executeRollingRound`

Same pattern as `lockEpoch`. The single oracle read in `executeRollingRound` (used for both checkpointB of `prev` and checkpointA of `k`) remains one call — Chainlink serves both from one `latestRoundData()`.

### 10.3 Rolling halt conditions mapping

| Pyth halt reason | Chainlink equivalent | Adapter behavior |
|---|---|---|
| `OracleFailure` (getPriceNoOlderThan reverts) | `latestRoundData()` reverts or answer ≤ 0 | Adapter reverts → engine catches → halts |
| `OracleConfidenceWide` | N/A (no confidence) | Never triggers with `maxConfidenceBps=0` |
| `BufferMissOnLock` | Same timing logic | Unchanged |
| `BufferMissOnResolve` | Same timing logic | Unchanged |
| `ManualAdmin` | Same | Unchanged |

Note: You should add sequencer-down as a **new halt reason** in `MarketTypes.RollingHaltReason`:

```solidity
enum RollingHaltReason {
    NoneReason,
    BufferMissOnLock,
    BufferMissOnResolve,
    OracleFailure,
    OracleConfidenceWide,
    ManualAdmin,
    SequencerDown   // NEW — emitted when ChainlinkAdapter reverts due to L2 sequencer
}
```

The engine's existing `try/catch` around oracle calls will naturally catch the `SequencerDown` revert and map it to `OracleFailure` without engine changes, but adding a dedicated reason makes debugging clearer.

---

## 11. Rolling Round Implications

Rolling mode is the most oracle-sensitive path. One call to `executeRollingRound` uses a **single oracle sample** applied to both checkpointB (resolve `prev`) and checkpointA (lock `k`).

### 11.1 Chainlink Update Timing vs Rolling Interval

This is the critical operational concern. For a rolling market with `rollingIntervalSeconds = 3600` (1-hour rounds):

```
Rolling timeline:
  epoch k-1: lockAt = T0,         resolveAt = T0 + 1h
  epoch k:   lockAt = T0 + 1h,    resolveAt = T0 + 2h
  epoch k+1: (opens on tick)

Keeper calls executeRollingRound at T0 + 1h (± buffer)

Oracle check:
  Chainlink BTC/USD on Arbitrum: heartbeat = 24h
  Last update might be at T0 - 23h
  
  block.timestamp - updatedAt = 23h + 1h = 24h

  If maxDelaySeconds = 86400 (24h): PASSES barely
  If maxDelaySeconds = 3600 (1h):   REVERTS → rolling halts
```

**Recommendation:** For Chainlink-backed Direction markets with rolling mode, set `oracleMaxDelaySeconds` to `heartbeat + buffer`. For daily-heartbeat feeds (Arbitrum BTC/ETH), use `90000` (25 hours). For 20-minute feeds (Base, OP), use `1500` (25 minutes).

### 11.2 No Keeper Pre-Update Cost

On Pyth, each rolling tick required the keeper to first post an update:
- `IPyth.updatePriceFeeds{value: fee}()` — ~50k-100k gas + fee
- `executeRollingRound()` — 376,754 gas

On Chainlink:
- `executeRollingRound()` — ~376,754 gas + ~2,100 gas (view call to AggregatorV3)
- No pre-update, no fee

**Estimated keeper cost reduction per round: ~30-40%** in gas + elimination of protocol fee.

---

## 12. Deploy Script Changes

```solidity
// script/production/DeployProduction.s.sol — updated sections

import {ChainlinkAdapter} from "../src/adapters/ChainlinkAdapter.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address stakeToken  = vm.envAddress("STAKE_TOKEN");
        address admin       = vm.envAddress("ADMIN");
        address treasury    = vm.envAddress("TREASURY");
        address worker      = vm.envAddress("WORKER");

        // L2 sequencer feed address — set to address(0) on L1
        // Arbitrum:  0xFdB631F5EE196F0ed6FAa767959853A9F217697D
        // Base:      0xBCF85224fc0756B9Fa45aA7892530B47e10b6433
        // Optimism:  0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389
        address sequencerFeedAddr = vm.envAddress("SEQUENCER_FEED"); // or address(0) for L1

        // Deploy adapter — replaces PythAdapter
        ChainlinkAdapter adapter = new ChainlinkAdapter(sequencerFeedAddr);

        bytes memory initData = abi.encodeCall(
            MarketEngine.initialize,
            (
                IERC20(stakeToken),
                IPriceOracle(address(adapter)),
                admin,
                treasury,
                worker,
                defFee,
                maxSw,
                maxOut,
                MarketTypes.OracleKind.Chainlink, // ← changed from Pyth
                0,                                 // delay: per-template via oracleMaxDelaySeconds
                0                                  // confidence: 0 disables check for Chainlink
            )
        );

        Options memory opts;
        address proxy = Upgrades.deployUUPSProxy("MarketEngine.sol:MarketEngine", initData, opts);

        console2.log("ChainlinkAdapter", address(adapter));
        console2.log("MarketEngine proxy", proxy);

        vm.stopBroadcast();
    }
}
```

### Environment variables to add to `.env`:

```bash
# Replace PYTH= with:
SEQUENCER_FEED=0xFdB631F5EE196F0ed6FAa767959853A9F217697D  # Arbitrum
# SEQUENCER_FEED=0x0000000000000000000000000000000000000000  # L1 (disabled)
```

---

## 13. Test Suite Migration

### 13.1 `MarketEngineBase.t.sol` — Oracle setup

```solidity
// Replace:
MockPriceOracle oracle = new MockPriceOracle();

// With (option A — keep MockPriceOracle, it already implements IPriceOracle):
MockPriceOracle oracle = new MockPriceOracle(); // no change needed

// OR (option B — test ChainlinkAdapter specifically):
MockAggregatorV3  mockFeed      = new MockAggregatorV3(8, 4500000000000); // BTC @ $45,000
MockSequencerFeed sequencerMock = new MockSequencerFeed();
ChainlinkAdapter  adapter       = new ChainlinkAdapter(address(sequencerMock));

// feedId encoding:
bytes32 feedId = bytes32(uint256(uint160(address(mockFeed))));
```

### 13.2 New test cases to add

```solidity
// Test: stale feed reverts
function test_chainlink_stale_revert() public {
    mockFeed.makeStale(90001); // 25h + 1s stale
    vm.expectRevert(ChainlinkAdapter.StalePriceFeed.selector);
    adapter.getNormalizedPrice(feedId, 86400, uint64(block.timestamp));
}

// Test: sequencer down reverts
function test_chainlink_sequencer_down() public {
    sequencerMock.setDown();
    vm.expectRevert(ChainlinkAdapter.SequencerDown.selector);
    adapter.getNormalizedPrice(feedId, 86400, uint64(block.timestamp));
}

// Test: sequencer in grace period reverts
function test_chainlink_grace_period() public {
    sequencerMock.setRecoveringInGracePeriod();
    vm.expectRevert(ChainlinkAdapter.SequencerInGracePeriod.selector);
    adapter.getNormalizedPrice(feedId, 86400, uint64(block.timestamp));
}

// Test: incomplete round reverts
function test_chainlink_incomplete_round() public {
    mockFeed.makeIncompleteRound();
    vm.expectRevert(ChainlinkAdapter.RoundNotComplete.selector);
    adapter.getNormalizedPrice(feedId, 86400, uint64(block.timestamp));
}

// Test: invalid price reverts
function test_chainlink_zero_price() public {
    mockFeed.setAnswer(0);
    vm.expectRevert(ChainlinkAdapter.InvalidPrice.selector);
    adapter.getNormalizedPrice(feedId, 86400, uint64(block.timestamp));
}

// Test: decimal normalization
function test_chainlink_decimal_normalization_18() public {
    MockAggregatorV3 feed18 = new MockAggregatorV3(18, 1e18); // $1.00 with 18 decimals
    bytes32 id18 = bytes32(uint256(uint160(address(feed18))));
    (int256 price,,) = adapter.getNormalizedPrice(id18, 86400, 0);
    assertEq(price, 1e8); // normalized to 8 decimals
}
```

### 13.3 Gas snapshot — expected changes

With Chainlink adapter, lock/resolve calls no longer include Pyth update overhead. The `executeRollingRound` gas should decrease by the removed Pyth fee/update check path (~3,000-5,000 gas savings in the adapter call itself).

Run `forge snapshot --diff` after migration to confirm.

---

## 14. Feed Address Reference

Quick reference for `upsertTemplate` calls. Use `ChainlinkAdapter.addressToFeedId(proxyAddress)` to generate the `oracleFeedId` value.

```solidity
// Solidity helper for template setup scripts:
function makeFeedId(address proxy) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(proxy)));
}

// Example template upsert for BTC/USD on Arbitrum:
engine.upsertTemplate(UpsertTemplateParams({
    slug:                   "btc-usd-1h",
    marketType:             MarketTypes.MarketType.Direction,
    oracleFeedId:           makeFeedId(0x6ce185539ab4640a9b2c674e3d1f8e34b69d1dc2),
    oracleMaxDelaySeconds:  90000,  // 25h — covers daily heartbeat
    oracleMaxConfidenceBps: 0,      // MUST be 0 for Chainlink
    outcomeCount:           2,
    switchFeeBps:           50,
    settlementFeeBps:       200,
    executionMode:          MarketTypes.ExecutionMode.Rolling,
    rollingIntervalSeconds: 3600,
    rollingBufferSeconds:   300,
    equalPriceVoids:        true
}));
```

---

## 15. Migration Checklist

### Contracts

- [ ] Create `src/adapters/ChainlinkAdapter.sol` (implementation above)
- [ ] Add `Chainlink` to `MarketTypes.OracleKind` enum
- [ ] Add `SequencerDown` to `MarketTypes.RollingHaltReason` enum (optional but recommended)
- [ ] Create `test/mocks/MockAggregatorV3.sol`
- [ ] Create `test/mocks/MockSequencerFeed.sol`
- [ ] Add `@chainlink/contracts` to `foundry.toml` dependencies

### foundry.toml

```toml
[dependencies]
# existing
"@openzeppelin/contracts-upgradeable" = "5.x"
# add:
"@chainlink/contracts" = "1.3.0"
```

Or via remappings:
```toml
remappings = [
    "@chainlink/contracts/=lib/chainlink/contracts/",
]
```

### Deploy

- [ ] Set `SEQUENCER_FEED` env var for target L2 (or `address(0)` for L1)
- [ ] Deploy `ChainlinkAdapter(sequencerFeed)` in `script/production/DeployProduction.s.sol`
- [ ] Pass `IPriceOracle(address(chainlinkAdapter))` to `initialize()`
- [ ] Pass `OracleKind.Chainlink` to `initialize()`
- [ ] Pass `oracleMaxConfidenceBps = 0` as global default to `initialize()`

### Templates

- [ ] Encode all feed IDs as `bytes32(uint256(uint160(proxyAddress)))`
- [ ] Set `oracleMaxConfidenceBps = 0` on every Chainlink template
- [ ] Set `oracleMaxDelaySeconds` to `heartbeat + 300` minimum per feed
- [ ] Verify proxy addresses against official Chainlink docs for target chain

### Tests

- [ ] Add staleness revert test
- [ ] Add sequencer down revert test
- [ ] Add grace period revert test
- [ ] Add incomplete round revert test
- [ ] Add decimal normalization tests (8 decimals, 18 decimals)
- [ ] Run existing `MarketEngine` test suite — all should pass unchanged
- [ ] Run `forge snapshot --diff` to confirm gas profile

### Operational

- [ ] Remove Pyth price update calls from keeper scripts
- [ ] Update keeper monitoring to check `sequencerStatus()` on `ChainlinkAdapter`
- [ ] Set alerts on `RollingHalted` events (now includes sequencer-down cause)
- [ ] Verify heartbeat vs rolling interval alignment per template
- [ ] Document feed address registry for each deployed chain

---

*End of specification. All code snippets are draft implementations — audit before mainnet deployment.*