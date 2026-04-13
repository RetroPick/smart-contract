RetroPick V1
Oracle-based scheduled event contracts on Solana
Product strategy, market catalog, protocol design, UX, and launch plan
DOCUMENT TYPE
V1 product spec	PRIMARY CHAIN
Solana	ORACLE LAYER
Chainlink Data Feeds first
LAUNCH WEDGE
Automated event contracts	EXCLUDE IN V1
Human-judged markets	EXPANSION PATH
Range + relative performance -> later exchange

Executive summary
RetroPick V1 should launch as a focused oracle-based event-contract product rather than a full prediction exchange. The goal is to ship a simple, repeatable market engine that can settle automatically from public onchain feeds without a disputes layer.
The best V1 categories are crypto price direction, threshold, range-close, and relative-performance markets. These have clear resolution formulas, strong repeatability, and direct compatibility with Chainlink public Data Feeds on Solana.
The product should deliberately avoid politics, sports match resolution, milestone promises, and any market that requires human judgment, scraping, or discretionary operator decisions.
RetroPick differentiates from PancakeSwap Prediction by expanding beyond two-sided short rounds into richer market templates, clearer market cards, better schedules, and a data model that can later evolve into a fuller event-share or exchange architecture.
Design principle
V1 optimizes for clarity, automation, repeatability, and speed to market.
If a market cannot be resolved by a deterministic formula using public feeds, it does not belong in V1.

1. Product thesis
RetroPick V1 is a consumer-facing prediction product for scheduled event contracts. It sits between a simple prediction game and a full prediction exchange: more expressive than Pancake-style UP/DOWN rounds, but much easier to ship and operate than a CLOB or hybrid exchange.
• One market engine, not multiple engines.
• Machine-resolvable outcomes only.
• Scheduled rounds and scheduled close times.
• Fast, repeatable market loops that support daily retention.
• A data model that can later support more advanced market formats.


2. Why this wedge works
A full exchange requires market makers, liquidity bootstrapping, book health, advanced charting, and position accounting across active secondary trading. V1 avoids that complexity. Event contracts only need oracle integration, round state, payout logic, and a clean interface.
Dimension	Event-contract V1	Prediction exchange
Core challenge	Resolve rounds correctly	Solve liquidity + price discovery + settlement
Cold start	No order book required	Needs makers or AMM
User learning curve	Simple	Higher
Engineering surface area	Lower	Much higher
Best launch metric	Participation and retention	Volume and book depth

3. V1 scope and exclusions
Included in V1
• Short-interval crypto direction rounds
• Timed above/below threshold markets
• Range-close markets
• Relative-performance markets across supported assets
• Automated lock and close based on feed reads
• Claimable winnings and treasury fee logic
Explicitly excluded from V1
• Politics, elections, and social sentiment markets
• Sports match outcome markets and player props
• Protocol milestone promises or launch-by-date claims
• Web-scraped or API-dependent resolution
• Human moderation, disputes, or discretionary settlement
• Secondary trading, AMM, or order book execution












4. Market primitives
RetroPick V1 should launch with three core primitives and one stretch primitive.
Primitive	Example	Resolution rule	Repeatability	Priority
Direction	BTC up or down in 5m	close_price > lock_price	Very high	Launch
Threshold	BTC above 110k by 23:59 UTC	close_price >= threshold	High	Launch
Range close	ETH closes in one of 4 bins	find bin containing close_price	High	Launch
Relative performance	ETH beats BTC over 24h	eth_return > btc_return	Medium-high	Launch / selective

4.1 Short-interval direction rounds
This is the Pancake-like retention loop and should be the easiest market to understand. A round opens, users choose UP or DOWN before lock, RetroPick stores the lock price from the oracle, then stores the close price at expiry and pays the winning side.
• Best assets: BTC, ETH, SOL, BNB
• Best schedules: 5m, 15m, 1h
• Best use: quick-play retention and habit loop
4.2 Timed threshold markets
Threshold markets are more expressive than pure UP/DOWN and create stronger narratives for discovery pages. They are still easy to settle because the contract only checks a single oracle value against a fixed threshold at close.
• Examples: BTC above 150k by date, ETH above weekly open, SOL above previous day's close
• Best use: daily and weekly market calendar
4.3 Range-close markets
Range markets are the strongest differentiation layer in V1. They turn a simple price feed into a richer event surface without introducing subjective resolution. Each market defines non-overlapping bins and the close price selects exactly one winner.
• Examples: BTC < 100k, 100k-110k, 110k-120k, > 120k
• Best use: daily close or weekly close markets
4.4 Relative-performance markets
Relative-performance markets compare the returns of two supported assets over the same interval. They remain fully automatable, but feel more distinctive than one-asset direction markets.
• Examples: ETH outperforms BTC over 24h; SOL outperforms BNB this week
• Formula: return(asset_a) > return(asset_b), measured from lock to close
5. Oracle and resolution architecture
Chainlink public Data Feeds should be the default data layer for V1. They are battle-tested, onchain, and available for Solana integration. The protocol should read feed values at lock and at close, store both values onchain, and resolve deterministically from those snapshots.
Feed type	V1 use	Why it fits	Priority
Price Feeds	BTC/USD, ETH/USD, SOL/USD, BNB/USD	Best fit for launch markets	Primary
Derived pair logic	ETH vs BTC via two feed reads	Supports relative-performance markets	Primary
Rate / Volatility feeds	ETH staking APR, realized volatility	Good for V1.5+ differentiation	Later
Data Streams	Lower-latency advanced use cases	Too advanced for first launch	Avoid in V1

Resolution contract rule
At lock: read feed and persist lock_price plus timestamp.
At close: read feed and persist close_price plus timestamp.
Apply the market formula only to those persisted values.
Never rely on offchain interpretation or post-hoc manual edits in V1.

6. Settlement formulas
The event engine should support a small formula library so new markets can reuse existing logic without custom code per market.
Formula type	Condition	Winner set	Notes
Direction	close_price > lock_price	UP else DOWN	Tie policy must be predefined
Threshold	close_price >= threshold	YES else NO	Threshold stored at creation
Range close	bin_i.lower <= close_price < bin_i.upper	Selected range bin	Bins must be non-overlapping
Relative performance	(close_a/lock_a - 1) > (close_b/lock_b - 1)	Asset A else Asset B	Requires two feeds

Tie and invalid-round policy
• Direction tie: default to refund if close_price == lock_price.
• Missing oracle read or stale feed beyond allowed threshold: mark round invalid and refund.
• Any unsupported feed error at lock or close: cancel that round only, not the full market family.
7. Market mechanics and economics
V1 should use a simple event-contract payout model, closer to a pooled scheduled market than to a fully traded prediction exchange. The core objective is clean UX and fast settlement, not market microstructure sophistication.
Recommended V1 economics
• Parimutuel-style payout per round or per scheduled market window.
• Transparent treasury fee, such as 2%-4% of each round pool.
• No secondary trading in V1.
• No liquidity provider role in V1.
• Support minimum and maximum stake per round to control risk and spam.
Why this is the right V1 trade-off
It removes the cold-start liquidity problem entirely.
It keeps settlement simple and machine-resolvable.
It makes product-market fit about participation and retention instead of order-book depth.

8. User experience
RetroPick should look like a market product, not just a gambling timer. Clear market cards, transparent rules, and visible oracle data are part of the product edge.
Field	Purpose
Market title	Short, readable event statement
Oracle source	Feed name and chain
Lock rule	What price is captured and when
Close rule	What price is captured and when
Resolution formula	Exact deterministic statement
Pool / potential payout	Clear expected return display
Countdown + round status	Opens, locks, closes, claimable

UX principles
• One market card must tell the user exactly how the market resolves.
• Show lock price, close price, and feed source after settlement.
• Use schedules users can understand: 5m, 15m, 1h, daily close, weekly close.
• Launch with a small curated set, not a giant market directory.





9. Solana program architecture
RetroPick V1 can stay modular while still being much simpler than an exchange. The protocol only needs a market registry, round state, oracle read path, treasury accounting, and claims.
Module	Role	Why it exists
Market registry	Stores market templates and active market configs	Single source of truth
Round account	Stores lock, close, pool totals, and status	Per-round settlement state
Oracle adapter	Reads Chainlink feed accounts	Deterministic onchain price access
Treasury vault	Collects protocol fee	Revenue and accounting
User position / ticket	Tracks user side, amount, claim state	Claim safety

10. Recommended day-1 market catalog
RetroPick V1 should launch with a concentrated catalog. Too many markets will fragment attention.
Market	Primitive	Schedule	Why launch it
BTC up/down	Direction	5m	Core retention loop
ETH up/down	Direction	5m	Second liquid benchmark
SOL up/down	Direction	15m	Differentiated crypto-native asset
BTC above daily open	Threshold	Daily	Simple narrative market
ETH above weekly open	Threshold	Weekly	Longer cycle anchor
BTC daily close range	Range close	Daily	Signature differentiated format
ETH vs BTC	Relative performance	24h	Distinctive and data-clean

11. Roadmap
1. Phase 0 - prototype: direction rounds with one price feed and one asset.
2. Phase 1 - launch: BTC, ETH, SOL direction plus threshold and range templates.
3. Phase 1.5 - differentiation: add relative-performance and better market cards.
4. Phase 2 - advanced feeds: selective volatility and rate-feed markets.
5. Phase 3 - expansion: creator tooling, broader event taxonomy, or a later exchange layer.
12. Risks and open decisions
• Feed coverage must be confirmed for target deployment chain and target assets before launch.
• Round cadence should be chosen with care; too many simultaneous rounds can create UI clutter.
• Tie and stale-feed policy must be explicit in the rules, not implied.
• Relative-performance markets require synchronized feed snapshots and robust normalization.
• If gasless or sponsored transactions are planned later, this should be treated as a separate product layer, not part of V1 scope.
Appendix: design references
This document is grounded in the following public product and oracle references:
• PancakeSwap Prediction docs: rolling 5-minute rounds, 3% participation fee, and pool-ratio payouts.
• Chainlink Price Feeds docs: public onchain data feeds aggregated from multiple data sources.
• Chainlink Solana Data Feeds docs: support for onchain feed access on Solana and Anchor-oriented workflows.
• Chainlink Rate and Volatility Feeds docs: realized volatility and ETH staking APR for later market expansion.
