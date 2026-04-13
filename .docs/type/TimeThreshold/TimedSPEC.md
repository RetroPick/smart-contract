# RetroPick TimedThresholdMarket

## Oracle-Integrated Contract Spec

This version extends the previous docs so that:

* **threshold rule** is derived from an **oracle price at a reference timestamp**
* **resolution schedule** is settled using an **oracle price at a scheduled close timestamp**
* both threshold and settlement are **time-bound, auditable, and deterministic**

---

# 1. Core Rule

TimedThresholdMarket uses this grammar:

**[Asset] [condition] [threshold rule] at [resolution schedule]**

But internally, the full rule becomes:

**[Asset] [condition] [oracle-derived threshold price from reference timestamp] at [oracle-derived final price from resolution timestamp]**

So every market instance has **two important oracle checkpoints**:

1. **Threshold checkpoint**

   * used to compute the threshold value
   * example: previous daily close price

2. **Resolution checkpoint**

   * used to compute the final settlement price
   * example: today daily close price

---

# 2. Core Idea

For recurring markets, you do **not** manually set:

* threshold price
* threshold date
* final close date

Instead, the system derives all of them from the template.

## Example

Template:

* Asset: BTC
* Condition: AT_OR_ABOVE
* Threshold Rule: PREVIOUS_DAILY_CLOSE
* Resolution Schedule: DAILY_CLOSE

Generated instance:

* Threshold reference time = 2026-03-17 23:59 UTC
* Threshold oracle price = 148,200
* Resolution time = 2026-03-18 23:59 UTC
* Final oracle price = read at close
* YES wins if `finalPrice >= 148,200`

---

# 3. Oracle-Driven Market Architecture

Each market instance should always store:

## Threshold-side oracle data

* `thresholdReferenceTimestamp`
* `thresholdOraclePrice`
* `thresholdOraclePublishedAt`
* `thresholdOracleRoundId` if available
* `thresholdRule`

## Resolution-side oracle data

* `resolutionTimestamp`
* `finalOraclePrice`
* `finalOraclePublishedAt`
* `finalOracleRoundId` if available
* `resolutionSchedule`

This is the minimum needed for full traceability.

---

# 4. Market Template Model

A template should define the recurring logic only.

## TimedThresholdTemplate

```text
templateId
asset
oracleFeedId
condition
thresholdRule
resolutionSchedule
referenceTimezone
lockOffsetSeconds
minStake
maxStake
feeBps
isActive
```

## Example

```text
templateId: BTC_DAILY_ABOVE_PREV_CLOSE
asset: BTC
oracleFeedId: BTC/USD
condition: AT_OR_ABOVE
thresholdRule: PREVIOUS_DAILY_CLOSE
resolutionSchedule: DAILY_CLOSE
referenceTimezone: UTC
lockOffsetSeconds: 3600
isActive: true
```

---

# 5. Market Instance Model

A market instance is generated from a template for one cycle.

## TimedThresholdMarketInstance

```text
marketId
templateId
asset
oracleFeedId

condition
thresholdRule
resolutionSchedule

cycleStartAt
cycleEndAt

thresholdReferenceTimestamp
thresholdOraclePrice
thresholdOraclePublishedAt
thresholdOracleRoundId

betOpenAt
lockAt
resolveAt

finalOraclePrice
finalOraclePublishedAt
finalOracleRoundId

status
result

yesPool
noPool

createdAt
resolvedAt
```

---

# 6. Oracle Price Integration Model

You should treat the oracle as the **source of truth** for both:

* threshold derivation
* final settlement

## Market generation rule

At instance creation time:

* compute the threshold reference timestamp from `thresholdRule`
* fetch oracle price corresponding to that timestamp
* store that oracle price as `thresholdOraclePrice`

## Settlement rule

At resolution time:

* fetch oracle price corresponding to `resolveAt`
* store as `finalOraclePrice`
* compare against `thresholdOraclePrice`

---

# 7. Threshold Rule with Oracle Time

This is the most important concept.

A threshold rule is not just a label.
It must map to a deterministic timestamp rule.

## Example mapping

### PREVIOUS_DAILY_CLOSE

Meaning:

* threshold is oracle price at previous daily close timestamp

If market resolves at:

* 2026-03-18 23:59 UTC

then:

* threshold reference timestamp = 2026-03-17 23:59 UTC

### TODAY_OPEN

Meaning:

* threshold is oracle price at today open timestamp

If market resolves at:

* 2026-03-18 23:59 UTC

then:

* threshold reference timestamp = 2026-03-18 00:00 UTC

### WEEKLY_OPEN

If market resolves at:

* Sunday 2026-03-22 23:59 UTC

then:

* threshold reference timestamp = Monday 2026-03-16 00:00 UTC

### PREVIOUS_WEEK_CLOSE

If market resolves at:

* Sunday 2026-03-22 23:59 UTC

then:

* threshold reference timestamp = Sunday 2026-03-15 23:59 UTC

### MONDAY_OPEN

If market resolves at:

* Friday 2026-03-20 23:59 UTC

then:

* threshold reference timestamp = Monday 2026-03-16 00:00 UTC

---

# 8. Resolution Schedule with Oracle Time

Resolution schedule must also map to a deterministic timestamp.

## Example mapping

### DAILY_CLOSE

* resolveAt = that day at 23:59 UTC

### WEEKLY_CLOSE

* resolveAt = Sunday 23:59 UTC

### FRIDAY_CLOSE

* resolveAt = Friday 23:59 UTC

### MONTH_END

* resolveAt = final day of month at 23:59 UTC

At `resolveAt`, the system reads the oracle and stores:

* `finalOraclePrice`
* `finalOraclePublishedAt`
* `finalOracleRoundId`

---

# 9. Resolution Logic

## Recommended conditions

### AT_OR_ABOVE

YES wins if:

```text
finalOraclePrice >= thresholdOraclePrice
```

### BELOW

YES wins if:

```text
finalOraclePrice < thresholdOraclePrice
```

This keeps equality behavior explicit.

---

# 10. Oracle Read Modes

There are two practical ways to integrate oracle prices.

## Mode A — Exact round/timestamp lookup

Best if oracle supports historical lookup or round-based access.

Use:

* reference timestamp → find matching oracle round
* resolution timestamp → find matching oracle round

Pros:

* strongest auditability
* deterministic
* easy to prove which oracle update was used

Cons:

* depends on oracle interface

## Mode B — First valid update at or after checkpoint

Use if oracle only provides current/latest updates around schedule boundaries.

Rule:

* at threshold checkpoint, capture first valid oracle update after reference boundary
* at resolution checkpoint, capture first valid oracle update after resolution boundary

Pros:

* easier operationally
* works with more systems

Cons:

* slightly more implementation nuance

## Recommendation

For V1, define a strict market rule:

**“The official price is the first valid oracle update at or after the scheduled reference timestamp, within the allowed staleness window.”**

That is clean and implementable.

---

# 11. Required Oracle Fields

For every threshold and final read, store:

```text
price
publishedAt
oracleRoundId (if available)
feedId
readMode
referenceTimestamp
```

This is useful for:

* dispute minimization
* frontend transparency
* indexers
* auditing

---

# 12. Oracle Validation Rules

## Threshold read validation

Before writing threshold:

* oracle response exists
* price > 0
* published timestamp exists
* published timestamp is within allowed window
* feed matches market asset
* threshold has not already been written

## Final resolution validation

Before resolving:

* oracle response exists
* price > 0
* published timestamp exists
* published timestamp is within allowed window
* final price has not already been written
* market is in correct pre-resolution state

---

# 13. Staleness Policy

Oracle reads must follow staleness rules.

## Example

For daily/weekly threshold markets:

* allow a short tolerance window around checkpoint
* reject responses that are too stale

## Suggested stored params

```text
maxOracleDelaySeconds
minOracleTimestamp
maxOracleTimestamp
```

## Example policy

For a 23:59 UTC close:

* acceptable oracle publication window = 23:59:00 to 00:05:00 UTC
* if no valid update appears, market becomes cancellable or delayed under policy

---

# 14. Recommended Oracle Settlement Policy

Use this rule consistently:

## Threshold

**Threshold price = first valid oracle update at or after thresholdReferenceTimestamp**

## Resolution

**Final price = first valid oracle update at or after resolveAt**

This removes ambiguity around “exact second” matching.

---

# 15. Full Market Lifecycle

## 1. Template active

Template exists in registry.

## 2. Cycle detected

Scheduler determines a new daily/weekly cycle needs an instance.

## 3. Compute timestamps

System computes:

* thresholdReferenceTimestamp
* betOpenAt
* lockAt
* resolveAt

## 4. Read threshold oracle price

System fetches first valid oracle update for threshold checkpoint.

## 5. Create market instance

Threshold gets written permanently.

## 6. Betting opens

Users enter YES or NO.

## 7. Lock

No more entries.

## 8. Resolve

At resolution schedule, system reads final oracle price.

## 9. Compare

Condition applied against threshold.

## 10. Claim

Winners claim.

---

# 16. Suggested Enums

## Condition

```text
AT_OR_ABOVE
BELOW
```

## ThresholdRule

```text
PREVIOUS_DAILY_CLOSE
TODAY_OPEN
WEEKLY_OPEN
PREVIOUS_WEEK_CLOSE
MONDAY_OPEN
PREVIOUS_MONTH_CLOSE
LAST_WEEK_HIGH
LAST_WEEK_LOW
ABSOLUTE
```

## ResolutionSchedule

```text
DAILY_CLOSE
WEEKLY_CLOSE
FRIDAY_CLOSE
MONTH_END
CUSTOM_TIMESTAMP
```

## MarketStatus

```text
SCHEDULED
BETTING_OPEN
LOCKED
LIVE
CALCULATING
RESOLVED
CANCELLED
EXPIRED
```

## OracleReadMode

```text
FIRST_VALID_AFTER_TIMESTAMP
EXACT_ROUND
EXACT_TIMESTAMP_MATCH
```

Recommended V1:

```text
FIRST_VALID_AFTER_TIMESTAMP
```

---

# 17. Derived Timestamp Engine

This is the automation brain.

## Function

```text
deriveThresholdReferenceTimestamp(thresholdRule, resolveAt)
deriveResolutionTimestamp(resolutionSchedule, cycleKey)
```

## Example outputs

| Threshold Rule       |           Resolve At | Threshold Reference Timestamp |
| -------------------- | -------------------: | ----------------------------: |
| PREVIOUS_DAILY_CLOSE | 2026-03-18 23:59 UTC |          2026-03-17 23:59 UTC |
| TODAY_OPEN           | 2026-03-18 23:59 UTC |          2026-03-18 00:00 UTC |
| WEEKLY_OPEN          | 2026-03-22 23:59 UTC |          2026-03-16 00:00 UTC |
| PREVIOUS_WEEK_CLOSE  | 2026-03-22 23:59 UTC |          2026-03-15 23:59 UTC |
| MONDAY_OPEN          | 2026-03-20 23:59 UTC |          2026-03-16 00:00 UTC |

---

# 18. Automation Jobs

## Job A — Cycle generator

For each active template:

* determine current cycle key
* determine resolveAt
* determine thresholdReferenceTimestamp
* if no instance exists, create one

## Job B — Threshold oracle capture

* query oracle around thresholdReferenceTimestamp
* validate response
* write thresholdOraclePrice

## Job C — Betting state transition

* open market at betOpenAt

## Job D — Lock transition

* close new entries at lockAt

## Job E — Final oracle capture

* query oracle around resolveAt
* validate response
* write finalOraclePrice

## Job F — Resolver

* apply comparison
* mark result
* set resolvedAt

## Job G — Safety fallback

* cancel or delay if no valid oracle price appears inside policy window

---

# 19. Contract-Level Pseudocode

## Template creation

```text
createTemplate(
  asset,
  oracleFeedId,
  condition,
  thresholdRule,
  resolutionSchedule,
  lockOffsetSeconds
)
```

## Instance generation

```text
generateInstance(template, cycleKey):
  resolveAt = deriveResolutionTimestamp(template.resolutionSchedule, cycleKey)
  thresholdReferenceTimestamp = deriveThresholdReferenceTimestamp(template.thresholdRule, resolveAt)
  thresholdOracle = readOracle(template.oracleFeedId, thresholdReferenceTimestamp)

  assert thresholdOracle.valid

  market.thresholdOraclePrice = thresholdOracle.price
  market.thresholdOraclePublishedAt = thresholdOracle.publishedAt
  market.thresholdOracleRoundId = thresholdOracle.roundId
  market.resolveAt = resolveAt
  market.lockAt = resolveAt - template.lockOffsetSeconds
  market.betOpenAt = deriveBetOpenAt(template, cycleKey)
```

## Resolution

```text
resolveMarket(market):
  finalOracle = readOracle(market.oracleFeedId, market.resolveAt)
  assert finalOracle.valid

  market.finalOraclePrice = finalOracle.price
  market.finalOraclePublishedAt = finalOracle.publishedAt
  market.finalOracleRoundId = finalOracle.roundId

  if market.condition == AT_OR_ABOVE:
      market.result = YES if finalOracle.price >= market.thresholdOraclePrice else NO

  if market.condition == BELOW:
      market.result = YES if finalOracle.price < market.thresholdOraclePrice else NO

  market.status = RESOLVED
```

---

# 20. Suggested Storage Schema

## Template

```text
id
asset
oracle_feed_id
condition
threshold_rule
resolution_schedule
lock_offset_seconds
max_oracle_delay_seconds
active
created_at
updated_at
```

## MarketInstance

```text
id
template_id
cycle_key

asset
oracle_feed_id
condition
threshold_rule
resolution_schedule

bet_open_at
lock_at
resolve_at

threshold_reference_timestamp
threshold_oracle_price
threshold_oracle_published_at
threshold_oracle_round_id

final_oracle_price
final_oracle_published_at
final_oracle_round_id

status
result

yes_pool
no_pool

created_at
resolved_at
```

---

# 21. Frontend Data Model

Each market card should show:

* asset
* condition text
* threshold label
* threshold numeric value
* threshold reference time
* resolve time
* current live price
* distance to threshold
* YES/NO pools
* status

Example:

**BTC at or above previous daily close by today close**
Previous daily close: **148,200**
Reference timestamp: **2026-03-17 23:59 UTC**
Settlement timestamp: **2026-03-18 23:59 UTC**

This makes the oracle timing legible to the user.

---

# 22. Recommended UX Copy

Always show these two lines:

* **Threshold source:** Previous daily close
* **Threshold value:** 148,200
* **Reference timestamp:** 2026-03-17 23:59 UTC
* **Settlement timestamp:** 2026-03-18 23:59 UTC

And rule explanation:

* **YES wins if the official oracle price at settlement is at or above 148,200.**

This is crucial for trust.

---

# 23. Market Possibilities Table

## Daily Oracle-Based Threshold Markets

| Asset | Condition   | Threshold Rule       | Threshold Oracle Time                             | Resolution Schedule | Resolution Oracle Time | Example                                             |
| ----- | ----------- | -------------------- | ------------------------------------------------- | ------------------- | ---------------------- | --------------------------------------------------- |
| BTC   | AT_OR_ABOVE | PREVIOUS_DAILY_CLOSE | Yesterday 23:59 UTC                               | DAILY_CLOSE         | Today 23:59 UTC        | BTC at or above previous daily close at today close |
| ETH   | AT_OR_ABOVE | TODAY_OPEN           | Today 00:00 UTC                                   | DAILY_CLOSE         | Today 23:59 UTC        | ETH at or above today open at today close           |
| SOL   | BELOW       | PREVIOUS_DAILY_CLOSE | Yesterday 23:59 UTC                               | DAILY_CLOSE         | Today 23:59 UTC        | SOL below previous daily close at today close       |
| BTC   | AT_OR_ABOVE | PREVIOUS_DAY_HIGH    | Yesterday daily high timestamp/derived checkpoint | DAILY_CLOSE         | Today 23:59 UTC        | BTC at or above previous day high at today close    |

## Weekly Oracle-Based Threshold Markets

| Asset | Condition   | Threshold Rule      | Threshold Oracle Time     | Resolution Schedule | Resolution Oracle Time | Example                                            |
| ----- | ----------- | ------------------- | ------------------------- | ------------------- | ---------------------- | -------------------------------------------------- |
| BTC   | AT_OR_ABOVE | WEEKLY_OPEN         | Monday 00:00 UTC          | WEEKLY_CLOSE        | Sunday 23:59 UTC       | BTC at or above weekly open at this week’s close   |
| ETH   | AT_OR_ABOVE | WEEKLY_OPEN         | Monday 00:00 UTC          | WEEKLY_CLOSE        | Sunday 23:59 UTC       | ETH at or above weekly open at this week’s close   |
| SOL   | BELOW       | PREVIOUS_WEEK_CLOSE | Previous Sunday 23:59 UTC | WEEKLY_CLOSE        | Sunday 23:59 UTC       | SOL below previous week close at this week’s close |
| BTC   | AT_OR_ABOVE | MONDAY_OPEN         | Monday 00:00 UTC          | FRIDAY_CLOSE        | Friday 23:59 UTC       | BTC at or above Monday open at Friday close        |

## Monthly Oracle-Based Threshold Markets

| Asset | Condition   | Threshold Rule       | Threshold Oracle Time     | Resolution Schedule | Resolution Oracle Time      | Example                                           |
| ----- | ----------- | -------------------- | ------------------------- | ------------------- | --------------------------- | ------------------------------------------------- |
| BTC   | AT_OR_ABOVE | PREVIOUS_MONTH_CLOSE | Prior month end 23:59 UTC | MONTH_END           | Current month end 23:59 UTC | BTC at or above previous month close at month end |
| ETH   | BELOW       | MONTH_OPEN           | Month start 00:00 UTC     | MONTH_END           | Month end 23:59 UTC         | ETH below month open at month end                 |

---

# 24. Best V1 Oracle-Integrated Templates

## Daily

* BTC at or above previous daily close at today close
* ETH at or above previous daily close at today close
* SOL at or above previous daily close at today close

## Weekly

* BTC at or above weekly open at this week’s close
* ETH at or above weekly open at this week’s close

Why these are strongest:

* deterministic timestamps
* threshold easy to derive
* threshold intuitive to explain
* final settlement easy to audit
* zero need for manual weekly deployment

---

# 25. Recommended Engineering Policy

For RetroPick V1, define this hard rule:

## Threshold policy

**Threshold value is the first valid oracle price update at or after the threshold reference timestamp.**

## Resolution policy

**Final value is the first valid oracle price update at or after the resolution timestamp.**

## Market result

* AT_OR_ABOVE: YES if final >= threshold
* BELOW: YES if final < threshold

This policy is simple, auditable, and scalable.

---

# 26. Final Definition

**TimedThresholdMarket** is a recurring binary oracle market where:

* a reusable template defines the asset, condition, threshold rule, and resolution schedule
* the threshold is automatically derived from a timestamped oracle price according to the threshold rule
* the final outcome is determined by comparing a timestamped oracle price at the resolution schedule against that threshold

So the full implementation formula becomes:

**[Asset] [condition] [oracle price derived from threshold rule timestamp] at [oracle price derived from resolution schedule timestamp]**

That is the cleanest architecture for recurring daily and weekly RetroPick markets.

I can turn this next into either:

1. **Solidity structs + interfaces**, or
2. **full backend scheduler + DB schema + API routes**
