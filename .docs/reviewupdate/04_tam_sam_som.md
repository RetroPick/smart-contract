# RetroPick TAM / SAM / SOM Model

## 1) Model intent

This sizing model is designed for strategic planning, not absolute forecasting.  
It uses:
- a **top-down lens** (global addressable pools),
- a **bottom-up lens** (user, frequency, stake, fee mechanics),
- low/base/high scenarios with explicit assumptions.

All numbers are directional planning ranges in USD-equivalent terms.

## 2) Market definitions

- **TAM (Total Addressable Market):** global users and flows that could theoretically use deterministic event contracts for speculative expression or hedging.
- **SAM (Serviceable Addressable Market):** TAM segments that are reachable under RetroPick's current product/chain/operational constraints.
- **SOM (Serviceable Obtainable Market):** realistic 12-24 month capture based on execution capacity and wedge strategy.

## 3) Top-down model

## TAM (global)

RetroPick TAM includes:
1. active crypto market participants with appetite for event-expression products,
2. retail/prosumer users expressing macro/asset directional views,
3. creator-driven forecasting audiences that can convert to transactional participation.

Directional TAM estimate (annual gross participation volume potential):
- **Low:** $8B
- **Base:** $20B
- **High:** $45B

Rationale:
- combines speculative event-expression demand + utility/hedging adjacent usage,
- excludes institutional derivative books where RetroPick is not competitive today.

## SAM (reachable with current and near-term architecture)

SAM focus slices:
- rolling-compatible crypto templates (`Direction`, `Threshold`, `RangeClose`, selective `Velocity`),
- curated daily/weekly financial and macro templates with deterministic rules,
- creator-led channels where onboarding friction is manageable.

Directional SAM estimate (annual):
- **Low:** $600M
- **Base:** $1.8B
- **High:** $4.5B

## SOM (12-24 month obtainable)

SOM is based on concentrated wedge execution, not broad catalog expansion.

Directional SOM estimate (annual):
- **Low:** $6M
- **Base:** $22M
- **High:** $70M

These figures represent annual gross participation volume processed through RetroPick templates in early scale stage.

## 4) Bottom-up model

## Core formula

Annual gross participation volume:

`Users * ActiveWeeksPerYear * MarketsPerWeek * AvgStakePerMarket`

Protocol revenue proxy:

`AnnualGrossParticipationVolume * EffectiveTakeRate`

Where effective take rate includes settlement/participation fee economics and excludes incentives/rebates.

## Base scenario assumptions (planning baseline)

- Monthly active users at year-end: 35,000
- Average active weeks per user-year: 18
- Average markets per active week: 3.2
- Average stake per market: $11
- Effective take rate: 2.8%

Calculated outputs:
- Annual gross participation volume ~= $22.2M
- Annualized protocol fee revenue proxy ~= $622k

## Low and high scenario table

| Scenario | Users | Active weeks | Markets/week | Avg stake | Annual volume | Effective take |
|---|---:|---:|---:|---:|---:|---:|
| Low | 12,000 | 12 | 2.1 | $7 | ~$2.1M | 2.2% |
| Base | 35,000 | 18 | 3.2 | $11 | ~$22.2M | 2.8% |
| High | 90,000 | 24 | 4.2 | $15 | ~$136.1M | 3.0% |

## 5) SOM wedge strategy by geography and user type

## Stage 1 SOM (0-9 months)
- Geo: global crypto online users with optional GCC/MENA focused campaigns.
- Product: high-frequency and daily deterministic templates.
- Channel: creator-led and referral-led market discovery.
- Target: concentration over breadth.

## Stage 2 SOM (9-18 months)
- Geo: expansion into broader non-crypto financial users in selected regions.
- Product: utility-framed threshold/range/velocity products.
- Channel: educational distribution + creator partnerships.
- Target: increase repeat weekly participation, not just acquisition.

## Stage 3 SOM (18-24+ months)
- Geo: extend to region-specialized categories where legal and data paths are strong.
- Product: selective advanced templates (`Ladder`, `Convergence`, `Composite`) with clear UX.
- Channel: verticalized communities and professional signal creators.

## 6) Assumption register (must be tracked monthly)

1. Wallet/onboarding friction can be reduced enough for recurring usage.
2. Liquidity concentration can be maintained in curated templates.
3. Creator channels can sustainably drive lower-CAC users.
4. Deterministic trust framing improves conversion/retention versus generic alternatives.
5. Operational uptime and oracle correctness remain high enough to avoid trust breaks.

## 7) What changes the model most

Biggest upside drivers:
- higher markets-per-user frequency,
- creator-driven distribution efficiency,
- stronger weekly retention.

Biggest downside drivers:
- fragmented catalog with weak liquidity,
- unresolved messaging mismatch across chain/scope,
- oracle/settlement incidents reducing trust.

## 8) Recommendation

Use the **base case as operational target** and track a rolling variance versus low/high monthly.  
Do not optimize for maximum TAM narrative early; optimize for repeat behavior in a narrow SOM wedge and expand only after retention proof.

## 9) Worldwide need map (crypto vs non-crypto)

## Crypto-native worldwide needs
- fast repeatable conviction expression,
- transparent and fair settlement,
- richer formats than binary loops without full derivatives complexity.

## Non-crypto worldwide needs
- plain-language event contracts tied to familiar indicators,
- confidence in objective outcomes,
- lower-friction onboarding and clear risk framing.

## Practical implication for sizing
- TAM should include both cohorts, but **SOM should be captured from crypto wedge first**.
- Non-crypto capture should be modeled as conditional upside unlocked by onboarding and trust UX proof.
