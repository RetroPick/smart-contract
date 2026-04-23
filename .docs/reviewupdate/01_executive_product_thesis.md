# RetroPick Executive Product Thesis

## 1) What RetroPick is

RetroPick is a deterministic, oracle-resolved event market protocol built on an EVM architecture (current deployment and operations are Arbitrum-oriented). The core product insight is to ship a market engine that is more expressive than basic binary prediction rounds, but much simpler to operate than a full order-book exchange.

The technical foundation in `MarketEngineDispatcher` and lifecycle modules supports:
- recurring rolling rounds for high-frequency markets,
- template-based market creation across multiple market types,
- deterministic settlement rules tied to oracle checkpoints,
- treasury and optional yield routing mechanics.

## 2) Canonical strategic position

RetroPick should position itself as:
- **A programmable market engine for machine-resolvable events**, not a generic "betting app."
- **A hybrid product path**: crypto-native retention wedge first, then non-crypto financial utility expansion.
- **A trust-forward protocol**: explicit rule visibility, deterministic formulas, and transparent settlement data.

## 3) Problem statement

Current market offerings leave a gap:
- simple prediction apps are sticky but narrow,
- rich prediction platforms often rely on subjective resolution or complex market microstructure,
- non-crypto users need understandable, utility-oriented contracts, not pure speculation UX.

RetroPick can fill that gap by combining automation, richer market templates, and a "hedge + view expression" framing.

## 4) Core customer segments

## Segment A: Crypto-native active traders
- Jobs-to-be-done: frequent expression of directional or volatility conviction, rapid loops, composable on-chain participation.
- Product pull: rolling rounds, differentiated market templates beyond plain up/down.
- Success signal: high weekly participation frequency and repeat staking behavior.

## Segment B: Financially exposed non-crypto users
- Jobs-to-be-done: simple event-based hedging around assets/rates/macro indicators they already track.
- Product pull: clear rule cards, transparent settlement, low cognitive load.
- Success signal: repeat usage in longer cadence markets (daily/weekly), not one-off novelty use.

## Segment C: Creators/analysts/distribution partners
- Jobs-to-be-done: publish thesis markets, build audience, monetize attention and forecasting skill.
- Product pull: templated market creation with strict oracle constraints.
- Success signal: creator-driven inflow as a share of new users.

## 5) Product strategy principles

1. **Determinism over narrative flexibility**  
   If a market cannot be settled by explicit formula and trusted data path, it is out of scope for near-term launch.

2. **Operational safety over catalog breadth**  
   Launch on market types that are already production-safe with current engine constraints.

3. **Liquidity concentration over long-tail fragmentation**  
   Start with fewer, repeated, high-clarity market archetypes.

4. **Trust UX is product, not compliance overhead**  
   Lock price, close price, feed source, and settlement logic must be obvious at market card level.

## 6) Strategic contradictions to resolve now

Current docs show narrative mismatch across chain focus and scope. The operating baseline for this strategy pack is:
- **Chain and architecture baseline:** EVM deployment reality first (Arbitrum/Base-compatible path), while keeping Solana expansion as a future track.
- **Product scope baseline:** prioritize machine-resolvable financial/event contracts; do not message broad subjective categories as near-term core.

## 7) Why now

- Infrastructure maturity: modular dispatcher architecture already supports scalable template operations.
- User demand: appetite exists for short-cycle market participation and structured volatility/range products.
- Market whitespace: few platforms combine deterministic settlement + advanced market types + creator-led distribution in one coherent system.

## 8) Strategic objective (12-month)

Build RetroPick into the default deterministic event market layer for:
- high-frequency crypto-native engagement,
- utility-oriented macro/financial event expression,
- creator-led market distribution with transparent settlement.

The objective is not "be the biggest prediction exchange quickly." The objective is to establish category ownership in deterministic, template-programmable event contracts with strong repeat usage.

## 9) North-star outcomes

- Establish a repeatable wedge with concentrated recurring templates.
- Prove PMF through behavior metrics (retention + repeat participation + creator pull).
- Expand safely into higher-differentiation templates only after operational and demand validation.
