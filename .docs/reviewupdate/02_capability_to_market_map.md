# RetroPick Capability to Market Map

## 1) Purpose

This document maps current smart contract capabilities to market opportunities and clearly separates:
- **Now**: safe to launch with current architecture and constraints,
- **Next**: feasible with limited additive changes,
- **Later**: needs significant oracle/architecture/product changes.

## 2) Capability summary from current engine

Current strengths:
- modular UUPS dispatcher with template-driven market lifecycle,
- manual and rolling execution modes,
- multi-oracle-class routing for threshold-like products,
- advanced resolver families already present in architecture,
- reserve accounting and fee/yield plumbing.

Operational constraints that directly affect product strategy:
- rolling mode is not available for all market families,
- TrustedReporter templates are manual-only,
- some path-dependent types require OHLC data and are unsafe on pure Chainlink close-only path,
- template behavior has opinionated defaults that reduce customization.

## 3) Market-readiness matrix

| Market family | Operational fit now | Recommended status | Primary user fit | Notes |
|---|---|---|---|---|
| Direction | High (rolling compatible) | **Now** | Crypto-native | Best retention loop template. |
| Threshold | High (rolling compatible) | **Now** | Crypto + non-crypto | Core bridge to macro/rate/NAV style markets via oracle class. |
| RangeClose | High (rolling compatible) | **Now** | Crypto + non-crypto | Differentiates from plain yes/no and up/down products. |
| Velocity | High (rolling compatible in current model) | **Now / Early next** | Crypto-native advanced | Strong volatility expression primitive. |
| Ladder | Medium-high | **Next** | Advanced users | Differentiated payout structure; careful UX needed. |
| Convergence | Medium (manual-only) | **Next** | Pro users | Dual-feed sophistication with lower operational throughput. |
| Composite | Medium (manual-only) | **Next** | Pro + macro users | High strategic value for multi-signal theses. |
| Corridor | Low-medium (requires OHLC on TRO path) | **Later** | Non-crypto utility and risk users | Avoid chainlink-only launch due to correctness risks. |
| Cascade | Low-medium (requires OHLC on TRO path) | **Later** | Advanced structured users | Path-dependent; high complexity and messaging burden. |

## 4) Product packages from technical primitives

## Package A: Pulse Markets (launch wedge)
- Templates: `Direction`, `Threshold`, `RangeClose`
- Cadence: 5m, 15m, 1h, daily close
- Users: crypto-native first, then mainstream traders
- Why: strongest operations and simplest learning curve

## Package B: Signal Markets (phase 2)
- Templates: `Velocity`, `Ladder`
- Cadence: hourly/daily/weekly
- Users: advanced retail and creator analysts
- Why: meaningful differentiation without full oracle architecture expansion

## Package C: Intelligence Markets (phase 2+)
- Templates: `Convergence`, `Composite`
- Cadence: daily/weekly
- Users: macro-oriented and sophisticated users
- Why: unique thesis expression format; likely higher-quality creator content

## Package D: Path Markets (phase 3)
- Templates: `Corridor`, `Cascade`
- Cadence: daily/weekly windows
- Users: specialist and utility-oriented hedging users
- Why: strongest novelty, but depends on robust OHLC event-oracle operations

## 5) Avoid zones right now

- Do not ship `Corridor`/`Cascade` on chainlink-only close-price semantics.
- Do not market "fully automated event markets" where TrustedReporter manual lifecycle is required.
- Do not over-expand catalog breadth before proving concentration and repeat usage in launch templates.
- Do not promise deep per-template fee-policy flexibility until defaults are made configurable.

## 6) Capability-backed differentiation

RetroPick differentiation should be framed as:
1. deterministic settlement transparency,
2. richer template surface than binary incumbents,
3. rolling lifecycle efficiency for high-frequency products,
4. progressive path from speculative to utility/hedging use cases.

## 7) Recommended launch-safe template list

Prioritized launch-safe list:
- `Direction`: BTC, ETH, SOL short-cycle rounds,
- `Threshold`: daily/weekly directional thresholds on major assets and macro-linked feeds,
- `RangeClose`: curated daily close-range products on highly followed assets,
- selective `Velocity` pilots after baseline metrics stabilize.

This list balances operational confidence and visible product differentiation without overreaching into oracle-dependent complexity too early.
