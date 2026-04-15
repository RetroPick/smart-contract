Here is the content of the provided document converted into Markdown format.

```markdown
**RetroPick Protocol**

Master Oracle Architecture & Market Innovation Plan

*V2.0 Expanded --- Chainlink Feed Taxonomy · Backend API Matrix · 12 Market Types*

| **Entity**                 | RetroPick FZ-LLC, RAK DAO, Ras Al Khaimah, UAE                              |
| :------------------------- | :-------------------------------------------------------------------------- |
| **Chain**                  | Arbitrum One (deployed) \| Solana (Phase 2 roadmap)                          |
| **Oracle infrastructure**  | Chainlink Price Feeds · Rate/Volatility Feeds · SmartData · US Macro Feeds · TrustedReporterAdapter |
| **Document version**       | 2.0 --- April 2026                                                          |
| **Classification**         | Confidential                                                                |

### **1. Executive Summary & Strategic Expansion**

This V2.0 document expands the original RetroPick Innovation Plan with three new dimensions: (1) a complete Chainlink feed taxonomy across all five feed families with Arbitrum One proxy addresses and oracle class assignments; (2) a comprehensive backend API matrix mapping every market subcategory to its authoritative free public API endpoint; and (3) three additional novel market types unlocked by Chainlink's Rate/Volatility and SmartData feeds that have no equivalent anywhere in the prediction market landscape.

> **V2.0 expansion summary**
> 
> - **12** total market type primitives (3 live V1 + 9 from V1 plan + 3 new from Chainlink feed analysis)
> - **5** Chainlink feed families now fully mapped: Price Feeds, Rate/Volatility Feeds, SmartData, US Macro Feeds, Tokenized Equity Feeds
> - **68+** Arbitrum One oracle feeds catalogued across crypto, forex, commodities, indices, rates, volatility, and macro
> - Complete backend API matrix: **40+** free public APIs matched to every RetroPick market subcategory
> - New oracle architecture: `IEventOracle` extended to `ICompositeOracle` supporting multi-feed, multi-type, multi-source resolution in one epoch

The core architectural principle from V1 remains unchanged and is strengthened: every market type resolves deterministically from oracle data. No human judge. No dispute window. V2.0 expands what 'oracle data' means --- from price-only to rates, volatility, macro indicators, NAV, AUM, proof-of-reserve, and structured financial data --- all via the same `AggregatorV3Interface` the existing `ChainlinkAdapter` already supports.

### **2. Chainlink Feed Taxonomy --- Complete Arbitrum One Catalogue**

Chainlink operates five distinct data feed families on Arbitrum One, each with a different data type, update model, and use case. RetroPick can consume all five via the existing `ChainlinkAdapter` pattern --- each feed type exposes the same `AggregatorV3Interface`. The table below is the master oracle registry for RetroPick template creation.

#### **2.1 Feed Family Overview**

| **Feed family**              | **Data type**                              | **Update model**                    | **RetroPick use case**                                                                               | **Oracle class**            |
| :--------------------------- | :----------------------------------------- | :---------------------------------- | :--------------------------------------------------------------------------------------------------- | :-------------------------- |
| **Price Feeds**              | Single numeric --- spot price              | Deviation + heartbeat (0.1--1%)     | Direction, Threshold, RangeClose, Velocity, Ladder, Anchor, Convergence, Composite, Cascade, Corridor | `CHAINLINK_PRICE_FEED`      |
| **Rate & Volatility Feeds**  | Realized volatility (%), BTC interest rate curve, ETH staking APR | Daily or deviation-triggered        | VolatilityBand (new type), StakingAPR (new type), BitcoinIRC (new type)                               | `CHAINLINK_RATE_FEED`       |
| **SmartData --- NAV / AUM**  | Net Asset Value, Assets Under Management   | Daily (fund administrator driven)   | NAV Threshold, AUM direction --- tokenized fund markets                                               | `CHAINLINK_SMARTDATA`       |
| **US Government Macro Feeds**| CPI, GDP, unemployment, trade balance --- NIST / BEA data onchain | Monthly (data release aligned)      | Economics subcategory markets --- inflation, growth, labor                                            | `CHAINLINK_MACRO`           |
| **Tokenized Equity Feeds**   | NAV of tokenized stocks & ETFs (Ondo Finance) | Daily, market-hours aligned         | Tokenized equity direction markets --- AAPL, TSLA, SPY, QQQ                                           | `CHAINLINK_EQUITY`          |
| **TrustedReporterAdapter**   | Any verifiable data --- signed by operator key | Event-triggered / on-demand         | Climate, tech, business, pre-TGE, DeFi metrics --- all non-price-feed categories                      | `TRUSTED_REPORTER`          |

*All six oracle classes share the `AggregatorV3Interface`. The `ChainlinkAdapter` in the current codebase supports `CHAINLINK_PRICE_FEED` natively. A `RateAdapter` and `SmartDataAdapter` follow the identical pattern --- same `getNormalizedPrice()` interface, different feed address.*

#### **2.2 Arbitrum One --- Price Feeds (Complete List)**

The following feeds are live on Arbitrum One mainnet. All use the same `ChainlinkAdapter` pattern. `feedId = bytes32(uint256(uint160(proxyAddress)))`.

**2.2.1 Crypto / USD Price Feeds**

| **Pair**      | **Decimals** | **Arbitrum One proxy address**                 | **Heartbeat / deviation** |
| :------------ | :----------- | :--------------------------------------------- | :----------------------- |
| **BTC/USD**   | 8            | `0x6ce185860a4963106506C203335A2910413708e9`   | 1h heartbeat / 0.05% dev |
| **ETH/USD**   | 8            | `0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612`   | 1h / 0.05%               |
| **SOL/USD**   | 8            | `0x24ceA4b8ce57cdA33F4B56b0a9f4FCC72A34fc6A`   | 1h / 0.05%               |
| **BNB/USD**   | 8            | `0x6970460aabF80C5BE983C6b74e5D06dEDCA95D4A`   | 1h / 0.05%               |
| **XRP/USD**   | 8            | `0xB4AD57B52aB9141de9926a3e0C8dc6264c2ef205`   | 24h / 0.05%              |
| **DOGE/USD**  | 8            | `0x9A7FB1b3950837a8D9b40517626E11D4127C098C`   | 24h / 0.05%              |
| **LINK/USD**  | 8            | `0x86E53CF1B873786aC9Cc9f7c0f1a60A11F01D10f`   | 1h / 0.05%               |
| **ARB/USD**   | 8            | `0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6`   | 1h / 0.05%               |
| **MATIC/USD** | 8            | `0x52099D4523531f678Dfc568a7B1e5038aadcE1d6`   | 1h / 0.05%               |
| **AVAX/USD**  | 8            | `0x8bf61728eeDCE2F32c456454d87B5d6eD6150208`   | 1h / 0.05%               |
| **OP/USD**    | 8            | `0x205aaD468a11fd5D34fA7211bC6Bad5b3deB9b98`   | 24h / 0.05%              |
| **ATOM/USD**  | 8            | `0xCDA67618e51762235eacA373894F0C79256768fa`   | 24h / 0.05%              |
| **UNI/USD**   | 8            | `0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720`   | 24h / 0.05%              |
| **AAVE/USD**  | 8            | `0xaD1d5344AaDE45F43E596773Bcc4c423EAbdDD14`   | 24h / 0.05%              |
| **GMX/USD**   | 8            | `0xDB98056FecFff59D032aB628337A4887110df3dB`   | 24h / 0.05%              |
| **PENDLE/USD**| 8            | `0x66853E19d73c0F9301fe099c324A1E9726171374`   | 24h / 0.05%              |

**2.2.2 Forex / USD Price Feeds**

| **Pair**   | **Decimals** | **Arbitrum One proxy address**                 | **Heartbeat / deviation** |
| :--------- | :----------- | :--------------------------------------------- | :----------------------- |
| **EUR/USD**| 8            | `0xA14d53bC1F1c0F31B4aA3BD109344E5009051a84`   | 1h / 0.10%               |
| **GBP/USD**| 8            | `0x9C4424Fd84C6661F97D8d6b3fc3C1aAc2BeDd137`   | 1h / 0.10%               |
| **JPY/USD**| 8            | `0x3dD6e51CB9caE717d5a8778CF79A04029f9cFDF8`   | 1h / 0.10%               |
| **AUD/USD**| 8            | `0x9854e9a850e7C354c1de177eA953a6b1fba8Fc22`   | 1h / 0.10%               |
| **CHF/USD**| 8            | `0xe32AccC8c4eC03F6E75bd3621BfC9Fbb234E1FC3`   | 1h / 0.10%               |
| **CAD/USD**| 8            | `0xf6DA27749484843c4F02f5Ad1378ceE723dD61d4`   | 1h / 0.10%               |
| **SGD/USD**| 8            | `0xF0d38324d1F86a176aC727A4b0c43c9F9d9c5EB1`   | 24h / 0.15%              |
| **KRW/USD**| 8            | `0x85bb02E0Ae286600d1c68Bb6Ce22CC998d411916`   | 24h / 0.15%              |
| **CNY/USD**| 8            | `0xcC3370Bde6AFE51e1205a5038947b9836371eCCb`   | 24h / 0.15%              |

*Note: USD/AED and USD/SAR are not on Chainlink Arbitrum. Use `TrustedReporterAdapter` sourced from UAE Central Bank API or a forex data API for GCC pairs. These represent a first-mover opportunity.*

**2.2.3 Commodities --- Metals & Energy**

| **Asset**                | **Decimals** | **Arbitrum One proxy address**                 | **Heartbeat / deviation** |
| :----------------------- | :----------- | :--------------------------------------------- | :----------------------- |
| **XAU/USD (Gold)**       | 8            | `0x1F954Dc24a49708C26E0C1777f16750B5C6d5a2c`   | 1h / 0.10%               |
| **XAG/USD (Silver)**     | 8            | `0xC56765f04B248394CF1619D20dB8082Edbfa75b1`   | 1h / 0.10%               |
| **WTI Crude Oil / USD**  | 8            | `0x594b919AD828e693B935705c3F816221729E7AE8`   | 1h / 0.10%               |
| **BTC Denominated in XAU**| 8            | *Derived: BTC/USD ÷ XAU/USD --- use dual-feed Convergence* | *Derived feed*           |
| **Natural Gas / USD**    | 8            | `0x0d79df66BE487753B02D015Fb622DED7f0E9798d`   | 24h / 0.10%              |

**2.2.4 Equity Indices & ETF Feeds**

| **Asset**               | **Decimals** | **Arbitrum One proxy address**                 | **Notes**                                 |
| :---------------------- | :----------- | :--------------------------------------------- | :---------------------------------------- |
| **SPX / USD (S&P 500)** | 8            | `0x43593c715Fdd31c61141ABd1F07E10ED07` (via Chainlink) | Market-hours only, 15m delay              |
| **NASDAQ Composite / USD**| 8          | *Via Chainlink Streams --- contact for Arbitrum address* | Data Streams for sub-second updates       |
| **Tokenized SPY NAV (via Ondo)**| 8       | *Chainlink NAVLink on Ondo/Arbitrum --- see SmartData catalogue* | Ondo Finance partnership                  |
| **Tokenized QQQ NAV (via Ondo)**| 8       | *Chainlink NAVLink --- Ondo platform*          | Daily NAV update                          |
| **Tokenized AAPL / TSLA (Ondo)**| 8       | *Ondo OUSG / OSOL via Chainlink tokenized equity feeds* | Equity direction markets                  |

#### **2.3 Rate & Volatility Feeds --- New Oracle Class**

Chainlink's Rate and Volatility feeds unlock three new market types that have never existed. These feeds use the same `AggregatorV3Interface` as price feeds. A new `RateAdapter.sol` follows the identical pattern as `ChainlinkAdapter` with no engine changes required.

| **Feed name**            | **Data type**                     | **Update frequency**        | **Market type enabled**                            |
| :----------------------- | :-------------------------------- | :-------------------------- | :------------------------------------------------- |
| **BTC Realized Vol 24h** | % annualized --- sampled every 10m | Deviation + 1h heartbeat    | **VolatilityBand**: is BTC realized vol above X% today? |
| **BTC Realized Vol 7-day**| % annualized rolling 7d          | Deviation + 24h heartbeat   | Weekly vol regime prediction                       |
| **BTC Realized Vol 30-day**| % annualized rolling 30d         | Deviation + 24h heartbeat   | Monthly vol band market                            |
| **ETH Realized Vol 24h** | % annualized                      | Deviation + 1h heartbeat    | ETH volatility speed markets (feeds Velocity type) |
| **ETH Realized Vol 7-day**| % annualized rolling              | Deviation + 24h heartbeat   | ETH weekly vol prediction                          |
| **ETH Staking APR 30-day**| % annualized return               | Daily --- once per day minimum | **StakingAPR** type: will ETH staking yield exceed X%? |
| **ETH Staking APR 90-day**| % annualized return               | Daily                       | Quarterly staking yield market                     |
| **BTC Interest Rate Curve (CF BIRC)** | Daily rate %           | Daily --- OTC + DeFi aggregated | **BitcoinIRC** type: will BTC lending rate exceed X%? |

> **Why Rate & Volatility feeds are a strategic unlock**
> 
> These feeds allow RetroPick to create markets on financial primitives that derivatives traders care about deeply --- volatility regimes, lending rates, staking yields. No prediction market has ever offered a 'will realized volatility exceed X%?' market. This is a product that options traders and DeFi yield farmers will immediately understand and want to use. The oracle is already decentralized and live. The market type is a 3-line resolver.

#### **2.4 Chainlink SmartData --- NAV, AUM, and Proof of Reserve**

SmartData feeds provide onchain Net Asset Value (NAV) and Assets Under Management (AUM) for tokenized real-world assets. These are live on Arbitrum One and used by institutional DeFi protocols. For RetroPick, they enable a category of market that has never existed: betting on whether a tokenized fund's NAV will cross a threshold, or whether a token's reserves remain above a minimum.

| **SmartData feed type**| **Example assets**                              | **Update model**            | **RetroPick market type**                                 |
| :--------------------- | :---------------------------------------------- | :-------------------------- | :-------------------------------------------------------- |
| **SmartNav (NAV feed)**| Ondo OUSG (tokenized US Treasury ETF), Superstate USTB | Daily --- fund administrator | **NAV Threshold**: will tokenized fund NAV exceed $X?     |
| **SmartAUM (AUM feed)**| BlackRock BUIDL, Franklin Templeton FOBXX       | Daily or weekly             | **AUM Direction**: will fund AUM grow this week?          |
| **Proof of Reserve (PoR)** | WBTC, USDT, USDC, tBTC, cbBTC, stETH         | Continuous or daily         | **Reserve Health**: will PoR ratio stay above 100%?       |
| **MVR Feeds (multi-variable)** | Multiple values per tx: NAV + AUM + reserve ratio | Single tx, multiple values  | **Composite**: NAV above X AND reserves above Y           |

#### **2.5 US Government Macroeconomic Feeds (Onchain)**

Chainlink launched a unique category in 2025: US Government macroeconomic data published onchain via official US Department of Commerce data. These are the first macroeconomic data feeds natively on-chain with Chainlink's decentralized oracle network --- not `TrustedReporter`, not a single operator. This is fully decentralized macroeconomic oracle data.

| **Feed**               | **Data source**                         | **Update cadence**          | **RetroPick market enabled**                          |
| :--------------------- | :-------------------------------------- | :-------------------------- | :---------------------------------------------------- |
| **US CPI YoY**         | Bureau of Labor Statistics (BLS)        | Monthly (data release day)  | Will US CPI exceed X% this month?                     |
| **US Core CPI YoY**    | BLS --- ex food & energy                | Monthly                     | Core inflation threshold markets                      |
| **US PCE YoY (Fed preferred)** | Bureau of Economic Analysis (BEA) | Monthly                     | PCE vs Fed target --- above/below 2%?                 |
| **US GDP QoQ Advance** | BEA --- advance GDP estimate            | Quarterly                   | Will Q3 GDP beat +2.5%?                               |
| **US Unemployment Rate**| BLS --- monthly jobs report            | Monthly                     | Will unemployment stay below 4%?                      |
| **US NFP (Nonfarm Payrolls)** | BLS --- monthly jobs report       | Monthly                     | Will NFP beat 200K this month?                        |
| **US Trade Balance**   | US Census Bureau                        | Monthly                     | Will trade deficit widen?                             |

> **Chainlink US Macro feeds = zero `TrustedReporter` needed for economics**
> 
> The previous V1 plan required `TrustedReporterAdapter` for all economics markets. With Chainlink's new US Government Macroeconomic data feeds now live onchain, CPI, PCE, GDP, unemployment, and NFP markets resolve from a fully decentralized oracle --- same as BTC/USD. This is a significant trust upgrade. The resolver is the same `resolveThreshold()` already in production.

### **3. Backend API Matrix --- Free Public APIs by Market Subcategory**

For market subcategories not covered by Chainlink's onchain feeds, the `TrustedReporterAdapter` backend service fetches data from authoritative public APIs. The following matrix covers every subcategory in the RetroPick taxonomy with its primary API source, endpoint pattern, free tier availability, and rate limits.

#### **3.1 Economics APIs**

| **Subcategory**      | **API source**      | **Endpoint / data series**                                         | **Free tier**                                     | **Update**      |
| :------------------- | :------------------ | :----------------------------------------------------------------- | :------------------------------------------------ | :-------------- |
| **US CPI**           | BLS public API v2   | `api.bls.gov/publicAPI/v2/timeseries/data/` series: `CPIAUCSL`     | Yes --- 25 req/day unregistered, 500/day with key  | Monthly         |
| **US Core CPI**      | BLS public API v2   | series: `CPILFESL`                                                 | Yes --- same as above                             | Monthly         |
| **US PCE**           | FRED API (St. Louis Fed) | `api.stlouisfed.org/fred/series/observations?series_id=PCEPI` | Yes --- unlimited with free API key                | Monthly         |
| **Fed Funds Rate**   | FRED API            | `series_id=FEDFUNDS`                                               | Yes --- free                                      | 8 per year (FOMC)|
| **US GDP**           | BEA API             | `apps.bea.gov/api/data?datasetname=NIPA&TableName=T10105`          | Yes --- free with key                             | Quarterly       |
| **US NFP / Unemployment** | BLS public API v2 | series: `CES0000000001` (NFP), `LNS14000000` (UE)                  | Yes --- free                                      | Monthly         |
| **10Y Treasury Yield**| FRED API           | `series_id=DGS10`                                                  | Yes --- free                                      | Daily           |
| **2Y Treasury Yield** | FRED API           | `series_id=DGS2`                                                   | Yes --- free                                      | Daily           |
| **Yield Curve (spread)**| FRED API          | `series_id=T10Y2Y` (10Y-2Y spread)                                 | Yes --- free                                      | Daily           |
| **ISM PMI**          | ISM / FRED          | `series_id=MANEMP` (proxy) or ISM press release parsing            | Free via FRED proxy                               | Monthly         |
| **EU HICP / ECB Rate**| ECB Data Portal     | `sdw-wsrest.ecb.europa.eu/service/data/ICP`                        | Yes --- free, no key                              | Monthly / ECB meetings |
| **GCC: UAE CPI**     | UAE Statistics Authority | `bayanat.ae` API (public portal) or `TrustedReporter` from CBUAE PDF | Free --- PDF parsing needed                        | Monthly         |
| **GCC: Saudi SAMA rate**| SAMA official      | `open.sama.gov.sa/api` (public data portal)                        | Yes --- free                                      | Varies          |

#### **3.2 Climate & Weather APIs**

| **Subcategory**         | **API source**      | **Endpoint pattern**                                                                    | **Free tier**                    | **Granularity**  |
| :---------------------- | :------------------ | :-------------------------------------------------------------------------------------- | :------------------------------- | :--------------- |
| **Temperature records** | Open-Meteo          | `api.open-meteo.com/v1/forecast?latitude=25.2&longitude=55.3&daily=temperature_2m_max`  | Yes --- unlimited                | Hourly/daily     |
| **Dubai / UAE weather** | Open-Meteo + NCMS   | `api.open-meteo.com` --- Dubai coords `25.2048, 55.2708`                                 | Yes --- free                     | Hourly           |
| **Rainfall / precipitation**| Open-Meteo       | `daily=precipitation_sum` parameter                                                      | Yes --- free                     | Daily            |
| **Hurricane / cyclone count**| NOAA NHC API     | `nhc.noaa.gov/data/tcr/` (REST endpoints)                                                | Yes --- free                     | Seasonal         |
| **Earthquake magnitude** | USGS Earthquake API | `earthquake.usgs.gov/fdsnws/event/1/query?format=geojson`                                | Yes --- free, no key             | Real-time        |
| **Global temp anomaly**  | NOAA NCEI Climate API| `www.ncei.noaa.gov/cdo-web/api/v2/data`                                                 | Yes --- free with token          | Monthly          |
| **Air quality index (AQI)**| OpenAQ API         | `api.openaq.org/v2/measurements?location_id=...`                                         | Yes --- free                     | Hourly           |
| **Dubai AQI specifically**| IQAir API          | `api.airvisual.com/v2/city?city=Dubai`                                                   | Free tier: 10k req/month         | Real-time        |
| **Arctic sea ice extent** | NSIDC public data  | `nsidc.org/data/seaice_index` --- CSV files                                              | Yes --- free download            | Daily            |
| **Solar energy production**| EIA API            | `api.eia.gov/v2/electricity/facility-fuel/data/`                                         | Yes --- free API key             | Monthly          |

#### **3.3 Technology & Science APIs**

| **Subcategory**           | **API source**           | **Endpoint / method**                                                               | **Free tier**                        | **Latency**       |
| :------------------------ | :----------------------- | :---------------------------------------------------------------------------------- | :----------------------------------- | :---------------- |
| **AI model releases (OpenAI)** | OpenAI public blog / GitHub | `api.github.com/repos/openai/openai-python/releases` --- version tags               | Yes --- 60 req/h unauth, 5000 with token | Real-time         |
| **AI benchmarks (MMLU, GPQA)**| HuggingFace Open LLM Leaderboard | `huggingface.co/api/models?filter=text-generation` --- scrape leaderboard JSON      | Yes --- free                         | Daily updates     |
| **FDA drug approvals**    | FDA openFDA API          | `api.fda.gov/drug/drugsfda.json`                                                    | Yes --- 1000 req/h without key       | On approval       |
| **SpaceX / NASA launches**| SpaceX API (unofficial)  | `api.spacexdata.com/v5/launches` (community maintained)                              | Yes --- free                         | Event-driven      |
| **App Store rankings**    | iTunes RSS / App Annie   | `itunes.apple.com/us/rss/topfreeapplications/limit=100/json`                         | Yes --- free                         | Real-time         |
| **Semiconductor news / TSMC**| SEC EDGAR + official press releases | `efts.sec.gov/LATEST/search-index?q=TSMC&dateRange=custom`                           | Yes --- free                         | Event-driven      |
| **Energy transition (EV share)**| IEA public data         | `iea.org/data-and-statistics` (CSV download) --- no live API                          | Free --- manual trigger              | Annual/quarterly  |
| **EU tech regulation (fines, laws)**| EUR-Lex API            | `api.op.europa.eu/legislation-identifier` --- JSON                                    | Yes --- free                         | Event-driven      |

#### **3.4 DeFi Protocol Metrics APIs**

| **Metric**               | **API source**        | **Endpoint**                                                                 | **Free tier**                        | **Update**    |
| :----------------------- | :-------------------- | :--------------------------------------------------------------------------- | :----------------------------------- | :------------ |
| **Protocol TVL (all)**   | DeFiLlama API         | `api.llama.fi/protocols` --- JSON array with current TVL                      | Yes --- no key                       | Real-time     |
| **Chain TVL (Arbitrum, Base, etc)**| DeFiLlama          | `api.llama.fi/v2/chains`                                                      | Yes --- free                         | Real-time     |
| **Stablecoin market cap**| DeFiLlama Stablecoins | `stablecoins.llama.fi/stablecoins`                                            | Yes --- free                         | Real-time     |
| **DEX volume (Uniswap, etc)**| DeFiLlama / The Graph | `api.llama.fi/overview/dexs` or Uniswap v3 subgraph                           | Yes --- free                         | Daily         |
| **BTC spot ETF flows**   | CoinGlass API         | `open-api.coinglass.com/public/v2/fund/btc-spot-fund-flow`                    | Free tier: 100 req/day               | Daily         |
| **Crypto open interest** | CoinGlass             | `open-api.coinglass.com/public/v2/openInterest`                               | Free tier available                  | Real-time     |
| **Funding rates**        | CoinGlass             | `open-api.coinglass.com/public/v2/fundingRate`                                | Free tier available                  | Real-time     |
| **ETH gas (gwei)**       | Etherscan Gas Oracle  | `api.etherscan.io/api?module=gastracker`                                      | Free: 100k req/day with key          | Real-time     |
| **L2 bridge flows**      | L2Beat API            | `l2beat.com/api/tvl` (public endpoint)                                        | Yes --- free                         | Daily         |
| **Pre-TGE listing price**| Binance / OKX spot feed| `api.binance.com/api/v3/ticker/price?symbol=XYZUSDT` --- day 1 listing        | Yes --- free                         | Real-time on listing |

#### **3.5 Business & Corporate Events APIs**

| **Event type**               | **API source**         | **Endpoint / method**                                                                | **Free tier**                        | **Timing**         |
| :--------------------------- | :--------------------- | :----------------------------------------------------------------------------------- | :----------------------------------- | :----------------- |
| **IPO filings & pricing**    | SEC EDGAR API          | `data.sec.gov/submissions/` --- S-1, 424B4 forms                                     | Yes --- free                         | Day of filing      |
| **Earnings beats (EPS vs estimate)**| Financial Modeling Prep (FMP) | `financialmodelingprep.com/api/v3/earnings-surprises/` --- free tier                  | 250 req/day free                     | Post-earnings      |
| **M&A announcements**        | SEC EDGAR 8-K filings  | `efts.sec.gov/LATEST/search-index?q=acquisition&dateRange=custom`                    | Yes --- free                         | Day of announcement|
| **CEO / executive changes**  | SEC EDGAR 8-K (Item 5.02)| EDGAR full-text search: `efts.sec.gov`                                               | Yes --- free                         | Day of filing      |
| **Product launches (Apple, Tesla)**| Apple Newsroom RSS / Tesla IR RSS | Apple: `newsroom.apple.com/rss-feed.rss` --- Tesla: `ir.tesla.com/rss/`               | Yes --- free RSS                     | Event-driven       |
| **Layoff announcements**     | SEC 8-K (Item 2.05) + Layoffs.fyi API | `layoffs.fyi/api` (unofficial) or EDGAR                                              | Free --- unofficial                  | Event-driven       |
| **DOJ / FTC antitrust rulings**| US Courts PACER RSS / DOJ press release RSS | `justice.gov/news` --- RSS feed                                                       | Yes --- free                         | Event-driven       |

#### **3.6 GCC / MENA Specific APIs**

These APIs are entirely uncovered by US-based prediction platforms. They represent a structural first-mover advantage for RetroPick's UAE FZ-LLC positioning.

| **Data point**          | **API source**                      | **Endpoint / method**                                            | **Free?**               | **Cadence**            |
| :---------------------- | :---------------------------------- | :-------------------------------------------------------------- | :---------------------- | :--------------------- |
| **UAE CPI**             | Federal Competitiveness & Statistics Centre | `bayanat.ae/en/api` (open data portal)                          | Yes                     | Monthly                |
| **CBUAE benchmark rate**| Central Bank of UAE                 | `cbuae.gov.ae` (press release PDF + RSS)                        | Yes --- needs parsing   | 8 meetings/year        |
| **Saudi SAMA policy rate**| SAMA Open Data                     | `open.sama.gov.sa/en/open-data`                                 | Yes --- free            | 6--8 times/year        |
| **Aramco production figures**| Saudi Aramco IR (SEC-equivalent 20-F) | `aramco.com/en/investors/reports` and SEC EDGAR                 | Yes --- free            | Quarterly              |
| **DXB / ADGM aviation data**| Dubai Airports annual report / GCAA | `gcaa.gov.ae/en/open-data` (partial)                            | Limited --- annual      | Annual                 |
| **USD/AED exchange rate**| UAE Central Bank or ExchangeRate-API| `exchangerate-api.com/v6/latest/USD` --- AED from peg data      | Free tier: 1500/month   | Daily                  |
| **UAE weather (NCMS)**  | Open-Meteo (includes UAE stations) + official NCMS | `ncm.ae` or `api.open-meteo.com` (UAE coords)                   | Yes --- free            | Hourly                 |
| **Tadawul (Saudi stock exchange)**| Tadawul openAPI / Yahoo Finance proxy | `finance.yahoo.com/quote/2222.SR` for Aramco etc.               | Free --- unofficial     | Real-time trading hours |

### **4. Three New Market Types --- Unlocked by Chainlink Rate & SmartData Feeds**

Analysing Chainlink's Rate/Volatility feeds and SmartData feeds reveals three market types that were not in the V1 innovation plan. Each resolves from a Chainlink feed that already exists on Arbitrum One. No `TrustedReporter` needed. No new oracle infrastructure. These are V1.5-priority additions alongside Anchor and Velocity.

#### **4.1 VolatilityBand --- Predict whether realized volatility exceeds a threshold**

> **What makes this different from Velocity**
> 
> Velocity (V1 plan) measures the actual price move percentage during an epoch. VolatilityBand reads Chainlink's realized volatility feed directly --- a rolling-window volatility measure aggregated from multiple data providers every 10 minutes. The user predicts a volatility regime ('will BTC be more than 60% annualized vol this week?'), not a specific price move. This is a derivatives concept being made accessible to retail.

**How VolatilityBand works end to end**

1.  Admin creates a template with `MarketType.VolatilityBand`, `oracleFeedId` = BTC Realized Vol 7-day Chainlink address, and `volThresholdE4` = 6000 (60.00% annualized)
2.  Epoch opens. Users deposit to side 0 (`VOL_HIGH`: vol will exceed 60%) or side 1 (`VOL_LOW`: vol will stay at or below 60%)
3.  No checkpoint A needed --- the vol feed has no lock-time reference price
4.  At resolve, engine reads checkpoint B from the realized volatility Chainlink feed. `resolveVolatilityBand(checkpointB.valueE4, volThresholdE4)` returns `winningOutcomeMask`
5.  Settlement as normal. Protocol fee applied. Pool distributed to winning side

| **Attribute**      | **Specification**                               | **Notes**                                   |
| :----------------- | :---------------------------------------------- | :------------------------------------------ |
| **New enum value** | `MarketType.VolatilityBand`                     | Additive to `MarketTypes.sol`               |
| **Template fields**| `volThresholdE4: uint32` --- vol % in basis points x100 | 60% = 6000; 80% = 8000                      |
| **Oracle feed**    | Chainlink BTC/ETH Realized Vol 7d or 30d --- existing Arbitrum address | `RateAdapter` (same pattern as `ChainlinkAdapter`) |
| **Resolver**       | `resolveVolatilityBand(checkpointB, threshold)` --- compare value to threshold | 5 lines --- identical to `resolveThreshold` |
| **Epoch struct changes** | None --- uses existing `checkpointB` only       | No checkpoint A                             |
| **Complexity**     | Lowest --- port of `resolveThreshold` with different feed | V1.5 priority                               |

**Market examples**
- Will BTC 7-day realized volatility exceed 70% annualized at week close? --- crypto volatility regime bet
- Will ETH realized vol stay below 50% for the entire month? --- 'calm market' prediction for DeFi LPs
- Will BTC 30-day volatility be higher or lower than the 7-day volatility at month close? --- convergence variant
- Will ETH realized vol exceed the 90-day historical average this week? --- Anchor variant with vol reference

#### **4.2 StakingAPR --- Predict whether ETH staking yield crosses a threshold**

> **Why this market exists**
> 
> Chainlink's ETH Staking APR feeds provide daily onchain APR for ETH validator staking over 30-day and 90-day rolling windows. ETH staking yield affects the entire Lido / EigenLayer / restaking ecosystem. Institutional DeFi participants make capital allocation decisions based on whether staking yield is above or below key thresholds (4%, 5%, 6%). A prediction market on staking APR is a natural hedging and speculative instrument for this enormous market --- ~$50B in ETH staked.

**How StakingAPR works end to end**

6.  Admin creates template with `MarketType.StakingAPR`, `oracleFeedId` = ETH Staking APR 30-day Chainlink feed address, `aprThresholdBps` = 450 (4.50%)
7.  Epoch opens weekly or monthly. Users deposit to HIGH (APR will exceed 4.50%) or LOW (will be at or below 4.50%)
8.  At resolve (weekly), engine reads ETH staking APR from Chainlink feed. `resolveStakingAPR` is identical to `resolveThreshold`
9.  Window variants: use 30-day feed for monthly markets, 90-day feed for quarterly markets --- different template, same resolver

**Market examples**
- Will ETH 30-day staking APR exceed 4.5% at month close? --- yield threshold for institutional stakers
- Will ETH staking yield fall below 3% this quarter? --- bearish APR market for protocol revenue modelers
- Will ETH staking APR be higher this month than last month? --- direction market using dual-epoch anchor comparison

| **Attribute**      | **Specification**                                | **Notes**                                          |
| :----------------- | :----------------------------------------------- | :------------------------------------------------- |
| **New enum**       | `MarketType.StakingAPR`                          | Additive                                           |
| **Template fields**| `aprThresholdBps: uint32` (APR in basis points), `stakingWindow: enum{30d, 90d}` | 4.5% = 450 bps                                     |
| **Oracle feed**    | Chainlink ETH Staking APR 30d or 90d --- live on Arbitrum | Read via `RateAdapter`                             |
| **Resolver**       | `resolveStakingAPR` = `resolveThreshold` with APR value | Zero new code                                      |
| **Complexity**     | Lowest --- pure template configuration, identical resolver | V1.5 priority                                      |

#### **4.3 BitcoinIRC --- Predict Bitcoin interest rate curve direction or threshold**

> **Why this market exists**
> 
> Chainlink's Bitcoin Interest Rate Curve (CF BIRC) brings institutional-grade BTC lending market rates onchain. This feed aggregates OTC lending desks, DeFi lending pools, and perpetual futures funding rates into a single daily BTC interest rate. As institutional BTC lending and borrowing scales (via Aave, Morpho, protocols using BTC as collateral), market participants need to hedge their interest rate exposure. A prediction market on BTC lending rates is a genuinely novel institutional-grade instrument.

**Market examples**
- Will BTC 30-day lending rate exceed 8% annualized by month end? --- threshold market for BTC lenders
- Will BTC lending rate be higher or lower than it is today in 7 days? --- direction market for rate traders
- Will BTC lending rate fall below ETH staking APR this quarter? --- convergence market using dual Chainlink rate feeds

| **Attribute**      | **Specification**                                            | **Notes**                                                    |
| :----------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| **New enum**       | `MarketType.BitcoinIRC` *or reuse Direction/Threshold*       | These are scalar feeds                                       |
| **Oracle feed**    | Chainlink CF BIRC feed --- Arbitrum address from `docs.chain.link/data-feeds/rates-feeds/addresses` | `RateAdapter`                                                |
| **Resolver**       | `resolveDirection` or `resolveThreshold` --- no new code needed | BTC IRC is a price-like scalar value                         |
| **Implementation complexity** | Zero --- existing Direction/Threshold templates, new feed address only | Deploy new template, no code change                          |
| **Recommended epoch cadence** | Daily or weekly --- matches CF BIRC daily update             | Rolling daily works                                           |

### **5. Complete Market Type Registry --- 12 Primitives**

The following is the complete V2.0 market type registry. The 12 types span four oracle classes. Types marked V1 are live. Types marked V1.5 are the highest-priority additions requiring minimal code. Types marked V2 and V3 require more infrastructure.

| **Market type**      | **Core mechanic**                       | **Oracle class**           | **Contract delta**                           | **Phase** | **Complexity** |
| :------------------- | :-------------------------------------- | :------------------------- | :------------------------------------------- | :-------- | :------------- |
| **Direction**        | Price B vs price A                      | `CHAINLINK_PRICE_FEED`     | None --- live                                | V1        | Live           |
| **Threshold**        | B vs fixed level                        | `CHAINLINK_PRICE_FEED`     | None --- live                                | V1        | Live           |
| **RangeClose**       | N-bucket landing                        | `CHAINLINK_PRICE_FEED`     | None --- live                                | V1        | Live           |
| **Anchor**           | B vs historic reference                 | `CHAINLINK_PRICE_FEED`     | 1 field + 3-line resolver                    | V1.5      | Lowest         |
| **Velocity**         | % move speed bucket                     | `CHAINLINK_PRICE_FEED`     | 1 field + 15-line resolver                   | V1.5      | Lowest         |
| **VolatilityBand**   | Realized vol vs threshold               | `CHAINLINK_RATE_FEED`      | 1 field + `RateAdapter`                      | V1.5      | Lowest         |
| **StakingAPR**       | ETH APR vs threshold                    | `CHAINLINK_RATE_FEED`      | Template only (reuses Threshold resolver)    | V1.5      | Lowest         |
| **BitcoinIRC**       | BTC lending rate direction              | `CHAINLINK_RATE_FEED`      | Template only (reuses Direction resolver)    | V1.5      | Lowest         |
| **Ladder**           | Progressive payout tiers                | `CHAINLINK_PRICE_FEED`     | 2 fields + payout math                       | V2        | Medium         |
| **Convergence**      | Two-asset spread direction              | `CHAINLINK_PRICE_FEED` x2  | Dual feed + spread resolver                  | V2        | Medium         |
| **Composite**        | AND/OR multi-asset logic                | `CHAINLINK_PRICE_FEED` x4  | Array fields + logic resolver                | V2        | Medium         |
| **Momentum**         | N-epoch streak                          | `CHAINLINK_PRICE_FEED`     | Array checkpoint + scorer                    | V2        | Medium         |
| **Streak**           | Pre-committed sequence                  | `CHAINLINK_PRICE_FEED`     | Position struct extension                    | V2        | High           |
| **Corridor**         | Sustained range                         | `CHAINLINK + Reporter`     | OHLC Reporter extension                      | V3        | High           |
| **Cascade**          | Multi-trigger waterfall                 | `CHAINLINK + Reporter`     | High watermark Reporter                      | V3        | High           |

> **V1.5 delivers 5 new market types with near-zero code change**
> 
> Anchor and Velocity use existing `ChainlinkAdapter`. VolatilityBand, StakingAPR, and BitcoinIRC add a `RateAdapter` (30-line port of `ChainlinkAdapter`) and 3 new template configurations. The total new code is under 100 lines across all 5 types. This is the highest ROI engineering sprint in RetroPick's roadmap --- 5 novel market types no competitor has, shipping in 2--3 weeks.

### **6. Updated Oracle Architecture --- `ICompositeOracle`**

V2.0 introduces a cleaner oracle routing model. The existing single `OracleType` enum is expanded to an `ICompositeOracle` design pattern that accommodates all six oracle classes without changing the engine's core `resolveEpoch()` path. The pattern remains: read oracle → get value → pass to resolver.

#### **6.1 Oracle Class Enum Extension**

```solidity
// MarketTypes.sol --- oracle class enum extension

enum OracleClass {
    CHAINLINK_PRICE_FEED,   // existing --- ChainlinkAdapter
    CHAINLINK_RATE_FEED,    // new --- RateAdapter (same interface)
    CHAINLINK_SMARTDATA,    // new --- SmartDataAdapter (same interface)
    CHAINLINK_MACRO,        // new --- US macro feeds (same interface)
    CHAINLINK_EQUITY,       // new --- Ondo tokenized equity (same interface)
    TRUSTED_REPORTER        // existing --- TrustedReporterAdapter
}

// MarketTemplate extension
struct MarketTemplate {
    // ... existing fields ...
    OracleClass oracleClass;        // NEW: which adapter handles this template
    IPriceOracle oracleAdapter;     // NEW: pointer to the correct adapter instance
}
```

#### **6.2 `RateAdapter.sol` --- 30-line Port of `ChainlinkAdapter`**

The `RateAdapter` follows the identical pattern as `ChainlinkAdapter`. The only difference is that realized volatility values are expressed as a percentage (e.g. 65.43% = 6543 in e4 format) rather than a price. The `AggregatorV3Interface` is identical. The adapter normalizes to e8 for internal consistency.

```solidity
// RateAdapter.sol --- identical interface to ChainlinkAdapter

contract RateAdapter is IPriceOracle {
    // Same AggregatorV3Interface consumption
    // latestRoundData() returns the rate/vol value
    // Normalized to e8 for engine consistency
    // Staleness check uses the same maxAgeSeconds pattern
    // No confidence band for rate feeds (returns confidenceE8 = 0)
    // Sequencer uptime check: same L2 pattern
}

// To add a new rate feed template:
// feedId = bytes32(uint256(uint160(chainlinkRateFeedProxyAddress)))
// This is literally identical to how BTC/USD is configured today
```

#### **6.3 Resolver Extensions for Rate/Vol Market Types**

```solidity
// Resolvers.sol additions --- all pure functions, no state

// VolatilityBand: will realized vol exceed threshold?
function resolveVolatilityBand(
    uint32 volValueE4,  // from Chainlink realized vol feed
    uint32 thresholdE4, // e.g. 6000 = 60.00%
    Condition condition // AtOrAbove or Below
) internal pure returns (uint256 mask) {
    bool high = condition == Condition.AtOrAbove 
        ? volValueE4 >= thresholdE4 
        : volValueE4 < thresholdE4;
    return high ? (uint256(1) << 0) : (uint256(1) << 1);
}

// Note: resolveStakingAPR and resolveBitcoinIRC are IDENTICAL to resolveThreshold
// They are the same function --- just with different feed values
// No new resolver code needed for StakingAPR or BitcoinIRC
```

#### **6.4 `TrustedReporter` Upgrade --- `postOHLCResult()`**

The `TrustedReporterAdapter` is upgraded to support intraday OHLC data (required for Cascade and Corridor market types). The new `postOHLCResult()` function accepts four signed values in a single transaction: open, high, low, close. This is the only contract change needed for V3 types.

```solidity
// TrustedReporterAdapter.sol --- OHLC extension

struct OHLCResolution {
    int256 openE8;
    int256 highE8;
    int256 lowE8;
    int256 closeE8;
    uint256 timestamp;
    bool resolved;
    string dataSource;
}

function postOHLCResult(
    bytes32 marketId,
    int256 openE8, int256 highE8, int256 lowE8, int256 closeE8,
    uint256 timestamp,
    string calldata dataSource,
    bytes calldata signature
) external {
    // Same ECDSA verification pattern as postResult()
    // Stores all four values atomically
}
```

### **7. Complete Market Category Matrix --- Oracle + API + Market Type**

This is the definitive oracle routing table for every RetroPick market subcategory. Each row maps a market concept to its oracle class, Chainlink feed or backend API, resolution data point, and recommended primary market type.

#### **7.1 Crypto Category**

| **Subcategory**       | **Oracle class**       | **Feed / API**                                  | **Resolution data point**  | **Primary market types**                     |
| :-------------------- | :--------------------- | :---------------------------------------------- | :------------------------- | :------------------------------------------- |
| **BTC/USD price**     | `PRICE_FEED`           | Chainlink BTC/USD Arbitrum                      | Close price                | Direction, Velocity, Ladder, Anchor          |
| **ETH/USD price**     | `PRICE_FEED`           | Chainlink ETH/USD Arbitrum                      | Close price                | Direction, Velocity, VolatilityBand via rate feed |
| **BTC dominance**     | `TRUSTED_REPORTER`     | CoinMarketCap API `/global-metrics/quotes`      | BTC % of total market cap  | Threshold, Direction                         |
| **BTC realized vol**  | `RATE_FEED`            | Chainlink BTC Realized Vol 7d                   | % annualized               | VolatilityBand, Anchor                       |
| **ETH staking APR**   | `RATE_FEED`            | Chainlink ETH Staking APR 30d                   | % annualized APR           | StakingAPR (Threshold)                       |
| **BTC lending rate**  | `RATE_FEED`            | Chainlink CF BIRC                               | Daily rate %               | BitcoinIRC (Direction/Threshold)             |
| **BTC spot ETF flows**| `TRUSTED_REPORTER`     | CoinGlass API `/btc-spot-fund-flow`             | Net daily inflow USD       | Threshold, Direction                         |
| **Stablecoin depeg**  | `PRICE_FEED`           | Chainlink USDT/USD or USDC/USD                  | Price vs $1.00             | Corridor ($0.998--$1.002)                    |
| **BTC OI / funding rate**| `TRUSTED_REPORTER`  | CoinGlass API `/openInterest` `/fundingRate`    | USD value / %              | Threshold, Direction                         |
| **DeFi TVL (Aave, Uniswap)**| `TRUSTED_REPORTER`| DeFiLlama `/protocols`                          | USD TVL value              | Threshold, Direction                         |
| **Pre-TGE listing price**| `TRUSTED_REPORTER`  | Binance `/api/v3/ticker/price` on listing day   | First 24h close price      | Threshold: above/below issue price           |

#### **7.2 Economics Category**

| **Subcategory**       | **Oracle class**       | **Feed / API**                                  | **Resolution data point**  | **Primary market types**                     |
| :-------------------- | :--------------------- | :---------------------------------------------- | :------------------------- | :------------------------------------------- |
| **US CPI**            | `CHAINLINK_MACRO`      | Chainlink US Macro Feeds (onchain)              | YoY CPI %                  | Threshold, Anchor                            |
| **US Core CPI**       | `CHAINLINK_MACRO`      | Chainlink US Macro Feeds                        | YoY core CPI %             | Threshold                                    |
| **US PCE**            | `CHAINLINK_MACRO`      | Chainlink US Macro Feeds                        | YoY PCE %                  | Threshold, Anchor (vs Fed 2% target)         |
| **US GDP**            | `CHAINLINK_MACRO`      | Chainlink US Macro Feeds (BEA data)             | QoQ growth %               | Threshold, Direction                         |
| **US NFP**            | `CHAINLINK_MACRO`      | Chainlink US Macro Feeds (BLS data)             | Monthly jobs added (K)     | Threshold: beat/miss vs estimate             |
| **Fed Funds Rate decision**| `TRUSTED_REPORTER` | FRED API + Federal Reserve press release        | Rate decision (cut/hold/hike) | Direction (cut vs hold), Threshold (rate level) |
| **10Y UST yield**     | `PRICE_FEED`           | Chainlink via FRED proxy or TRO FRED series DGS10 | Daily close yield %        | Threshold, Corridor (yield band)             |
| **Yield curve (10Y-2Y)**| `TRUSTED_REPORTER`  | FRED API series T10Y2Y (derived)                | Spread in bps              | Threshold (inversion: < 0 bps)               |
| **UAE CPI**           | `TRUSTED_REPORTER`     | `bayanat.ae` open data API                      | UAE monthly CPI %          | Threshold                                    |
| **CBUAE / SAMA rate** | `TRUSTED_REPORTER`     | CBUAE press release + SAMA open data            | Rate decision bps          | Direction                                    |

#### **7.3 Financials Category**

| **Subcategory**       | **Oracle class**       | **Feed / API**                                  | **Resolution data point**  | **Primary market types**                     |
| :-------------------- | :--------------------- | :---------------------------------------------- | :------------------------- | :------------------------------------------- |
| **Gold XAU/USD**      | `PRICE_FEED`           | Chainlink XAU/USD Arbitrum                      | Spot price in USD/oz       | Direction, Threshold, Velocity, Corridor, Ladder |
| **Silver XAG/USD**    | `PRICE_FEED`           | Chainlink XAG/USD Arbitrum                      | Spot price                 | Direction, Threshold                         |
| **WTI Crude Oil**     | `PRICE_FEED`           | Chainlink WTI/USD Arbitrum                      | Spot $/barrel              | Direction, Threshold, Corridor               |
| **Natural Gas**       | `PRICE_FEED`           | Chainlink Natural Gas/USD Arbitrum              | $/MMBtu                    | Direction, Threshold (seasonal)              |
| **EUR/USD**           | `PRICE_FEED`           | Chainlink EUR/USD Arbitrum                      | FX rate                    | Direction, Corridor, Convergence             |
| **GBP/USD**           | `PRICE_FEED`           | Chainlink GBP/USD Arbitrum                      | FX rate                    | Direction, Convergence with EUR/USD          |
| **JPY/USD**           | `PRICE_FEED`           | Chainlink JPY/USD Arbitrum                      | FX rate                    | Direction, Corridor (BOJ intervention)       |
| **Tokenized SPY NAV** | `CHAINLINK_EQUITY`     | Ondo/Chainlink NAVLink                          | Daily NAV in USD           | Direction, Threshold                         |
| **Tokenized AAPL / TSLA**| `CHAINLINK_EQUITY`  | Ondo tokenized equity Chainlink feeds           | Daily price                | Direction, post-earnings threshold           |
| **S&P 500 Index**     | `TRUSTED_REPORTER`     | Financial Modeling Prep API `/v3/quote/^GSPC`   | Daily close                | Threshold (level), Anchor                    |
| **IPO pricing**       | `TRUSTED_REPORTER`     | SEC EDGAR 424B4 + FMP IPO calendar              | First day close price      | Threshold (above/below offer price)          |

### **8. Implementation Roadmap V2.0**

The updated roadmap integrates the five new market types discovered via Chainlink feed analysis into V1.5, bringing the total V1.5 delivery to seven market types (Anchor, Velocity, VolatilityBand, StakingAPR, BitcoinIRC plus a new `RateAdapter` contract and the US Macro oracle class).

| **#** | **Market type**    | **Phase** | **Oracle dependency**                      | **Contract delta**                              | **ETA**       |
| :---: | :----------------- | :-------: | :----------------------------------------- | :---------------------------------------------- | :-----------: |
| **1** | Anchor             | V1.5      | `CHAINLINK_PRICE` --- existing             | 1 field + 3-line resolver                       | Week 4--5     |
| **2** | Velocity           | V1.5      | `CHAINLINK_PRICE` --- existing             | 1 field + 15-line resolver                      | Week 4--5     |
| **3** | VolatilityBand     | V1.5      | `CHAINLINK_RATE` --- new `RateAdapter`     | 30-line `RateAdapter` + resolver                | Week 5--6     |
| **4** | StakingAPR         | V1.5      | `CHAINLINK_RATE` --- `RateAdapter` (shared)| Template only --- zero new code                  | Week 5--6     |
| **5** | BitcoinIRC         | V1.5      | `CHAINLINK_RATE` --- `RateAdapter` (shared)| Template only --- zero new code                  | Week 5--6     |
| **6** | US Macro feeds     | V1.5      | `CHAINLINK_MACRO` --- `MacroAdapter` (30 lines)| `MacroAdapter` + template                        | Week 6--7     |
| **7** | Ladder             | V2        | `CHAINLINK_PRICE` --- existing             | Payout weight fields + math                      | Week 8--10    |
| **8** | Convergence        | V2        | Dual `CHAINLINK_PRICE` --- existing x2     | Dual feed checkpoint + resolver                  | Week 9--11    |
| **9** | Composite          | V2        | Multi `CHAINLINK` x4 OR mixed classes      | Array template fields + logic resolver           | Week 10--12   |
| **10**| Momentum           | V2        | `CHAINLINK_PRICE` --- existing             | Array checkpoint + multi-epoch scorer            | Week 11--13   |
| **11**| Streak             | V2        | `CHAINLINK_PRICE` --- existing             | Position struct extension                        | Week 12--15   |
| **12**| Corridor           | V3        | `CHAINLINK` + Reporter OHLC                | `postOHLCResult` + breach flag + resolver        | Week 16--20   |
| **13**| Cascade            | V3        | `CHAINLINK` + Reporter OHLC                | High watermark + level array + resolver          | Week 17--22   |

> **Total new contracts in V1.5**
> 
> - `RateAdapter.sol` --- ~30 lines, port of `ChainlinkAdapter` for rate/vol/APR feeds
> - `MacroAdapter.sol` --- ~30 lines, port of `ChainlinkAdapter` for US macro feeds (Chainlink US Macro `AggregatorV3Interface`)
> - No changes to `MarketEngine`, resolvers, or modules for V1.5 (Anchor, Velocity, StakingAPR, BitcoinIRC reuse existing code)
> - VolatilityBand adds `resolveVolatilityBand()` --- 8 lines --- to `Resolvers.sol`

### **9. Competitive Moat Analysis --- V2.0**

With V2.0, RetroPick's oracle-resolved market type count expands from 3 (live) to 15 (full roadmap). The combination of market types, oracle classes, and API coverage creates a durable competitive moat across three dimensions.

| **Dimension**                | **Polymarket**                       | **Kalshi**                             | **RetroPick V2**                                                       |
| :--------------------------- | :----------------------------------- | :------------------------------------- | :--------------------------------------------------------------------- |
| **Oracle decentralization**  | Human judges + UMA optimistic --- dispute risk | Centralised operator resolution        | Chainlink DON + `TrustedReporter` --- no human judge for 90%+ of markets |
| **Market type diversity**    | Binary yes/no only                   | Binary + scalar (price level)          | 12+ primitives including vol, rates, multi-asset, parlay, corridor     |
| **Asset class coverage**     | Events only --- no financial prices  | US macro + event contracts             | Crypto, forex, commodities, rates, volatility, macro, climate, DeFi, GCC |
| **Rate / volatility markets**| None                                 | None                                   | VolatilityBand, StakingAPR, BitcoinIRC --- first in any prediction market |
| **RWA / NAV markets**        | None                                 | None                                   | SmartData NAV feeds via Ondo, Superstate, Franklin Templeton --- first  |
| **GCC / MENA coverage**      | None                                 | None                                   | UAE CPI, CBUAE rate, Aramco, USD/AED corridor --- first-mover monopoly |
| **User-created markets**     | None                                 | None                                   | Creator economy layer --- oracle-constrained, fee-sharing --- first     |
| **Hedging framing**          | Speculation only                     | Speculation + event hedging            | Full hedging instrument framing + real-world exposure mapping           |

> **The deepest moat: Chainlink US Macro + Rate Feeds**
> 
> Chainlink's US Government Macroeconomic Data Feeds and Rate/Volatility Feeds are production-live on Arbitrum One but have never been used by any prediction market protocol. These feeds represent the highest-quality, most institutionally trusted onchain data available --- published by the US Department of Commerce and aggregated by Chainlink's decentralized oracle network. RetroPick being the first prediction market to use them is a durable technical and reputational moat. These feeds cannot be replicated by competitors without the same Chainlink relationship.

**RetroPick Protocol --- Master Oracle Architecture & Market Innovation Plan V2.0**

Version 2.0 --- April 2026 --- Confidential --- RetroPick FZ-LLC, RAK DAO, UAE --- Arbitrum One

*Data feed classifications sourced from docs.chain.link --- April 2026*
```