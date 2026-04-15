Here's a markdown version of the document:

```markdown
# RetroPick Protocol
## Base L2 — Full Chainlink Oracle Innovation Plan

> **Implementation migration note (breaking):**
> Runtime `MarketType` enum has been consolidated. Threshold-style variants are now routed through
> canonical `Threshold` (or `Direction` for directional IRC mode) with `oracleClass` and template metadata.
> Mapping: Anchor/VolatilityBand/StakingAPR/NAVThreshold/MacroEvent -> Threshold; BitcoinIRC -> Direction or Threshold.

*Price Feeds · Rate & Volatility · SmartData · US Government Macro · DataLink — Expanded Market Types & Use Cases*

| | |
|---|---|
| **Entity** | RetroPick FZ-LLC — RAK DAO, Ras Al Khaimah, UAE |
| **Target chain** | Base Mainnet (OP Stack L2, Coinbase-operated sequencer) |
| **L2 sequencer feed** | `0xBCF85224fc0756B9Fa45aA7892530B47e10b6433` (Base Sequencer Uptime) |
| **Flags registry** | `0x71c5CC2aEB9Fa812CA360E9bAC7108FC23312cdd` (Base Chainlink flag registry) |
| **Oracle standard** | AggregatorV3Interface · `latestRoundData()` — identical across all 6 feed families |
| **Document version** | V3.0 — April 2026 — Confidential |

---

## 1. Why Base L2 + Full Chainlink Ecosystem = Strategic Advantage

RetroPick's migration to Base unlocks the entire Chainlink data ecosystem that is live on Base mainnet — not just BTC/USD and ETH/USD. Chainlink operates six distinct data feed families on Base, each using the same AggregatorV3Interface. Every new family maps to a new class of prediction market that no competitor offers.

> **The core thesis: one oracle interface, six product dimensions**
>
> 1. **Price Feeds** → Direction, Threshold, RangeClose, Velocity, Anchor, Ladder, Cascade, Corridor, Convergence, Composite (10 market types, 60+ live feeds on Base)
>
> 2. **Rate & Volatility Feeds** → VolatilityBand, StakingAPR, BitcoinIRC (3 market types — zero competitors offer these)
>
> 3. **SmartData (NAV / AUM / Proof of Reserve)** → TokenizedFundNAV, ReserveHealth (2 market types — first in any prediction market)
>
> 4. **US Government Macro Feeds** → MacroEvent with fully decentralised BEA oracle, not TrustedReporter (launched Aug 2025)
>
> 5. **Tokenized Equity Feeds (Ondo Finance on Base)** → tokenized stock/ETF direction markets (AAPL, TSLA, SPY, QQQ — never done before)
>
> 6. **DataLink (FTSE Russell, Deutsche Börse, Tradeweb, S&P Global)** → institutional index and treasury benchmark markets (2025–2026, emerging)

The engineering cost of unlocking feed families 2–6 is minimal: a new adapter contract (~30 lines, identical pattern to ChainlinkAdapter) per family, plus new template configurations. The product expansion is unlimited. This document is the full playbook for executing that expansion on Base.

---

## 2. Base L2 Infrastructure — Oracle Setup

### 2.1 L2 Sequencer Uptime Check (Mandatory on Base)

All Chainlink data feed reads on Base MUST check sequencer uptime before consuming data. Per Chainlink's official documentation, if the Base sequencer goes down, price feeds stop updating but `latestRoundData()` may still return stale values. The sequencer uptime check prevents your engine from consuming stale oracle data during a sequencer outage.

```solidity
// BaseSequencerChecker.sol — REQUIRED for all oracle reads on Base

address constant BASE_SEQUENCER_FEED = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
uint256 constant GRACE_PERIOD = 3600; // 1 hour after sequencer recovery

function _checkSequencer() internal view {
    (, int256 answer, uint256 startedAt,,) = 
        AggregatorV3Interface(BASE_SEQUENCER_FEED).latestRoundData();
    require(answer == 0, 'Sequencer down');
    require(block.timestamp - startedAt > GRACE_PERIOD, 'In grace period');
}

// Called before every latestRoundData() in lockEpoch and resolveEpoch
```

### 2.2 ChainlinkAdapter — Base Deployment

The existing ChainlinkAdapter pattern deploys unchanged on Base. The only difference from Arbitrum is the sequencer feed address. All proxy feed addresses are Base-specific (different from Ethereum/Arbitrum for the same asset pair). `feedId = bytes32(uint256(uint160(baseProxyAddress)))`.

```solidity
// Deploy on Base: pass Base sequencer feed address
ChainlinkAdapter adapter = new ChainlinkAdapter(
    0xBCF85224fc0756B9Fa45aA7892530B47e10b6433 // Base sequencer uptime feed
);

// RateAdapter (new — same pattern, for Rate/Vol/APR feeds)
RateAdapter rateAdapter = new RateAdapter(
    0xBCF85224fc0756B9Fa45aA7892530B47e10b6433 // same sequencer check
);

// MacroAdapter (new — same pattern, for US Gov Macro feeds)
MacroAdapter macroAdapter = new MacroAdapter(
    0xBCF85224fc0756B9Fa45aA7892530B47e10b6433
);
```

---

## 3. Chainlink Price Feeds on Base — Complete Market Catalogue

Base mainnet has 90+ Chainlink price feeds verified on basescan.org. Below is the full catalogue grouped by asset class, with confirmed proxy addresses, heartbeat/deviation parameters, and the specific RetroPick market types each feed enables. Every feed is verifiable at [docs.chain.link/data-feeds/price-feeds/addresses](https://docs.chain.link/data-feeds/price-feeds/addresses) (select Base network).

### 3.1 Crypto / USD — Core Feeds

| **Pair** | **Dec** | **Base proxy address** | **Heartbeat / dev** | **Market types** |
|---|---|---|---|---|
| **ETH/USD** | 8 | `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70` | 1h / 0.15% | Direction, Velocity, VolatilityBand, Ladder, Anchor |
| **BTC/USD** | 8 | `0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F` | 1h / 0.05% | Direction, Velocity, Ladder, Cascade, Anchor, Composite |
| **SOL/USD** | 8 | `0x975043adBb80fc32276CbF9Bbcfd4A601a12462D` | 1h / 0.1% | Direction, Threshold, Momentum |
| **LINK/USD** | 8 | `0x17CAb8Fe31E32f08326e5E27412894e49B0f9D65` | 1h / 0.5% | Direction, Threshold |
| **ARB/USD** | 8 | `0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6` | 1h / 0.5% | Direction, Threshold |
| **OP/USD** | 8 | `0x0a1D1b9f7Ed17a17Ae35Dd2a56D6f07a54a6bB6A` | 24h / 1% | Direction |
| **AAVE/USD** | 8 | `0xe64f81abef9f6F6b061fFA0B3A70f0E2B5c7B69` | 24h / 1% | Direction, Threshold |
| **UNI/USD** | 8 | `0xa0E730E80b68bc3a41d5c92b89aA43c3D7A0Ab7e` | 24h / 1% | Direction |
| **USDC/USD** | 8 | `0x7e860098F58bBFC8648a4311b374B1D669a2bc9B` | 24h / 0.1% | Corridor (depeg: $0.995–$1.005) |
| **USDT/USD** | 8 | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` | 24h / 0.1% | Corridor (depeg monitoring) |

### 3.2 LST / LRT Feeds — Base-Native Staking Assets

Base has native liquid staking tokens with dedicated Chainlink feeds. These are critically important for DeFi prediction markets. cbETH is Coinbase's liquid staking token, natively issued on Base. wstETH is Lido's wrapped staked ETH bridged to Base. These feeds enable a new category of market: yield-bearing asset direction predictions.

| **Pair** | **Dec** | **Base proxy address** | **Heartbeat / dev** | **Market type / innovation** |
|---|---|---|---|---|
| **cbETH/USD** | 8 | `0xd7818272B9e248357d13057AAb0B417aF31E817d` | 1h / 0.5% | cbETH Direction, cbETH/ETH convergence |
| **cbETH/ETH** | 18 | `0x806b4Ac04501c29769051e42783cF04dCE41440b` | 24h / 0.5% | cbETH premium/discount vs ETH — Convergence market |
| **wstETH/USD** | 8 | `0x43a5C292A453A3bF3606fa1840ae173Da62D18f` | 24h / 0.5% | wstETH Direction, staking yield capture |
| **wstETH/ETH** | 18 | `0xa669E5272E60f78299F4824495cE01a3923f4380` | 24h / 0.5% | wstETH/ETH exchange rate — StakingAPR proxy |
| **stETH/USD** | 8 | `0xf586d0728a47229e747d824a939000Cf21dEF5A0` | 24h / 0.5% | Direction, Threshold |
| **rETH/ETH** | 18 | `0x3D3f5B4a0be4b5DeB55BF2857e22A2B84aF28d20` | 24h / 0.5% | rETH/ETH exchange rate — Composite with wstETH |

> **Innovation: cbETH/ETH Convergence Market**
>
> This is entirely new in prediction markets. cbETH/ETH fluctuates between 1.01 and 1.06 ETH based on staking rewards accrual. A Convergence market asks: will the cbETH/ETH ratio converge toward (or diverge from) the wstETH/ETH ratio this week? Two Chainlink feeds, one resolver, zero human judgment. DeFi stakers and yield farmers understand this product immediately.

### 3.3 Commodities — Metals, Energy, Agriculture

| **Asset** | **Dec** | **Base proxy address** | **Heartbeat / dev** | **Market types** |
|---|---|---|---|---|
| **XAU/USD (Gold)** | 8 | `0xFFE405EB4D20b680e1A7eF62e5E34E1498D0d7a4` | 1h / 0.1% | Direction, Threshold, Velocity, Corridor, Ladder, Anchor |
| **XAG/USD (Silver)** | 8 | `0x9dFC79Aaeb5bb0f96C6e8402099D9B5B6Ed49CC` | 24h / 0.5% | Direction, Threshold, Convergence (vs Gold) |
| **WTI/USD (Oil)** | 8 | `0x6cF2f5c1A5d65cdD2C2EAb9D2A7e9B6b6E4aAbf` | 1h / 0.5% | Direction, Threshold, Corridor, Composite (oil+FX) |
| **Nat Gas/USD** | 8 | Verify at docs.chain.link — Base node | 24h / 0.5% | Direction, Threshold (seasonal) |

### 3.4 Forex / USD Pairs

Chainlink forex feeds on Base source from 3+ premium market data vendors including ICE (Intercontinental Exchange, NYSE parent) — as per the Aug 2025 ICE-Chainlink partnership. These are institutional-grade FX rates, not web-scraped data.

| **Pair** | **Dec** | **Base proxy address** | **Heartbeat / dev** | **Market types** |
|---|---|---|---|---|
| **EUR/USD** | 8 | `0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F` | 1h / 0.1% | Direction, Corridor, Convergence (EUR/GBP spread) |
| **GBP/USD** | 8 | `0x84b97F0f94E96CE8C23E94AE22A50cBFAA98B1BA` | 1h / 0.1% | Direction, Corridor, Convergence |
| **JPY/USD** | 8 | `0x5E1A8e4f6Ef87C61F1d8E91F12AAaF2d04E28c59` | 1h / 0.1% | Direction (BOJ intervention), Corridor |
| **AUD/USD** | 8 | `0x4498C77ff12a72F5D9BB447AD8C3B39050d89F` | 24h / 0.2% | Direction, Threshold |
| **CAD/USD** | 8 | `0xD0b9B18cAF9d21a0b98fC38ceD16391AF4Afef8A` | 24h / 0.2% | Direction, Corridor |
| **CHF/USD** | 8 | `0xd5e3B1571E5C34d5dF6B350C72DF3b3D3c7F9b` | 24h / 0.2% | Direction (SNB intervention) |

*Note: For GCC-specific pairs (USD/AED, USD/SAR), use TrustedReporterAdapter sourcing from ExchangeRate-API or CBUAE. These are not covered by Chainlink on Base but are a RetroPick first-mover opportunity.*

### 3.5 Tokenized Equities on Base (Ondo Finance Partnership)

This is one of the most important developments in the entire prediction market landscape. Chainlink launched Tokenized Equity Feeds via the Ondo Finance partnership in 2025. Real-time NAV and price data for tokenized US stocks and ETFs is now onchain — on Base. RetroPick can create prediction markets on tokenized Apple, Tesla, or S&P 500 ETF prices, resolved deterministically from a Chainlink oracle. No prediction market has ever offered this.

| **Asset** | **Dec** | **Description / Oracle Source** | **Market types enabled** |
|---|---|---|---|
| **ONDO OUSG NAV/USD** | 8 | Ondo US Gov Bond tokenized fund — Chainlink NAVLink on Base | NAV Threshold: will OUSG NAV exceed $X? Anchor: vs quarterly open |
| **ONDO USDY NAV/USD** | 8 | Ondo US Dollar Yield tokenized note | NAV Direction: is USDY NAV rising? Corridor: within $0.01 of peg? |
| **Tokenized SPY/USD** | 8 | Via Ondo Global Markets — Chainlink equity feed on Base | Direction: will tokenized SPY be up this week? |
| **Tokenized QQQ/USD** | 8 | Via Ondo — Nasdaq 100 ETF tokenized | Direction, Threshold: will tokenized QQQ beat $X? |
| **Tokenized AAPL/USD** | 8 | Ondo Global Markets — single-stock equity | Direction, post-earnings Threshold |
| **Tokenized TSLA/USD** | 8 | Ondo Global Markets — high-volatility equity | Velocity (TSLA is the most volatile S&P 500 stock) |
| **Tokenized NVDA/USD** | 8 | Ondo Global Markets — AI/semiconductor | Direction, Momentum (AI sector market) |
| **Tokenized MSFT/USD** | 8 | Ondo Global Markets — large cap | Anchor (vs fiscal year open), Threshold |

> **Strategic moat: tokenized equity prediction markets**
>
> No prediction market in the world has oracle-resolved tokenized equity direction markets. Kalshi has earnings-beat binary markets with human resolution. Polymarket has none. RetroPick + Base + Ondo + Chainlink = the world's first deterministic, oracle-resolved prediction market on tokenized Apple, Tesla, and S&P 500 ETF prices.
>
> These markets appeal to: (a) traditional investors who already hold tokenized stocks on Ondo and want to hedge; (b) crypto-native traders who want equity exposure without touching a brokerage; (c) normie finance users who understand 'will Apple be up this week?' immediately.

---

## 4. Rate & Volatility Feeds — Three New Market Types

Chainlink Rate & Volatility Feeds provide Bitcoin Interest Rate Curve (CF BIRC), ETH Staking APR (30-day and 90-day rolling), and realized volatility for BTC and ETH across 24h, 7d, and 30d windows. All use the same AggregatorV3Interface. A new RateAdapter contract (~30 lines, identical pattern to ChainlinkAdapter) is all that is required to consume them.

> **Why this has never existed in any prediction market**
>
> Every prediction market asks 'up or down'. Rate & Volatility feeds let RetroPick ask: 'is BTC lending rate above 8%?', 'is ETH staking yield falling?', 'is crypto volatility elevated or suppressed right now?' These are the questions institutional traders, options desks, and yield farmers ask every day. No platform routes them to a prediction market. RetroPick + Base + Chainlink Rate Feeds is the first.

### 4.1 Realized Volatility Feeds

| **Feed name** | **What it measures** | **Update model** | **RetroPick market type** |
|---|---|---|---|
| **BTC RVOL 24h** | BTC price volatility — annualised % over last 24h | Every 10min deviation + 1h heartbeat | VolatilityBand: is BTC vol above 60% today? |
| **BTC RVOL 7d** | BTC volatility annualised over rolling 7 days | Deviation + 24h heartbeat | VolatilityBand: weekly vol regime prediction |
| **BTC RVOL 30d** | BTC volatility annualised over rolling 30 days | Deviation + 24h heartbeat | Anchor (vs 30d average), Threshold |
| **ETH RVOL 24h** | ETH annualised volatility — 24h window | Every 10min deviation + 1h heartbeat | VolatilityBand: is ETH vol above 70% today? |
| **ETH RVOL 7d** | ETH volatility — 7d rolling | Deviation + 24h heartbeat | VolatilityBand + Convergence (vs BTC vol) |

### 4.2 ETH Staking APR Feeds

| **Feed name** | **What it measures** | **Update model** | **RetroPick market type** |
|---|---|---|---|
| **ETH Staking APR 30d** | Annualised return from ETH validator staking — 30d rolling | Daily (minimum) | StakingAPR Threshold: will APR exceed 4.5%? |
| **ETH Staking APR 90d** | Annualised return — 90d rolling window | Daily | StakingAPR quarterly trend, Direction |

### 4.3 Bitcoin Interest Rate Curve (CF BIRC)

The Bitcoin Interest Rate Curve (CF BIRC) is Chainlink's live onchain benchmark for BTC lending/borrowing rates. It aggregates OTC lending desk rates, DeFi lending pool rates, and perpetual futures funding. As institutional BTC lending scales via Aave, Morpho, and WBTC collateral protocols, this rate moves institutional capital.

| **Feed** | **Data sources aggregated** | **RetroPick market type** |
|---|---|---|
| **BTC IRC Daily** | OTC lending desks + DeFi pools (Aave, Compound) + perp funding rates | BitcoinIRC Direction: will rate be higher tomorrow? BitcoinIRC Threshold: will rate exceed 8% annualised? |

### 4.4 New Resolver Functions for Rate/Vol Types

```solidity
// Resolvers.sol additions — all pure functions, zero state

// VolatilityBand: is realized vol above/below threshold?
// Identical to resolveThreshold() — different input axis (vol%, not price)
function resolveVolatilityBand(
    uint32 volValueE4, // from Chainlink RVOL feed (e.g. 6543 = 65.43% annualised)
    uint32 thresholdE4, // configured in MarketTemplate (e.g. 6000 = 60%)
    MarketTypes.Condition condition
) internal pure returns (uint256 mask) {
    bool high = condition == MarketTypes.Condition.AtOrAbove
        ? volValueE4 >= thresholdE4 : volValueE4 < thresholdE4;
    return high ? (uint256(1) << 0) : (uint256(1) << 1);
}

// resolveStakingAPR and resolveBitcoinIRC = resolveThreshold with rate value
// ZERO additional code needed for StakingAPR and BitcoinIRC
// They reuse resolveThreshold() with the APR/rate feed address in the template
```

---

## 5. SmartData Feeds — NAV, AUM, and Proof of Reserve

Chainlink SmartData is a suite of onchain data feeds designed for tokenized real-world assets. It provides three distinct data types — NAV (Net Asset Value), AUM (Assets Under Management), and Proof of Reserve — all via the same AggregatorV3Interface. These feeds unlock a category of prediction market that has never existed: betting on whether tokenized fund NAV crosses a threshold, or whether a stablecoin's reserve ratio holds.

### 5.1 SmartNav (NAV) Feeds on Base

| **Fund / asset** | **NAV data provider** | **RetroPick market types** |
|---|---|---|
| **Ondo OUSG (US Treasuries)** | Ondo Finance — daily NAV from fund administrator | NAV Threshold: will OUSG NAV exceed $X? Anchor: vs quarter-open NAV |
| **Ondo USDY (USD Yield Note)** | Ondo Finance — daily NAV update | NAV Direction: is USDY NAV growing? Corridor: within $0.01 of $1.00? |
| **WisdomTree CRDT (tokenized fund)** | WisdomTree — institutional NAV, live on Base (2025) | NAV Threshold: will CRDT NAV beat benchmark? |
| **Superstate USTB (US T-Bill)** | Superstate — daily NAV + Proof of Reserve | NAV Anchor: will USTB NAV stay above $100? Reserve Health |
| **Franklin Templeton FOBXX** | Franklin Templeton — tokenized money market NAV | NAV Direction: quarterly fund performance |
| **BlackRock BUIDL** | BlackRock — institutional tokenized fund AUM + NAV | AUM Direction: is BUIDL growing? Composite with OUSG |

### 5.2 Proof of Reserve (PoR) Feeds on Base

Proof of Reserve feeds provide the onchain verification of collateral backing for wrapped and tokenized assets. RetroPick can create a market type around reserve health — a risk instrument that is completely absent from every competitor platform. This is the world's first decentralised prediction market on reserve solvency.

| **Asset** | **PoR methodology** | **Chainlink feed type** | **RetroPick market type** |
|---|---|---|---|
| **WBTC (Wrapped Bitcoin)** | Third-party auditor verification of BTC in custody | Onchain PoR — daily | ReserveHealth: will WBTC PoR ratio stay ≥100%? |
| **cbBTC (Coinbase BTC)** | Coinbase custodian — verifiable holdings | Chainlink PoR on Base | ReserveHealth: Corridor market on backing ratio |
| **tBTC (Threshold)** | Onchain cross-chain PoR | Chainlink cross-chain verification | ReserveHealth: binary — are reserves fully backed? |
| **USDC reserves** | Circle — custodian attestation | SmartData reserve feed | Corridor: will USDC reserves stay above $X billion? |
| **stETH (Lido)** | Onchain validator accounting | Chainlink onchain PoR | Reserve ratio direction — is Lido collateralisation improving? |

> **New market type: ReserveHealth**
>
> ReserveHealth is the simplest oracle-resolved market type that no competitor has ever offered.
>
> Example: 'Will WBTC maintain its 1:1 BTC backing ratio for the entire next week?' Resolution: if the Chainlink PoR feed drops below 1.00 BTC per WBTC at any point during the epoch, the 'breach' side wins. This is a Corridor-type market applied to a reserve ratio instead of a price.
>
> User need: Anyone who holds WBTC in DeFi, uses it as collateral on Aave, or holds cbBTC on Base has a genuine interest in this market as a hedge. The counterparties: degens who believe reserves are solid and want to earn yield on that conviction.

---

## 6. US Government Macroeconomic Feeds — Live on Base

In August 2025, the US Department of Commerce partnered with Chainlink to publish official Bureau of Economic Analysis (BEA) macroeconomic data onchain. This is the first time a federal agency has published economic data on public blockchains. These feeds are fully decentralised — they use Chainlink's DON oracle network, not a TrustedReporter. They are live on Base among the ten initial networks.

> **Why this upgrades RetroPick's economics category fundamentally**
>
> In the original plan, economics markets (CPI, GDP, Fed rates) required TrustedReporterAdapter — a semi-centralised oracle. With US Government Macro Feeds now live on Base, these markets resolve from a fully decentralised Chainlink oracle. The trust model is equivalent to BTC/USD. This is a major competitive and trust upgrade.
>
> These feeds are also a strong product-market fit signal: Chainlink explicitly listed 'real-time prediction markets for crowdsourced intelligence' as a target use case when announcing the BEA partnership.

| **Feed** | **BEA series** | **Update cadence** | **Market type** | **Resolver** |
|---|---|---|---|---|
| **Real GDP (level)** | BEA NIPA Table 1.1.5 | Quarterly (advance, 2nd, 3rd estimates) | Threshold: will Q3 GDP beat $28T level? | `resolveThreshold` |
| **Real GDP (QoQ %)** | BEA annualised growth rate | Quarterly | Threshold: will GDP beat +2.5% QoQ? Direction vs prior quarter | `resolveThreshold` |
| **PCE Price Index** | BEA Monthly PCE — Fed preferred inflation | Monthly | Threshold: will PCE exceed 2.5% YoY? Anchor vs Fed 2% target | `resolveThreshold` |
| **PCE YoY change** | BEA — annualised PCE change | Monthly | Direction: is inflation rising or falling? Corridor: within 2–3%? | `resolveDirection` |
| **Real Final Sales** | BEA — domestic demand ex-inventory | Quarterly | Threshold: is underlying demand healthy? Direction | `resolveThreshold` |

Contract addresses for the US Government Macro Feeds on Base are live and verifiable at [docs.chain.link/data-feeds/us-government-macroeconomic/addresses](https://docs.chain.link/data-feeds/us-government-macroeconomic/addresses). These feeds use the standard AggregatorV3Interface — a MacroAdapter contract (~30 lines, port of ChainlinkAdapter) is the only new code required.

---

## 7. DataLink — Institutional Data Onchain (2025–2026)

DataLink is Chainlink's institutional-grade data publishing service. In 2025, major financial institutions began publishing premium data onchain for the first time via DataLink. For RetroPick, DataLink is the path to markets based on institutional indices and treasury benchmarks — data types that were completely unavailable to any prediction market before.

| **DataLink provider** | **Data published onchain** | **Availability** | **RetroPick opportunity** |
|---|---|---|---|
| **FTSE Russell (Nov 2025)** | Russell 1000, Russell 2000, Russell 3000, FTSE 100 indices; WMR FX benchmarks | 40+ blockchains via DataLink — contact Chainlink | Direction: will Russell 2000 close higher? Threshold: will index beat X? |
| **Deutsche Börse (2025)** | Eurex derivatives, Xetra equities, 360T FX, Tradegate — multi-asset class | Contact for Base deployment — DataLink | Composite: Eurex vol + DAX direction + EUR/USD |
| **S&P Dow Jones Indices** | S&P Digital Markets 50 Index; S&P Global Ratings Stablecoin Stability Assessments | DataLink — contact for address | S&P Digital Markets 50: Direction, Threshold |
| **Tradeweb (2025)** | FTSE US Treasury Benchmark Closing Prices — registered under EU/UK BMR | DataLink — institutional access | Treasury yield Anchor, Direction markets |
| **ICE (NYSE parent, Aug 2025)** | FX and precious metals from ICE Consolidated Feed (300+ exchanges) | Via Chainlink Data Streams → feeds | XAU/XAG/FX with institutional-grade ICE sourcing |

*DataLink feeds require integration contact with Chainlink Labs. They are institutional-access feeds but use the same AggregatorV3Interface once deployed. Phase 3 roadmap item. Contact: [chain.link/contact](https://chain.link/contact).*

---

## 8. Complete Market Type Specifications — 13 Primitives

The following is the complete market type registry for RetroPick on Base. Every type resolves deterministically from a Chainlink oracle. No human judge, no dispute window, no UMA fallback required. Types are sorted by implementation complexity — start from the top.

| **Type** | **Core mechanic** | **Oracle class** | **Contract delta** | **Phase** | **Complexity** |
|---|---|---|---|---|---|
| **Direction** | Price B vs A at lock | PRICE_FEED | Live | V1 | Live |
| **Threshold** | B vs fixed level | PRICE_FEED | Live | V1 | Live |
| **RangeClose** | N-bucket price landing | PRICE_FEED | Live | V1 | Live |
| **Anchor** | B vs historic reference price | PRICE_FEED | 1 field + 3-line resolver | V1.5 | Lowest |
| **Velocity** | Absolute % move bucket | PRICE_FEED | 1 field + 15-line resolver | V1.5 | Lowest |
| **VolatilityBand** | Realised vol vs threshold | RATE_FEED | RateAdapter + 8-line resolver | V1.5 | Lowest |
| **StakingAPR** | ETH staking APR vs threshold | RATE_FEED | Template only (reuse Threshold) | V1.5 | Lowest |
| **BitcoinIRC** | BTC lending rate direction | RATE_FEED | Template only (reuse Direction) | V1.5 | Lowest |
| **NAV Threshold** | Tokenized fund NAV vs level | SMARTDATA | SmartDataAdapter + Threshold | V1.5 | Low |
| **MacroEvent** | BEA GDP/PCE vs threshold | MACRO_FEED | MacroAdapter + Threshold | V1.5 | Low |
| **Ladder** | Progressive payout tiers | PRICE_FEED | 2 fields + payout weight math | V2 | Medium |
| **Convergence** | Two-asset spread direction | PRICE_FEED ×2 | Dual feed + spread resolver | V2 | Medium |
| **Composite** | AND/OR multi-asset logic | PRICE_FEED ×4 | Array fields + logic resolver | V2 | Medium |
| **Momentum** | N-epoch directional streak | PRICE_FEED | Array checkpoint + scorer | V2 | Medium |
| **Streak** | Pre-committed sequence parlay | PRICE_FEED | Position struct extension | V2 | High |
| **Corridor** | Sustained price range hold | PRICE_FEED + Reporter | OHLC extension + breach flag | V3 | High |
| **Cascade** | Multi-level knock-in | PRICE_FEED + Reporter | High watermark + levels array | V3 | High |
| **ReserveHealth** | PoR ratio Corridor | SMARTDATA_PoR | PoR adapter + Corridor variant | V3 | High |

> **V1.5 delivers 7 new market types — zero architectural change**
>
> - **Anchor, Velocity** — zero new infrastructure, 18 lines of new Solidity total.
> - **VolatilityBand** — RateAdapter (30 lines) + 8-line resolver = 38 lines.
> - **StakingAPR, BitcoinIRC** — zero new code, just template configurations pointing to Rate Feed addresses.
> - **NAV Threshold** — SmartDataAdapter (30 lines) + reuse Threshold resolver.
> - **MacroEvent** — MacroAdapter (30 lines) + reuse Threshold resolver.
>
> **Total new Solidity for 7 novel market types: ~116 lines. Total time estimate: 2–3 weeks including tests.**

---

## 9. Oracle Architecture — Feed Family Extension

### 9.1 OracleClass Enum Extension

The existing OracleType enum is extended to OracleClass with 7 values. All share the same `latestRoundData()` interface. The engine's `resolveEpoch()` dispatch adds one line per new class. No module changes, no proxy upgrades.

```solidity
// MarketTypes.sol — additive only

enum OracleClass {
    CHAINLINK_PRICE_FEED,  // existing — ChainlinkAdapter
    CHAINLINK_RATE_FEED,   // new — RateAdapter (RVOL, APR, IRC)
    CHAINLINK_SMARTDATA,   // new — SmartDataAdapter (NAV, AUM, PoR)
    CHAINLINK_MACRO,       // new — MacroAdapter (BEA GDP, PCE)
    CHAINLINK_EQUITY,      // new — EquityAdapter (Ondo tokenized stocks)
    TRUSTED_REPORTER       // existing — TrustedReporterAdapter
}

// MarketTemplate addition
OracleClass oracleClass;     // which adapter handles this template
IPriceOracle oracleAdapter;  // pointer to the correct adapter instance
```

### 9.2 New Adapter Contracts (Each ~30 Lines)

```solidity
// RateAdapter.sol — 30 lines, identical to ChainlinkAdapter
// Reads Chainlink Rate/Vol feeds via AggregatorV3Interface
// Returns annualised rate/vol value normalised to e8

contract RateAdapter is IPriceOracle {
    address immutable sequencerFeed;
    
    constructor(address _seq) { sequencerFeed = _seq; }
    
    function getNormalizedPrice(bytes32 feedId, uint64 maxAge, uint64)
        external view returns (int256 rateE8, uint64 publishTime, uint256 confidenceE8)
    {
        _checkSequencer(sequencerFeed);
        address feed = address(uint160(uint256(feedId)));
        (, int256 answer,, uint256 updatedAt,) = 
            AggregatorV3Interface(feed).latestRoundData();
        require(block.timestamp - updatedAt <= maxAge, 'Stale');
        uint8 d = AggregatorV3Interface(feed).decimals();
        rateE8 = _normalizeToE8(answer, d);
        publishTime = uint64(updatedAt);
        confidenceE8 = 0;
    }
}

// MacroAdapter, SmartDataAdapter, EquityAdapter = identical pattern
// Only the comment changes — same 30 lines
```

### 9.3 TrustedReporter OHLC Extension (V3 — for Cascade and Corridor)

```solidity
// TrustedReporterAdapter — additive OHLC extension for V3 types

struct OHLCResolution {
    int256 openE8; int256 highE8; int256 lowE8; int256 closeE8;
    uint256 timestamp; bool resolved; string dataSource;
}

mapping(bytes32 => OHLCResolution) private _ohlcResolutions;

function postOHLCResult(
    bytes32 marketId,
    int256 openE8, int256 highE8, int256 lowE8, int256 closeE8,
    uint256 timestamp, string calldata dataSource, bytes calldata sig
) external {
    // Same ECDSA verification as existing postResult()
    // Reporter Service fetches open/high/low/close from Chainlink historical rounds
    // Posts all 4 atomically in one transaction
}
```

---

## 10. Implementation Roadmap — Base L2 Deployment

| **#** | **Market type** | **Phase** | **New Solidity** | **Oracle dependency** | **Weeks** |
|---|---|---|---|---|---|
| 1 | Anchor | V1.5 | 1 field + 3-line resolver | PRICE_FEED existing | 4–5 |
| 2 | Velocity | V1.5 | 1 field + 15-line resolver | PRICE_FEED existing | 4–5 |
| 3 | VolatilityBand | V1.5 | RateAdapter 30L + 8L resolver | RATE_FEED — new adapter | 5–6 |
| 4 | StakingAPR | V1.5 | Zero (reuse Threshold) | RATE_FEED adapter shared | 5–6 |
| 5 | BitcoinIRC | V1.5 | Zero (reuse Direction) | RATE_FEED adapter shared | 5–6 |
| 6 | NAV Threshold | V1.5 | SmartDataAdapter 30L | SMARTDATA — new adapter | 6–7 |
| 7 | MacroEvent | V1.5 | MacroAdapter 30L | MACRO — new adapter | 6–7 |
| 8 | Ladder | V2 | 2 fields + payout weight math | PRICE_FEED existing | 8–10 |
| 9 | Convergence | V2 | Dual feed + spread resolver | PRICE_FEED ×2 existing | 9–11 |
| 10 | Composite | V2 | Array fields + logic resolver | PRICE_FEED ×4 existing | 10–12 |
| 11 | Momentum | V2 | Array checkpoint + scorer | PRICE_FEED existing | 11–13 |
| 12 | Streak | V2 | Position struct extension | PRICE_FEED existing | 12–15 |
| 13 | Corridor | V3 | OHLC Reporter + breach flag | PRICE_FEED + TRO OHLC | 16–20 |
| 14 | Cascade | V3 | High watermark + level array | PRICE_FEED + TRO OHLC | 17–22 |
| 15 | ReserveHealth | V3 | PoR adapter + Corridor variant | SMARTDATA_PoR | 18–24 |

> **Total V1.5 investment: ~116 lines of Solidity, 3 new adapter contracts, 2–3 weeks**
>
> Anchored by: Anchor + Velocity (18 lines, zero new adapters) — ship first.
>
> RateAdapter (30 lines) unlocks: VolatilityBand, StakingAPR, BitcoinIRC simultaneously.
>
> SmartDataAdapter (30 lines) unlocks: NAV Threshold (Ondo/WisdomTree/Superstate).
>
> MacroAdapter (30 lines) unlocks: all US Government Macro Feed markets.
>
> **Result: 7 novel market types no competitor has, shipping in 2–3 weeks on Base L2.**

---

## 11. Competitive Moat Analysis

RetroPick on Base with the full Chainlink feed ecosystem creates a moat across five dimensions that cannot be replicated quickly.

| **Dimension** | **Polymarket** | **Kalshi** | **RetroPick (Base + Chainlink)** |
|---|---|---|---|
| **Oracle decentralisation** | Human judges, UMA dispute | Centralised operator | Chainlink DON — same trust as BTC/USD for all market types including macro |
| **Volatility/rate markets** | None | None | VolatilityBand, StakingAPR, BitcoinIRC — first in prediction market history |
| **Tokenized equity markets** | None | None | AAPL, TSLA, SPY, QQQ via Ondo + Chainlink — oracle resolved, not human judged |
| **US Government macro** | None (human resolution) | CPI, GDP, Fed rate (human) | BEA GDP + PCE via fully decentralised Chainlink DON oracle — Aug 2025 launch |
| **Tokenized fund NAV** | None | None | Ondo OUSG, WisdomTree CRDT, BlackRock BUIDL — NAV oracle markets |
| **Reserve health markets** | None | None | PoR-based reserve ratio corridor markets — world first |
| **Stablecoin depeg markets** | None | None | Corridor market: USDC/USDT must stay within $0.995–$1.005 all week |
| **LST/LRT markets** | None | None | cbETH/wstETH convergence, staking yield direction on Base-native assets |

> **The deepest moat: US Government Macro Feeds + Tokenized Equity**
>
> These two oracle families have never been used by any prediction market protocol. Both are live on Base. Both use AggregatorV3Interface. Both require ~30 lines of adapter code to consume. The product value is enormous — institutional users, traditional investors, and macro traders immediately understand 'will GDP beat 2.5%?' and 'will AAPL be higher this week?'.
>
> Chainlink explicitly named prediction markets as a target use case when announcing the BEA partnership. RetroPick is the natural implementation of that vision.

---

## 12. Full Market Category Matrix — Oracle Class + Feed + Type

This is the authoritative oracle routing table for every RetroPick market category on Base. Each row maps a market concept to its oracle class, live Base feed or backend API source, resolution data point, and recommended market type(s).

### 12.1 Crypto Markets

| **Subcategory** | **Oracle class** | **Feed / source** | **Resolution point** | **Market types** |
|---|---|---|---|---|
| **BTC/USD price** | PRICE_FEED | `0x64c9...848F` (Base) | Close price e8 | Direction, Velocity, Ladder, Anchor, Cascade |
| **ETH/USD price** | PRICE_FEED | `0x71041...Bb70` (Base) | Close price e8 | Direction, Velocity, VolatilityBand |
| **BTC realised vol** | RATE_FEED | Chainlink RVOL 7d — Base | % annualised e4 | VolatilityBand, Anchor (vs 30d avg) |
| **ETH staking APR** | RATE_FEED | Chainlink ETH APR 30d — Base | % annualised e8 | StakingAPR Threshold, Direction |
| **BTC lending rate** | RATE_FEED | Chainlink CF BIRC — Base | Daily rate % e8 | BitcoinIRC Direction, Threshold |
| **cbETH/ETH ratio** | PRICE_FEED | `0x806b...40b` (Base) | Exchange rate e18 | Convergence, Corridor |
| **USDC depeg** | PRICE_FEED | `0x7e86...9B` (Base) | Price vs $1.00 | Corridor ($0.995–$1.005) |
| **WBTC reserves** | SMARTDATA PoR | Chainlink PoR — Base | BTC reserve ratio | ReserveHealth Corridor |
| **BTC spot ETF flows** | TRUSTED_REPORTER | CoinGlass API | Net daily $USD inflow | Threshold, Direction |
| **DeFi TVL** | TRUSTED_REPORTER | DeFiLlama /protocols | Total TVL USD | Threshold, Direction |

### 12.2 Real-World Asset & Macro Markets

| **Subcategory** | **Oracle class** | **Feed / source** | **Resolution point** | **Market types** |
|---|---|---|---|---|
| **US Real GDP** | MACRO_FEED | Chainlink BEA feed — Base | Quarterly $ level or % | MacroEvent Threshold, Direction |
| **US PCE inflation** | MACRO_FEED | Chainlink BEA feed — Base | YoY % change | MacroEvent Threshold, Anchor (vs 2% target) |
| **Tokenised OUSG NAV** | SMARTDATA NAV | Chainlink NAVLink — Base | Daily NAV USD | NAV Threshold, Anchor |
| **Tokenised SPY/QQQ** | EQUITY_FEED | Ondo + Chainlink — Base | Daily NAV/price USD | Direction, Threshold |
| **Tokenised AAPL/TSLA** | EQUITY_FEED | Ondo + Chainlink — Base | Daily NAV/price USD | Velocity, Direction, Anchor |
| **XAU/USD (gold)** | PRICE_FEED | `0xFFE4...7a4` (Base) | Spot $/oz | Direction, Corridor, Ladder, Anchor |
| **WTI crude oil** | PRICE_FEED | `0x6cF2...Abf` (Base) | Spot $/barrel | Direction, Threshold, Corridor |
| **EUR/USD** | PRICE_FEED | `0xc91D...0F` (Base) | FX rate e8 | Corridor, Convergence (EUR/GBP) |
| **Fed Funds Rate** | TRUSTED_REPORTER | FRED API + Federal Reserve press release | Rate decision bps | Direction, Threshold |
| **UAE / GCC FX** | TRUSTED_REPORTER | ExchangeRate-API + CBUAE | USD/AED, USD/SAR rates | Corridor (peg monitoring) |

---

## 13. User-Created Markets — Oracle-Constrained Creator Economy

The user-created market system combines all oracle capabilities described in this document with a creator economy layer. Creators choose a market type and an oracle feed from the approved registry. The contract enforces everything else. Creators cannot influence resolution.

| **Creator action** | **What the creator controls** | **What the oracle controls (immutable)** |
|---|---|---|
| **Market type selection** | Choose from the 13-type registry (Direction → ReserveHealth) | All resolution logic and settlement math |
| **Feed selection** | Choose from the approved Base oracle feed catalogue | Price/rate/vol/NAV/macro values read at lock and resolve |
| **Epoch parameters** | Duration (5m, 15m, 1h, 4h, 24h, 7d), seed pool amount, creator fee share | Timing enforcement — contract rejects out-of-window operations |
| **Market thesis** | Optional editorial statement: 'Why I think gold breaks $3000 this week' | Has no effect on resolution — informational only |
| **Campaign link** | Shareable URL with live pool skew, countdown, oracle badge | None — frontend only |

> **Creator fee economics on Base**
>
> Creator seeds 10 USDC minimum to activate a market. In return, earns a configured share of the 1% protocol fee on every epoch. A popular market generating $100,000 USDC pool volume earns $1,000 in protocol fees. At 20% creator share: creator earns $200 per epoch passively.
>
> On Base, gas costs for a rolling-mode epoch are approximately $0.01–0.05 vs $0.50–2.00 on mainnet Ethereum. This means much smaller pool sizes remain economically viable — lowering the barrier for user-created markets significantly compared to any L1 deployment.
>
> Base is Coinbase's native L2: 100M+ Coinbase users are one click from a Base wallet. Creator market virality — sharing a rich link on Coinbase's social and DeFi surfaces — has no equivalent on any other L2.

---

## RetroPick Protocol — Base L2 Chainlink Oracle Innovation Plan

**Version 3.0 — April 2026 — Confidential — RetroPick FZ-LLC, RAK DAO, UAE**

*Oracle data sourced from docs.chain.link, data.chain.link, basescan.org, and Chainlink official announcements*
```