import "dotenv/config";

import { MARKET_ENGINE_PROGRAM_ID } from "@retropick/sdk";

console.log("worker started");
console.log("API_URL:", process.env.API_URL ?? "http://localhost:3001");
console.log("REDIS_URL:", process.env.REDIS_URL ?? "redis://localhost:6379");
console.log("MARKET_ENGINE_PROGRAM_ID:", MARKET_ENGINE_PROGRAM_ID.toBase58());
