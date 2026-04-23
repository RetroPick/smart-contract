Yes — here is a clean **RetroPick product timeline architecture** for **5 minutes, 1 hour, and 1 day** markets, based on the same good core rule Pancake uses:

* users enter **before lock**
* **lockedPrice** is fixed once
* no new entry after lock
* round runs during live phase
* **closedPrice** is fixed once at end
* settlement compares **closedPrice vs lockedPrice** ([PancakeSwap][1])

---

# 1. Core RetroPick round model

For every market, regardless of duration, use the same lifecycle:

1. **Scheduled**
2. **Betting Open**
3. **Locked / Live**
4. **Calculating**
5. **Resolved**
6. **Claimed / Expired**
7. **Cancelled** if oracle or automation fails

This keeps the product consistent across all durations. Pancake’s docs effectively use the same conceptual shape: users bet before live, the locked price is set at live start, the round stays live for the interval, then it moves to a brief calculating/result state. ([PancakeSwap][2])

---

# 2. Canonical state machine

## A. Scheduled

Round exists in advance but is not yet accepting bets.

Stored:

* `marketId`
* `asset`
* `duration`
* `betStartAt`
* `lockAt`
* `closeAt`
* `status = Scheduled`

Use this so frontend and indexers can show upcoming rounds early.

## B. Betting Open

Users may choose **UP** or **DOWN** and deposit stake.

Rules:

* entries allowed only during `now >= betStartAt && now < lockAt`
* position cannot be changed after submission
* optional: one position per wallet per round in V1 for simplicity

## C. Locked / Live

At `lockAt`:

* fetch oracle reference
* write `lockedPrice` once
* freeze new entries
* set `status = Live`

This is the anchor. Pancake defines the locked price as the oracle price at the start of the live phase. ([PancakeSwap][3])

## D. Calculating

At `closeAt`:

* fetch oracle reference
* write `closedPrice` once
* stop all market activity
* set `status = Calculating`

This is useful because even on fast systems there may be a short delay between nominal round end and official result display. Pancake explicitly describes a brief “Calculating” moment after the live period ends. ([PancakeSwap][2])

## E. Resolved

Apply deterministic result:

* if `closedPrice > lockedPrice` → `result = UP`
* if `closedPrice < lockedPrice` → `result = DOWN`
* if `closedPrice == lockedPrice` → `result = TIE`

Pancake’s docs define winner determination using closed price versus locked price. ([PancakeSwap][1])

## F. Claimed / Expired

Users claim winnings, or rewards are auto-credited to internal balance.

## G. Cancelled

Used if:

* oracle unavailable
* stale oracle
* invalid round timing
* automation failure
* market paused by governance/admin

In cancellation, safest V1 policy is **refund all stakes**.

---

# 3. RetroPick timing architecture by duration

The most important design choice is this:

**duration** should refer to the **live phase**, not the total wait from when a user first notices the market.

That avoids confusion.

## A. 5-minute market

Recommended timing:

* **betting window**: 5 minutes
* **live window**: 5 minutes
* **calculating**: 10–30 seconds target
* **claim window**: open after resolution

### Timeline

Example:

* 12:00:00 — betting opens
* 12:05:00 — lock, `lockedPrice` set, live starts
* 12:10:00 — close, `closedPrice` set
* 12:10:00–12:10:20 — calculating
* 12:10:20 — resolved

### User experience

* if user enters at 12:00:05, total wait is about 10 minutes
* if user enters at 12:04:55, total wait is about 5 minutes and a few seconds

That is why users often feel the round settles in “less than 5 minutes” from their perspective, even though the actual live phase is still 5 minutes. Pancake’s guide describes 5-minute rounds, a 5-minute live phase, and that an entered round may finish after 5 or 10 minutes depending on where the user joined in the cycle. ([PancakeSwap][2])

### Product role

Use 5m for:

* highest frequency
* retention
* repeated engagement
* small-size, arcade-style prediction

### Risks

* strongest herd behavior
* strongest first-candle bias
* easiest to feel “already decided”
* oracle/UI timing confusion is most noticeable here because Pancake notes oracle updates may lag by up to about 20 seconds. ([PancakeSwap][3])

---

## B. 1-hour market

Recommended timing:

* **betting window**: 15–30 minutes
* **live window**: 1 hour
* **calculating**: 10–60 seconds target

My preferred V1 choice:

* **betting = 30 minutes**
* **live = 60 minutes**

### Timeline

Example:

* 09:30 — betting opens
* 10:00 — lock, `lockedPrice` set
* 10:00–11:00 — live
* 11:00 — close, `closedPrice` set
* 11:00–11:01 — calculating
* 11:01 — resolved

### Why 30-minute betting works

For 1h markets, users need time to:

* notice the upcoming round
* form a view
* place stake calmly

If you make betting too short, the 1h product feels rushed.
If you make betting too long, capital idles too much.

### Product role

Use 1h for:

* better uncertainty than 5m
* more meaningful directional prediction
* less “it is already over” feeling
* stronger premium/trader experience

### Recommendation

This should probably be the **flagship serious mode** in RetroPick.

---

## C. 1-day market

Recommended timing:

* **betting window**: 4–12 hours
* **live window**: 24 hours
* **calculating**: 1–5 minutes target

My preferred V1 choice:

* **betting = 6 hours**
* **live = 24 hours**

### Timeline

Example:

* 18:00 previous day — betting opens
* 00:00 — lock, `lockedPrice` set
* 00:00–24:00 — live
* next 00:00 — close, `closedPrice` set
* next 00:00–00:05 — calculating
* next 00:05 — resolved

### Why daily boundary matters

Use a predictable universal cadence such as:

* UTC day
* or exchange/session-style anchor

Do not let daily rounds start at arbitrary user-triggered times. Scheduled boundaries make the market legible and easier to follow.

### Product role

Use 1d for:

* higher-conviction directional theses
* slower, more thoughtful users
* premium featured markets
* better content and commentary opportunities

### Risks

* slower bankroll turnover
* lower daily engagement frequency
* easier liquidity fragmentation if too many assets are listed

---

# 4. Clean scheduling framework for RetroPick

Use **market templates** and **round instances**.

## Market Template

Defines recurring configuration:

* `asset = BTC`
* `duration = 5m | 1h | 1d`
* `betWindow`
* `feeBps`
* `oracleId`
* `minStake`
* `maxStake`
* `isActive`

## Round Instance

Concrete scheduled market:

* `roundId`
* `marketTemplateId`
* `betStartAt`
* `lockAt`
* `closeAt`
* `lockedPrice`
* `closedPrice`
* `result`
* `status`
* pool totals

This gives you:

* predictable issuance
* cleaner indexing
* easy automation
* easy analytics across recurring rounds

---

# 5. Recommended cadence by market type

## 5m markets

Create overlapping rolling rounds continuously.

Example for BTC-5m:

* round 100: bet 12:00–12:05, live 12:05–12:10
* round 101: bet 12:05–12:10, live 12:10–12:15
* round 102: bet 12:10–12:15, live 12:15–12:20

This is effectively the Pancake model: new rounds roll every 5 minutes. ([PancakeSwap][1])

## 1h markets

Also rolling, but more spaced.

Example:

* round A: bet 09:30–10:00, live 10:00–11:00
* round B: bet 10:30–11:00, live 11:00–12:00

That keeps the market always having:

* one round open for betting
* one round currently live

## 1d markets

One scheduled daily cycle per asset.

Example:

* bet opens 18:00 UTC
* lock 00:00 UTC
* live until next 00:00 UTC

Simple and legible.

---

# 6. Best V1 UI flow

Your UI should clearly separate **three prices**:

1. **Current displayed market price**
2. **Locked price**
3. **Official close/result price**

This matters because Pancake explicitly notes oracle updates may lag by up to about 20 seconds, so displayed price and official settlement reference can appear slightly different around boundaries. ([PancakeSwap][3])

## Betting Open card

Show:

* countdown to lock
* current reference price
* projected payout for UP and DOWN
* total pool
* your entered side if any

## Live card

Show:

* locked price line
* current live market price
* countdown to close
* your side
* clear label: “Settlement uses official oracle snapshots”

## Calculating card

Show:

* “Round ended, fetching final oracle price”
* disable confusion by not showing provisional winner too aggressively

## Resolved card

Show:

* locked price
* closed price
* result
* your claimable amount

---

# 7. Oracle and settlement rules

## Required round fields

At minimum:

* `lockedPrice`
* `lockedAt`
* `closedPrice`
* `closedAt`
* `oracleRoundIdAtLock`
* `oracleRoundIdAtClose`
* `oracleUpdatedAtLock`
* `oracleUpdatedAtClose`

## Settlement validation

Before accepting lock/close snapshot:

* oracle response must be nonzero
* timestamp must be recent enough
* feed must be same configured oracle
* `closeAt > lockAt`
* `closedPrice` only written once
* `lockedPrice` only written once

## Tie rule

Do **not** copy Pancake’s “house wins ties” unless you have a strong reason. Pancake treats equal prices as a house-win case. ([PancakeSwap][3])

For RetroPick, better V1 policy is usually:

* **refund both sides minus no fee**, or
* **refund principal and waive treasury fee**

That feels much fairer.

---

# 8. Payout model recommendation

For V1, use **pari-mutuel binary pools**.

Meaning:

* UP pool total = `upTotal`
* DOWN pool total = `downTotal`
* treasury fee deducted once from total pot
* winners share remaining pool pro rata by stake

Formula:

* `netPot = upTotal + downTotal - fee`
* if UP wins, each UP winner gets
  `stake + stake / upTotal * downTotal - proportional fee handling`
* same symmetrically for DOWN

This is simple, transparent, and avoids turning the product into a latency-arbitrage game.

---

# 9. Recommended V1 market lineup

Do **not** launch all assets and all durations at once.

## Best V1 launch

* BTC: 5m, 1h
* ETH: 5m, 1h
* SOL: 1h
* BTC: 1d only after liquidity proves strong

## Why

* 5m gives habit loop
* 1h gives quality
* 1d should be limited to only the strongest asset at first

Too many markets will fragment liquidity and make projected payouts look dead.

---

# 10. My exact product recommendation

## Phase 1

Launch:

* BTC 5m
* ETH 5m
* BTC 1h

This is enough to prove:

* fast play
* serious play
* oracle architecture
* scheduling engine

## Phase 2

Add:

* ETH 1h
* SOL 1h
* BTC 1d

## Phase 3

Add:

* featured event-based daily markets
* advanced analytics
* leaderboards
* market commentary
* vault/LP/liquidity incentive overlays

---

# 11. Suggested end-to-end architecture

## Offchain scheduler / keeper

Responsible for:

* creating future round instances
* triggering lock
* triggering close
* retrying failed automation
* marking cancellation if oracle invalid

## Onchain or core contract

Responsible for:

* custody of stakes
* immutable round state
* result computation
* claims
* fee accounting

## Indexer / API

Responsible for:

* round history
* user PnL
* pool stats
* charts
* upcoming schedule

## Frontend

Responsible for:

* clear phase UX
* time countdowns
* lock/close explanation
* claim UX
* distinction between live chart and official oracle settlement

---

# 12. The cleanest RetroPick timeline spec

## 5m

* Betting: 5m
* Live: 5m
* Calculating: ~20s
* Best for retention

## 1h

* Betting: 30m
* Live: 60m
* Calculating: ~1m
* Best overall product-market fit

## 1d

* Betting: 6h
* Live: 24h
* Calculating: ~5m
* Best for high-conviction premium markets

---

# 13. Final architecture principle

For RetroPick, the best mental model is:

**Every round has one immutable start truth and one immutable end truth.**

That means:

* `lockedPrice` never changes
* `closedPrice` never changes
* no entry after lock
* UI may show live market movement, but settlement only uses oracle snapshots
* longer durations reuse the exact same engine, only with different scheduling parameters

That follows the sound part of Pancake’s design while making the product clearer and more extensible. ([PancakeSwap][1])

I can next turn this into a full **RetroPick technical spec** with:
**contracts/entities, DB schema, API routes, keeper jobs, and frontend round-state UX**.

[1]: https://docs.pancakeswap.finance/play/prediction?utm_source=chatgpt.com "Prediction"
[2]: https://docs.pancakeswap.finance/play/prediction/prediction-guide?utm_source=chatgpt.com "How to Use Prediction"
[3]: https://docs.pancakeswap.finance/play/prediction/prediction-faq?utm_source=chatgpt.com "Prediction FAQ"
