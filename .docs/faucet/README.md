## Faucet (testnet only)

Smart contracts in this repo that support **free, rate-limited minting** of demo ERC20 tokens for testnets.

Implementation lives under:

- `src/faucet/TokenFaucet.sol`

Why:

- The core protocol assumes a **standard ERC20** stake token; for testnet demos we want an easy on-ramp for users to get tokens without relying on a centralized distributor.

