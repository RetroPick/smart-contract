# Rolling rounds — threat model, invariants, and test matrix

This note complements [AUDIT_SOLIDITY.md](./AUDIT_SOLIDITY.md) and [rolling-rounds.md](./rolling-rounds.md). It documents **Direction-only** rolling execution in [`MarketEngine.sol`](../src/MarketEngine.sol).

## Threat model

| Actor / concern | Assumption | Mitigation in code |
|-----------------|------------|-------------------|
| **Deployer** | Proxy deploy + one-time `initialize`; frontrun init is an ops risk | [DEPLOYMENT_AND_EPOCHS.md](./DEPLOYMENT_AND_EPOCHS.md) |
| **Admin** | Trusted; can pause, halt rolling, reset lifecycle, cancel while halted | `onlyAdmin` on sensitive paths |
| **Worker** | Trusted; drives genesis and `executeRollingRound` | `onlyWorkerOrAdmin`; respects global pause |
| **Users** | Cannot advance rolling; may deposit/switch only on non-halted rolling templates | `RollingHaltedUserOps` when halted |
| **Oracle (`IPriceOracle`)** | Trusted for prices and publish times | Staleness via `maxDelay`; confidence band; rolling paths **halt** on failure instead of silent continue |
| **Keeper liveness** | Someone must call within `rollingBufferSeconds` of each boundary | Missed buffer → `Halted` with reason (`BufferMissOnResolve` / `BufferMissOnLock` / …) |

## Rolling invariants (steady state)

Let `k = activeEpochId` after a successful `executeRollingRound`. The docs’ canonical view (open / locked / resolved pipeline) maps to:

- **`rollingNextEpochId == k + 1`** — next id to allocate when opening a new epoch ([`getRollingLifecycle`](../src/MarketEngine.sol)).
- **`lastResolvedEpochId`** advances as epochs complete resolution; for healthy rolling ticks it tracks the pipeline behind `k`.
- **`RollingPhase.Live`** while the heartbeat is valid; **`Halted`** on buffer miss, oracle failure, wide confidence, or admin halt.

**Implementation note:** For uniform intervals, `ePrev.resolveAt` and `eCur.lockAt` align at the execute boundary, so a late tick typically hits **`BufferMissOnResolve`** before any separate lock-window check.

## Residual risks

- **Oracle compromise** is full market compromise (same as manual markets).
- **UUPS upgrades** are admin-gated; trust and process are documented in [AUDIT_SOLIDITY.md](./AUDIT_SOLIDITY.md).
- **ERC20** must be standard `transfer`/`transferFrom`; fee-on-transfer not supported.
- **Economic edge cases** (dust, rounding) should be monitored; tests cover common paths, not all combinatorial states.

## Test matrix (Foundry)

| Concern | Test contract / location |
|---------|---------------------------|
| **Genesis + steady execute + claim** | [`MarketEngineRolling.t.sol`](../test/MarketEngineRolling.t.sol) |
| **Multi-tick `lastResolved`** | [`MarketEngineRollingLifecycle.t.sol`](../test/MarketEngineRollingLifecycle.t.sol) |
| **Buffer / confidence / oracle halt / too-early / batch** | [`MarketEngineRollingOracle.t.sol`](../test/MarketEngineRollingOracle.t.sol) |
| **Manual API gating, pause, roles** | [`MarketEngineRollingAccess.t.sol`](../test/MarketEngineRollingAccess.t.sol) |
| **Reset / cancel / invalid recovery** | [`MarketEngineRollingRecovery.t.sol`](../test/MarketEngineRollingRecovery.t.sol) |
| **Double execute, halted deposits/switches** | [`MarketEngineRollingAttacks.t.sol`](../test/MarketEngineRollingAttacks.t.sol) |
| **Equal-price void + vault vs ERC20** | [`MarketEngineRollingEconomicVoid.t.sol`](../test/MarketEngineRollingEconomicVoid.t.sol), [`MarketEngineRollingEconomicVault.t.sol`](../test/MarketEngineRollingEconomicVault.t.sol) |
| **Cursor fuzz** | [`MarketEngineRollingFuzz.t.sol`](../test/MarketEngineRollingFuzz.t.sol) |
| **Oracle effective delay (min)** | [`MarketEngineOracleParity.t.sol`](../test/MarketEngineOracleParity.t.sol) |
| **Manual Direction + RangeClose lifecycles** | [`MarketEngineManualTypes.t.sol`](../test/MarketEngineManualTypes.t.sol) |
| **Gas (rolling)** | [`MarketEngineRolling.t.sol`](../test/MarketEngineRolling.t.sol) `test_gas_*` |

Regenerate gas snapshots after contract changes:

```bash
forge snapshot --match-contract 'EpochGasTest|MarketEngineRollingTest'
```
