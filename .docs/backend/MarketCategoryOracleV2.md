Here's the document converted to a clean, well-structured Markdown file:

```markdown
# RetroPick Protocol  
## Market Category & Oracle Architecture  
### FZ-LLC Product Strategy Document  
**Arab Free Zone · Arbitrum One · April 2026**

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)  
2. [Legal Framework — Arab FZ-LLC](#2-legal-framework--arab-fz-llc)  
   2.1 [Why UAE Free Zone](#21-why-uae-free-zone)  
   2.2 [Categories Permitted Under FZ-LLC Structure](#22-categories-permitted-under-fz-llc-structure)  
3. [Market Category: Economics](#3-market-category-economics)  
   3.1 [Subcategories](#31-subcategories)  
   3.2 [Gap Analysis vs Competitors](#32-gap-analysis-vs-competitors)  
4. [Market Category: Crypto](#4-market-category-crypto)  
   4.1 [Subcategories](#41-subcategories)  
   4.2 [Gap Analysis vs Competitors](#42-gap-analysis-vs-competitors)  
5. [Market Category: Financials](#5-market-category-financials)  
   5.1 [Subcategories](#51-subcategories)  
   5.2 [Gap Analysis vs Competitors](#52-gap-analysis-vs-competitors)  
6. [Market Category: Business & Companies](#6-market-category-business--companies)  
   6.1 [Subcategories](#61-subcategories)  
   6.2 [Key Safety Rule](#62-key-safety-rule)  
7. [Market Category: Tech & Science](#7-market-category-tech--science)  
   7.1 [Subcategories](#71-subcategories)  
   7.2 [Gap Analysis vs Competitors](#72-gap-analysis-vs-competitors)  
8. [Market Category: Climate](#8-market-category-climate)  
   8.1 [Subcategories](#81-subcategories)  
9. [Untapped Categories — Not Covered by Any Competitor](#9-untapped-categories--not-covered-by-any-competitor)  
   9.1 [Islamic Finance & GCC Economy](#91-islamic-finance--gcc-economy)  
   9.2 [DeFi Protocol Metrics](#92-defi-protocol-metrics)  
   9.3 [Aviation & Transportation (UAE-Specific)](#93-aviation--transportation-uae-specific)  
10. [Oracle Architecture — Trusted Reporter Oracle](#10-oracle-architecture--trusted-reporter-oracle)  
    10.1 [Current State and the Problem](#101-current-state-and-the-problem)  
    10.2 [Design Goals](#102-design-goals)  
    10.3 [Architecture Overview](#103-architecture-overview)  
    10.4 [IEventOracle Interface](#104-ieventoracle-interface)  
    10.5 [TrustedReporterAdapter.sol](#105-trustedreporteradaptersol)  
    10.6 [MarketEngine.sol Changes](#106-marketenginesol-changes)  
    10.7 [Backend Reporter Service](#107-backend-reporter-service)  
    10.8 [Security Model](#108-security-model)  
    10.9 [Upgrade Path — Adding Reporter Redundancy](#109-upgrade-path--adding-reporter-redundancy)  
11. [Template Registry — Oracle Type Mapping](#11-template-registry--oracle-type-mapping)  
12. [Implementation Roadmap](#12-implementation-roadmap)  
    - [V1 (Live)](#v1-live)  
    - [V1.5 — Economics & Extended Chainlink (4–6 weeks)](#v15--economics--extended-chainlink-46-weeks)  
    - [V2 — Trusted Reporter Oracle (6–10 weeks)](#v2--trusted-reporter-oracle-610-weeks)  
    - [V3 — Multi-Reporter + Optional UMA (12+ weeks)](#v3--multi-reporter--optional-uma-12-weeks)  
13. [Appendix A: Summary Market Category Count](#appendix-a-summary-market-category-count)  
14. [Appendix B: Data Source API Reference](#appendix-b-data-source-api-reference)

---

## 1. Executive Summary

This document defines the complete market category taxonomy and oracle architecture for RetroPick Protocol, structured as a Free Zone LLC (FZ-LLC) in the UAE Arab region.

RetroPick is an oracle-resolved, epoch-based pool prediction market deployed on Arbitrum One. Its FZ-LLC structure in the UAE provides the lowest global regulatory friction for event contract trading — no specific prohibition on event contracts, DFSA/SCA frameworks accommodate innovative financial products, and no personal income tax on trading gains.

**This document covers two deliverables:** (1) a full subcategory map of all legally safe market types for an Arab FZ-LLC event contract platform, benchmarked against Kalshi, Polymarket, and Opinion Trade; and (2) a complete technical specification for a pluggable Trusted Reporter Oracle that extends the current Chainlink-only oracle model to support all non-price-feed market types.

The market category taxonomy is organized into 6 primary verticals: Economics, Crypto, Financials, Business & Companies, Tech & Science, and Climate. Each vertical is broken into subcategories with oracle strategy, example contracts, resolution source, and legal risk assessment for UAE FZ-LLC operations.

The oracle architecture proposes a new `IEventOracle` interface alongside the existing `IPriceOracle`, with a `TrustedReporterAdapter` contract that validates ECDSA-signed results posted by a whitelisted backend service.

---

## 2. Legal Framework — Arab FZ-LLC

### 2.1 Why UAE Free Zone

RetroPick's FZ-LLC structure is registered in one of the UAE's financial free zones (ADGM, DIFC, or IFZA equivalent). This jurisdiction provides the following advantages over US CFTC, EU MiCA, or SEA frameworks:

- No specific prohibition on event contracts or prediction market products  
- DFSA and SCA regulatory frameworks accommodate innovative financial product structures  
- Zero personal income tax on trading gains  
- No capital controls — USDT/USDC inflows and outflows unrestricted  
- English common law legal system for contract enforcement  
- Time zone bridges Asian and European trading sessions  

### 2.2 Categories Permitted Under FZ-LLC Structure

| Category | FZ-LLC Status | Notes |
|---|---|---|
| Economics | **Permitted — no restrictions** | Macro data, public sources |
| Crypto | **Permitted — no restrictions** | Price feeds, protocol events |
| Financials | **Permitted — no restrictions** | Indices, ETFs, forex |
| Business / Companies | **Permitted with care** | Avoid earnings pre-disclosure |
| Tech & Science | **Permitted — no restrictions** | Verified public milestones |
| Climate | **Permitted — no restrictions** | NOAA/WMO data sources |
| Sports | **Permitted in UAE — caution** | No gambling licence needed in ADGM |
| Elections / Politics | **Permitted with disclaimers** | Avoid domestic UAE politics |

**Note:** This document focuses exclusively on the 6 safe categories (Economics, Crypto, Financials, Business, Tech & Science, Climate) for V1 launch. Sports and Elections are V2+ decisions requiring separate legal review.

---

## 3. Market Category: Economics

**Overview:** Economics markets cover macroeconomic data releases and central bank policy decisions. These are the most institutionally respected event contracts — Kalshi's founding category, already validated by the CFTC as legitimate derivatives. Resolution is clean, objective, and uses publicly accessible government data sources. No insider information is possible.

### 3.1 Subcategories

| Subcategory | Example Markets | Oracle Source | Timeframe | Risk |
|---|---|---|---|---|
| Inflation | Will US CPI exceed X%? Will EU HICP stay below Y? | BLS, Eurostat, official releases | Monthly | **Low** |
| Central Banks | Will Fed cut by 25bps? Will ECB hold rates? Will BOJ raise? | FOMC statement, ECB press release | 6–8 weeks | **Low** |
| GDP Growth | Will US Q2 GDP beat +2.5%? Will China GDP exceed 5%? | BEA, NBS, Eurostat advance release | Quarterly | **Low** |
| Jobs & Employment | Will US NFP beat 200K? Will unemployment stay below 4%? | BLS, Labour Dept official reports | Monthly | **Low** |
| Housing Market | Will US existing home sales rise MoM? Will Case-Shiller beat X? | NAR, S&P Case-Shiller, Census Bureau | Monthly | **Low** |
| Oil & Energy Prices | Will WTI crude close above $85? Will natural gas exceed $X? | Chainlink (WTIUSD feed) | Daily / Weekly | **Low** |
| Trade & Tariffs | Will US trade deficit widen in Q3? Will tariff rate change? | US Census Bureau, WTO announcements | Monthly / one-off | **Low** |
| Global Macro Indicators | Will IMF revise global growth forecast? Will PMI stay above 50? | IMF, ISM, Markit official releases | Quarterly / Monthly | **Low** |
| Treasury & Yields | Will 10Y UST yield exceed 4.5%? Will yield curve invert? | Chainlink (UST yield feed) or TreasuryDirect | Daily / Weekly | **Low** |
| Emerging Markets | Will India GDP beat 7%? Will Brazil inflation fall below 5%? | IBGE, MoSPI, national statistics offices | Quarterly | **Low** |

### 3.2 Gap Analysis vs Competitors

**Kalshi covers:** Fed rates, GDP, inflation, jobs, housing, oil/energy — their core product.  
**Polymarket covers:** Fed rates, inflation, macro indicators, GDP, treasuries, trade war, taxes.  
**Opinion Trade (Macro tag):** Broad macro, overlaps with Kalshi.

**RetroPick FZ-LLC unique opportunities:** Emerging market macro (India, Brazil, GCC-specific data like UAE CPI or Saudi Aramco production targets), halal finance rate decisions (Saudi SAMA, Central Bank of UAE), and GCC housing/property indices. These are entirely uncovered by US-regulated platforms and align naturally with an Arab FZ-LLC user base.

---

## 4. Market Category: Crypto

**Overview:** Crypto markets are RetroPick's native strength. Chainlink price feeds resolve all price-direction markets automatically. This is the category with the deepest existing infrastructure, the highest oracle confidence, and the fastest settlement velocity. V1 is already live for BTC/ETH direction markets.

### 4.1 Subcategories

| Subcategory | Example Markets | Oracle Source | Timeframe | Risk |
|---|---|---|---|---|
| Price Direction (Direction) | Will BTC close above $X? Will ETH go UP this hour? | Chainlink (existing) | 5min–Daily | **Low** |
| Price Threshold (Threshold) | Will SOL hit $300 before end of month? Will BNB stay above $400? | Chainlink (existing) | Weekly–Monthly | **Low** |
| Price Range (RangeClose) | Will BTC close within $90K–$95K band? | Chainlink (existing) | Daily–Weekly | **Low** |
| ETF Flows | Will BTC spot ETF see net inflows >$500M this week? | Bloomberg / TheBlock API, CoinGlass | Weekly | **Low** |
| Dominance | Will BTC dominance stay above 60%? | CoinMarketCap API (public) | Weekly–Monthly | **Low** |
| Stablecoin Peg | Will USDT depeg below $0.99? Will USDC stay 1:1? | Chainlink (USDT/USD) | Continuous | **Low** |
| Network Metrics | Will ETH gas average above 30 gwei this week? | Etherscan/Alchemy public API | Weekly | **Low** |
| Protocol Events | Will Ethereum upgrade deploy on schedule? Will Solana hit 1K TPS? | Official GitHub / announcement | One-off | **Low** |
| Pre-TGE (Opinion Trade model) | Will X token launch above $X price in first week? | Binance/OKX public API at listing | One-off | **Low** |
| Derivatives Metrics | Will BTC OI exceed $X? Will funding rate turn negative? | Coinglass / exchange public data | Daily–Weekly | **Low** |
| Layer 2 Metrics | Will Base TVL exceed $10B? Will Arbitrum gas fees beat Optimism? | DeFiLlama public API | Monthly | **Low** |

### 4.2 Gap Analysis vs Competitors

**Unique to RetroPick FZ-LLC:** Pre-TGE markets are currently only on Opinion Trade and are not available on Kalshi or Polymarket. This is a natural fit for a crypto-native Arab FZ-LLC user base and requires no new oracle infrastructure — resolution is against exchange listing price. Layer 2 metrics and protocol events are also uncovered by US-regulated platforms.

---

## 5. Market Category: Financials

**Overview:** Financials covers traditional financial instruments — stock indices, ETFs, commodities, forex, and IPOs. Many subcategories map directly to Chainlink price feeds. For subcategories without Chainlink feeds (IPO first-day price, earnings beats), the Trusted Reporter Oracle (Section 8) is used.

### 5.1 Subcategories

| Subcategory | Example Markets | Oracle Source | Timeframe | Risk |
|---|---|---|---|---|
| Stock Indices | Will S&P 500 close above 5500 this week? Will Nasdaq gain >2%? | Chainlink (SPX, IXIC feeds) | Daily–Weekly | **Low** |
| ETF Price | Will QQQ close above $450? Will GLD break $240? | Chainlink (ETF price feeds) | Daily–Weekly | **Low** |
| Commodities — Metals | Will Gold close above $3200? Will Silver hit $35? | Chainlink (XAU/USD, XAG/USD) | Daily–Weekly | **Low** |
| Commodities — Energy | Will WTI exceed $90 this month? Will Brent Crude fall below $80? | Chainlink (WTI, BRENT feeds) | Weekly–Monthly | **Low** |
| Forex | Will EUR/USD close above 1.10? Will USD/JPY fall below 145? | Chainlink (FX feeds) | Daily–Weekly | **Low** |
| GCC / Regional Forex | Will USD/SAR remain pegged? Will AED stay 3.67? | Chainlink / Forex API | Monthly | **Low** |
| IPO Markets | Will X IPO open above issue price? Will Y IPO raise >$1B? | Trusted Reporter Oracle | One-off | **Low** |
| Earnings Beats | Will AAPL beat Q3 EPS? Will NVDA revenue exceed $25B? | Trusted Reporter Oracle | Quarterly | **Medium** |
| Acquisitions & M&A | Will announced MSFT acquisition close before deadline? | Trusted Reporter Oracle | One-off | **Medium** |
| Market Volatility | Will VIX close above 20 this week? | Chainlink (VIX feed if available) or TRO | Weekly | **Low** |
| Prediction Market Meta | Will Kalshi daily volume exceed $500M this month? | Trusted Reporter Oracle | Monthly | **Low** |

### 5.2 Gap Analysis vs Competitors

**Unique to RetroPick FZ-LLC:** GCC/regional forex pairs (USD/SAR, AED pegs) and MENA-specific equity indices (Tadawul, DFM, ADX) are completely uncovered by US platforms and directly relevant to the Arab FZ-LLC audience. These require only a Chainlink feed lookup or a simple Trusted Reporter Oracle query.

---

## 6. Market Category: Business & Companies

**Overview:** Business markets cover corporate events, executive decisions, and company-level metrics. This category carries moderate insider trading risk — the CFTC's Feb 2026 enforcement advisory specifically flagged company-specific contracts. **Safe rule:** only list markets where the outcome is determined by publicly announced events with a clear, verifiable resolution date. Never list markets where employees of the subject company would have material non-public information advantage.

### 6.1 Subcategories

| Subcategory | Example Markets | Oracle Source | Timeframe | Risk |
|---|---|---|---|---|
| IPO Outcomes | Will announced X IPO raise above $2B? Will Y list on NYSE vs NASDAQ? | Trusted Reporter Oracle | One-off | **Low** |
| CEO / Leadership | Will X CEO remain in role through Q4? Was CEO change announced? | Trusted Reporter Oracle | Quarterly | **Medium** |
| Product Launches | Will Apple launch Vision Pro 2 in 2026? Will Tesla release Cybertruck V2? | Trusted Reporter Oracle | One-off | **Low** |
| Layoffs & Hiring | Will Meta announce layoffs >5K in H1 2026? Will Google hit 200K employees? | Trusted Reporter Oracle | Quarterly | **Low** |
| Post-Announcement Earnings | After announced earnings date — will revenue beat guidance? | Trusted Reporter Oracle | Quarterly | **Medium** |
| M&A Completion | Will announced acquisition close before stated deadline? | Trusted Reporter Oracle | One-off | **Low** |
| Company KPIs | Will Uber monthly trips exceed 2B in Q3? Will AirBnb nights booked beat Q2? | Trusted Reporter Oracle | Quarterly | **Medium** |
| Regulatory / Antitrust | Will DOJ approve announced merger? Will FTC block X deal? | Trusted Reporter Oracle | One-off | **Low** |

### 6.2 Key Safety Rule

**Only list AFTER public announcement.** A market on "Will X acquire Y?" opened before any announcement creates insider trading risk. The same market opened after both companies officially confirm a deal in progress is safe — the information is public, and the market resolves on whether the deal closes on the stated date.

---

## 7. Market Category: Tech & Science

**Overview:** Tech & Science markets cover AI product milestones, space exploration events, scientific publications, and regulatory decisions on technology. Resolution sources are authoritative, public, and machine-verifiable. This is a high-growth category — Polymarket reports 1,700% volume growth in Tech & Science in 2024–2025.

### 7.1 Subcategories

| Subcategory | Example Markets | Oracle Source | Timeframe | Risk |
|---|---|---|---|---|
| AI Models & Releases | Will OpenAI release GPT-5 before Q3 2026? Will Claude 4 Opus beat GPT-5 on MMLU? | Official announcement / Trusted Reporter | One-off | **Low** |
| AI Benchmarks | Will any model exceed 95% on MMLU by end 2026? Will AI beat humans at IMO? | Academic papers / official leaderboard | Monthly–Yearly | **Low** |
| Space Exploration | Will SpaceX Starship reach orbit in 2026? Will Mars mission launch on schedule? | SpaceX official / NASA announcement | One-off | **Low** |
| App Store & Platform | Will X app reach #1 on App Store in 2026? Will TikTok ban take effect? | App store rankings API / news wire | One-off | **Low** |
| Semiconductor & Hardware | Will TSMC 2nm volume production start H1 2026? Will NVIDIA release B300? | Trusted Reporter Oracle | One-off | **Low** |
| FDA / Medical Approvals | Will X drug receive FDA approval in Q2 2026? | FDA official approval database | One-off | **Low** |
| Science Milestones | Will a fusion energy record be broken in 2026? Will CERN discover new particle? | Nature/Science publication date | Yearly | **Low** |
| Energy Transition | Will global EV share exceed 25% in 2026? Will solar hit 15% of US grid? | IEA, EIA official reports | Yearly | **Low** |
| Big Tech Regulation | Will EU fine Google >€5B in 2026? Will US pass AI regulation bill? | Official court/regulatory docs | One-off | **Low** |

### 7.2 Gap Analysis vs Competitors

**Unique to RetroPick FZ-LLC:** AI benchmark markets (model performance vs academic benchmarks) are not available anywhere. FDA approval markets exist on Polymarket but resolution disputes are common — using the FDA's own database as oracle source solves this. Energy transition markets with IEA data are uncovered and relevant to the UAE's Vision 2030 audience.

---

## 8. Market Category: Climate

**Overview:** Climate markets are the single cleanest event contract category from a legal and oracle standpoint. No insider information is possible on weather outcomes. NOAA, WMO, and national meteorological services publish data freely. No gambling law jurisdiction has challenged weather outcome contracts. This category is underserved by competitors despite its legal safety.

### 8.1 Subcategories

| Subcategory | Example Markets | Oracle Source | Timeframe | Risk |
|---|---|---|---|---|
| Temperature Records | Will global avg temp set new record in 2026? Will Dubai exceed 50°C? | NOAA, UAE NCMS data | Yearly / Summer | **Low** |
| Rainfall & Precipitation | Will UAE receive above-average rainfall in Q1? Will California drought worsen? | NCMS, NOAA precipitation data | Quarterly | **Low** |
| Hurricanes & Cyclones | Will there be >15 named Atlantic storms in 2026? Will a Category 5 hit Gulf? | NOAA National Hurricane Center | Seasonal | **Low** |
| Earthquakes | Will a 7.0+ earthquake occur in California in 2026? | USGS Earthquake Hazards Program | Yearly | **Low** |
| Polar Ice & Sea Level | Will Arctic sea ice hit record low in September 2026? | NSIDC official records | Yearly | **Low** |
| Air Quality | Will Dubai AQI exceed 150 on any day in July 2026? | UAE EPA / IQAir public API | Monthly | **Low** |
| GCC-Specific Weather | Will Riyadh exceed 45°C for >10 days in 2026? Will Dubai fog close airport? | NCMS / Saudi PME data | Seasonal | **Low** |
| Climate Policy | Will COP31 agree on new 1.5°C binding target? | UNFCCC official statements | One-off | **Low** |
| Renewable Energy Records | Will UAE solar production exceed X TWh in 2026? | IRENA, DEWA annual reports | Yearly | **Low** |

**GCC-specific climate markets** are a distinctive differentiator for RetroPick's Arab FZ-LLC positioning. Dubai, Abu Dhabi, Riyadh, and Doha weather records are highly relevant to the local audience and not available on any competing platform.

---

## 9. Untapped Categories — Not Covered by Any Competitor

These market types are safe, legally uncontested, and not currently offered by Kalshi, Polymarket, or Opinion Trade. They represent first-mover opportunities for an Arab FZ-LLC operator.

### 9.1 Islamic Finance & GCC Economy

| Market | Example | Oracle Source |
|---|---|---|
| Murabaha Rate | Will CBUAE benchmark rate stay at X%? | CBUAE official announcement |
| Sukuk Issuance | Will UAE government issue >$5B sukuk in H1? | CBUAE / Bloomberg Sukuk data |
| Saudi Aramco Production | Will Aramco Q2 production exceed 9M bpd? | Aramco official quarterly report |
| GCC Sovereign Wealth | Will ADIA or PIF announce >$10B new investment? | Official press release |

### 9.2 DeFi Protocol Metrics

| Market | Example | Oracle Source |
|---|---|---|
| Aave / Compound TVL | Will Aave v3 TVL exceed $20B by month end? | DeFiLlama public API |
| Stablecoin Supply | Will USDT market cap exceed $150B? | CoinMarketCap API |
| DEX Volume | Will Uniswap weekly volume exceed $10B? | Dune Analytics / public subgraph |
| Bridge Flows | Will Arbitrum bridge inflows exceed $1B this week? | L2Beat / official bridge data |

### 9.3 Aviation & Transportation (UAE-Specific)

| Market | Example | Oracle Source |
|---|---|---|
| Dubai Airports Passengers | Will DXB handle >100M passengers in 2026? | GACA / Dubai Airports official data |
| Emirates Earnings | Will Emirates report profit for 6th consecutive year? | Emirates Group annual results |
| Expo / Event Attendance | Will Formula E Abu Dhabi exceed 100K attendance? | Official event organisers |

---

## 10. Oracle Architecture — Trusted Reporter Oracle

### 10.1 Current State and the Problem

RetroPick V1 uses a single oracle path: Chainlink price feed → ChainlinkAdapter → IPriceOracle interface → MarketEngine. This works perfectly for crypto price direction, threshold, and range-close markets. It covers 100% of the existing Phase 1 markets.

The problem is that Chainlink price feeds only cover continuously-priced assets. They cannot resolve:

- Binary event outcomes: "Did the Fed cut rates at the March 2026 FOMC meeting?"  
- Company KPI events: "Did Apple Q2 revenue beat analyst estimates?"  
- Protocol milestones: "Did SpaceX Starship reach orbit?"  
- Climate records: "Did global average temperature set a new record in 2026?"  
- IPO and M&A outcomes: "Did the announced acquisition close before the deadline?"

All of the Economics, Business, Tech & Science, and Climate subcategories defined in this document require a different oracle model — one that resolves against a publicly verifiable binary or scalar data point from an API source, rather than a continuously-updating price feed.

### 10.2 Design Goals

- **Pluggable:** new event types added without changing MarketEngine.sol  
- **Trustless-compatible:** cryptographic proof of data origin, not just operator assertion  
- **Upgradeable:** backend data sources can change (API providers, endpoints) without contract redeployment  
- **Auditable:** every resolution result stored on-chain with provenance  
- **Fail-safe:** if oracle disputes or fails, admin can trigger emergency resolution or market cancellation  
- **Minimal gas overhead:** result delivered in a single transaction, same as existing Chainlink path  

### 10.3 Architecture Overview

The Trusted Reporter Oracle (TRO) consists of three components:

- **TrustedReporterAdapter.sol** — a new smart contract implementing `IEventOracle` interface, validates ECDSA-signed results  
- **MarketEngine.sol update** — adds `IEventOracle` as a second oracle path alongside the existing `IPriceOracle`  
- **Backend Reporter Service** — a Node.js service that fetches data from APIs, signs the result with a private key, and submits the transaction on-chain  

### 10.4 IEventOracle Interface

A new Solidity interface alongside the existing `IPriceOracle`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IEventOracle
/// @notice Interface for resolving non-price event contracts
/// @dev Pluggable alongside ChainlinkAdapter / IPriceOracle in MarketEngine
interface IEventOracle {

    /// @notice Emitted when a result is posted on-chain
    event ResultPosted(
        bytes32 indexed marketId,
        int256  result,          // binary: 1=YES, 0=NO; scalar: actual value
        /// @NOTE: upgrade to Dynamic outcome because retroPick is not only Binary Type, but range, threshold, up vs down, etc
        uint256 timestamp,
        address reporter
    );

    /// @notice Returns the resolved result for a given market
    /// @param marketId keccak256(abi.encodePacked(templateId, epochId))
    /// @return result  The resolved value
    /// @return resolved True if market has been resolved
    function getResult(bytes32 marketId)
        external
        view
        returns (int256 result, bool resolved);

    /// @notice Returns the data source URI for a given market (for audit trail)
    function getDataSource(bytes32 marketId) external view returns (string memory);
}
```

### 10.5 TrustedReporterAdapter.sol

The adapter implements `IEventOracle` and validates that results are signed by a whitelisted reporter private key before storing them.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IEventOracle.sol";

/// @title TrustedReporterAdapter
/// @notice Validates ECDSA-signed event results from an off-chain reporter service
contract TrustedReporterAdapter is IEventOracle, Ownable {
    using ECDSA for bytes32;

    // ── storage ─────────────────────────────────────────────────────
    address public trustedReporter;         // whitelisted backend key
    uint256 public constant RESULT_TTL = 1 hours; // reject stale signatures

    struct Resolution {
        int256  result;
        uint256 timestamp;
        bool    resolved;
        string  dataSource;   // e.g. 'https://api.bls.gov/cpi/2026-03'
    }

    mapping(bytes32 => Resolution) private _resolutions;

    // ── events ──────────────────────────────────────────────────────
    event ReporterUpdated(address oldReporter, address newReporter);

    // ── constructor ─────────────────────────────────────────────────
    constructor(address _reporter) Ownable(msg.sender) {
        trustedReporter = _reporter;
    }

    // ── reporter interface ───────────────────────────────────────────
    /// @notice Called by backend reporter with signed result
    /// @param marketId     keccak256(abi.encodePacked(templateId, epochId))
    /// @param result       1 = YES / true, 0 = NO / false, or scalar value
    /// @NOTE: upgrade to Dynamic outcome because retroPick is not only Binary Type, but range, threshold, up vs down, etc
    /// @param timestamp    Unix timestamp when data was fetched
    /// @param dataSource   URL/identifier of the authoritative source
    /// @param signature    ECDSA sig over keccak256(marketId, result, timestamp, dataSource)
    function postResult(
        bytes32 marketId,
        int256  result,
        uint256 timestamp,
        string calldata dataSource,
        bytes calldata signature
    ) external {
        require(!_resolutions[marketId].resolved, "Already resolved");
        require(block.timestamp - timestamp < RESULT_TTL, "Signature expired");

        // reconstruct and verify the signed message
        bytes32 msgHash = keccak256(
            abi.encodePacked(marketId, result, timestamp, dataSource)
        ).toEthSignedMessageHash();

        address signer = msgHash.recover(signature);
        require(signer == trustedReporter, "Invalid reporter signature");

        _resolutions[marketId] = Resolution({
            result:     result,
            timestamp:  timestamp,
            resolved:   true,
            dataSource: dataSource
        });

        emit ResultPosted(marketId, result, timestamp, msg.sender);
    }

    // ── IEventOracle implementation ──────────────────────────────────
    function getResult(bytes32 marketId)
        external view override
        returns (int256 result, bool resolved)
    {
        Resolution storage r = _resolutions[marketId];
        return (r.result, r.resolved);
    }

    function getDataSource(bytes32 marketId)
        external view override
        returns (string memory)
    {
        return _resolutions[marketId].dataSource;
    }

    // ── admin ────────────────────────────────────────────────────────
    function setTrustedReporter(address newReporter) external onlyOwner {
        emit ReporterUpdated(trustedReporter, newReporter);
        trustedReporter = newReporter;
    }
}
```

### 10.6 MarketEngine.sol Changes

The MarketEngine needs two additions: a new oracle type field on each template, and a new resolution path in `resolveEpoch()`.

```solidity
// In MarketTemplate struct — add oracle type field:
enum OracleType { CHAINLINK_PRICE_FEED, TRUSTED_REPORTER }

struct MarketTemplate {
    // ... existing fields ...
    OracleType  oracleType;          // NEW: which oracle resolves this market
    bytes32     eventOracleMarketId; // NEW: for TRO markets, the marketId key
    IEventOracle eventOracle;        // NEW: reference to TrustedReporterAdapter
}

// In resolveEpoch() — add a branch for TRO resolution:
function resolveEpoch(bytes32 templateId, uint64 epochId) external {
    MarketTemplate storage tmpl = templates[templateId];
    Epoch storage epoch = epochs[templateId][epochId];
    require(epoch.state == EpochState.LOCKED, "Not locked");

    int256 outcomeValue;

    if (tmpl.oracleType == OracleType.CHAINLINK_PRICE_FEED) {
        // existing path: read from ChainlinkAdapter
        (, int256 price, , ,) = tmpl.priceFeed.latestRoundData();
        outcomeValue = price;
    } else if (tmpl.oracleType == OracleType.TRUSTED_REPORTER) {
        // new path: read from TrustedReporterAdapter
        (int256 result, bool resolved) =
            tmpl.eventOracle.getResult(tmpl.eventOracleMarketId);
        require(resolved, "Event oracle not resolved yet");
        outcomeValue = result;
    }

    // ... existing settlement logic using outcomeValue ...
}
```

### 10.7 Backend Reporter Service

The Reporter Service is a TypeScript/Node.js backend that:

- Fetches data from authoritative APIs (BLS, NOAA, FDA, DeFiLlama, etc.)  
- Computes the binary or scalar resolution value  
- Signs the result with the trusted reporter private key (stored in AWS KMS or HSM)  
- Submits the signed transaction to `TrustedReporterAdapter.postResult()`  
- Records the data source URL, raw API response, and timestamp in a PostgreSQL audit table  

```typescript
// reporter-service/src/resolveMarket.ts

import { ethers } from 'ethers';
import { TrustedReporterAdapter__factory } from '../typechain';

export async function resolveMarket(
  marketId: string,          // keccak256(templateId, epochId)
  result: number,            // 1 = YES, 0 = NO // Dynamic outcome because retroPick is not only Binary Type, but range, threshold, up vs down, etc
  dataSourceUrl: string,     // authoritative source URL
  wallet: ethers.Wallet,     // reporter private key
  adapterAddress: string     // TrustedReporterAdapter contract
) {
  const timestamp = Math.floor(Date.now() / 1000);

  // construct the message that the contract will verify
  const msgHash = ethers.solidityPackedKeccak256(
    ['bytes32', 'int256', 'uint256', 'string'],
    [marketId, result, timestamp, dataSourceUrl]
  );

  // sign with personal_sign prefix (matches toEthSignedMessageHash in contract)
  const signature = await wallet.signMessage(ethers.getBytes(msgHash));

  // submit to chain
  const provider = new ethers.JsonRpcProvider(process.env.ARBITRUM_RPC);
  const adapter = TrustedReporterAdapter__factory.connect(adapterAddress, wallet.connect(provider));

  const tx = await adapter.postResult(
    marketId, result, timestamp, dataSourceUrl, signature
  );
  await tx.wait();

  console.log(`Resolved ${marketId} → result=${result}, tx=${tx.hash}`);
}

// Example: resolve a Fed rate decision market
// const fedResult = await fetchFOMCDecision(); // 1 if cut, 0 if hold
// await resolveMarket(marketId, fedResult,
//   'https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm',
//   reporterWallet, ADAPTER_ADDRESS);
```

### 10.8 Security Model

The Trusted Reporter Oracle is a semi-centralised design — it trades some decentralisation for the ability to resolve any publicly-verifiable event. The trust model is:

| Property | Chainlink Path | Trusted Reporter Path |
|---|---|---|
| Trust assumption | Chainlink DON (decentralised) | Single operator key (semi-centralised) |
| Tamper resistance | On-chain aggregation, no single point of failure | ECDSA sig verification in contract; operator cannot forge results without private key |
| Auditability | All rounds stored on-chain | dataSource URL + raw API response stored in PostgreSQL; resolution tx immutable on-chain |
| Dispute mechanism | None needed — continuous price feed | Admin dispute window: owner can void a resolution within 24h if evidence of error |
| Key compromise mitigation | N/A | setTrustedReporter() rotates key; existing resolutions unaffected |
| Multi-sig upgrade | N/A | Owner can be a Gnosis Safe multisig — require 2-of-3 for key rotation |

### 10.9 Upgrade Path — Adding Reporter Redundancy

V1 TRO uses a single trusted reporter. V2 can upgrade to a multi-reporter threshold model without changing the `IEventOracle` interface:

- Deploy a `MultiReporterAdapter` that requires N-of-M reporters to sign the same result  
- Each reporter