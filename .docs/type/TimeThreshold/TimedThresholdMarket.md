Rule Automation: [Asset] [condition] [threshold rule] at [resolution schedule]

# RetroPick TimedThresholdMarket Docs

## 1. Overview

**TimedThresholdMarket** is a recurring binary market format built from this rule:

**[Asset] [condition] [threshold rule] at [resolution schedule]**

Examples:

* BTC **at or above** **previous daily close** **at today daily close**
* ETH **below** **weekly open** **at this week’s close**
* SOL **at or above** **Monday open** **at Friday close**

This format is designed for:

* repetitive recurring markets
* automatic market creation
* deterministic oracle resolution
* strong discovery-page narratives
* clean daily and weekly calendars

The key idea is that the market does **not** hardcode a fresh threshold manually every time.
Instead, the system derives the threshold from a known rule and a known reference timestamp.

So the product runs as:

**Template → Auto-derived threshold → Market instance → Lock → Resolve**

---

# 2. Core Design Goal

TimedThresholdMarket should solve four problems at once:

1. **Repetitiveness**

   * one template can generate endless daily/weekly/monthly markets

2. **Automation**

   * no manual deployment every day or every week

3. **Clear oracle settlement**

   * settlement uses one threshold and one final oracle price

4. **Narrative discovery**

   * markets are easier to browse than plain UP/DOWN

---

# 3. Market Grammar

## Canonical rule

**[Asset] [condition] [threshold rule] at [resolution schedule]**

## Components

### Asset

The asset whose oracle price will be checked.
Examples:

* BTC
* ETH
* SOL

### Condition

The comparison rule for final settlement.
Recommended values:

* `AT_OR_ABOVE`
* `ABOVE`
* `AT_OR_BELOW`
* `BELOW`

Recommended V1 user-facing wording:

* “at or above”
* “below”

This avoids ambiguity around equality.

### Threshold Rule

How the threshold value is derived.
Examples:

* previous daily close
* today open
* weekly open
* previous week close
* Monday open
* last week high
* last week low
* custom absolute threshold

### Resolution Schedule

When the market resolves.
Examples:

* at today daily close
* at this week’s close
* at Friday close
* at month end

---

# 4. Mental Model

TimedThresholdMarket is built from two layers:

## A. Template

Permanent reusable market logic.

Example:

* Asset = BTC
* Condition = AT_OR_ABOVE
* Threshold Rule = PREVIOUS_DAILY_CLOSE
* Resolution Schedule = DAILY_CLOSE

This template stays active and keeps generating new market instances.

## B. Market Instance

A concrete market generated from the template for one cycle.

Example:

* Market title: BTC at or above 148,200 at today daily close
* Threshold value: 148,200
* Lock at: 23:00 UTC
* Resolve at: 23:59 UTC
* Final result: YES or NO

---

# 5. Product Principles

## 5.1 Immutable threshold

Once an instance is created and threshold is derived, the threshold value must never change.

## 5.2 Immutable close price

The final oracle price used for resolution must be written once and never changed.

## 5.3 No entry after lock

Users can only enter before lock time.

## 5.4 One explicit comparison rule

Each market must clearly define the exact equality behavior.

## 5.5 Strong user labeling

Show both:

* threshold label, such as “weekly open”
* threshold numeric value, such as “3,420”

Do not show only one.

---

# 6. Market Lifecycle

## States

1. `TEMPLATE_ACTIVE`
2. `INSTANCE_SCHEDULED`
3. `BETTING_OPEN`
4. `LOCKED`
5. `LIVE`
6. `CALCULATING`
7. `RESOLVED`
8. `CLAIMABLE`
9. `CANCELLED`
10. `EXPIRED`

## Simplified flow

1. Template exists
2. Scheduler decides next cycle is due
3. Threshold reference timestamp is computed
4. Threshold oracle price is fetched
5. Instance is created
6. Betting opens
7. Betting locks
8. Final oracle price is fetched at resolution time
9. Market resolves
10. Winners claim

---

# 7. Market Resolution Logic

## Variables

* `thresholdValue`
* `finalPrice`
* `condition`

## Recommended V1 resolution rules

### AT_OR_ABOVE

* YES wins if `finalPrice >= thresholdValue`
* NO wins if `finalPrice < thresholdValue`

### BELOW

* YES wins if `finalPrice < thresholdValue`
* NO wins if `finalPrice >= thresholdValue`

This pair is the clearest for users.

## Why this is good

* no tie ambiguity
* deterministic
* simple for frontend
* simple for contract logic

---

# 8. Threshold Rule System

## 8.1 Purpose

Threshold Rule tells the system how to derive a threshold automatically.

## 8.2 Threshold Rule Types

### Relative Reference Rules

Derived from a known past market snapshot.

Examples:

* `PREVIOUS_DAILY_CLOSE`
* `TODAY_OPEN`
* `WEEKLY_OPEN`
* `PREVIOUS_WEEK_CLOSE`
* `MONDAY_OPEN`
* `PREVIOUS_MONTH_CLOSE`

### Relative Range Rules

Derived from prior extrema.

Examples:

* `LAST_WEEK_HIGH`
* `LAST_WEEK_LOW`
* `PREVIOUS_DAY_HIGH`
* `PREVIOUS_DAY_LOW`

### Absolute Rules

Fixed explicit price values.

Examples:

* BTC at or above 150,000 at week close
* ETH below 4,000 at month end

### Derived Numeric Transform Rules

Threshold derived from a reference plus transformation.

Examples:

* above previous daily close + 2%
* above weekly open + 500
* below previous week close - 3%

These are more advanced and better for later versions.

---

# 9. Resolution Schedule System

## Supported schedule types

### Daily

Examples:

* today daily close
* tomorrow daily close

### Weekly

Examples:

* Friday close
* Sunday close
* this week’s close

### Monthly

Examples:

* month end close

## Recommendation for V1

Keep to:

* daily close
* weekly close

That is enough for a strong recurring calendar.

---

# 10. Canonical Template Structure

A template should contain:

* `templateId`
* `asset`
* `condition`
* `thresholdRule`
* `resolutionSchedule`
* `lockOffsetSeconds`
* `oracleFeedId`
* `isActive`
* `titleFormat`
* `descriptionFormat`
* `minStake`
* `maxStake`
* `feeBps`

Example template:

* asset = BTC
* condition = AT_OR_ABOVE
* thresholdRule = PREVIOUS_DAILY_CLOSE
* resolutionSchedule = DAILY_CLOSE
* lockOffsetSeconds = 3600
* oracleFeedId = BTC/USD
* isActive = true

---

# 11. Canonical Market Instance Structure

Each generated instance should contain:

* `marketId`
* `templateId`
* `asset`
* `condition`
* `thresholdRule`
* `thresholdLabel`
* `thresholdValue`
* `thresholdReferenceAt`
* `thresholdOracleRoundId`
* `betOpenAt`
* `lockAt`
* `resolveAt`
* `finalPrice`
* `finalPriceAt`
* `finalOracleRoundId`
* `status`
* `yesPool`
* `noPool`
* `result`
* `createdAt`

Optional:

* `humanTitle`
* `humanSubtitle`
* `marketCycleKey`

---

# 12. Template Rendering

## Human-readable title generation

Format:
**[Asset] [condition text] [threshold label/value] at [resolution text]**

Examples:

* BTC at or above previous daily close at today close
* ETH below weekly open at this week’s close
* SOL at or above 182.4 at today close

## Better frontend style

Display both label and value:

**BTC at or above previous daily close by today close**
Previous daily close: **148,200**

This is best for clarity.

---

# 13. Automation Architecture

## Components

### A. Template Registry

Stores active templates.

### B. Scheduler / Instance Generator

Creates market instances when a new cycle starts.

### C. Threshold Oracle Reader

Fetches oracle price for threshold reference timestamp.

### D. Resolver

Fetches final oracle price and resolves the market.

### E. Indexer / API

Serves markets to frontend.

### F. Frontend

Discovery, detail page, betting, claim flow.

---

# 14. Automation Flow

## 14.1 Template registration

Operator or governance registers template once.

## 14.2 Cycle detection

System checks whether a new cycle for a template needs a market instance.

## 14.3 Threshold reference timestamp derivation

System computes the exact timestamp for threshold derivation.

## 14.4 Threshold fetch

Oracle value is fetched for that reference point.

## 14.5 Instance creation

System creates market instance with fixed threshold value.

## 14.6 Betting open

Users can enter YES or NO.

## 14.7 Lock

Entry disabled.

## 14.8 Resolve

Final oracle value fetched at resolution schedule.

## 14.9 Claim

Users claim winnings.

---

# 15. Automation Jobs

## Job 1: Template cycle scanner

Runs periodically and checks:

* active templates
* current cycle
* whether instance exists for that cycle

### Output

Creates missing instance if needed.

## Job 2: Threshold derivation job

For a template cycle:

* compute threshold reference timestamp
* fetch oracle price
* store threshold

### Output

Threshold-ready instance.

## Job 3: Betting transition job

Switches state to `BETTING_OPEN` when time arrives.

## Job 4: Lock job

At `lockAt`:

* stops new entries
* sets market to `LOCKED` or `LIVE`

## Job 5: Resolve job

At `resolveAt`:

* fetch final oracle price
* apply comparison rule
* write result

## Job 6: Cancellation / safety job

Cancels if:

* oracle unavailable
* stale oracle
* threshold missing
* invalid timestamps
* duplicate cycle issue

---

# 16. Reference Timestamp Derivation

This is the most important automation rule.

## PREVIOUS_DAILY_CLOSE

For market resolving at today close:

* threshold reference = yesterday close

## TODAY_OPEN

For market resolving at today close:

* threshold reference = today open

## WEEKLY_OPEN

For market resolving at weekly close:

* threshold reference = this week’s Monday open

## PREVIOUS_WEEK_CLOSE

For weekly market:

* threshold reference = previous week close

## MONDAY_OPEN

For Friday close or Sunday close weekly market:

* threshold reference = Monday open of same week

## PREVIOUS_MONTH_CLOSE

For monthly market:

* threshold reference = previous month’s close

---

# 17. Time Rules

## Daily template example

* betOpenAt = today 00:05 UTC
* lockAt = today 23:00 UTC
* resolveAt = today 23:59 UTC

## Weekly template example

* betOpenAt = Monday 00:05 UTC
* lockAt = Sunday 18:00 UTC
* resolveAt = Sunday 23:59 UTC

## Best V1 guidance

* daily lock: 1 hour before close
* weekly lock: 6 hours before close

This prevents last-minute sniping.

---

# 18. Oracle Requirements

The oracle system should provide:

* reliable asset price
* timestamped data
* consistent reference feed
* ability to use the same feed for threshold and final resolution

Each market instance should store:

* oracle feed ID
* threshold oracle round identifier if available
* final oracle round identifier if available
* timestamps for both reads

---

# 19. Oracle Validation Rules

Before writing threshold:

* oracle response must exist
* timestamp must be valid
* value must be nonzero
* reference timestamp must match expected schedule window

Before writing final resolution:

* oracle response must exist
* timestamp must be valid
* response must be recent enough for resolution schedule
* final price must be written once only

If checks fail:

* market should be cancellable/refundable

---

# 20. User Flow

## 20.1 Discovery page

User sees recurring markets grouped by:

* Today
* This Week
* Ending Soon
* Featured Thresholds

Each card shows:

* title
* current price
* threshold label
* threshold value
* distance to threshold
* countdown
* YES pool
* NO pool

## 20.2 Market detail page

User sees:

* title
* explanation
* chart with threshold line
* current price
* threshold label and value
* lock time
* resolve time
* rule text

## 20.3 Betting flow

User selects:

* YES
* NO

Then:

* enters stake
* reviews projected payout
* confirms transaction

## 20.4 Locked/live flow

User sees:

* threshold fixed
* current price relative to threshold
* time remaining
* market cannot be entered anymore

## 20.5 Resolution flow

User sees:

* final oracle price
* threshold value
* result
* claimable rewards

---

# 21. UX Copy Rules

Always explain the rule in plain language.

Example:

* “YES wins if the final oracle price is at or above 148,200 at today’s close.”

For below markets:

* “YES wins if the final oracle price is below 148,200 at today’s close.”

Never rely only on hidden documentation.

---

# 22. Discovery Design Strategy

TimedThresholdMarket is especially strong for discovery pages because users understand the story.

## Good discovery categories

* Today’s Key Levels
* Weekly Breakout Watch
* Above Yesterday Close
* Below Weekly Open
* Ending Soon
* Almost There

## Good card framing

* BTC at or above weekly open by Sunday
* Current: 147,800
* Threshold: 148,200
* Need: +0.27%
* Ends in: 2d 4h

This is far more compelling than generic directional-only cards.

---

# 23. Market Possibility Matrix

## 23.1 Daily possibilities

| Asset | Condition   |       Threshold Rule | Resolution Schedule | Example                                             |
| ----- | ----------- | -------------------: | ------------------- | --------------------------------------------------- |
| BTC   | AT_OR_ABOVE | PREVIOUS_DAILY_CLOSE | DAILY_CLOSE         | BTC at or above previous daily close at today close |
| BTC   | BELOW       | PREVIOUS_DAILY_CLOSE | DAILY_CLOSE         | BTC below previous daily close at today close       |
| ETH   | AT_OR_ABOVE |           TODAY_OPEN | DAILY_CLOSE         | ETH at or above today open at today close           |
| SOL   | BELOW       |           TODAY_OPEN | DAILY_CLOSE         | SOL below today open at today close                 |
| BTC   | AT_OR_ABOVE |    PREVIOUS_DAY_HIGH | DAILY_CLOSE         | BTC at or above previous day high at today close    |
| ETH   | BELOW       |     PREVIOUS_DAY_LOW | DAILY_CLOSE         | ETH below previous day low at today close           |

## 23.2 Weekly possibilities

| Asset | Condition   |      Threshold Rule | Resolution Schedule | Example                                                  |
| ----- | ----------- | ------------------: | ------------------- | -------------------------------------------------------- |
| BTC   | AT_OR_ABOVE |         WEEKLY_OPEN | WEEKLY_CLOSE        | BTC at or above weekly open at this week’s close         |
| ETH   | AT_OR_ABOVE |         WEEKLY_OPEN | WEEKLY_CLOSE        | ETH at or above weekly open at this week’s close         |
| SOL   | BELOW       |         WEEKLY_OPEN | WEEKLY_CLOSE        | SOL below weekly open at this week’s close               |
| BTC   | AT_OR_ABOVE | PREVIOUS_WEEK_CLOSE | WEEKLY_CLOSE        | BTC at or above previous week close at this week’s close |
| ETH   | BELOW       |      LAST_WEEK_HIGH | WEEKLY_CLOSE        | ETH below last week high at this week’s close            |
| SOL   | AT_OR_ABOVE |       LAST_WEEK_LOW | WEEKLY_CLOSE        | SOL at or above last week low at this week’s close       |

## 23.3 Monthly possibilities

| Asset | Condition   |       Threshold Rule | Resolution Schedule | Example                                           |
| ----- | ----------- | -------------------: | ------------------- | ------------------------------------------------- |
| BTC   | AT_OR_ABOVE | PREVIOUS_MONTH_CLOSE | MONTH_END           | BTC at or above previous month close at month end |
| ETH   | BELOW       |           MONTH_OPEN | MONTH_END           | ETH below month open at month end                 |
| SOL   | AT_OR_ABOVE |  PREVIOUS_MONTH_HIGH | MONTH_END           | SOL at or above previous month high at month end  |

## 23.4 Absolute threshold possibilities

| Asset | Condition   | Threshold Rule | Resolution Schedule | Example                                      |
| ----- | ----------- | -------------: | ------------------- | -------------------------------------------- |
| BTC   | AT_OR_ABOVE |  ABSOLUTE_150K | WEEKLY_CLOSE        | BTC at or above 150,000 at this week’s close |
| ETH   | BELOW       |  ABSOLUTE_4000 | MONTH_END           | ETH below 4,000 at month end                 |

## 23.5 Transformed threshold possibilities

| Asset | Condition   |                 Threshold Rule | Resolution Schedule | Example                                                 |
| ----- | ----------- | -----------------------------: | ------------------- | ------------------------------------------------------- |
| BTC   | AT_OR_ABOVE | PREVIOUS_DAILY_CLOSE_PLUS_2PCT | DAILY_CLOSE         | BTC at or above previous daily close +2% at today close |
| ETH   | BELOW       |         WEEKLY_OPEN_MINUS_1PCT | WEEKLY_CLOSE        | ETH below weekly open -1% at this week’s close          |

---

# 24. Best V1 Template Set

## Best minimal daily set

* BTC at or above previous daily close at today close
* ETH at or above previous daily close at today close
* SOL at or above previous daily close at today close

## Best minimal weekly set

* BTC at or above weekly open at this week’s close
* ETH at or above weekly open at this week’s close

## Why this is best

* repetitive
* understandable
* easily automated
* always relevant
* clean oracle logic
* good discovery surface

---

# 25. V1 vs Later Possibilities

## V1

Use only:

* relative reference thresholds
* daily close
* weekly close
* simple yes/no pari-mutuel pools

## V2

Add:

* below templates
* previous week close
* Monday open
* transformed thresholds
* monthly schedules
* editorial featured thresholds

## V3

Add:

* user-personalized market feeds
* AI-selected editorial thresholds
* event-linked thresholds
* liquidity programs per template family

---

# 26. Payout Design

For V1, best to use simple pari-mutuel pools:

* YES pool
* NO pool

At resolution:

* winners split loser pool pro rata
* fee optional
* claims deterministic

This keeps the market engine simple.

---

# 27. Failure Handling

## Cancel conditions

* missing threshold
* invalid threshold timestamp
* oracle unavailable
* invalid final oracle response
* duplicated instance for same cycle
* scheduler failed and market missed required setup

## Refund policy

Safest V1 policy:

* full refund to all participants
* no fee collected

---

# 28. API Suggestions

## Template endpoints

* `GET /templates`
* `POST /templates`
* `PATCH /templates/:id`
* `GET /templates/:id/instances`

## Market instance endpoints

* `GET /markets`
* `GET /markets/:id`
* `GET /markets?status=betting_open`
* `GET /markets?group=daily`
* `GET /markets?group=weekly`

## User endpoints

* `POST /markets/:id/position`
* `GET /users/:address/positions`
* `POST /markets/:id/claim`

---

# 29. Suggested Database Shapes

## Template

* id
* asset
* condition
* threshold_rule
* resolution_schedule
* lock_offset_seconds
* oracle_feed_id
* title_format
* active
* created_at
* updated_at

## MarketInstance

* id
* template_id
* cycle_key
* asset
* threshold_label
* threshold_value
* threshold_reference_at
* threshold_oracle_round_id
* bet_open_at
* lock_at
* resolve_at
* final_price
* final_price_at
* final_oracle_round_id
* status
* result
* yes_pool
* no_pool
* created_at

## Position

* id
* market_id
* user_address
* side
* amount
* claimed
* created_at

---

# 30. Example Templates

## Example 1

**BTC at or above previous daily close at today close**

* asset = BTC
* condition = AT_OR_ABOVE
* thresholdRule = PREVIOUS_DAILY_CLOSE
* resolutionSchedule = DAILY_CLOSE
* lockOffset = 1 hour

## Example 2

**ETH at or above weekly open at this week’s close**

* asset = ETH
* condition = AT_OR_ABOVE
* thresholdRule = WEEKLY_OPEN
* resolutionSchedule = WEEKLY_CLOSE
* lockOffset = 6 hours

## Example 3

**SOL below Monday open at Friday close**

* asset = SOL
* condition = BELOW
* thresholdRule = MONDAY_OPEN
* resolutionSchedule = FRIDAY_CLOSE
* lockOffset = 4 hours

---

# 31. Recommended Naming Standard

Internal enum-friendly format:

* `BTC_AT_OR_ABOVE_PREVIOUS_DAILY_CLOSE_AT_DAILY_CLOSE`
* `ETH_AT_OR_ABOVE_WEEKLY_OPEN_AT_WEEKLY_CLOSE`
* `SOL_BELOW_MONDAY_OPEN_AT_FRIDAY_CLOSE`

User-facing format:

* BTC at or above previous daily close by today close
* ETH at or above weekly open by this week’s close
* SOL below Monday open by Friday close

---

# 32. Why This Market Type Is Strong

TimedThresholdMarket gives RetroPick a recurring, scalable, story-rich market layer.

It is strong because it combines:

* deterministic automation
* simple oracle resolution
* reusable templates
* meaningful market headlines
* cleaner discovery UX than plain directional markets

It is likely the best recurring non-event market format for daily and weekly calendars.

---

# 33. Final Recommendation

For RetroPick V1, define TimedThresholdMarket as:

**A recurring binary market generated from a reusable template where a threshold is derived from a deterministic reference rule and resolved by comparing the final oracle price at a scheduled time against that threshold.**

Start with this minimal set:

### Daily

* BTC at or above previous daily close at today close
* ETH at or above previous daily close at today close
* SOL at or above previous daily close at today close

### Weekly

* BTC at or above weekly open at this week’s close
* ETH at or above weekly open at this week’s close

That gives you:

* no manual redeployment
* strong automation
* recurring discovery content
* clean settlement logic

I can turn this next into a **contract-level spec** with enums, structs, scheduler pseudocode, and Solidity or Anchor-style schema.
