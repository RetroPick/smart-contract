RetroPick V1 — Technical Architecture Doc
1. Product definition
RetroPick V1 is an oracle-based scheduled event contract platform on Solana for fully automatable, repeatable, machine-resolvable markets. It is intentionally not a general prediction exchange yet.
V1 focuses on:
•	short-interval crypto direction rounds,
•	timed threshold events,
•	range-close events,
•	relative-performance events.
This product wedge is modeled to keep the strengths of PancakeSwap Prediction’s round-based simplicity while expanding into richer event types. PancakeSwap’s current prediction product runs 5-minute rolling rounds, resolves outcomes from oracle price feeds, and charges a 3% participation fee from each round’s total prize pool. (PancakeSwap)
For oracle infrastructure, Chainlink officially supports Data Feeds on Solana, including Anchor/Rust onchain usage, and documents Solana-specific feed consumption. (Chainlink Documentation)
________________________________________
2. V1 design principles
2.1 Hard requirements
Every V1 market must be:
•	clearly resolvable,
•	fully automatable,
•	repetitive,
•	based on public onchain feeds,
•	shippable without disputes.
2.2 What V1 is not
Do not include:
•	politics,
•	sports result resolution,
•	social/media outcomes,
•	governance interpretation,
•	milestone/event markets requiring human judgment.
Those need custom data pipelines or dispute systems and are out of scope for V1.
2.3 Product thesis
V1 should win by being:
•	simpler than a prediction exchange,
•	broader than Pancake’s pure UP/DOWN rounds,
•	cheaper and faster than an L2-first event contract system for small bets,
•	structured enough to evolve into V2 exchange markets later.
________________________________________
3. Market model
3.1 Supported market primitives
A. Direction rounds
Examples:
•	BTCUSD up/down in 5m
•	ETHUSD up/down in 5m
•	SOLUSD up/down in 15m
Resolution:
•	store lock_price
•	store close_price
•	UP wins if close_price > lock_price
•	DOWN wins if close_price < lock_price
•	DRAW/CANCEL if equal or invalid feed case
B. Threshold events
Examples:
•	BTC above 110k by 23:59 UTC
•	ETH above weekly open by Friday close
Resolution:
•	compare close_price against fixed threshold or stored reference threshold
C. Range-close events
Examples:
•	BTC daily close in:
o	< 100k
o	100k–110k
o	110k–120k
o	> 120k
Resolution:
•	exactly one bin wins based on close price
D. Relative-performance events
Examples:
•	ETH outperforms BTC over 24h
•	SOL outperforms BNB over a week
Resolution:
•	calculate normalized return from lock to close for both feeds
•	winner is higher return
________________________________________
4. Recommended V1 market catalog
4.1 Launch set
Start with 7 markets:
Direction
•	BTC up/down 5m
•	ETH up/down 5m
•	SOL up/down 15m
Threshold
•	BTC above/below daily open
•	ETH above/below weekly open
Range
•	BTC daily close range market
Relative
•	ETH vs BTC 24h relative-performance market
4.2 Why this set
This gives:
•	high repeatability,
•	clean machine resolution,
•	familiar UX,
•	more differentiation than Pancake,
•	enough breadth to test which primitive users prefer.
________________________________________
5. System overview
flowchart TD
    U[User Wallet] --> FE[Frontend / Mobile UI]
    FE --> API[Indexing + API Layer]
    FE --> RPC[Solana RPC]

    API --> IDX[Indexer / Event Processor]
    IDX --> DB[(Postgres / Analytics DB)]
    IDX --> CANDLE[Candle / Metrics Builder]

    CRON[Round Scheduler / Keeper] --> ORCH[Orchestrator Service]
    ORCH --> RPC

    ORCH --> FEEDS[Chainlink Feed Accounts on Solana]
    RPC --> PROGRAMS[RetroPick Solana Programs]

    PROGRAMS --> REG[Market Registry Program]
    PROGRAMS --> ROUND[Round Engine Program]
    PROGRAMS --> VAULT[Vault / Treasury Logic]
    PROGRAMS --> CLAIM[Claim / Settlement Logic]

    FEEDS --> ROUND
    ROUND --> POS[(User Position Accounts)]
    ROUND --> RV[(Round Vaults)]
    CLAIM --> RV
________________________________________
6. End-to-end architecture
6.1 Offchain components
Frontend
Responsibilities:
•	market discovery,
•	round countdowns,
•	quote preview,
•	participation flow,
•	claim UI,
•	portfolio/history.
Indexer
Responsibilities:
•	index all created markets and rounds,
•	compute round states,
•	derive chart candles and stats,
•	power leaderboard and rankings.
Orchestrator / Keeper
Responsibilities:
•	create scheduled rounds,
•	trigger lock,
•	trigger close,
•	retry failed state transitions,
•	monitor stale or missed transitions.
API layer
Responsibilities:
•	read-optimized market endpoints,
•	user portfolio endpoints,
•	leaderboard,
•	chart/history,
•	market metadata.
________________________________________
6.2 Onchain programs
A. Market Registry Program
Stores long-lived market template definitions.
Responsibilities:
•	create market template,
•	configure feed(s),
•	configure cadence,
•	configure fee,
•	configure market type,
•	enable/disable markets.
B. Round Engine Program
The main runtime engine.
Responsibilities:
•	create round accounts,
•	accept entries,
•	lock round,
•	read oracle prices,
•	close round,
•	compute outcome,
•	mark claimability.
C. Treasury / Vault Logic
Responsibilities:
•	hold protocol fee balances,
•	hold round-level pooled collateral,
•	route winnings and fees.
D. Claim Program or claim instructions inside round engine
Responsibilities:
•	verify winner,
•	transfer payout,
•	mark claim consumed.
For V1, this can live inside the round engine to reduce complexity.
________________________________________
7. Solana program structure
A clean Anchor workspace:
retropick-v1/
  programs/
    market_registry/
    round_engine/
  crates/
    shared_types/
    math/
  apps/
    web/
    api/
    worker/
  packages/
    sdk/
If minimizing complexity, you can merge registry + round engine first, but the cleaner long-term path is keeping registry separate.
________________________________________
8. Core account model
8.1 GlobalConfig
Fields:
•	admin
•	treasury vault
•	pause flags
•	fee caps
•	keeper authority rules
•	allowed feeds list
•	creation controls
8.2 Market
One per recurring market template.
Fields:
•	market_id
•	market_type
•	status
•	feed_1
•	optional feed_2
•	quote_decimals
•	asset symbol
•	cadence
•	lock duration
•	close duration
•	fee_bps
•	payout_mode
•	threshold params
•	range bins
•	min_entry
•	max_entry
•	next_round_epoch
•	creation authority
8.3 Round
One per scheduled round.
Fields:
•	market
•	round_id
•	start_ts
•	lock_ts
•	close_ts
•	status
•	lock_price_1
•	close_price_1
•	lock_price_2
•	close_price_2
•	total_up
•	total_down
•	total_pool
•	total_claimed
•	winning_outcome
•	fee_amount
•	cancelled_flag
8.4 Position
Per user per round.
Fields:
•	owner
•	round
•	outcome
•	amount
•	claimed
8.5 RoundVault
Holds collateral for a round.
Fields:
•	round
•	token mint
•	vault amount
________________________________________
9. Oracle integration
Chainlink documents Solana Data Feeds and specifically shows consuming feeds onchain using Rust and the Chainlink Solana starter kit. (Chainlink Documentation)
9.1 V1 oracle strategy
Use:
•	Chainlink standard public Data Feeds only,
•	one feed per asset pair,
•	no custom oracle writing,
•	no offchain signed custom resolution.
9.2 Feed access pattern
At lock:
•	read latest feed value from feed account
•	validate freshness / validity
•	store as lock_price
At close:
•	read again
•	validate freshness / validity
•	store as close_price
Then resolve.
9.3 Oracle safety checks
For every read:
•	feed account must match allowlist,
•	answer must be positive,
•	timestamp/update freshness must be acceptable,
•	decimals normalization must be deterministic,
•	market must reject invalid or stale values.
9.4 Why not Data Streams in V1
Chainlink also supports Data Streams and onchain verification on Solana, but that is a more advanced integration than needed for a simple repetitive round product. (Chainlink Documentation)
________________________________________
10. Market mechanics
10.1 Participation model
V1 should use a parimutuel pooled payout model.
Why:
•	simpler than exchange matching,
•	no maker problem,
•	no AMM needed,
•	fits round/event structure,
•	very easy for users to understand.
10.2 Fee model
Take a fee from each round pool, similar to Pancake’s participation-fee model. Pancake’s docs state a 3% participation fee from each round’s total prize pool. (PancakeSwap)
Recommended RetroPick fee:
•	default: 200–300 bps
•	start at 300 bps only if UX remains strong
•	allow governance/admin to lower later
10.3 Payout formula
For binary markets:
winner_payout = user_stake / winner_pool * (total_pool - fee_amount)
For range markets:
winner_payout = user_stake / winning_bin_pool * (total_pool - fee_amount)
10.4 Cancel/refund rules
Round should refund if:
•	oracle value unavailable,
•	stale feed,
•	same lock and close price in unsupported rule mode if you choose cancel-on-draw,
•	keeper missed state transition beyond grace period,
•	feed validation fails.
________________________________________
11. State machine
stateDiagram-v2
    [*] --> Scheduled
    Scheduled --> Open: round start
    Open --> Locked: lock instruction + oracle snapshot
    Locked --> Closed: close instruction + oracle snapshot
    Closed --> Resolved: outcome computed
    Resolved --> Claimable
    Claimable --> Settled: claims complete or sweep finalized
    Open --> Cancelled
    Locked --> Cancelled
    Closed --> Cancelled
________________________________________
12. Round lifecycle flow
flowchart TD
    A[Round created] --> B[Users enter positions]
    B --> C[Lock time reached]
    C --> D[Keeper calls lock]
    D --> E[Read Chainlink feed]
    E --> F[Store lock price]
    F --> G[Wait until close time]
    G --> H[Keeper calls close]
    H --> I[Read Chainlink feed]
    I --> J[Store close price]
    J --> K[Compute outcome]
    K --> L[Round claimable]
    L --> M[Users claim winnings]
    M --> N[Unclaimed sweep after deadline]
________________________________________
13. Market-type-specific resolution logic
13.1 Direction rounds
if close_price > lock_price => UP
if close_price < lock_price => DOWN
if close_price == lock_price => DRAW/CANCEL
13.2 Threshold events
if close_price > threshold => ABOVE
else => BELOW
Optional inclusive semantics must be explicit:
•	>
•	>=
•	<
•	<=
Never leave ambiguous.
13.3 Range-close
Example bins:
•	bin0: price < a
•	bin1: a <= price < b
•	bin2: b <= price < c
•	bin3: price >= c
Must be:
•	exhaustive,
•	non-overlapping,
•	deterministic.
13.4 Relative-performance
For assets A and B:
return_a = (close_a - lock_a) / lock_a
return_b = (close_b - lock_b) / lock_b

if return_a > return_b => A_WINS
if return_b > return_a => B_WINS
else => DRAW/CANCEL
Use fixed-point math, not floating point.
________________________________________
14. Onchain instruction set
Suggested minimum instruction set:
Admin
•	initialize_global_config
•	create_market
•	update_market
•	pause_market
•	unpause_market
Round management
•	create_next_round
•	lock_round
•	close_round
•	cancel_round
User actions
•	enter_position
•	claim
•	refund_if_cancelled
Treasury
•	withdraw_protocol_fees
•	sweep_unclaimed
________________________________________
15. Keeper / automation design
Pancake’s product depends on timed rounds and oracle updates, and its FAQ highlights edge cases where oracle update timing and round transitions interact. (PancakeSwap)
So RetroPick V1 needs a robust keeper/orchestrator.
15.1 Keeper responsibilities
•	poll active markets,
•	create upcoming rounds,
•	lock due rounds,
•	close due rounds,
•	retry failures,
•	emit alerts.
15.2 Keeper architecture
Use:
•	one scheduler process,
•	one execution worker queue,
•	idempotent jobs,
•	replay-safe transition checks.
15.3 Transition policy
Every transition instruction must be:
•	independently callable,
•	permissioned to keeper or permissionless with reward,
•	idempotent.
Recommended:
•	admin-configured keeper initially,
•	permissionless fallback later.
________________________________________
16. Frontend architecture
16.1 Main pages
•	Home / market discovery
•	Market detail page
•	Round detail card
•	Portfolio / history
•	Claim center
•	Leaderboard
16.2 Core UI components
Market card
Show:
•	asset/feed
•	market type
•	cadence
•	time until lock
•	oracle source
•	exact resolution rule
Round card
Show:
•	round id
•	start, lock, close
•	current pool
•	sides / bins
•	projected payout multiplier
•	status
Position card
Show:
•	side selected
•	stake
•	claimable amount
•	result
16.3 UX differentiation vs Pancake
RetroPick should beat Pancake in V1 by showing:
•	more market types,
•	clearer rule text,
•	exact oracle source,
•	lock/close formula transparency,
•	richer market schedules.
________________________________________
17. Charts and analytics
Because V1 is pooled event contracts, not a continuous exchange, the “chart” should be about:
•	historical lock/close values,
•	participation by side,
•	implied payout multipliers,
•	round outcomes,
•	streaks and win rate.
Do not force a fake exchange chart.
Suggested analytics
•	round participation count
•	total volume
•	average stake
•	side imbalance
•	win rate by market type
•	fee revenue
•	user retention by cadence
________________________________________
18. Security model
18.1 Main risks
•	oracle stale reads,
•	keeper failure,
•	invalid state transitions,
•	double claim,
•	vault accounting bugs,
•	decimal normalization errors,
•	race conditions around lock/close windows.
18.2 Required protections
•	strict state machine checks,
•	PDA-derived vault ownership,
•	one-claim-only flag,
•	safe math / fixed-point math,
•	oracle freshness validation,
•	pause controls,
•	market allowlist,
•	per-round cancellation path.
18.3 Solana-specific concerns
•	account size and rent planning,
•	deterministic PDA seeds,
•	compute budget for range math and claims,
•	transaction retry handling,
•	avoiding oversized claim fanout in a single tx.
________________________________________
19. Data model and indexer schema
Recommended DB tables:
markets
•	id
•	type
•	feed_1
•	feed_2
•	cadence
•	threshold_json
•	bins_json
•	fee_bps
•	status
rounds
•	id
•	market_id
•	status
•	start_ts
•	lock_ts
•	close_ts
•	lock_price_1
•	close_price_1
•	lock_price_2
•	close_price_2
•	winner
•	total_pool
•	fee_amount
positions
•	id
•	round_id
•	user
•	outcome
•	amount
•	claimed
claims
•	id
•	round_id
•	user
•	amount
•	tx_sig
market_metrics_daily
•	market_id
•	day
•	volume
•	users
•	fee_revenue
•	rounds_count
________________________________________
20. API surface
Suggested endpoints:
Public
•	GET /markets
•	GET /markets/:id
•	GET /markets/:id/rounds
•	GET /rounds/:id
•	GET /leaderboard
•	GET /stats/overview
User
•	GET /users/:wallet/positions
•	GET /users/:wallet/claims
•	GET /users/:wallet/history
Internal
•	POST /keeper/lock
•	POST /keeper/close
•	POST /keeper/create-next
________________________________________
21. Revenue model
21.1 Core revenue
Protocol earns from per-round fee.
Example:
round_fee = total_pool * fee_bps / 10_000
21.2 Secondary revenue later
Not V1:
•	creator fees,
•	premium analytics,
•	sponsored markets,
•	white-label market engine.
________________________________________
22. Growth loops
22.1 Why V1 can grow
Because it has:
•	low-friction repetitive markets,
•	clear win/loss feedback,
•	shareable result cards,
•	leaderboard mechanics,
•	daily/weekly ritual loops.
Pancake highlights leaderboard, rounds played, and winnings as engagement layers on top of basic rounds; that’s a useful signal for user retention design. (PancakeSwap)
22.2 Built-in loops
•	daily streaks,
•	best predictor leaderboard,
•	category leaderboards,
•	“next round in X seconds” retention loop,
•	portfolio recap.
________________________________________
23. What V1 should not attempt
Do not add:
•	CLOB,
•	LS-LMSR,
•	user-generated arbitrary markets,
•	dispute arbitration,
•	sports result markets,
•	social prediction markets,
•	multi-chain deployment.
Keep V1 single-chain, single-model, oracle-clean.
________________________________________
24. Release plan
Phase 0 — Devnet
•	integrate Chainlink Solana feeds,
•	implement one binary market type,
•	test lock/close lifecycle,
•	verify cancellation path.
Phase 1 — Testnet/internal beta
•	3 direction markets,
•	manual keeper,
•	claim center,
•	leaderboard basic.
Phase 2 — Public beta
•	add threshold and range markets,
•	add relative-performance market,
•	add analytics and streaks,
•	add production monitoring.
Phase 3 — V1 full launch
•	7 launch markets live,
•	treasury reporting,
•	referral/share loops,
•	stronger API and uptime.
________________________________________
25. Suggested smart contract pseudomodel
enum MarketType {
    Direction,
    Threshold,
    Range,
    RelativePerformance,
}

enum RoundStatus {
    Scheduled,
    Open,
    Locked,
    Closed,
    Resolved,
    Cancelled,
}

enum Outcome {
    Up,
    Down,
    Above,
    Below,
    Bin(u8),
    AssetA,
    AssetB,
    Draw,
}
________________________________________
26. Canonical end-to-end user flow
sequenceDiagram
    participant U as User
    participant FE as Frontend
    participant API as API/Indexer
    participant RE as Round Engine
    participant K as Keeper
    participant CL as Chainlink Feed

    U->>FE: Open market
    FE->>API: Fetch active rounds
    API-->>FE: Round data + timers

    U->>FE: Select side and amount
    FE->>RE: enter_position
    RE-->>FE: position recorded

    K->>RE: lock_round
    RE->>CL: read lock price
    RE-->>K: lock saved

    K->>RE: close_round
    RE->>CL: read close price
    RE-->>K: outcome resolved

    FE->>API: Fetch claimable state
    API-->>FE: claimable amount
    U->>RE: claim
    RE-->>U: payout transferred
________________________________________
27. Why this architecture is the right V1
This architecture is correct for V1 because it:
•	keeps oracle dependency simple,
•	avoids the liquidity bootstrapping problem entirely,
•	matches Solana’s low-cost, high-frequency UX,
•	supports richer event types than Pancake immediately,
•	remains compatible with a later exchange roadmap.
Chainlink’s official Solana feed support and Anchor-oriented docs make the oracle side feasible, while Pancake’s current prediction product validates the round-based, oracle-resolved model commercially. (Chainlink Documentation)
________________________________________
28. Recommended next technical doc
The best next doc is:
RetroPick V1 Anchor Program Spec
with:
•	PDA seeds,
•	exact account structs,
•	instruction definitions,
•	round math,
•	claim math,
•	oracle validation logic,
•	keeper transaction sequence.
I can write that next in the same format.

Yes — this repo shape is correct for the product in your docs.
Your docs define RetroPick V1 as a single-chain Solana, oracle-resolved, scheduled event-contract system with a market registry, a round engine, round vault / treasury accounting, user positions, an API/indexer, and a keeper/worker. They also explicitly recommend a clean Anchor workspace with programs/market_registry, programs/round_engine, shared crates for types/math, and app surfaces for web, api, worker.
I’d keep that structure and make one important implementation decision:
V1 should stay two-program, but claim + treasury logic should live inside round_engine at first.
That matches your technical doc: registry stores long-lived market templates; round engine handles create/lock/close/resolve/claim; and claim logic can live inside round engine in V1 to reduce complexity.
________________________________________
1. Recommended repo structure
retropick-v1/
├─ Anchor.toml
├─ Cargo.toml
├─ Cargo.lock
├─ package.json
├─ pnpm-workspace.yaml
├─ turbo.json
├─ .gitignore
├─ .env.example
├─ README.md
├─ docs/
│  ├─ architecture.md
│  ├─ anchor-program-spec.md
│  ├─ pda-seeds.md
│  ├─ state-machine.md
│  ├─ keeper-sequence.md
│  ├─ oracle-integration.md
│  ├─ api-spec.md
│  ├─ db-schema.md
│  ├─ security-invariants.md
│  └─ launch-runbook.md
├─ programs/
│  ├─ market_registry/
│  │  ├─ Cargo.toml
│  │  ├─ Xargo.toml
│  │  └─ src/
│  │     ├─ lib.rs
│  │     ├─ constants.rs
│  │     ├─ errors.rs
│  │     ├─ events.rs
│  │     ├─ state/
│  │     │  ├─ mod.rs
│  │     │  ├─ global_config.rs
│  │     │  └─ market.rs
│  │     ├─ instructions/
│  │     │  ├─ mod.rs
│  │     │  ├─ initialize_global_config.rs
│  │     │  ├─ create_market.rs
│  │     │  ├─ update_market.rs
│  │     │  ├─ pause_market.rs
│  │     │  └─ unpause_market.rs
│  │     └─ utils/
│  │        ├─ mod.rs
│  │        └─ validation.rs
│  └─ round_engine/
│     ├─ Cargo.toml
│     ├─ Xargo.toml
│     └─ src/
│        ├─ lib.rs
│        ├─ constants.rs
│        ├─ errors.rs
│        ├─ events.rs
│        ├─ state/
│        │  ├─ mod.rs
│        │  ├─ round.rs
│        │  ├─ position.rs
│        │  ├─ round_vault.rs
│        │  └─ fee_vault.rs
│        ├─ instructions/
│        │  ├─ mod.rs
│        │  ├─ create_next_round.rs
│        │  ├─ enter_position.rs
│        │  ├─ lock_round.rs
│        │  ├─ close_round.rs
│        │  ├─ cancel_round.rs
│        │  ├─ claim.rs
│        │  ├─ refund_if_cancelled.rs
│        │  ├─ sweep_unclaimed.rs
│        │  └─ withdraw_protocol_fees.rs
│        └─ utils/
│           ├─ mod.rs
│           ├─ oracle.rs
│           ├─ math.rs
│           ├─ resolution.rs
│           ├─ payout.rs
│           └─ guards.rs
├─ crates/
│  ├─ shared_types/
│  │  ├─ Cargo.toml
│  │  └─ src/
│  │     ├─ lib.rs
│  │     ├─ enums.rs
│  │     ├─ params.rs
│  │     ├─ seeds.rs
│  │     └─ serialization.rs
│  └─ math/
│     ├─ Cargo.toml
│     └─ src/
│        ├─ lib.rs
│        ├─ fixed_point.rs
│        ├─ payout.rs
│        ├─ relative_performance.rs
│        └─ range.rs
├─ packages/
│  └─ sdk/
│     ├─ package.json
│     ├─ tsconfig.json
│     └─ src/
│        ├─ index.ts
│        ├─ constants.ts
│        ├─ pda.ts
│        ├─ idl/
│        ├─ clients/
│        │  ├─ registry.ts
│        │  └─ roundEngine.ts
│        ├─ serializers/
│        │  └─ market.ts
│        └─ helpers/
│           ├─ outcome.ts
│           └─ odds.ts
├─ apps/
│  ├─ web/
│  │  ├─ package.json
│  │  ├─ next.config.ts
│  │  ├─ tsconfig.json
│  │  ├─ app/
│  │  │  ├─ page.tsx
│  │  │  ├─ markets/[marketId]/page.tsx
│  │  │  ├─ portfolio/page.tsx
│  │  │  ├─ claims/page.tsx
│  │  │  └─ leaderboard/page.tsx
│  │  ├─ components/
│  │  │  ├─ MarketCard.tsx
│  │  │  ├─ RoundCard.tsx
│  │  │  ├─ PositionCard.tsx
│  │  │  ├─ OracleBadge.tsx
│  │  │  └─ ClaimPanel.tsx
│  │  └─ lib/
│  │     ├─ api.ts
│  │     ├─ wallet.ts
│  │     └─ sdk.ts
│  ├─ api/
│  │  ├─ package.json
│  │  ├─ tsconfig.json
│  │  ├─ src/
│  │  │  ├─ main.ts
│  │  │  ├─ app.module.ts
│  │  │  ├─ modules/
│  │  │  │  ├─ markets/
│  │  │  │  ├─ rounds/
│  │  │  │  ├─ users/
│  │  │  │  ├─ leaderboard/
│  │  │  │  └─ stats/
│  │  │  ├─ prisma/
│  │  │  └─ common/
│  │  └─ prisma/
│  │     ├─ schema.prisma
│  │     └─ migrations/
│  └─ worker/
│     ├─ package.json
│     ├─ tsconfig.json
│     └─ src/
│        ├─ main.ts
│        ├─ scheduler.ts
│        ├─ queue.ts
│        ├─ jobs/
│        │  ├─ create-next-round.job.ts
│        │  ├─ lock-round.job.ts
│        │  ├─ close-round.job.ts
│        │  ├─ retry-round.job.ts
│        │  └─ metrics-rollup.job.ts
│        ├─ services/
│        │  ├─ keeper.service.ts
│        │  ├─ transition.service.ts
│        │  ├─ round-monitor.service.ts
│        │  └─ alerting.service.ts
│        └─ clients/
│           ├─ rpc.client.ts
│           ├─ api.client.ts
│           └─ sdk.client.ts
└─ tests/
   ├─ market-registry.spec.ts
   ├─ round-engine-direction.spec.ts
   ├─ round-engine-threshold.spec.ts
   ├─ round-engine-range.spec.ts
   ├─ round-engine-relative.spec.ts
   ├─ cancellation.spec.ts
   ├─ claim.spec.ts
   └─ keeper-flow.spec.ts
________________________________________
2. Why this structure fits the docs
The docs describe these major boundaries:
•	market registry = long-lived market templates/configuration
•	round engine = per-round runtime
•	shared types + fixed-point math
•	web for discovery/entry/claims/portfolio
•	api/indexer for read models
•	worker/keeper for create/lock/close/retry flows
So the cleanest mapping is:
programs/market_registry
Owns:
•	GlobalConfig
•	Market
•	admin controls
•	feed allowlist
•	fee caps
•	market creation/update/pause
This directly follows the docs’ account model and admin instruction set.
programs/round_engine
Owns:
•	Round
•	Position
•	RoundVault
•	fee accounting
•	create/enter/lock/close/cancel/claim/refund/sweep
This matches the V1 runtime lifecycle and claimability model in the docs.
crates/shared_types
Owns:
•	enums like MarketType, RoundStatus, Outcome
•	market parameter structs
•	PDA seed constants
•	account serialization helpers
This is justified by the docs’ repeated canonical enum/state definitions and the need for consistency across programs.
crates/math
Owns:
•	fixed-point arithmetic
•	payout formula
•	relative-performance return comparison
•	deterministic range-bin selection
Your docs explicitly say relative performance must use fixed-point math, not floating point.
apps/api
Owns:
•	read-optimized API
•	indexer-backed responses
•	leaderboard/stats/user history
That is directly listed in the API/data model sections.
apps/worker
Owns:
•	scheduler
•	due-round polling
•	lock/close/create-next execution
•	retries and alerts
That matches the keeper/orchestrator design: one scheduler process, execution queue, idempotent jobs, replay-safe transitions.
packages/sdk
Owns:
•	TS clients for both programs
•	PDA helpers
•	serializers
•	frontend/worker shared client logic
That keeps web/api/worker from each hand-rolling Anchor calls.
________________________________________
3. Program boundary decisions
A. Registry stays separate
Keep market_registry separate because Market is a long-lived config object, while Round is high-churn runtime state. That separation also keeps round_engine smaller and cleaner.
B. Claims stay inside round_engine
Do not make a separate claim program yet. Your doc already says V1 can keep claim instructions inside round engine to reduce complexity.
C. Treasury split
Do not make a standalone treasury program in V1. Instead:
•	fee_vault and protocol fee withdrawal logic live in round_engine
•	treasury vault pubkey/config is stored in GlobalConfig
This gives modular accounting without over-fragmenting the protocol.
________________________________________
4. Recommended docs folder and technical files
Below are the first technical files I would create.
________________________________________
docs/architecture.md
# RetroPick V1 Architecture

## Summary
RetroPick V1 is an oracle-based scheduled event contract protocol on Solana.
It supports deterministic, machine-resolvable markets only.

V1 primitives:
- Direction
- Threshold
- Range close
- Relative performance

V1 excludes:
- human-judged markets
- sports/politics/social outcome markets
- secondary trading
- AMM/CLOB execution
- disputes layer

## System components

### Onchain
- market_registry program
- round_engine program

### Offchain
- web app
- API/indexer
- worker/keeper

## Design principles
- deterministic resolution from onchain feed snapshots
- one recurring market template => many rounds
- parimutuel pooled payout
- strict round state machine
- cancellation/refund path for invalid oracle conditions

## Core runtime flow
1. Admin creates market template in registry
2. Worker schedules next round in round_engine
3. Users enter positions before lock
4. Keeper locks round and stores oracle lock snapshot
5. Keeper closes round and stores oracle close snapshot
6. Program resolves winner deterministically
7. Users claim winnings
8. Unclaimed funds may be swept after deadline
This file should explicitly mirror the architecture in the technical doc.
________________________________________
docs/anchor-program-spec.md
# RetroPick V1 Anchor Program Spec

## Programs

### market_registry
Purpose:
- own global protocol config
- own long-lived market templates

Instructions:
- initialize_global_config
- create_market
- update_market
- pause_market
- unpause_market

Accounts:
- GlobalConfig
- Market

### round_engine
Purpose:
- manage per-round runtime
- accept user entries
- read oracle values
- resolve rounds
- process claims, refunds, sweeps, fee withdrawal

Instructions:
- create_next_round
- enter_position
- lock_round
- close_round
- cancel_round
- claim
- refund_if_cancelled
- sweep_unclaimed
- withdraw_protocol_fees

Accounts:
- Round
- Position
- RoundVault
- FeeVault
This is the natural follow-up doc your technical spec itself recommends.
________________________________________
docs/pda-seeds.md
# PDA Seeds

## market_registry

### GlobalConfig
seed = ["global-config"]

### Market
seed = ["market", market_id_le_bytes]

## round_engine

### Round
seed = ["round", market_pubkey, round_id_le_bytes]

### Position
seed = ["position", round_pubkey, user_pubkey, outcome_discriminant]

### RoundVault
seed = ["round-vault", round_pubkey]

### FeeVault
seed = ["fee-vault", global_config_pubkey]
Notes
•	all seeds must be deterministic and stable
•	market_id and round_id should be protocol-assigned monotonically increasing integers
•	use explicit discriminants for outcome variants
•	do not derive seeds from mutable market labels or symbols

This follows the docs’ concern about deterministic PDA seeds and claim safety. :contentReference[oaicite:17]{index=17} :contentReference[oaicite:18]{index=18}

---

## `docs/state-machine.md`

```md
# Round State Machine

## States
- Scheduled
- Open
- Locked
- Closed
- Resolved
- Claimable
- Settled
- Cancelled

## Allowed transitions
Scheduled -> Open
Open -> Locked
Locked -> Closed
Closed -> Resolved
Resolved -> Claimable
Claimable -> Settled

Open -> Cancelled
Locked -> Cancelled
Closed -> Cancelled

## Invariants
- users may only enter when round is Open
- lock may only happen once
- close may only happen once
- claim may only happen when round is Claimable
- refund may only happen when round is Cancelled
- sweep_unclaimed may only happen after claim deadline
This comes straight from the docs’ lifecycle/state machine sections.
________________________________________
docs/oracle-integration.md
# Oracle Integration

## V1 oracle strategy
RetroPick V1 uses public Chainlink Data Feeds on Solana only.

V1 does not use:
- custom oracle writing
- offchain signed resolution
- Data Streams

## Lock flow
At lock:
1. verify feed account is allowed
2. read latest feed value
3. validate answer > 0
4. validate freshness window
5. normalize decimals
6. persist lock price and lock timestamp

## Close flow
At close:
1. verify feed account is allowed
2. read latest feed value
3. validate answer > 0
4. validate freshness window
5. normalize decimals
6. persist close price and close timestamp

## Safety checks
- allowlisted feeds only
- positive answer only
- deterministic decimal normalization
- stale feed => round cancel/refund
- feed read failure => round cancel/refund
This is directly aligned with the oracle section and invalid-round policy.
________________________________________
docs/keeper-sequence.md
# Keeper Transaction Sequence

## Responsibilities
- create upcoming rounds
- lock due rounds
- close due rounds
- retry failed transitions
- alert on stale transitions

## Job model
- one scheduler process
- one execution queue
- idempotent jobs
- replay-safe transitions

## create_next_round
Preconditions:
- market active
- no conflicting active scheduled/open round for same slot
- next_round_epoch reached or market requires pre-scheduling

## lock_round
Preconditions:
- round status == Open
- current_time >= lock_ts
- lock snapshot not yet written

## close_round
Preconditions:
- round status == Locked
- current_time >= close_ts
- close snapshot not yet written

## retry policy
- retries must not break invariants
- each instruction must re-check state onchain
- worker never assumes previous step succeeded unless indexed or confirmed
This matches the keeper responsibilities and idempotent job model in the doc.
________________________________________
docs/security-invariants.md
# Security Invariants

## Protocol invariants
- a round may resolve at most once
- a position may claim at most once
- fee amount must be <= configured fee cap
- total_claimed must never exceed distributable pool
- cancelled rounds must never allow claim path
- non-cancelled rounds must never allow refund path

## Oracle invariants
- feed must be allowlisted
- price must be positive
- timestamps must satisfy freshness constraints
- decimals normalization must be deterministic

## Accounting invariants
- round vault balance must cover total_pool minus already-claimed payouts minus swept remainder
- fee withdrawal only touches fee vault
- sweep_unclaimed only after grace deadline

## Solana-specific invariants
- PDA seeds are deterministic
- no transition depends on client-side state alone
- oversized loops are avoided in claim paths
That reflects the documented main risks and protections.
________________________________________
docs/api-spec.md
# API Spec

## Public
GET /markets
GET /markets/:id
GET /markets/:id/rounds
GET /rounds/:id
GET /leaderboard
GET /stats/overview

## User
GET /users/:wallet/positions
GET /users/:wallet/claims
GET /users/:wallet/history

## Internal
POST /keeper/create-next
POST /keeper/lock
POST /keeper/close
This is taken directly from your API surface section.
________________________________________
docs/db-schema.md
# DB Schema

## markets
- id
- type
- feed_1
- feed_2
- cadence
- threshold_json
- bins_json
- fee_bps
- status

## rounds
- id
- market_id
- status
- start_ts
- lock_ts
- close_ts
- lock_price_1
- close_price_1
- lock_price_2
- close_price_2
- winner
- total_pool
- fee_amount

## positions
- id
- round_id
- user
- outcome
- amount
- claimed

## claims
- id
- round_id
- user
- amount
- tx_sig

## market_metrics_daily
- market_id
- day
- volume
- users
- fee_revenue
- rounds_count
This is directly grounded in the indexer schema the docs already define.
________________________________________
5. Program file breakdown
Now I’ll make the technical file intent very explicit.
________________________________________
programs/market_registry/src/lib.rs
use anchor_lang::prelude::*;

pub mod constants;
pub mod errors;
pub mod events;
pub mod instructions;
pub mod state;
pub mod utils;

use instructions::*;

declare_id!("ReplaceWithRegistryProgramId");

#[program]
pub mod market_registry {
    use super::*;

    pub fn initialize_global_config(
        ctx: Context<InitializeGlobalConfig>,
        params: InitializeGlobalConfigParams,
    ) -> Result<()> {
        instructions::initialize_global_config::handler(ctx, params)
    }

    pub fn create_market(
        ctx: Context<CreateMarket>,
        params: CreateMarketParams,
    ) -> Result<()> {
        instructions::create_market::handler(ctx, params)
    }

    pub fn update_market(
        ctx: Context<UpdateMarket>,
        params: UpdateMarketParams,
    ) -> Result<()> {
        instructions::update_market::handler(ctx, params)
    }

    pub fn pause_market(ctx: Context<PauseMarket>) -> Result<()> {
        instructions::pause_market::handler(ctx)
    }

    pub fn unpause_market(ctx: Context<UnpauseMarket>) -> Result<()> {
        instructions::unpause_market::handler(ctx)
    }
}
________________________________________
programs/round_engine/src/lib.rs
use anchor_lang::prelude::*;

pub mod constants;
pub mod errors;
pub mod events;
pub mod instructions;
pub mod state;
pub mod utils;

use instructions::*;

declare_id!("ReplaceWithRoundEngineProgramId");

#[program]
pub mod round_engine {
    use super::*;

    pub fn create_next_round(
        ctx: Context<CreateNextRound>,
        params: CreateNextRoundParams,
    ) -> Result<()> {
        instructions::create_next_round::handler(ctx, params)
    }

    pub fn enter_position(
        ctx: Context<EnterPosition>,
        params: EnterPositionParams,
    ) -> Result<()> {
        instructions::enter_position::handler(ctx, params)
    }

    pub fn lock_round(ctx: Context<LockRound>) -> Result<()> {
        instructions::lock_round::handler(ctx)
    }

    pub fn close_round(ctx: Context<CloseRound>) -> Result<()> {
        instructions::close_round::handler(ctx)
    }

    pub fn cancel_round(
        ctx: Context<CancelRound>,
        reason: CancelReason,
    ) -> Result<()> {
        instructions::cancel_round::handler(ctx, reason)
    }

    pub fn claim(ctx: Context<Claim>) -> Result<()> {
        instructions::claim::handler(ctx)
    }

    pub fn refund_if_cancelled(ctx: Context<RefundIfCancelled>) -> Result<()> {
        instructions::refund_if_cancelled::handler(ctx)
    }

    pub fn sweep_unclaimed(ctx: Context<SweepUnclaimed>) -> Result<()> {
        instructions::sweep_unclaimed::handler(ctx)
    }

    pub fn withdraw_protocol_fees(
        ctx: Context<WithdrawProtocolFees>,
        amount: u64,
    ) -> Result<()> {
        instructions::withdraw_protocol_fees::handler(ctx, amount)
    }
}
These instruction sets are exactly what your docs recommend.
________________________________________
6. Shared types you should define first
crates/shared_types/src/enums.rs
use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum MarketType {
    Direction,
    Threshold,
    Range,
    RelativePerformance,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum MarketStatus {
    Active,
    Paused,
    Disabled,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum RoundStatus {
    Scheduled,
    Open,
    Locked,
    Closed,
    Resolved,
    Claimable,
    Settled,
    Cancelled,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum Outcome {
    Up,
    Down,
    Above,
    Below,
    Bin0,
    Bin1,
    Bin2,
    Bin3,
    AssetA,
    AssetB,
    Draw,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum ThresholdOperator {
    Gt,
    Gte,
    Lt,
    Lte,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum CancelReason {
    OracleUnavailable,
    OracleStale,
    InvalidFeed,
    DrawNotSupported,
    KeeperTimeout,
    ManualAdminCancel,
}
I recommend fixed bin variants (Bin0..Bin3) for V1 instead of Bin(u8) inside account-critical logic. The docs describe four-bin range examples repeatedly, so fixed bins will keep serialization simpler and safer for a first launch.
________________________________________
7. State structs you should implement first
GlobalConfig
#[account]
pub struct GlobalConfig {
    pub admin: Pubkey,
    pub treasury_authority: Pubkey,
    pub fee_collector: Pubkey,
    pub paused: bool,
    pub max_fee_bps: u16,
    pub keeper_authority: Pubkey,
    pub market_creation_disabled: bool,
    pub allowed_feeds_root: Pubkey,
    pub market_count: u64,
    pub bump: u8,
}
Market
#[account]
pub struct Market {
    pub market_id: u64,
    pub status: MarketStatus,
    pub market_type: MarketType,
    pub feed_1: Pubkey,
    pub feed_2: Option<Pubkey>,
    pub quote_decimals: u8,
    pub asset_symbol: [u8; 16],
    pub cadence_sec: i64,
    pub lock_offset_sec: i64,
    pub close_offset_sec: i64,
    pub fee_bps: u16,
    pub min_entry: u64,
    pub max_entry: u64,
    pub next_round_epoch: i64,
    pub creation_authority: Pubkey,
    pub threshold_value: i128,
    pub threshold_operator: ThresholdOperator,
    pub range_count: u8,
    pub range_edges: [i128; 3], // 4 bins
    pub bump: u8,
}
Round
#[account]
pub struct Round {
    pub market: Pubkey,
    pub round_id: u64,
    pub start_ts: i64,
    pub lock_ts: i64,
    pub close_ts: i64,
    pub status: RoundStatus,

    pub lock_price_1: i128,
    pub close_price_1: i128,
    pub lock_price_2: i128,
    pub close_price_2: i128,

    pub total_up: u64,
    pub total_down: u64,
    pub total_above: u64,
    pub total_below: u64,
    pub total_bin0: u64,
    pub total_bin1: u64,
    pub total_bin2: u64,
    pub total_bin3: u64,
    pub total_asset_a: u64,
    pub total_asset_b: u64,

    pub total_pool: u64,
    pub total_claimed: u64,
    pub fee_amount: u64,

    pub winning_outcome: Outcome,
    pub cancelled: bool,
    pub claim_deadline_ts: i64,
    pub bump: u8,
}
Position
#[account]
pub struct Position {
    pub owner: Pubkey,
    pub round: Pubkey,
    pub outcome: Outcome,
    pub amount: u64,
    pub claimed: bool,
    pub bump: u8,
}
This is based on your core account model: GlobalConfig, Market, Round, Position, RoundVault.
________________________________________
8. Math crate responsibilities
Your docs clearly say V1 is parimutuel pooled payout, and relative-performance must use fixed-point math.
So crates/math should expose only a few things:
fixed_point.rs
•	decimal normalization
•	safe mul/div helpers
•	signed return calculations
payout.rs
pub fn fee_amount(total_pool: u64, fee_bps: u16) -> u64
pub fn distributable_pool(total_pool: u64, fee_amount: u64) -> u64
pub fn winner_payout(user_stake: u64, winner_pool: u64, distributable: u64) -> u64
relative_performance.rs
pub fn normalized_return(lock: i128, close: i128, scale: i128) -> Result<i128>
pub fn compare_returns(
    lock_a: i128,
    close_a: i128,
    lock_b: i128,
    close_b: i128,
    scale: i128,
) -> Result<Ordering>
range.rs
pub fn select_bin(close_price: i128, edges: &[i128; 3]) -> u8
________________________________________
9. SDK file layout
The SDK should not be generic. It should be product-shaped.
packages/sdk/src/index.ts
export * from "./constants";
export * from "./pda";
export * from "./clients/registry";
export * from "./clients/roundEngine";
export * from "./helpers/outcome";
export * from "./helpers/odds";
clients/registry.ts
•	initialize config
•	create market
•	update market
•	pause/unpause
clients/roundEngine.ts
•	create next round
•	enter position
•	lock round
•	close round
•	claim
•	refund
•	sweep
pda.ts
•	derive globalConfigPda
•	derive marketPda
•	derive roundPda
•	derive positionPda
•	derive roundVaultPda
•	derive feeVaultPda
This keeps your web app and worker operating against the same source of truth.
________________________________________
10. API module structure
Your docs define public, user, and internal keeper endpoints.
So structure apps/api/src/modules like this:
modules/
  markets/
    markets.controller.ts
    markets.service.ts
    markets.repository.ts
  rounds/
    rounds.controller.ts
    rounds.service.ts
    rounds.repository.ts
  users/
    users.controller.ts
    users.service.ts
  leaderboard/
    leaderboard.controller.ts
    leaderboard.service.ts
  stats/
    stats.controller.ts
    stats.service.ts
  internal/
    internal.controller.ts
    internal.service.ts
Prisma tables
Mirror the doc exactly at first:
•	markets
•	rounds
•	positions
•	claims
•	market_metrics_daily
Do not invent too many tables yet.
________________________________________
11. Worker architecture
The docs are very explicit here: scheduler, execution queue, idempotent jobs, replay-safe transition checks.
So your worker should be:
scheduler
Find due work:
•	markets needing next round
•	rounds needing lock
•	rounds needing close
•	stale/failed transitions
queue
Dispatch jobs with dedupe key:
•	create-next:{marketId}:{epoch}
•	lock:{roundPubkey}
•	close:{roundPubkey}
transition service
Before every tx:
•	re-fetch round state
•	verify status still needs action
•	send tx only if valid
That makes the offchain layer safe against retry storms.
________________________________________
12. File-by-file priority order
Build in this order:
Phase 1 — foundation
1.	crates/shared_types
2.	crates/math
3.	programs/market_registry state + create/update
4.	programs/round_engine state + create_next_round
5.	docs/anchor-program-spec.md
6.	docs/pda-seeds.md
Phase 2 — direction market complete
7.	enter_position
8.	lock_round
9.	close_round
10.	claim
11.	refund_if_cancelled
12.	tests for direction round lifecycle
Phase 3 — richer markets
13.	threshold resolution
14.	range resolution
15.	relative performance resolution
16.	API/indexer
17.	worker
18.	web
This follows your roadmap: direction first, then threshold/range, then relative performance and fuller analytics.
________________________________________
13. What not to add to repo yet
Per your own docs, do not add these folders yet:
programs/orderbook/
programs/amm/
programs/disputes/
programs/market_factory_permissionless/
packages/maker-bot/
apps/pro/
Because V1 explicitly excludes:
•	CLOB
•	LS-LMSR
•	arbitrary user-generated markets
•	dispute arbitration
•	AMM/order book execution
•	multi-chain deployment
________________________________________
14. My practical recommendation
If you want the cleanest repo for an actual build:
•	keep 2 Anchor programs
•	keep claim + treasury logic inside round_engine
•	keep range markets capped at 4 bins in V1
•	keep one worker service only
•	keep one SDK shared by web/api/worker
•	keep docs/ as a first-class engineering surface, not an afterthought
That is the best balance between your docs’ modularity and your actual V1 need for speed and simplicity.
Next, I can write the actual contents for these two files in full:
docs/anchor-program-spec.md
docs/pda-seeds.md
with exact account structs, seed formulas, and instruction-by-instruction spec.


