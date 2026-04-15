# RetroPick Protocol  
## Full Innovation Plan  
### Market Type Architecture, Product-Market Fit & Growth Strategy

| | |
|---|---|
| **Document type** | Product Strategy & Technical Architecture |
| **Entity** | RetroPick FZ-LLC, RAK DAO, Ras Al Khaimah, UAE |
| **Chain** | Arbitrum One (Solana roadmap Phase 2) |
| **Version** | 1.0 — April 2026 |
| **Classification** | Confidential |

---

## 1. Executive Summary

RetroPick is an oracle-resolved, epoch-based prediction market protocol deployed on Arbitrum One, registered as a Free Zone LLC under RAK DAO in the UAE. The protocol's core innovation is deterministic settlement: every market outcome is resolved by on-chain or cryptographically signed off-chain oracle data — no human judges, no dispute windows, no subjective interpretation.

This document is the full innovation plan. It covers three integrated layers:

- Nine novel market types that have never existed on any prediction market platform, each oracle-resolved and architecturally compatible with the existing MarketEngineDispatcher smart contract
- Product-market fit analysis for both crypto-native users (degens) and non-crypto financial users (normies), including the circular growth flywheel between them
- A user-created market system with oracle-constrained resolution, creator fee economics, and viral campaign mechanics

> **Strategic thesis**
>
> RetroPick's three-layer moat: (1) the only prediction market that operates as a genuine hedging tool for real-world financial exposures; (2) the only platform where all market types resolve deterministically from verifiable data with zero operator discretion; (3) the first platform to combine user-created markets with oracle-enforced resolution — giving creators virality without giving them the ability to manipulate outcomes.

The existing smart contract architecture — MarketEngineDispatcher with its modular resolver pattern, Chainlink price feed integration, and TrustedReporterAdapter oracle path — provides the exact foundation required to implement every innovation described in this document. No architectural overhaul is needed. All additions are additive enum values, new pure resolver functions, and targeted struct field additions.

---

## 2. Current Market Types vs Innovation Gap

RetroPick V1 ships with three market primitives: Direction (up/down vs checkpoint A), Threshold (above/below fixed level), and RangeClose (N-bucket price landing). These are solid, battle-tested structures that cover the core crypto trading use cases. The gap analysis below shows why they are necessary but not sufficient.

| **Market type** | **Core mechanic** | **Polymarket** | **PancakeSwap** | **Kalshi** | **RetroPick** |
|---|---|---|---|---|---|
| **Direction** | Price B vs price A at lock | Yes | Yes | Yes | Live |
| **Threshold** | Above / below fixed line | Partial | No | Yes | Live |
| **RangeClose** | N-bucket price landing | No | No | Partial | Live |
| **Momentum** | N-consecutive epoch streak | No | No | No | Innovate |
| **Cascade** | Multi-trigger level progression | No | No | No | Innovate |
| **Corridor** | Must stay in band for duration | No | No | No | Innovate |
| **Convergence** | Two-asset spread direction | No | No | No | Innovate |
| **Streak** | Pre-committed sequence parlay | No | No | No | Innovate |
| **Composite** | AND/OR multi-asset condition | No | No | No | Innovate |
| **Velocity** | Speed of move, not direction | No | No | No | Innovate |
| **Anchor** | Relative to historic reference | No | No | No | Innovate |
| **Ladder** | Progressive multiplier tiers | No | No | No | Innovate |

> **Key constraint (and advantage)**
>
> Every single innovative market type in this plan resolves from oracle price checkpoints only — no human judge, no UMA fallback, no dispute window. This is the critical differentiator. Polymarket's most complex markets require human resolution. RetroPick's most complex markets are more deterministic than Polymarket's simplest ones.

---

## 3. Nine Innovative Market Types — Full Specifications

Each market type below includes: the concept definition, oracle path, resolver logic, required smart contract changes, market examples, and implementation complexity. All types fit within the existing MarketEngineDispatcher + Resolvers.sol module pattern — additive only.

---

### 3.1 Momentum

*Bet on whether an asset maintains directional momentum across N consecutive epochs.*

> **What it is**
>
> A Momentum market asks: will asset X close higher (or lower) in each of the next N consecutive epochs? The user picks the direction and the streak count (2 to 8 epochs). Every checkpoint is recorded on-chain. If the asset reverses direction even once, the streak breaks. This is structurally different from a single Direction bet — it is a multi-epoch commitment with compounding resolution logic. The question is not just whether the asset moves; it is whether it sustains that movement.

| **Oracle path** | **Resolver function** |
|---|---|
| Chainlink price feed only. Uses existing checkpointA + checkpointB per epoch. A streakCount field in MarketTemplate. MarketLedger tracks currentStreakEpoch cursor. No new oracle infrastructure required. | `resolveMomentum(checkpoints[], direction, required)` — iterates checkpoint array, compares consecutive B vs A. Returns streakIntact boolean. If any epoch breaks direction, the streak-breaks side wins immediately. Early-exit claim available for streak-breaks side the moment the first reversal occurs. |

> **Contract additions required**
>
> New `MarketType.Momentum` enum. Add `streakLength: uint8` and `streakDirection: enum{Up,Down}` to MarketTemplate. Add `momentumCheckpoints: OracleCheckpoint[8]` array to Epoch struct (max 8-epoch streak). New `resolveMomentum()` in Resolvers.sol. Rolling mode compatible.

**Market examples**

- Will BTC close higher in 5 consecutive 1-hour rounds? (crypto degen momentum play)
- Will gold close higher for 10 consecutive days? (normie macro hedge)
- Will ETH outperform BTC for 3 consecutive weeks? (relative momentum, dual feed variant)

**Outcomes**

- Streak holds — all N epochs match direction (wins full pool)
- Streak breaks — any epoch reverses (wins pool, early exit available)
- Void if N=1 and checkpoint B equals checkpoint A (existing direction void logic)

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| Medium — multi-epoch lifecycle tracking | Chainlink only | V2 — Phase 1 priority | New enum value + resolver function |

---

### 3.2 Cascade

*Multiple price levels that must be breached in sequence. Each level reached shifts the winning outcome.*

> **What it is**
>
> A Cascade market defines N price levels (e.g. $95k, $97k, $100k for BTC). Users bet on how many levels will be breached during the epoch window — not just at close but at any point intraday. This is a structured knock-in market: the more levels reached, the more pools cascade to the deepest winning tier. The oracle must report the epoch's high-watermark price, not just the close. This is the only market type in this plan requiring intraday data beyond the closing price.

| **Oracle path** | **Resolver function** |
|---|---|
| Chainlink close-price feed (existing) + TrustedReporter for epochHighE8. Reporter Service monitors price feed in real time, computes epoch high watermark, and posts it via TrustedReporterAdapter at epoch close. Both values stored on-chain for auditability. | `resolveCascade(epochHighE8, cascadeLevels[], cascadeDirection)` — counts how many levels were breached by the high watermark. Returns levelsReached: uint8. Maps to winningOutcomeMask: bit 0 = 0 levels, bit 1 = 1 level, bit 2 = 2, bit 3 = all 3. Up to 4 levels per market. |

> **Contract additions required**
>
> New `MarketType.Cascade` enum. Add `cascadeLevels: int256[4]` and `cascadeDirection: enum{Up,Down}` to MarketTemplate. Add `epochHighE8: int256` to Epoch struct for high-watermark storage. New `resolveCascade()` in Resolvers.sol. Requires TrustedReporterAdapter extension for high-watermark posting.

**Market examples**

- BTC hits $98k, $100k, $102k — how many resistance levels in 4 hours? (high-frequency degen)
- Gold breaks $2450, $2480, $2500 — how many in this week? (normie resistance levels)
- Oil drops below $80, $78, $75 — how many supports break today? (energy trader hedge)

**Outcomes**

- 0 levels reached — asset never touches first level
- 1 level reached — touches first but not second
- 2 levels reached — touches first and second but not third
- All levels reached — maximum payout, rarest outcome

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| High — requires Reporter + new oracle data type | Chainlink + Reporter | V3 — Phase 2 | High — requires Reporter Service for intraday data |

---

### 3.3 Corridor

*Price must stay within a defined band for the entire epoch duration — not just close inside it.*

> **What it is**
>
> A Corridor market defines an upper and lower price bound. The resolution question is not where the price closes — it is whether the price stays within the corridor for the entire epoch window. A single tick outside the corridor, at any point during the epoch, triggers the 'escape' outcome immediately. This is fundamentally different from RangeClose (which only checks close price) because it measures sustained containment across time. For normie users in FX-exposed businesses, this maps directly to a real hedging concept: is my currency corridor holding?

| **Oracle path** | **Resolver function** |
|---|---|
| Chainlink close-price feed + TrustedReporter for epochHighE8 and epochLowE8. Reporter Service tracks both the high and low watermarks during the epoch and posts them at epoch close. | `resolveCorridor(epochHighE8, epochLowE8, upperBound, lowerBound)` — single conditional check. Returns corridorHeld: bool. Maps to winningOutcomeMask bit 0 = held, bit 1 = escaped upper, bit 2 = escaped lower. Optional early-resolution flag: if Reporter detects a breach mid-epoch, earlyResolveOnBreach instruction can settle immediately. |

> **Contract additions required**
>
> New `MarketType.Corridor` enum. Add `corridorUpperBound` and `corridorLowerBound` (both int256) to MarketTemplate. Add `epochHighE8` and `epochLowE8` to Epoch struct (shared with Cascade). Add `corridorBreachPosted: bool` flag. New `resolveCorridor()` in Resolvers.sol. New `earlyResolveOnBreach()` instruction in CoreLifecycleModule.

**Market examples**

- Will BTC stay between $95k and $105k all week? (range-bound trader's market)
- Will USD/IDR stay within 15,500–16,500 this month? (EM FX hedge for Indonesian exporters)
- Will gold stay between $2400 and $2600 for all of Q3? (quarterly portfolio hedge instrument)

**Outcomes**

- Corridor holds — price stayed fully contained for entire epoch
- Escaped upper — price touched or exceeded upper bound at any point
- Escaped lower — price touched or fell below lower bound at any point

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| High — requires Reporter + intraday data | Chainlink + Reporter | V3 — Phase 2 | High — requires Reporter + early-breach logic |

---

### 3.4 Convergence

*Two assets start the epoch at a spread. Will that spread narrow (converge) or widen (diverge)?*

> **What it is**
>
> A Convergence market captures the directional relationship between two assets' prices over time. Two oracle feeds are read at lock (checkpointA for feed A and feed B, computing the spread) and at resolve (checkpointB for both, computing the new spread). If the spread narrowed beyond a configurable tolerance band, the convergence side wins. If it widened, divergence wins. If the spread moved less than the tolerance, the market voids and stakes are refunded. This is a fundamentally new information product — no platform has offered spread-direction markets.

| **Oracle path** | **Resolver function** |
|---|---|
| Dual Chainlink price feed — existing adapter called twice with oracleFeedIdA and oracleFeedIdB. Both feeds read at lock and resolve via the same ChainlinkAdapter contract. No new oracle infrastructure required. | `resolveConvergence(pA_lock, pB_lock, pA_close, pB_close, toleranceBps)` — computes spreadOpen = abs(pA_lock - pB_lock) and spreadClose = abs(pA_close - pB_close). If spreadClose < spreadOpen * (1 - tolerance) → convergence. If spreadClose > spreadOpen * (1 + tolerance) → divergence. Else → void refund. |

> **Contract additions required**
>
> New `MarketType.Convergence` enum. Add `oracleFeedIdB: bytes32` to MarketTemplate (second feed). Add `spreadToleranceBps: uint16`. Add dual checkpoints for feed B (`checkpointA_B` and `checkpointB_B`: OracleCheckpoint) to Epoch struct. New `resolveConvergence()` in Resolvers.sol.

**Market examples**

- Will the BTC–ETH spread (in USD) narrow this week? (macro crypto market structure trade)
- Will the WTI–Brent crude spread narrow below $2 by Friday? (oil arb market for commodity traders)
- Will EUR/USD and GBP/USD converge this month? (FX pairs correlation for institutional users)

**Outcomes**

- Converge — spread narrowed beyond tolerance at epoch close
- Diverge — spread widened beyond tolerance at epoch close
- Stable / void — spread moved less than tolerance band (refund)

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| Medium — dual-feed checkpoint tracking | Chainlink only | V2 — Phase 1 priority | Medium — dual-feed checkpoint pattern |

---

### 3.5 Streak

*Users pre-commit a sequence of predictions across N epochs before any of them begin. Correct sequences earn multiplied payouts.*

> **What it is**
>
> A Streak market is an on-chain prediction parlay that resolves entirely by oracle without any human judgment. Before epoch 1 opens, users commit to a full sequence — for example [UP, UP, DOWN, UP] across 4 daily direction rounds. This sequence is stored in the Position struct. After all epochs resolve, the contract scores how many predictions were correct and applies a payout multiplier tier. Getting all N correct earns the maximum multiplier (e.g. 30x for 8-of-8). Getting 0 or 1 correct returns nothing. The pre-commitment is enforced by the contract — users cannot change their sequence after depositing, which is the core game mechanic.

| **Oracle path** | **Resolver function** |
|---|---|
| Chainlink price feed only — Streak runs on top of Direction, Threshold, or RangeClose epochs. No new oracle infrastructure. Each sub-epoch resolves via its standard resolver. | `scoreStreak(templateId, epochId, user)` — called after each sub-epoch resolves. Compares resolvedOutcome to predictedSequence[epochIndex]. Increments correctCount in Position struct. After final epoch: `claimStreak()` reads correctCount, looks up streakPayoutMultipliers[correctCount], computes payout = stake * multiplier / 10000. |

> **Contract additions required**
>
> New `MarketType.Streak` enum. Extend Position struct: add `predictedSequence: uint8[8]` and `correctCount: uint8`. Add `streakEpochs: uint8` and `streakPayoutMultipliers: uint16[9]` to MarketTemplate. New `depositStreakPosition()` instruction in UserOpsModule. New `scoreStreak()` and `claimStreak()` instructions.

**Market examples**

- Will BTC go [UP, DOWN, UP, UP, DOWN] over the next 5 daily closes? (sequence prediction game)
- Will gold go [UP, UP, UP] for 3 consecutive weeks? (directional streak for macro traders)
- Will EUR/USD direction match my 4-round sequence? (FX multi-session commitment trade)

**Outcomes**

- 0–1 correct — total loss of stake
- 2–3 correct — partial return (configurable per template)
- 4–6 correct — meaningful multiplier tier
- 7–8 correct — maximum multiplier (30x default), funded by all lower tiers

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| High — requires Position struct redesign | Chainlink only | V2 — Phase 1 priority | High — Position struct extension + new deposit instruction |

---

### 3.6 Composite

*A single market that resolves on multiple assets satisfying a logical condition simultaneously: AND, OR, or MAJORITY.*

> **What it is**
>
> A Composite market encodes a logical expression over up to 4 oracle feeds in a single epoch. Users bet on whether the composite condition is met or not met. The logic operator (AND, OR, MAJORITY) is defined in the MarketTemplate. At lock, the engine records checkpoint A for each feed. At resolve, it evaluates each feed's condition independently and applies the logic operator to determine the final outcome. This lets users express macro thesis views across multiple assets in one on-chain position — eliminating the need to manually combine positions on separate markets.

| **Oracle path** | **Resolver function** |
|---|---|
| Multi-feed Chainlink — up to 4 feeds via compositeFeeds: bytes32[4] in template. All feeds read via existing ChainlinkAdapter at lock and resolve. No new oracle infrastructure. | `resolveComposite(prices[], conditions[], logic)` — evaluates each condition independently into results[4] boolean array. Applies logic operator: AND = all true, OR = at least one true, MAJORITY = more than half true. Returns single winningOutcomeMask: bit 0 = condition met, bit 1 = not met. Clean binary outcome despite multi-asset complexity. |

> **Contract additions required**
>
> New `MarketType.Composite` enum. Add `compositeFeeds: bytes32[4]`, `compositeConditions: Condition[4]`, and `compositeLogic: enum{AND, OR, MAJORITY}` to MarketTemplate. Add `compositeCheckpointsA[4]` and `compositeCheckpointsB[4]`: OracleCheckpoint arrays to Epoch struct. New `resolveComposite()` in Resolvers.sol.

**Market examples**

- Will BTC close UP and gold close UP this week? (risk-on vs risk-off macro thesis)
- Will oil close DOWN and USD/IDR stay stable this month? (EM macro hedge for Indonesian exporters)
- Will at least 2 of [BTC, ETH, SOL, BNB] close higher today? (MAJORITY logic — broad crypto health)

**Outcomes**

- Condition met — AND: all feeds satisfied; OR: at least one; MAJORITY: more than half
- Condition not met — logic operator not satisfied by the oracle outcomes

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| Medium — multi-feed checkpoint array | Chainlink only | V2 — Phase 1 priority | Medium — multi-feed template fields |

---

### 3.7 Velocity

*Not which direction will price move — but how fast. Users pick the speed bin, not the direction.*

> **What it is**
>
> A Velocity market resolves on the absolute percentage move of an asset during the epoch, regardless of direction. The resolver computes move = abs(checkpointB - checkpointA) / checkpointA as a basis-point value. This result is bucketed into N velocity bins defined in the template (e.g. flat < 50bps, slow 50–200bps, medium 200–500bps, fast 500–1000bps, extreme > 1000bps). Users who correctly predict the volatility speed bucket win the pool from all other buckets. This is structurally identical to RangeClose but the input axis is percentage movement, not absolute price level. It is conceptually a new product: a volatility prediction market.

| **Oracle path** | **Resolver function** |
|---|---|
| Chainlink price feed only. Uses existing checkpointA (at lock) and checkpointB (at resolve) — same as Direction. No new oracle infrastructure. The percentage computation happens entirely in the resolver using existing on-chain checkpoint values. | `resolveVelocity(checkpointA, checkpointB, velocityBoundsE4[])` — computes moveBps = (abs(B - A) * 10000) / abs(A). Iterates bounds array to find bucket. Returns bucket index as winningOutcomeMask bit. Identical structure to resolveRangeClose — same N-bucket bit-mask output, different input axis. |

> **Contract additions required**
>
> New `MarketType.Velocity` enum. Add `velocityBoundsE4: uint32[4]` to MarketTemplate (bounds in basis points). Re-uses existing checkpointA and checkpointB from Epoch struct. New `resolveVelocity()` in Resolvers.sol — approximately 15 lines, direct port of resolveRangeClose with percentage computation prepended.

**Market examples**

- Will BTC move more than 5% in either direction today? (pure volatility play for options-adjacent traders)
- Will gold move less than 1% this week? (low-vol prediction for range traders and mean-reversion strategies)
- Will EUR/USD move between 0.5–2% this month? (FX volatility bucketing for forex traders)

**Outcomes**

- Flat — absolute move under 0.5%
- Slow — absolute move 0.5–2%
- Medium — absolute move 2–5%
- Fast — absolute move 5–10%
- Extreme — absolute move over 10%

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| Low — port of RangeClose | Chainlink only | V1.5 — highest priority new type | Low — direct RangeClose port |

---

### 3.8 Anchor

*Resolution is relative to a historical reference price stored at template creation — not the lock price. A fixed yardstick for long-horizon macro markets.*

> **What it is**
>
> An Anchor market stores a reference price at template creation time (anchorPriceE8) rather than capturing it at epoch lock. At resolve, checkpointB is compared against this static anchor, not against checkpointA. This means the anchor never moves across any number of epochs running on the same template — it is the permanent reference point. This enables questions like "is BTC above where it started 2025?" or "is gold above its post-2020-crisis floor?" — questions with a fixed historical yardstick that direction markets cannot express. The contract change is minimal: one additional field in MarketTemplate and a one-line resolver variant.

| **Oracle path** | **Resolver function** |
|---|---|
| Chainlink price feed only. No checkpoint A required — the anchor IS the fixed threshold. Only checkpointB is read at resolve. Anchor price is set once during upsertTemplate() by the admin from the current oracle price or any historical value. | `resolveAnchor(anchorPriceE8, checkpointB, condition)` — single comparison: checkpointB.valueE8 >= anchorPriceE8 for AtOrAbove condition. Returns winningOutcomeMask. One-liner variant of resolveThreshold with a static threshold. Extended form: `resolveAnchorRange(anchorPriceE8, upperPct, lowerPct, checkpointB)` for band markets. |

> **Contract additions required**
>
> New `MarketType.Anchor` enum. Add `anchorPriceE8: int256` to MarketTemplate. No Epoch struct changes needed — checkpoint A is not recorded for Anchor markets. New `resolveAnchor()` in Resolvers.sol — 3 lines. Minimal implementation cost.

**Market examples**

- Will BTC close above its January 1, 2025 price by December 31, 2025? (annual performance market)
- Will gold stay above its post-2008 crisis anchor of $900 in Q3? (historical support level market)
- Will SOL reclaim its all-time high anchor price by year end? (ATH recovery market for degen thesis)

**Outcomes**

- Above anchor at epoch close — price at or above the stored reference
- Below anchor at epoch close — price has not recovered to reference
- Within anchor band — close within configured percentage band of anchor (range variant)

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| Lowest — one field, one resolver | Chainlink only | V1.5 — ship immediately after Velocity | Minimal — one field + one-liner resolver |

---

### 3.9 Ladder

*Progressive outcome tiers where the further price moves from a reference, the higher the payout multiplier. A structured product — entirely oracle-resolved.*

> **What it is**
>
> A Ladder defines N outcome tiers along a price axis, each with a different configured payout weight stored in the template. Tier 0 (closest to reference price) carries the lowest multiplier. Tier N (furthest) carries the highest. Users allocate stake to any tier. The oracle resolves which tier the close price lands in. The key distinction from RangeClose is in the payout math: Ladder uses ladderPayoutWeights[] to create a structured payoff curve — lower tiers subsidize higher tiers in a directional way, rewarding correct predictions of extreme moves. This is a prediction market implementation of a structured note or binary knock-out ladder.

| **Oracle path** | **Resolver function** |
|---|---|
| Chainlink price feed only. Uses existing checkpointB at resolve. No checkpointA needed. Template stores both the price boundaries (ladderBoundsE8[]) and the payout weights per tier (ladderPayoutWeights[]). | `resolveLadder(checkpointB, ladderBoundsE8[])` — identical to resolveRangeClose for bucket selection. Returns winning tier index as winningOutcomeMask bit. Payout weights applied in MarketMath.computeEpochClaimLiabilityStorage — reads ladderPayoutWeights[winningTier] to compute the structured distribution from lower tiers to winning tier. |

> **Contract additions required**
>
> New `MarketType.Ladder` enum. Add `ladderBoundsE8: int256[8]` and `ladderPayoutWeights: uint16[8]` to MarketTemplate. Update MarketMath.computeEpochClaimLiabilityStorage to read weights when marketType == Ladder. New `resolveLadder()` in Resolvers.sol — 5 lines. Payout math change is the main implementation work.

**Market examples**

- BTC weekly ladder: under $90k, $90k–95k, $95k–100k, $100k–105k, over $105k — stake on your target tier
- Gold move ladder from weekly open: <1%, 1–2%, 2–4%, 4–7%, 7%+ — where does it land?
- SOL price ladder from current price in $10 increments — 5 tiers across a $50 range

**Outcomes**

- Tier 0 — closest to reference, lowest payout weight (conservative prediction)
- Tier 1–3 — intermediate tiers, increasing weights
- Tier N — furthest from reference, maximum payout weight (funded by all closer-tier stakes)

| **Implementation complexity** | **Oracle dependency** | **Priority** | **Contract change** |
|---|---|---|---|
| Medium — payout weight math | Chainlink only | V2 — after Velocity and Anchor | Medium — payout math modification |

---

## 4. Implementation Roadmap

The nine market types are ranked below by implementation complexity and strategic value. The ordering maximises shipped value while minimising risk — starting with pure Chainlink-only types before adding Reporter Service dependencies.

| **Order** | **Market type** | **Phase** | **Oracle dependency** | **Contract delta** | **Target** |
|---|---|---|---|---|---|
| 1 | Anchor | V1.5 | Chainlink only | 1 field + 3-line resolver | Weeks 4–5 |
| 2 | Velocity | V1.5 | Chainlink only | 1 field + 15-line resolver | Weeks 4–5 |
| 3 | Ladder | V2 | Chainlink only | 2 fields + payout math | Weeks 6–8 |
| 4 | Convergence | V2 | Dual Chainlink | Dual feed + spread resolver | Weeks 7–9 |
| 5 | Composite | V2 | Multi Chainlink (up to 4) | Array fields + logic resolver | Weeks 8–10 |
| 6 | Momentum | V2 | Chainlink only | Array checkpoint + scorer | Weeks 9–11 |
| 7 | Streak | V2 | Chainlink only | Position struct extension | Weeks 10–13 |
| 8 | Corridor | V3 | Chainlink + Reporter | High/low oracle + breach flag | Weeks 14–18 |
| 9 | Cascade | V3 | Chainlink + Reporter | High watermark + level array | Weeks 15–20 |

> **V1.5 quick wins (Weeks 4–6)**
>
> Anchor and Velocity require zero new oracle infrastructure — both resolve entirely from existing Chainlink close-price checkpoints. Combined, they add two entirely new product dimensions (historical reference markets + volatility speed markets) that no competitor offers, while touching only Resolvers.sol and MarketTypes.sol. These should ship together in a single upgrade cycle.

---


## 6. Product-Market Fit Analysis

### 6.1 Two Distinct User Types — Different Motivations, Same Protocol

| **Crypto degen wants** | **Non-crypto user wants** |
|---|---|
| Fast rolling rounds (5m, 15m). On-chain proof of non-manipulation. Leverage-like upside without liquidation. Social bragging rights and leaderboards. Yield on idle capital during open windows. New asset classes: meme coins, AI tokens, protocol TVL. Market creation power — I called this, I built this market. | No wallet friction — email login, USDC invisible. Markets on things they already track: gold, oil, FX, weather. Plain-English resolution rules. Hedging logic: I lose on my physical gold position, I win here. Small-stakes entry — no $100 minimums. Trust signals: audited, regulated, UAE-licensed. |

### 6.2 Competitive Gap — What No Platform Has Solved

| **Platform** | **Gaps for degens** | **Gaps for normies** |
|---|---|---|
| **Polymarket** | Human resolution — disputes possible. No financial asset direction markets. No user-created markets. | No hedging framing. No non-crypto onramp. Wallet required. US-blocked. |
| **PancakeSwap Prediction** | Only BTC/ETH direction. Only one market type. No user markets. No data context. | No commodities or FX. Binary only. No non-crypto appeal whatsoever. |
| **Kalshi** | No crypto markets. Regulated to the point of friction. No rolling rounds. | US-only. No GCC/MENA coverage. No hedging utility framing. |
| **RetroPick** | All asset classes. 9 novel market types. Rolling rounds. Creator markets. Oracle proof. | Gold, FX, oil, weather. Hedging framing. Email onramp. UAE-regulated. |

### 6.3 The Hedging Narrative — Untouched by Every Competitor

Every prediction market positions itself as speculation. RetroPick is the first to explicitly position financial prediction markets as hedging instruments for real-world exposure. This is not a marketing claim — it is structurally true. A gold exporter who holds physical gold and bets "gold falls below $2400" on RetroPick is running a classic hedge: if their physical inventory falls in value, their prediction market position profits.

This framing is available to RetroPick because of its oracle-resolved design — the oracle's authoritative price data is the same price that governs real-world commodity contracts. No human-judged prediction market can claim this equivalence.

---

## 7. Circular Growth Flywheel

The most durable growth mechanic is a flywheel where each user cohort attracts the other. RetroPick's design creates a natural cross-audience loop that no competitor has architected.

| **Step** | **Actor** | **Action** | **Effect** |
|---|---|---|---|
| 1 | Crypto degen | Creates a high-conviction BTC threshold market. Seeds pool. Shares on CT/Fintwit with thesis. | Market appears on discovery feed. Campaign link goes viral. |
| 2 | Non-crypto user | Sees market card via shared link. Reads thesis. Onboards via email — no wallet needed. | New normie user enters the protocol for the first time. |
| 3 | Non-crypto user | Uses the market as a hedge against their existing gold or FX exposure. Deposits USDC. | Pool grows. Protocol fee accrues. Creator earns fee share. |
| 4 | Non-crypto user | Shares their hedge thesis: "I hedged my gold position with this market — join me." | Brings their non-crypto financial network into the protocol. |
| 5 | Crypto degen | Sees heavy normie-side pool skew (80%+ on one outcome). Fades the crowd for asymmetric expected value. | Both sides now have liquidity. Degen profits from normie flow. Normie gets a deeper pool to participate in. |
| ↻ | Loop repeats | Each cycle brings new users from both cohorts. Creator earns fee share on growing volume. | Protocol TVL grows. Reputation scores accumulate. Featured creators attract their own audiences. |

### 7.1 Retention Mechanics

| **For crypto degens** | **For non-crypto users** |
|---|---|
| 5-minute rolling rounds for continuous engagement. Leaderboards ranked by accuracy per sector (gold, BTC, FX). "I called it" shareable win cards auto-generated after resolution. Creator reputation score building over time. | Streak and Streak protection mechanics for daily habit formation. Portfolio-style prediction history dashboard. Weekly email summary of active markets and their hedging relevance to the user's stated financial exposures. |

| **Cross-audience mechanics** | **Copy-prediction (social trading)** |
|---|---|
| Asymmetric pool alert: notify users when one side has 80%+ of the pool — contrarian opportunity signal for degens, confirmation signal for normies hedging against consensus. | Follow a top creator and auto-mirror their positions with one tap. Converts passive normie observers into active participants. Largest untapped growth mechanic in prediction markets. |

---

## 8. Market Category Expansion — Beyond Crypto

The nine novel market types defined in this plan apply across all asset categories. Below is the full taxonomy of market categories available to RetroPick under its UAE FZ-LLC structure, mapped to the most relevant market types.

| **Category** | **Subcategory examples** | **Best market types** | **Oracle** | **Legal risk** |
|---|---|---|---|---|
| **Crypto** | BTC/ETH/SOL price, dominance, ETF flows, DeFi TVL, stablecoin peg | Direction, Velocity, Momentum, Ladder, Cascade | Chainlink | Low |
| **Economics** | CPI, Fed rates, GDP, NFP, treasury yields | Threshold, Anchor, Composite | TrustedReporter + BLS/Fed APIs | Low |
| **Financials** | S&P 500, gold, WTI crude, EUR/USD, GLD ETF | Direction, Corridor, Convergence, Velocity, Ladder | Chainlink | Low |
| **GCC / MENA** | USD/AED, USD/SAR, Tadawul index, UAE CPI, Aramco production | Corridor, Anchor, Threshold | Chainlink + CBUAE API | Low — first mover |
| **Climate** | NOAA records, UAE temp/rainfall, Dubai AQI, hurricane count | Threshold, Anchor, Corridor (sustained weather) | TrustedReporter + NOAA | Low — no precedent for challenge |
| **Tech & Science** | AI model releases, FDA approvals, SpaceX launches, semiconductor | Threshold (binary event), Cascade (multi-milestone) | TrustedReporter + official APIs | Low |
| **Business** | Post-announcement M&A, IPO outcomes, CEO tenure, earnings beats | Threshold (binary event) | TrustedReporter (post-announcement only) | Medium — insider risk if pre-announcement |

> **UAE FZ-LLC first-mover categories**
>
> GCC and MENA-specific markets (UAE CPI, Saudi Aramco production, USD/AED corridor, Dubai weather records) are completely uncovered by any US-regulated platform. These are low-risk, high-relevance markets for RetroPick's natural user base and cannot be offered by Kalshi or Polymarket due to regulatory jurisdiction. This is a durable geographic moat.

---

## 9. Oracle Architecture — Extending the TrustedReporter

The current MarketEngine supports two oracle paths: ChainlinkAdapter (for continuously-priced assets) and TrustedReporterAdapter (for non-price-feed event data). The nine new market types require two oracle extensions beyond the current design.

### 9.1 Intraday High/Low Oracle (Required for Cascade and Corridor)

Cascade and Corridor market types require the epoch's high watermark and/or low watermark — not just the close price. The existing TrustedReporter pattern handles this cleanly: the Reporter Service monitors the Chainlink price feed in real time during each epoch, computes the intraday high and low, and posts them via `postResult()` at epoch close alongside the standard close price.

| **Reporter Service extension** | **IEventOracle interface extension** |
|---|---|
| New monitoring loop: subscribe to Chainlink price feed updates throughout epoch window. Track running max (epochHigh) and running min (epochLow). At epoch close time, batch-post three values via TrustedReporterAdapter: closePrice, epochHigh, epochLow — all signed in a single ECDSA message. | New `postOHLCResult()` function on TrustedReporterAdapter accepting four values: open (checkpoint at lock), high, low, close. Returns all four via `getOHLCResult(marketId)`. MarketEngine reads the appropriate values based on market type during `resolveEpoch()`. |

### 9.2 Dual-Feed Oracle (Required for Convergence and Composite)

Convergence and Composite market types require simultaneous oracle reads from two or more price feeds at the same timestamp. The existing ChainlinkAdapter already handles multiple feeds — it simply needs to be called with different feedId values. The key change is in MarketTemplate: adding secondary feed IDs and in the Epoch struct: adding secondary checkpoints.

### 9.3 Oracle Security Model (Unchanged)

| **Property** | **Chainlink path** | **TrustedReporter path** |
|---|---|---|
| **Trust assumption** | Chainlink DON — decentralised oracle network | Single operator key (semi-centralised, ECDSA-verified) |
| **Tamper resistance** | On-chain aggregation across multiple nodes | ECDSA signature verification in contract — operator cannot forge without private key |
| **Auditability** | All rounds stored on-chain permanently | dataSource URL + raw API response stored in PostgreSQL; resolution tx immutable on-chain |
| **Dispute window** | None needed — continuous feed | Admin 24h void window; Owner can be Gnosis Safe multisig for key rotation |

---

## 10. Summary — What RetroPick Becomes

RetroPick launches as an oracle-resolved prediction market with three market primitives and a non-custodial architecture. With this innovation plan fully executed, it becomes something that does not exist anywhere in the prediction market landscape.

> **What RetroPick becomes**
>
> The first prediction market that simultaneously serves crypto traders seeking volatility exposure, financial professionals hedging real-world positions, and content creators who can build and monetise their own oracle-resolved markets — all on a single on-chain engine with zero human judges and complete resolution transparency.

### 10.1 Innovation Delivered per Phase

| **Phase** | **New market types** | **Product additions** | **Oracle additions** |
|---|---|---|---|
| **V1 (live)** | Direction, Threshold, RangeClose | Rolling rounds, Aave yield router, protocol fee | Chainlink price feeds (7 assets) |
| **V1.5** | Anchor, Velocity | Extended Chainlink feeds (FX, indices, commodities). User-created markets (Phase 1) | Chainlink — EUR/USD, S&P 500, WTI, GLD, BTC dominance |
| **V2** | Ladder, Convergence, Composite, Momentum, Streak | Creator reputation, campaign links, copy-prediction. Economics and Tech markets via TRO | TrustedReporter — BLS, Fed, NOAA, FDA, DeFiLlama. Dual-feed Chainlink |
| **V3** | Corridor, Cascade | Multi-reporter TRO upgrade. GCC-specific markets. Social trading (full copy-prediction) | OHLC intraday Reporter. Multi-Reporter threshold model. Optional UMA for subjective events |

### 10.2 The Uncopiable Combination

Each individual element of this plan — novel market types, oracle-resolved settlement, user-created markets, hedging framing, UAE regulatory positioning — could theoretically be copied by a competitor. What cannot be copied quickly is the combination: a working smart contract engine with modular resolvers, an ECDSA-signed TrustedReporter infrastructure, a live user base that spans both crypto degens and normie finance users, and a UAE FZ-LLC structure that permits GCC-specific markets that US-regulated platforms cannot touch.

The implementation roadmap is conservative: Anchor and Velocity can ship in weeks because they require zero new oracle infrastructure. Corridor and Cascade are the most ambitious but they share the same Reporter Service plumbing. By the time any competitor begins building toward this capability set, RetroPick will have 18 months of live trading data, established creator relationships, and a liquidity network across both user cohorts.

---

**RetroPick Protocol — Full Innovation Plan**

Version 1.0 — April 2026 — Confidential — RetroPick FZ-LLC, RAK DAO, Ras Al Khaimah, UAE