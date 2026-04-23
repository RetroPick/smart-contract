The best free public API for **“top 20 crypto prices”** is **CoinGecko Demo API**. Its `/coins/markets` endpoint is designed to return coin price plus market cap, rank, volume, and price-change fields; it supports `vs_currency`, `order=market_cap_desc`, and `per_page`, which is exactly what you need for a top-20 list. CoinGecko’s free Demo plan uses the public base URL `https://api.coingecko.com/api/v3` and accepts the demo key either as `x_cg_demo_api_key` query param or `x-cg-demo-api-key` header. ([docs.coingecko.com][1])

If you want **candles/orderbook/trades**, Binance public market-data endpoints are also excellent and do not require authentication on `data-api.binance.vision`, but Binance is not the best source for a ranked “top 20 coins by market cap” list. ([developers.binance.com][2])

Here is a clean **TypeScript** example for **top 20 crypto prices by market cap** using CoinGecko.

```ts
type CoinGeckoMarket = {
  id: string;
  symbol: string;
  name: string;
  image: string;
  current_price: number;
  market_cap: number;
  market_cap_rank: number;
  total_volume: number;
  high_24h: number | null;
  low_24h: number | null;
  price_change_24h: number | null;
  price_change_percentage_24h: number | null;
  circulating_supply: number | null;
  total_supply: number | null;
  max_supply: number | null;
  last_updated: string;
};

type TopCoin = {
  rank: number;
  id: string;
  symbol: string;
  name: string;
  priceUsd: number;
  marketCapUsd: number;
  volume24hUsd: number;
  change24hPct: number | null;
  lastUpdated: string;
};

const COINGECKO_BASE_URL = "https://api.coingecko.com/api/v3";

/**
 * Fetch top N crypto assets by market cap from CoinGecko Demo API.
 *
 * Setup:
 *   1. Create a free CoinGecko Demo API key
 *   2. Put it in your environment:
 *      export COINGECKO_DEMO_API_KEY=your_key_here
 */
export async function getTopCryptoPrices(limit = 20): Promise<TopCoin[]> {
  const apiKey = process.env.COINGECKO_DEMO_API_KEY;

  if (!apiKey) {
    throw new Error(
      "Missing COINGECKO_DEMO_API_KEY in environment variables."
    );
  }

  const params = new URLSearchParams({
    vs_currency: "usd",
    order: "market_cap_desc",
    per_page: String(limit),
    page: "1",
    sparkline: "false",
    price_change_percentage: "24h",
  });

  const url = `${COINGECKO_BASE_URL}/coins/markets?${params.toString()}`;

  const res = await fetch(url, {
    method: "GET",
    headers: {
      accept: "application/json",
      "x-cg-demo-api-key": apiKey,
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`CoinGecko request failed: ${res.status} ${body}`);
  }

  const data = (await res.json()) as CoinGeckoMarket[];

  return data.map((coin) => ({
    rank: coin.market_cap_rank,
    id: coin.id,
    symbol: coin.symbol.toUpperCase(),
    name: coin.name,
    priceUsd: coin.current_price,
    marketCapUsd: coin.market_cap,
    volume24hUsd: coin.total_volume,
    change24hPct: coin.price_change_percentage_24h,
    lastUpdated: coin.last_updated,
  }));
}

// Example usage
async function main() {
  try {
    const top20 = await getTopCryptoPrices(20);

    console.table(
      top20.map((coin) => ({
        Rank: coin.rank,
        Symbol: coin.symbol,
        Name: coin.name,
        Price_USD: coin.priceUsd,
        MarketCap_USD: coin.marketCapUsd,
        Volume24h_USD: coin.volume24hUsd,
        Change24h_Pct: coin.change24hPct,
      }))
    );
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

main();
```

If you want a **frontend-ready API route** for Next.js App Router:

```ts
// app/api/top-crypto/route.ts
import { NextResponse } from "next/server";

type CoinGeckoMarket = {
  id: string;
  symbol: string;
  name: string;
  current_price: number;
  market_cap: number;
  market_cap_rank: number;
  total_volume: number;
  price_change_percentage_24h: number | null;
  last_updated: string;
};

export async function GET() {
  const apiKey = process.env.COINGECKO_DEMO_API_KEY;

  if (!apiKey) {
    return NextResponse.json(
      { error: "Missing COINGECKO_DEMO_API_KEY" },
      { status: 500 }
    );
  }

  const params = new URLSearchParams({
    vs_currency: "usd",
    order: "market_cap_desc",
    per_page: "20",
    page: "1",
    sparkline: "false",
    price_change_percentage: "24h",
  });

  const res = await fetch(
    `https://api.coingecko.com/api/v3/coins/markets?${params.toString()}`,
    {
      headers: {
        accept: "application/json",
        "x-cg-demo-api-key": apiKey,
      },
      next: { revalidate: 30 }, // cache for 30s
    }
  );

  if (!res.ok) {
    const text = await res.text();
    return NextResponse.json(
      { error: `CoinGecko error: ${res.status}`, details: text },
      { status: 502 }
    );
  }

  const data = (await res.json()) as CoinGeckoMarket[];

  return NextResponse.json(
    data.map((coin) => ({
      rank: coin.market_cap_rank,
      id: coin.id,
      symbol: coin.symbol.toUpperCase(),
      name: coin.name,
      priceUsd: coin.current_price,
      marketCapUsd: coin.market_cap,
      volume24hUsd: coin.total_volume,
      change24hPct: coin.price_change_percentage_24h,
      lastUpdated: coin.last_updated,
    }))
  );
}
```

And a tiny frontend fetch:

```ts
const res = await fetch("/api/top-crypto");
const top20 = await res.json();
console.log(top20);
```

For your product, I’d use this split:

* **Top assets / watchlist / rankings** → CoinGecko Demo
* **Candlestick chart + live ticker stream** → Binance public market-data endpoints/websocket ([docs.coingecko.com][1])

I can turn this into:
a Next.js hook + table component, or
a chart data service for your RetroPick frontend.

[1]: https://docs.coingecko.com/reference/coins-markets "Coins List with Market Data - CoinGecko API"
[2]: https://developers.binance.com/docs/binance-spot-api-docs/rest-api "General API Information | Binance Open Platform"
