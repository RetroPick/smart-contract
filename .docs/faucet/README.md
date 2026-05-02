## Faucet (testnet only)

Smart contracts in this repo that support **free, rate-limited minting** of demo ERC20 tokens for testnets.

Implementation lives under:

- `src/test/faucet/TokenFaucet.sol`

Why:

- The core protocol assumes a **standard ERC20** stake token; for testnet demos we want an easy on-ramp for users to get tokens without relying on a centralized distributor.

Gasless onboarding:

- `requestWithSig(recipient, amount, deadline, signature)` lets a relayer submit a user-authorized mint.
- This avoids the user needing testnet ETH just to receive demo stake tokens.
- The existing `request(amount)` path still works for users who already have gas.

Backend relay (RetroPick API):

- Enable with `FAUCET_RELAY_ENABLED=1` and `FAUCET_RELAYER_PRIVATE_KEY` (fund that EOA on Base Sepolia). See monorepo root `.env.example`.
- `GET /api/v1/user/faucet-state` exposes `nonce` for EIP-712 signing; `POST /api/v1/user/faucet-relay` submits the signed mint. Relayer enforces `amount == maxMintAmount`.

Hardening follow-up:

- `MockERC20.mint` is public in the test token; UI should only use `TokenFaucet`. Consider `AccessControl` minter role for future testnet redeploys.
