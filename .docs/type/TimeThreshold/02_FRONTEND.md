20. User Flow
20.1 Discovery page
User sees recurring markets grouped by:

Today
This Week
Ending Soon
Featured Thresholds
Each card shows:

title
current price
threshold label
threshold value
distance to threshold
countdown
YES pool
NO pool
20.2 Market detail page
User sees:

title
explanation
chart with threshold line
current price
threshold label and value
lock time
resolve time
rule text
20.3 Betting flow
User selects:

YES
NO
Then:

enters stake
reviews projected payout
confirms transaction
20.4 Locked/live flow
User sees:

threshold fixed
current price relative to threshold
time remaining
market cannot be entered anymore
20.5 Resolution flow
User sees:

final oracle price
threshold value
result
claimable rewards
21. UX Copy Rules
Always explain the rule in plain language.

Example:

“YES wins if the final oracle price is at or above 148,200 at today’s close.”
For below markets:

“YES wins if the final oracle price is below 148,200 at today’s close.”
Never rely only on hidden documentation.

22. Discovery Design Strategy
TimedThresholdMarket is especially strong for discovery pages because users understand the story.

Good discovery categories
Today’s Key Levels
Weekly Breakout Watch
Above Yesterday Close
Below Weekly Open
Ending Soon
Almost There
Good card framing
BTC at or above weekly open by Sunday
Current: 147,800
Threshold: 148,200
Need: +0.27%
Ends in: 2d 4h
This is far more compelling than generic directional-only cards.

Absolutely — for **RetroPick Discovery Page / Markets**, the right mental model is:

**Polymarket / Kalshi market browsing UX**
**+**
**crypto-native recurring market calendar**
**+**
**RetroPick’s deterministic threshold stories**

So this page should **not** feel like:

* a raw table of contracts
* a generic sportsbook lobby
* a DEX token screener
* a gambling timer wall

It should feel like:

> **a curated market directory where users can scan narratives, understand rules instantly, and enter recurring markets fast**

And because RetroPick V1 is **not** a full exchange, discovery must do more work than on Polymarket/Kalshi:

* explain the market faster
* reduce ambiguity more aggressively
* group markets more intelligently
* compensate for lower market variety with stronger presentation

That also matches your V1 spec: **small curated catalog**, **clear market cards**, **visible oracle data**, and a product that looks like a real market system rather than a timer game.

---

# RetroPick Frontend Docs

# Discovery Page / Markets

## Product + UX + Frontend Specification

---

# 1. Page purpose

## Primary goal

Help the user quickly find **understandable, relevant, recurring markets** and answer four questions without opening the detail page:

1. what is the market asking?
2. what does YES mean?
3. how far is price from the threshold?
4. when does it end?

This is the single most important discovery-page principle.

## Secondary goals

* create a **daily habit loop**
* make recurring markets feel like **living stories**
* support **fast scanning across categories**
* surface a **small but rich launch catalog**
* route users cleanly into market detail or quick-bet flow

Because RetroPick V1 launches as a focused oracle-settled event-contract product, the discovery page is effectively the **main exchange surface** for users, even though V1 does not have secondary trading.

---

# 2. Discovery page product positioning

## 2.1 What it should feel like

The page should combine three UX patterns:

### A. Polymarket / Kalshi

For:

* market-style browsing
* confidence and seriousness
* category navigation
* event-card readability
* clean scanning

### B. crypto market terminal

For:

* live price context
* threshold distance
* asset familiarity
* recurring market rhythm

### C. editorial market homepage

For:

* featured stories
* category framing
* “Today” / “This Week” mental organization
* curated launch experience

## 2.2 What it should not feel like

It should not feel like:

* a giant list of all contracts
* a token watchlist
* a casino tile grid
* a pure trading dashboard
* a table-first admin explorer

The uploaded RetroPick V1 spec explicitly recommends a **small curated set**, better market cards, and a market product feel rather than a gambling timer surface.

---

# 3. Core information architecture

The discovery page should be organized around **market stories and time buckets**, not only raw primitives.

## 3.1 IA principle

A user thinks in this order:

1. **What kind of market is this?**
2. **What asset is it about?**
3. **What is the condition?**
4. **How soon does it end?**
5. **Do I care enough to open it?**

So the page architecture should reflect that.

---

# 4. Recommended page structure

## 4.1 Top-level structure

```text
Header
├─ Logo
├─ Search
├─ Categories nav
├─ Asset filters
├─ Wallet / Portfolio shortcut

Market Discovery Surface
├─ Hero / Featured strip
├─ Tabs: All / Today / This Week / Ending Soon / Open Positions
├─ Filter bar
├─ Optional pinned sections
│  ├─ Today’s Key Levels
│  ├─ This Week
│  ├─ Above Yesterday Close
│  ├─ Below Weekly Open
│  ├─ Featured Thresholds
│  └─ Your Open Positions
└─ Main market feed
   ├─ cards grid or hybrid list
   ├─ pagination or infinite scroll
   └─ empty / loading / error states
```

---

# 5. Navigation model

## 5.1 Primary nav

Top nav should include:

* Markets
* Portfolio
* History / Results
* Learn / How it works

For V1, **Markets** is the dominant entry point.

## 5.2 Discovery subnav

Under Markets, use horizontal tabs:

* All
* Today
* This Week
* Ending Soon
* Featured
* My Positions

These are not just filters.
They are **behavioral entry points**.

### Why these work

* **All** = full browsing surface
* **Today** = daily retention loop
* **This Week** = slower-cycle narrative markets
* **Ending Soon** = urgency bucket
* **Featured** = editorial / high-signal curation
* **My Positions** = re-engagement and tracking

---

# 6. Category model

This is where RetroPick can become stronger than a flat Polymarket-like feed.

## 6.1 Category dimensions

Each market should belong to multiple category layers:

### A. Time category

* Today
* This Week
* Ending Soon
* Resolved
* Upcoming

### B. Primitive category

* Threshold
* Direction
* Range
* Relative Performance

### C. Narrative family

* Above Yesterday Close
* Below Weekly Open
* Above Daily Open
* Daily Close Range
* Weekly Breakout Watch

### D. Asset category

* BTC
* ETH
* SOL
* BNB later

### E. State category

* Open
* Locked
* Resolving
* Claimable
* Cancelled

This matters because the uploaded product spec says V1 will eventually contain multiple market primitives, but launch must remain curated and easy to browse. Discovery therefore needs **structure**, not just sorting.

---

# 7. Recommended discovery sections

These should appear as either:

* editorial rows
* collapsible market shelves
* tab-dependent content blocks

## 7.1 Today’s Key Levels

Purpose:

* strongest daily threshold markets
* fast habit-loop entry point
* “main event” feeling for daily users

Include:

* BTC above previous daily close
* ETH above previous daily close
* SOL above previous daily close

## 7.2 This Week

Purpose:

* longer-horizon anchor markets
* stronger narrative and larger pool concentration

Include:

* BTC above weekly open
* ETH above weekly open
* weekly range-close markets later

## 7.3 Ending Soon

Purpose:

* urgency + action
* good for conversion

Sort by:

* nearest lockAt or resolveAt depending on status

## 7.4 Above Yesterday Close

Purpose:

* recurring family shelf
* easy-to-understand market cluster

## 7.5 Below Weekly Open

Purpose:

* inverse narrative bucket
* strong editorial framing for later V1.5 / V2

## 7.6 Featured Thresholds

Purpose:

* curated / hand-prioritized market highlights
* useful when catalog grows

## 7.7 Your Open Positions

Purpose:

* return-user retention
* quick resume behavior

The discovery page should feel like a **market calendar plus market stories**, exactly as your flow principle states.

---

# 8. Recommended page layout pattern

## 8.1 Best default layout for V1

Use a **hybrid layout**:

### Top section

* one featured horizontal strip
* one compact metrics / filters row

### Main section

* desktop: 2-column card feed
* tablet: 2-column card feed
* mobile: 1-column stacked feed

This is better than:

* pure table, which feels too dry
* pure tile grid, which feels too casual
* over-dense feed, which hurts comprehension

## 8.2 Why not a pure Polymarket row list?

Polymarket works with short natural-language markets and rich volume / odds context.

RetroPick threshold markets require more explanation:

* threshold label
* threshold value
* current price
* distance to threshold
* schedule

So RetroPick needs **slightly larger cards** than Polymarket to preserve clarity.

---

# 9. Discovery card system

This is the core frontend object.

## 9.1 Card design goal

One card should make the user understand:

* the market story
* the condition
* the current setup
* the timing
* the action opportunity

The uploaded spec directly says one market card must tell the user how the market resolves.

---

# 10. Card anatomy

## 10.1 Required fields

Each card should show:

* market title
* asset symbol
* status badge
* current price
* threshold label
* threshold value
* distance to threshold
* time remaining
* YES pool
* NO pool

## 10.2 Optional fields

* implied pool skew
* participant count
* oracle source
* schedule label
* template family badge
* quick action buttons

## 10.3 Recommended visual hierarchy

### Row 1

* asset icon + asset symbol
* status badge
* schedule badge

### Row 2

* title

### Row 3

* threshold label + threshold value
* current price

### Row 4

* distance to threshold
* ends in countdown

### Row 5

* YES pool / NO pool
* optional skew bar

### Row 6

* click target or quick action area

---

# 11. Recommended card copy structure

## 11.1 Title

Use user-facing grammar:

**BTC at or above previous daily close by today close**

Not internal grammar like:

* BTC_AT_OR_ABOVE_PREVIOUS_DAILY_CLOSE_AT_DAILY_CLOSE

## 11.2 Threshold row

**Previous daily close:** 148,200

## 11.3 Current price row

**Current:** 147,800

## 11.4 Distance row

**Need:** +0.27%

or

**Above threshold:** +1.12%

## 11.5 Countdown row

**Ends in:** 2h 14m

## 11.6 Pool row

**YES:** 1,240 USDC
**NO:** 980 USDC

---

# 12. Card variants by market state

The same card system should adapt to status.

## 12.1 BETTING_OPEN card

Show:

* countdown to lock
* action emphasis
* YES/NO pools
* stronger CTA

CTA:

* View market
* optional quick bet

## 12.2 LOCKED / LIVE card

Show:

* entry disabled
* “watching” or “locked” badge
* current price vs threshold
* countdown to resolution

CTA:

* View result tracking

## 12.3 RESOLVED card

Show:

* final price
* threshold
* result badge
* winning side
* no entry action

CTA:

* View details

## 12.4 CLAIMABLE card

Show:

* result
* claimable amount if user connected and eligible

CTA:

* Claim
* View details

## 12.5 CANCELLED card

Show:

* cancelled badge
* refund available if applicable

CTA:

* Refund or View reason

---

# 13. Card interaction rules

## 13.1 Primary action

Click/tap anywhere on card opens detail page.

This should be the default V1 behavior.

## 13.2 Secondary action

Optional quick actions:

* Bet YES
* Bet NO

These should only be enabled if:

* market is open
* wallet connected or connect prompt supported
* action does not reduce comprehension

### Recommendation

Do **not** lead with quick-bet in earliest V1 if it makes the card noisy.
Clarity first.

## 13.3 Hover behavior on desktop

Can reveal:

* mini rule summary
* quick CTA
* subtle threshold chart sparkline

But hover should never hide critical info.

---

# 14. Discovery UX principle translated into UI rules

Your four discovery questions should map to explicit UI blocks.

## 14.1 What is the market asking?

Answer with:

* title
* family badge
* asset symbol

## 14.2 What does YES mean?

Answer with:

* short visible rule text or condition framing
* status-aware side explanation on hover or microcopy

Example:
**YES if close >= threshold**

## 14.3 How far is price from threshold?

Answer with:

* current price
* threshold value
* distance percentage
* optional bar indicator

## 14.4 When does it end?

Answer with:

* countdown
* schedule tag
* lock/resolve label

If any card cannot answer these 4 questions, the card is failing.

---

# 15. Filters

RetroPick needs filters because the catalog will eventually span multiple primitives and schedules.

## 15.1 Recommended filters

### Asset

* All
* BTC
* ETH
* SOL

### Schedule

* Daily
* Weekly
* 5m
* 15m
* 1h
* 24h later

### Primitive

* Threshold
* Direction
* Range
* Relative

### Status

* Open
* Locked
* Resolving
* Claimable
* Resolved

### Family

* Above yesterday close
* Above weekly open
* Below weekly open
* Daily close range

### Open only

* toggle

## 15.2 Filter UX design

Best pattern:

* horizontal pill filters for most common dimensions
* advanced filter drawer for secondary filters

### Default visible pills

* Asset
* Schedule
* Status
* Open only

### Drawer filters

* Primitive
* Family
* Sort
* Pool size thresholds
* Participant thresholds later

---

# 16. Sorting

## 16.1 Recommended sorts

* Ending soon
* Highest pool
* Closest to threshold
* Newest cycle
* Asset

## 16.2 Best default sort

For open threshold markets, default should be:

**Featured / ending soon hybrid**

Reason:

* pure highest pool over-favors established pools
* pure newest cycle can hide urgency
* pure closest to threshold can create chaos

## 16.3 Section-specific sorting

### Today

* featured then ending soon

### Ending Soon

* nearest lockAt

### This Week

* by editorial importance or highest pool

### Asset view

* open first, then nearest resolution

---

# 17. Search

## 17.1 What search should support

User should be able to search by:

* asset
* market title fragment
* threshold family
* primitive
* schedule label

Examples:

* BTC
* weekly open
* above daily close
* range
* this week

## 17.2 Search behavior

Search should not be deep full-text only.
It should also act like a **structured matcher**.

For example:
searching `BTC weekly` should surface:

* BTC above weekly open
* BTC weekly close range
* BTC weekly markets

---

# 18. Section behavior

## 18.1 Today tab

Should prioritize:

* daily threshold markets
* intraday direction markets
* fast loops

This aligns with your spec’s daily retention and scheduled rounds model.

## 18.2 This Week tab

Should prioritize:

* weekly threshold markets
* slower-cycle markets
* stronger narrative anchors

## 18.3 Ending Soon

Should be the highest-conversion section.

Design:

* compact list or tighter cards
* strong countdown emphasis
* open-only by default

## 18.4 Featured

Editorial / operator controlled.
Use for:

* strongest narratives
* highest-confidence user-friendly markets
* launch-page curation

## 18.5 My Positions

Should merge:

* open positions
* locked positions
* claimable positions

This is especially important because V1 product-market fit is about **participation and retention**, not exchange liquidity.

---

# 19. Empty states

## 19.1 No markets found

Show:

* no matching markets
* clear reset filters CTA
* suggested categories

## 19.2 No open positions

Show:

* “You don’t have open positions yet”
* featured market suggestions

## 19.3 No weekly markets currently

Show:

* “No weekly markets are open right now”
* upcoming markets preview if available

---

# 20. Loading states

The discovery page is price-sensitive and list-heavy, so loading quality matters.

## 20.1 Initial page load

Use:

* skeleton cards
* skeleton section headers
* sticky filter placeholders

## 20.2 Incremental data updates

Use:

* silent refresh
* preserve card positions
* avoid layout jumps

## 20.3 Countdown refresh

Countdowns should update smoothly every second or every minute depending on view density.

Recommendation:

* second-level for detail page
* minute-level for dense list/grid cards unless near expiry

---

# 21. Real-time behavior

Because RetroPick is crypto-native and threshold-based, the discovery page should feel live.

## 21.1 Fields that should update live

* current price
* distance to threshold
* countdown
* status
* pools
* claimability if connected

## 21.2 Update strategy

Use a split model:

### High-frequency updates

* price
* countdown

### medium-frequency updates

* pools
* participant count

### event-triggered updates

* status transitions
* claimable state
* cancellation

---

# 22. Frontend data model for cards

A clean frontend card DTO should exist separate from raw backend objects.

## 22.1 Suggested card DTO

```ts
type DiscoveryMarketCard = {
  marketId: string;
  templateId: string;
  slug: string;

  asset: "BTC" | "ETH" | "SOL";
  assetIconUrl?: string;

  primitive: "THRESHOLD" | "DIRECTION" | "RANGE" | "RELATIVE";
  familyKey?: string;

  title: string;
  shortRuleText: string;

  status: "INSTANCE_SCHEDULED" | "BETTING_OPEN" | "LOCKED" | "LIVE" | "CALCULATING" | "RESOLVED" | "CLAIMABLE" | "CANCELLED";

  thresholdLabel?: string;
  thresholdValue?: number;
  currentPrice?: number;
  distanceAbs?: number;
  distancePct?: number;

  yesPool?: number;
  noPool?: number;
  totalPool?: number;
  participantCount?: number;

  betOpenAt: string;
  lockAt: string;
  resolveAt: string;

  countdownLabel: string;
  countdownTarget: "LOCK" | "RESOLVE";

  oracleSourceLabel?: string;
  scheduleLabel?: string;

  userPositionSide?: "YES" | "NO";
  userPositionAmount?: number;
  userClaimableAmount?: number;

  featured?: boolean;
};
```

---

# 23. API requirements for discovery page

The page should not assemble everything client-side from raw chain objects.

## 23.1 Discovery API responsibilities

API/indexer should provide:

* preformatted titles
* threshold labels
* current price
* derived distance to threshold
* section tags
* state labels
* pool totals
* user-position overlays if wallet connected

## 23.2 Recommended endpoints

* `GET /markets`
* `GET /markets/featured`
* `GET /markets?tab=today`
* `GET /markets?tab=this-week`
* `GET /markets?status=betting_open`
* `GET /markets?asset=BTC`
* `GET /markets?family=above-yesterday-close`
* `GET /users/:address/open-positions`

---

# 24. Ranking logic recommendations

RetroPick should not use only one feed ordering.

## 24.1 Suggested feed ranking formula

For open discovery feed, rank by weighted score using:

* featured weight
* time urgency weight
* closeness to threshold weight
* total pool weight
* category priority weight
* launch catalog priority

## 24.2 Why closeness matters

Threshold markets become more compelling when price is near threshold.
This creates a real “story tension” effect.

But closeness alone should not dominate, or the page becomes noisy.

---

# 25. Responsive behavior

## 25.1 Desktop

Recommended:

* left-aligned content
* sticky top filters
* 2-column cards
* optional right rail for featured/open positions later

## 25.2 Tablet

Recommended:

* compressed horizontal filter pills
* 2-column grid if space allows

## 25.3 Mobile

Recommended:

* sticky search + filter button
* tab pills horizontally scrollable
* 1-column cards
* tighter card spacing
* avoid table layout

Mobile should emphasize:

* title
* threshold
* current price
* countdown
* pools

---

# 26. Visual design language

## 26.1 Tone

The design should feel:

* financial
* modern
* focused
* slightly editorial
* not casino-like

## 26.2 Visual priorities

* typography-led clarity
* clean spacing
* subtle badges
* limited accent usage
* threshold and current price separation
* countdown visible but not screaming

## 26.3 Badge system

Recommended badges:

* Open
* Locked
* Live
* Resolving
* Claimable
* Cancelled
* Daily
* Weekly
* Threshold
* Featured

---

# 27. Launch recommendations for V1 discovery

Based on your V1 product spec, the launch discovery page should stay concentrated. The spec explicitly warns that too many markets fragment attention and recommends a curated day-1 catalog. 

## 27.1 Best day-1 discovery shelves

### Shelf 1: Today

* BTC above previous daily close
* ETH above previous daily close
* SOL above previous daily close

### Shelf 2: This Week

* BTC above weekly open
* ETH above weekly open

### Shelf 3: Fast Markets

* BTC up/down 5m
* ETH up/down 5m
* SOL up/down 15m

### Shelf 4: Signature Markets

* BTC daily close range
* ETH vs BTC later

This keeps the page broad enough to feel alive, but curated enough to avoid clutter.

---

# 28. Discovery page success metrics

## Product metrics

* CTR from card to detail
* market participation conversion
* repeat daily sessions
* section-level engagement
* open-position revisit rate

## UX metrics

* time to first meaningful click
* filter usage rate
* search success rate
* drop-off before detail page
* card scan efficiency

## State metrics

* percent of cards that answer the 4 core questions
* percent of users entering from Today / This Week tabs
* claimable revisit rate through discovery

---

# 29. Final design thesis

## The right RetroPick discovery page is:

not a contract explorer,
not a sportsbook lobby,
not a DEX terminal,
and not just a Polymarket clone.

It should be:

> **a curated, category-driven recurring market homepage where each card behaves like a small self-explanatory financial story**

That means:

* categories first
* clear card grammar
* threshold story visible
* live price context
* urgency without chaos
* curated launch catalog
* smooth path to detail and entry

---

# 30. Final V1 recommendation

For V1, I recommend this exact structure:

## Top nav

* Markets
* Portfolio
* Results

## Markets tabs

* All
* Today
* This Week
* Ending Soon
* My Positions

## Top filter pills

* Asset
* Schedule
* Status
* Open only

## Discovery shelves

* Today’s Key Levels
* This Week
* Ending Soon
* Featured Thresholds
* Your Open Positions

## Card style

* medium-density financial cards
* threshold label + value always visible
* current price + distance always visible
* status + countdown always visible
* pools always visible
* detail click everywhere

That is the cleanest frontend foundation for RetroPick’s discovery page.

If you want, next I’ll turn this into a **screen-level UI spec** with:
**desktop layout, mobile layout, exact card wireframe, filters bar wireframe, and component hierarchy.**
