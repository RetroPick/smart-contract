# Chain abstraction (funding `MarketEngine`)

This folder documents how to integrate **swap / bridge / solver** flows around [`MarketEngine`](../src/MarketEngine.sol) without changing core market math. The engine stays **single–stake-asset** (`stakeToken` set at `initialize`).

## Read order

| Doc | Purpose |
|-----|---------|
| [01-engine-boundaries.md](./01-engine-boundaries.md) | What the contract guarantees; vault model; non-goals |
| [02-integration-modes.md](./02-integration-modes.md) | Tier A/B/C: frontend, smart wallet, router / intents |
| [03-contract-sketches.md](./03-contract-sketches.md) | Router pattern, `depositToSideFor`, pseudocode |
| [04-cross-chain-and-bridges.md](./04-cross-chain-and-bridges.md) | Getting `stakeToken` on the deployment chain |
| [05-solvers-and-intents.md](./05-solvers-and-intents.md) | Intent flow, solvers, dependencies |
| [06-security-checklist.md](./06-security-checklist.md) | Approvals, slippage, executor trust |

## Glossary

- **Stake token** — The single `IERC20` the engine uses for deposits, vault accounting, and claims (often USDC on an L2).
- **Abstraction layer** — Everything *outside* `MarketEngine` that converts user assets into the stake token or batches calls (UI, router, bridge SDK, bundler).
- **Executor / router** — A contract allowed to call `depositToSideFor` (see [03-contract-sketches.md](./03-contract-sketches.md)); pulls stake token from itself and credits a **beneficiary** user.

## Related docs

- [DEPLOYMENT_AND_EPOCHS.md](../DEPLOYMENT_AND_EPOCHS.md) — Ops, gas, rolling mode
- [rolling-rounds.md](../rolling-rounds.md) — Rolling lifecycle
- [AUDIT_SOLIDITY.md](../AUDIT_SOLIDITY.md) — Audit notes (see also abstraction security checklist)
