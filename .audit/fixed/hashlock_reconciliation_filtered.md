# Hashlock Reconciliation Filtered View

## Scope

This document is derived from `hashlock_reconciliation.csv`, but excludes:

- `duplicate`
- `already fixed`

The remaining rows therefore keep only:

- `fixed`
- `false positive`
- `governance risk`

This filtered view is the useful part of the Hashlock catalogue for a human auditor. It removes repeated AI noise and focuses on what still needs one of three outcomes:

- accept the fix
- close the false positive with evidence
- escalate the governance or deployment risk

## Filtered Counts

After excluding `duplicate` and `already fixed`:

- total remaining: `120`
- `governance risk`: `93`
- `false positive`: `22`
- `fixed`: `5`

Severity split:

- `critical`: `6`
- `high`: `15`
- `medium`: `20`
- `low`: `75`
- `informational`: `4`

## Fixed Findings

These are the live-code fixes from the Hashlock set that should be considered closed unless regression appears.

| Severity | Finding | Current disposition | File | Test |
| --- | --- | --- | --- | --- |
| high | Oracle cursor state persists after oracle adapter replacement, enabling stale data bypass | fixed | `src/engine/modules/MarketEngineAdminModule.sol` | `test/engine/core/MarketEngineCoreMarketUpgrade.t.sol:test_admin_can_reset_oracle_cursor_after_adapter_swap` |
| medium | Yield router deposit approval race condition via `forceApprove` | fixed | `src/engine/modules/MarketEngineUserOpsClaimsModule.sol` | `test/engine/core/MarketEngineYieldRouting.t.sol:test_deposit_failedRouting_clears_router_allowance` |
| high | Oracle cursor monotonicity not reset on oracle adapter change | fixed | `src/engine/modules/MarketEngineAdminModule.sol` | `test/engine/core/MarketEngineCoreMarketUpgrade.t.sol:test_admin_can_reset_oracle_cursor_after_adapter_swap` |
| medium | `claimMany` batch DoS via front-running or partial claim state | fixed | `src/engine/modules/MarketEngineUserOpsClaimsModule.sol` | `test/engine/core/MarketEngineUserOpsClaimsBranches.t.sol:test_claimMany_skips_epochs_that_become_already_claimed_mid_batch` |
| medium | Residual token approval left after failed yield router deposit | fixed | `src/engine/modules/MarketEngineUserOpsClaimsModule.sol` | `test/engine/core/MarketEngineYieldRouting.t.sol:test_deposit_failedRouting_clears_router_allowance` |

## False Positives That Should Be Closed With Evidence

These findings do not currently justify code changes based on the live implementation. They should be retained only as review notes with evidence links.

### High-confidence false positives

| Severity | Finding | Why this is not live | Primary evidence |
| --- | --- | --- | --- |
| high | Unchecked return value from `depositScaled` | current accounting only credits routed principal when attribution is returned; failure paths emit and continue | `src/engine/modules/MarketEngineUserOpsClaimsModule.sol` |
| high | Signature replay protection missing in event oracle settlement | adapter stores one result per market path and uses EIP-712 + OZ `ECDSA` recovery | `src/oracle/TrustedReporterAdapter.sol` |
| high | Signature malleability in reporter verification | OZ `ECDSA.recoverCalldata` already rejects malformed signatures | `src/oracle/TrustedReporterAdapter.sol` |
| high | Caller-supplied `nowTs` bypasses freshness checks | current adapter tests already reject stale data even with spoofed caller input | `test/adapters/ChainlinkAdapter.t.sol` |
| high | Yield-router withdraw return value blindly trusted | manual cancel/resolve paths use stake-token balance delta, not router return value, for safety-critical accounting | `src/engine/modules/MarketEngineCoreLifecycleModule.sol` |
| high | Replay attack via `clearLockSample` / `clearResolveResult` | replay claim as described was not reproducible against current adapter semantics | `src/oracle/TrustedReporterAdapter.sol` |
| high | Corridor market can trap funds in zero-winning-pool scenario | broad claim overstated; current settlement/claim tests do not reproduce permanent stuck-funds behavior | `src/logic/SettlementLogic.sol`, `src/math/MarketMath.sol` |
| high | Fallback bypasses reentrancy protection across module delegatecalls | current external entrypoints are `nonReentrant`; tested malicious-router paths degrade safely under current architecture | `test/engine/security/MarketEngineReentrancy.t.sol` |

### Medium-confidence false positives

| Severity | Finding | Why this is not currently actionable |
| --- | --- | --- |
| medium | `emergencyWithdraw` unchecked return value causes silent loss | broad claim does not match current accounting-critical paths; still worth human review as an ops surface |
| medium | `ReentrancyGuardTransient` incompatible with delegatecall architecture | broad statement is too strong for the current modular layout and tested call graph |
| medium | division by zero in `computeClaimPayoutStorage` after winning-stake check | not reproduced in current settlement paths |

### Low / informational false positives

These are low-value closure items rather than launch blockers:

- floating pragma claim is false because the repo is pinned to `0.8.24`
- missing outcome-index validation claim is false for current user-op entrypoints

## Governance Risks That Remain Real

This is the dominant unresolved bucket.

### Critical governance risks

| Finding | Why it remains real | Live surface |
| --- | --- | --- |
| Delegatecall to untrusted module contracts via selector routing | admin-controlled delegatecall target selection is equivalent to full protocol compromise if governance is weak | `src/engine/MarketEngineDispatcher.sol` |
| Centralized trusted reporter single point of failure | one signer controls market data for all templates using that adapter | `src/oracle/TrustedReporterAdapter.sol` |
| Storage compatibility marker is insufficient by itself | compatibility marker helps, but cannot replace disciplined storage-layout review for delegatecall modules | `src/engine/MarketEngineDispatcher.sol` |
| Single admin key controls critical protocol operations | upgrade, module routing, pausing, treasury/worker changes remain concentrated | `src/engine/MarketEngineDispatcher.sol`, `src/engine/modules/MarketEngineAdminModule.sol` |
| No timelock on critical admin operations | module/oracle/router changes are immediate | `src/engine/MarketEngineDispatcher.sol`, `src/engine/modules/MarketEngineAdminModule.sol` |

### High and medium governance risks worth explicit launch review

| Severity | Finding | Why it matters |
| --- | --- | --- |
| medium | missing monotonicity enforcement for oracle round IDs allows stale price injection | needs explicit operator and oracle-management review even if not currently proven exploitable |
| medium | missing admin transfer mechanism creates single point of failure | ownership continuity and recovery model are weak without a robust transfer process |
| medium | sequencer feed staleness not validated | L2-style oracle health assumptions should be validated explicitly if those deployments are in scope |
| medium | no events emitted on `clearLockSample` and `clearResolveResult` | security-sensitive state mutation is insufficiently observable |
| medium | owner can re-settle markets by clearing and re-posting results | this is a real trust/governance risk, even if intentional as a recovery lever |
| medium | fee-on-transfer token accounting mismatch in yield router | should be accepted or rejected as a supported-token policy, not left implicit |
| medium | hardcoded Aave config bit offsets may fail on forks | integration and deployment safety issue, especially across chain/fork assumptions |

### Low-severity governance and economic risks

These do not look like immediate theft vectors, but they should still be reviewed before production launch:

- short manual market windows and timestamp sensitivity
- on-chain auditability gaps such as missing data-source strings
- weak interface-versioning and upgrade ergonomics
- user epoch array growth and long-tail gas/UX degradation
- token rescue and emergency-withdraw policy clarity
- niche resolver edge cases and input-validation assumptions

These should be handled as:

- documented accepted risk
- code hardening
- deployment restriction
- operational monitoring item

## Auditor Interpretation

The filtered output shows that the raw Hashlock set is not best read as "120 bugs remain". The accurate read is:

- `5` findings are fixed and should remain regression-tested
- `22` findings are better treated as false-positive closures with evidence
- `93` findings are mostly governance, trust-model, economic, or deployment concerns that need explicit acceptance or mitigation

That means the next audit stage should not be another broad bug hunt. It should be:

1. targeted live-code human review
2. invariant testing of accounting conservation
3. governance and deployment hardening
4. economic review of rolling and oracle assumptions

## Recommended Use Of This Document

Use this file as the human-audit triage layer:

- `fixed` items stay regression-tested
- `false positive` items get one-paragraph evidence notes and are then closed
- `governance risk` items move into the launch checklist and risk register

Do not use the raw Hashlock markdown set as the final launch checklist without this filtering step.
