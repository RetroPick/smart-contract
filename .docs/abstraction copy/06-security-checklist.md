# Security checklist (abstraction layer)

Use this for **routers**, **executors**, and **frontend** integrations. [`MarketEngine`](../src/MarketEngine.sol) invariants (reentrancy, pause) apply as usual.

## Approvals

- Prefer **Permit2** or **EIP-2612 permit** where available to limit approval scope and time.
- Avoid unlimited `approve` to unverified contracts.
- Users approving a **router** should understand the router can call `depositToSideFor` **only** while it is allowlisted; **admin** can revoke executor status.

## Slippage and oracles

- Router **must** enforce `minStakeOut` (or revert) after any swap into `stakeToken`.
- Distinguish **price oracles for trading** from **oracle feeds used for market resolution** — different systems and risk profiles.

## Phishing / signing

- Off-chain intents: clear **domain separation** (EIP-712), show human-readable market and amounts in wallet UI.
- Never sign messages that grant **arbitrary** token transfers without limits.

## Engine surface

- [`depositToSide`](../src/MarketEngine.sol) / [`depositToSideFor`](../src/MarketEngine.sol): `nonReentrant`, `notPausedUserOps` where applicable.
- **Executor trust model:** Only addresses with `isDepositExecutor[addr] == true` can use `depositToSideFor`. Compromise of an executor contract can mis-credit users if combined with bad UX; **audit routers** like any custodial-adjacent code.

## Claims and treasury

- **Claims:** Users call [`claim`](../src/MarketEngine.sol) as themselves; stake token transfers to `msg.sender`.
- **Fees:** [`withdrawFees`](../src/MarketEngine.sol) remains **treasury / admin** — abstraction layer does not change fee vault accounting ([`VaultBalances`](../src/types/MarketTypes.sol)).

## Testing

- Foundry tests should cover `depositToSideFor` with allowlisted and non-allowlisted callers.
- Fuzz `beneficiary` zero address rejection if applicable.

## Audit linkage

Document executor addresses and upgrade policy in deployment runbooks; cross-reference [AUDIT_SOLIDITY.md](../AUDIT_SOLIDITY.md) when the core engine is re-audited after executor changes.
