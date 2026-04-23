Perfect. Below is the **screen-level UI spec** for **RetroPick Discovery / Markets**, focused on **desktop layout, mobile layout, exact card wireframe, filter bar wireframe, and component hierarchy**.

I’m optimizing this for:

* **Polymarket / Kalshi-like market browsing**
* **clear recurring crypto market stories**
* **small curated V1 catalog**
* **threshold-first readability**
* **easy expansion later into direction, range, and relative-performance markets**

That direction is consistent with your V1 product spec: RetroPick should feel like a **market product**, use **clear market cards**, keep a **small curated launch catalog**, and support **daily retention** through repeatable scheduled markets.  

---

# RetroPick Discovery Page / Markets

## Screen-Level Frontend UI Spec

---

# 1. Screen goal

The Discovery page is the **primary browsing surface** for RetroPick.

Its job is to let users:

* scan markets quickly
* understand market meaning instantly
* filter by category, asset, and schedule
* jump into market detail
* return daily to recurring market families

This page must bridge two worlds:

* **market browsing UX** like Polymarket / Kalshi
* **crypto-native live market context** like price, threshold, countdown, and urgency

For V1, this page matters even more because RetroPick is launching as a **focused event-contract product**, not a full exchange with order books or secondary markets. 

---

# 2. Discovery page design thesis

## The page should feel like:

* a **market homepage**
* a **category-driven market directory**
* a **calendar of active stories**
* a **clean financial product**

## The page should not feel like:

* a contract explorer
* a DEX terminal
* a sportsbook lobby
* a casino wall of tiles

Because threshold markets create stronger discovery narratives than generic direction rounds, the Discovery page should visually emphasize:

* market title
* threshold label
* threshold value
* current price
* distance to threshold
* time remaining

That is directly aligned with the V1 product direction that threshold markets are especially strong for discovery and that one market card should explain how resolution works.  

---

# 3. Desktop screen layout

## 3.1 Recommended desktop layout

Use a **three-layer layout**:

```text
Top App Header
Sticky Discovery Nav + Filters
Main Discovery Content
```

## 3.2 Desktop structure

```text id="9xyeqw"
┌──────────────────────────────────────────────────────────────────────┐
│ Header                                                               │
│ Logo | Markets | Portfolio | Results | Search | Wallet              │
├──────────────────────────────────────────────────────────────────────┤
│ Markets Subnav                                                       │
│ All | Today | This Week | Ending Soon | Featured | My Positions     │
├──────────────────────────────────────────────────────────────────────┤
│ Sticky Filters Bar                                                   │
│ Asset ▾ | Schedule ▾ | Primitive ▾ | Status ▾ | Open only ☐ | Sort ▾│
├──────────────────────────────────────────────────────────────────────┤
│ Featured Strip / Hero Shelf                                          │
│ [featured card] [featured card] [featured card]                      │
├──────────────────────────────────────────────────────────────────────┤
│ Section: Today’s Key Levels                                          │
│ [card] [card]                                                        │
│ [card] [card]                                                        │
├──────────────────────────────────────────────────────────────────────┤
│ Section: This Week                                                   │
│ [card] [card]                                                        │
├──────────────────────────────────────────────────────────────────────┤
│ Section: Ending Soon                                                 │
│ [compact card row] [compact card row] [compact card row]             │
├──────────────────────────────────────────────────────────────────────┤
│ Section: Your Open Positions                                         │
│ [position card] [position card]                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

# 4. Desktop spacing and grid rules

## 4.1 Content width

Recommended max width:

* `1280px` to `1440px`

## 4.2 Grid

Recommended card grid:

* **2 columns** for standard cards
* gap: `20px` to `24px`

## 4.3 Sections

Each section should have:

* section title
* optional subtitle
* “See all” link if expandable

## 4.4 Sticky behavior

The following should stay sticky on desktop:

* top nav
* subnav tabs
* filter bar

But only the filter bar should remain highly persistent while scrolling deep into the feed.

---

# 5. Mobile screen layout

## 5.1 Mobile philosophy

On mobile, Discovery must be:

* fast to scan
* one-column
* thumb-friendly
* filter-light by default
* search-first

## 5.2 Mobile structure

```text id="q7vfko"
┌──────────────────────────────┐
│ Header                       │
│ Logo        Search   Wallet  │
├──────────────────────────────┤
│ Tab pills                    │
│ All Today This Week Ending…  │
├──────────────────────────────┤
│ Filter row                   │
│ Asset ▾  Schedule ▾  Filter  │
├──────────────────────────────┤
│ Featured strip               │
│ [horizontal scroll cards]    │
├──────────────────────────────┤
│ Main feed                    │
│ [card]                       │
│ [card]                       │
│ [card]                       │
├──────────────────────────────┤
│ Sticky bottom nav later      │
└──────────────────────────────┘
```

## 5.3 Mobile rules

* one-column cards only
* horizontal scroll for tabs
* filters condensed into one drawer trigger
* search accessible immediately
* section shelves may flatten into one prioritized feed if needed

---

# 6. Recommended page hierarchy

## Order of importance on Discovery page

### 1. Tab / context

Where am I browsing?

* Today
* This Week
* Ending Soon
* Featured

### 2. Filters

What subset am I looking at?

### 3. Best markets first

Featured / highest-signal / nearest action

### 4. Main feed

Full list or shelf groups

### 5. Re-engagement

Open positions, claimable items

This hierarchy works because V1 is about **participation and retention**, not exchange-depth browsing. 

---

# 7. Exact discovery card wireframe

This is the most important UI object on the page.

## 7.1 Standard market card wireframe

```text id="7lk9x0"
┌──────────────────────────────────────────────┐
│ BTC                         OPEN      DAILY  │
│ BTC at or above previous daily close         │
│ by today close                               │
│                                              │
│ Previous daily close   148,200               │
│ Current price          147,800               │
│ Need                  +0.27%                 │
│                                              │
│ Ends in               2h 14m                 │
│ YES pool              1,240 USDC             │
│ NO pool                 980 USDC             │
│                                              │
│ [View market]                    [Yes / No]  │
└──────────────────────────────────────────────┘
```

## 7.2 Card content priority

Priority order:

1. asset + status
2. title
3. threshold
4. current price
5. distance to threshold
6. countdown
7. pool info
8. action

---

# 8. Recommended card visual zones

## Zone A — Meta header

Contains:

* asset icon
* asset symbol
* status badge
* schedule badge

Example:

* BTC
* OPEN
* DAILY

## Zone B — Title

Contains:

* full readable market title
* max 2 lines desktop
* max 3 lines mobile

Example:
**BTC at or above previous daily close by today close**

## Zone C — Key figures

Contains:

* threshold label + value
* current price
* distance

This is the main informational block.

## Zone D — Timing + liquidity

Contains:

* countdown
* YES pool
* NO pool

## Zone E — Action

Contains:

* primary card click target
* optional quick bet later

---

# 9. Card variants

## 9.1 Open market card

Best for:

* BETTING_OPEN

Shows:

* threshold
* current price
* distance
* countdown to lock
* pool values
* CTA

## 9.2 Locked / live card

Best for:

* LOCKED
* LIVE

Shows:

* threshold
* current price
* “entry closed”
* countdown to resolve
* no bet CTA

## 9.3 Resolved card

Best for:

* RESOLVED

Shows:

* final price
* threshold
* result badge
* settlement summary

## 9.4 Claimable card

Best for:

* CLAIMABLE

Shows:

* result
* claimable amount if connected
* claim CTA

## 9.5 Position overlay card

Best for:

* My Positions shelf

Adds:

* your side
* your stake
* claimable amount or live status

---

# 10. Filter bar wireframe

## 10.1 Desktop filter bar

```text id="hyyrh2"
┌─────────────────────────────────────────────────────────────────────┐
│ Asset ▾ | Schedule ▾ | Primitive ▾ | Status ▾ | Family ▾ | Open only│
│ Sort: Ending soon ▾                                     Reset        │
└─────────────────────────────────────────────────────────────────────┘
```

## 10.2 Recommended visible filters for V1

Always visible:

* Asset
* Schedule
* Status
* Open only
* Sort

Advanced drawer or dropdown:

* Primitive
* Family
* Featured only
* Has positions
* Pool size threshold later

## 10.3 Mobile filter bar

```text id="6m4orc"
┌──────────────────────────────┐
│ Asset ▾   Schedule ▾  Filter │
└──────────────────────────────┘
```

Tapping **Filter** opens full-screen bottom sheet or side drawer.

---

# 11. Tab system wireframe

## 11.1 Desktop tabs

```text id="b1r513"
All | Today | This Week | Ending Soon | Featured | My Positions
```

## 11.2 Mobile tabs

Use horizontally scrollable pill tabs:

```text id="mw06ir"
[All] [Today] [This Week] [Ending Soon] [Featured] [My Positions]
```

## 11.3 Tab behavior

### All

Mixed feed with shelves

### Today

Prioritize daily threshold + short rounds

### This Week

Prioritize weekly threshold + longer-cycle markets

### Ending Soon

Prioritize urgency and countdown

### Featured

Operator-curated signal

### My Positions

Connected-wallet personalized list

---

# 12. Section-level wireframes

## 12.1 Featured Thresholds shelf

Use horizontal shelf with larger cards.

```text id="n1w7yg"
Featured Thresholds                                  See all →
┌────────────────────┐ ┌────────────────────┐ ┌────────────────────┐
│ Large card         │ │ Large card         │ │ Large card         │
└────────────────────┘ └────────────────────┘ └────────────────────┘
```

Best for:

* flagship threshold markets
* operator-prioritized stories
* strongest launch narratives

## 12.2 Today’s Key Levels

Use standard 2-column grid.

```text id="6f6tzh"
Today’s Key Levels                                   See all →
┌────────────────────┐ ┌────────────────────┐
│ Standard card      │ │ Standard card      │
└────────────────────┘ └────────────────────┘
┌────────────────────┐ ┌────────────────────┐
│ Standard card      │ │ Standard card      │
└────────────────────┘ └────────────────────┘
```

## 12.3 Ending Soon

Use denser compact row cards.

```text id="v3z1lu"
Ending Soon                                          See all →
┌────────────────────────────────────────────────────────────┐
│ BTC above weekly open | Ends in 42m | YES 3.1k | NO 2.4k  │
└────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────┐
│ ETH above daily close | Ends in 1h 08m | YES 2.1k | NO 1.7k│
└────────────────────────────────────────────────────────────┘
```

## 12.4 Your Open Positions

Use cards with stronger personalization overlay.

```text id="ohjts9"
Your Open Positions                                   See all →
┌────────────────────┐ ┌────────────────────┐
│ Your side: YES     │ │ Your side: NO      │
│ Stake: 100 USDC    │ │ Stake: 50 USDC     │
│ Status: Locked     │ │ Claimable: 84 USDC │
└────────────────────┘ └────────────────────┘
```

---

# 13. Card microcopy system

## 13.1 Primary title format

Use:

**[Asset] [condition text] [threshold label] by [resolution text]**

Examples:

* BTC at or above previous daily close by today close
* ETH below weekly open by this week’s close

## 13.2 Secondary field labels

Use short labels:

* Threshold
* Current
* Need
* Above threshold
* Ends in
* YES
* NO

## 13.3 Status badges

Use:

* OPEN
* LOCKED
* LIVE
* RESOLVING
* CLAIMABLE
* CANCELLED
* RESOLVED

## 13.4 Schedule badges

Use:

* 5M
* 15M
* 1H
* DAILY
* WEEKLY

This is aligned with the V1 UX principle that schedules should be user-understandable and cards should explain resolution clearly. 

---

# 14. Frontend component hierarchy

## 14.1 Discovery page component tree

```text id="h1q7yd"
MarketsPage
├─ AppHeader
├─ MarketsTabs
├─ DiscoveryFilterBar
├─ DiscoverySearchBar
├─ FeaturedMarketsShelf
│  └─ FeaturedMarketCard[]
├─ MarketSection
│  ├─ SectionHeader
│  └─ MarketCardGrid
│     └─ MarketCard[]
├─ EndingSoonSection
│  └─ CompactMarketRow[]
├─ OpenPositionsSection
│  └─ PositionMarketCard[]
├─ EmptyState
├─ LoadingState
└─ ErrorState
```

## 14.2 Market card internals

```text id="nrh7pv"
MarketCard
├─ CardHeader
│  ├─ AssetChip
│  ├─ StatusBadge
│  └─ ScheduleBadge
├─ MarketTitle
├─ MarketMetrics
│  ├─ ThresholdRow
│  ├─ CurrentPriceRow
│  └─ DistanceRow
├─ MarketTimingAndPools
│  ├─ CountdownRow
│  ├─ YesPoolRow
│  └─ NoPoolRow
└─ CardFooter
   ├─ PrimaryCTA
   └─ OptionalQuickAction
```

---

# 15. Frontend state model

## 15.1 Page states

Discovery page must support:

* initial loading
* loaded
* partial refresh
* empty feed
* filtered empty
* error

## 15.2 Card states

Each card must support:

* hover
* pressed
* disabled
* loading skeleton
* stale data indicator if feed not fresh enough later

## 15.3 Personalized states

If wallet connected:

* show open positions shelf
* show claimable overlays
* show “your side” on cards where relevant

If wallet disconnected:

* hide personalized shelf or replace with CTA

---

# 16. Recommended V1 visual density

## Desktop

Medium density.

Not too sparse, not too cramped.

Each card should fit:

* title
* 5–6 metrics
* CTA
  without feeling bloated.

## Mobile

Slightly denser, but only one column.

Do not attempt table-like layouts on mobile.

---

# 17. Ranking and content order

## Recommended home / all page order

1. Featured Thresholds
2. Today’s Key Levels
3. This Week
4. Ending Soon
5. Your Open Positions

Why:

* gives immediate signal
* supports daily habit loop
* supports weekly anchor markets
* supports urgency
* supports returning users

This also fits the V1 guidance to launch with a curated catalog rather than a massive directory. 

---

# 18. Day-1 screen content recommendation

For initial Discovery page, keep it highly concentrated.

## Top shelf

Featured Thresholds:

* BTC above previous daily close
* ETH above previous daily close
* BTC above weekly open

## Today’s Key Levels

* BTC daily threshold
* ETH daily threshold
* SOL daily threshold

## This Week

* BTC weekly open
* ETH weekly open

## Optional secondary row

Fast Markets:

* BTC up/down 5m
* ETH up/down 5m
* SOL up/down 15m

This follows the product spec’s launch recommendation: small catalog, repeatable schedules, and a balance of direction + threshold formats. 

---

# 19. Empty and loading wireframes

## 19.1 Loading

```text id="arjv3g"
MarketsPage
├─ skeleton tabs
├─ skeleton filters
├─ 4 skeleton cards
├─ section header skeleton
└─ 4 skeleton cards
```

## 19.2 Empty filtered results

```text id="a0w51s"
No markets match these filters.
[Reset filters]
[Browse Today]
[Browse Featured]
```

## 19.3 No open positions

```text id="6f8wvh"
You don’t have open positions yet.
[Explore today’s markets]
```

---

# 20. Responsive card rules

## Desktop card

* 360–420px width
* 220–260px height target

## Mobile card

* full width
* 190–230px height target

## Compact row card

* only for Ending Soon or dense sections
* desktop first
* avoid as default on mobile for threshold markets

---

# 21. Exact implementation priorities

## Phase A — must build first

* Markets page shell
* tabs
* filter bar
* standard market card
* section shelves
* loading / empty states

## Phase B — second

* featured shelf
* compact ending-soon row
* my positions shelf
* personalized overlays

## Phase C — later

* quick bet from card
* sparkline or mini chart
* richer ranking personalization
* watchlist / notify me

---

# 22. Final recommended screen spec

## Desktop

* sticky top nav
* sticky tabs + filter bar
* 2-column card grid
* featured shelf first
* sectioned discovery layout

## Mobile

* one-column feed
* horizontal tab pills
* compact top filter row
* filter drawer
* featured shelf as horizontal scroll

## Card

Every card must answer:

* what is it?
* what does YES mean?
* how far is price from threshold?
* when does it end?

## V1 product tone

* financial
* serious
* not casino-like
* curated
* live but calm

---

# 23. Final judgment

For RetroPick, the discovery page should be built as:

> **a category-driven market homepage with recurring threshold stories, not a flat contract list**

That means your UI should prioritize:

* shelves over giant tables
* readable cards over hyper-dense rows
* threshold and timing clarity over visual novelty
* curation over volume
* repetition and retention over endless market breadth

That is the right frontend foundation for RetroPick V1.

Next, I can turn this into a **component-level engineering spec** with:
**React component props, TypeScript interfaces, page sections, and exact frontend folder structure for Next.js.**
