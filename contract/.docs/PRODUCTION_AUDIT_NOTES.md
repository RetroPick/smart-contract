# Production audit notes (RetroPick MarketEngine)

Structured pass using project `.agents/skills` (security, gas, upgrades) and periphery trust-boundary review. Not a substitute for external audit.

## Critical / High

- **Admin / module wiring:** `MarketEngineDispatcher.setSelectorModule` and UUPS `_authorizeUpgrade` gate full storage. Compromised `admin` or malicious module bytecode equals protocol takeover. Operational controls and immutable critical selectors after deploy are mandatory.
- **Yield router trust:** `yieldRouter` is set by `admin`; routers use `onlyEngine` with `ENGINE` = dispatcher. `keeperClaimLmRewards` calls `claimLmRewards` from the engine so `msg.sender` on the router matches. Do not point production at untested router bytecode.

## Medium

- **Two router semantics:** `YieldRouterV2` uses scaled balance + liquidity index; `YieldRouterAaveV3` tracks principal/shares with `currentValueOf` as principal lower bound. Off-chain reporting and risk must match the deployed router.
- **Yield buffer (500 bps):** Only `(10000 - buffer)/10000` of stake is routed; remainder stays in the engine vault. Invariants rely on this split matching `_vaults` and ledger updates—covered by fuzz tests; re-check after any routing change.

## Low / Informational

- **Reentrancy:** Dispatcher `nonReentrant` (transient) + module `nonReentrant` on user paths; yield calls are behind trusted router. New external entrypoints should follow the same pattern.
- **Oracle:** Chainlink / round-id and confidence checks are template-scoped; rolling vs manual paths differ—see oracle modules and tests.
- **Compiler:** Use `FOUNDRY_PROFILE=production` (`optimizer_runs = 1_000_000`) for release bytecode per `foundry.toml`.

## Dependency patch

- `lib/openzeppelin-foundry-upgrades`: local mutability patches (`StringFinder`, `DefenderDeploy`) silence 2018 warnings; re-apply or upgrade the package when updating the submodule.

## Gas snapshot reference (`forge snapshot --match-contract EpochGasTest`)

Approximate runtime gas (lower is better for these harnesses):

| Test | default (`optimizer_runs=200`) | `FOUNDRY_PROFILE=production` (`1_000_000`) |
|------|----------------------------------|---------------------------------------------|
| `test_gas_claim_afterResolve` | 58259 | 58028 |
| `test_gas_lockEpoch_direction` | 88769 | 88350 |
| `test_gas_lockEpoch_threshold` | 17606 | 17442 |
| `test_gas_openEpoch_cold` | 148515 | 148166 |
| `test_gas_resolveEpoch_direction` | 147521 | 146474 |
| `test_gas_resolveEpoch_threshold` | 170874 | 169875 |

`switchSide` path: single storage pointer for `_vaults[templateId]` in `MarketEngineUserOpsClaimsModule` reduces repeated mapping lookups when switch fees route to yield.
