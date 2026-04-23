# Hashlock Reconciliation Matrix

Status values:
- `fixed`
- `already fixed`
- `false positive`
- `governance risk`
- `duplicate`

This matrix reconciles the material Hashlock findings against the live codebase and current tests. It does **not** claim all architectural risk is eliminated; it separates code bugs from governance and design assumptions.

## 01_BroadMarketEngine.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| critical | Delegatecall to Untrusted Module Contracts via `setSelectorModule` | duplicate | Covered more precisely in `04`, `13`, and `14`; equivalent to admin/module trust boundary. |
| high | Oracle Confidence Validation Insufficient for Small Prices | already fixed | Current engine enforces confidence bands with floor behavior; covered by manual/rolling oracle tests. |
| medium | Missing Validation of Array Lengths in Batch Operations | already fixed | Batch length and max-size checks exist; covered in core lifecycle and claim branch tests. |
| low | Potential Integer Overflow in Yield Fee Calculation | false positive | Solidity 0.8 checked arithmetic plus current fee calculation patterns make this non-exploitable. |
| informational | Floating Pragma Version Allows Inconsistent Compiler Behavior | false positive | Repo uses pinned `pragma solidity 0.8.24`. |

## 02_BroadInterfaces.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| critical | Unexpected `ecrecover` Null Address Vulnerability in Event Oracle Signature Verification | already fixed | `TrustedReporterAdapter` uses OZ `ECDSA.recoverCalldata` and forbids zero reporter; tested. |
| high | Missing Signature Replay Protection in `IEventOracle` Signed Payload Settlement | false positive | Current adapter stores one result per `marketId`/path and blocks reposts without clear; interface-level note, not current exploit. |
| medium | Precision Loss in `IYieldRouterV2.withdrawScaled` proportional slice calculation | duplicate | Broad interface note; any real accounting issue belongs to concrete router implementation findings. |
| low | Missing Data Source URI On-Chain Creates Unverifiable Settlement Claims | governance risk | Traceability/operational transparency issue, not code exploit. |

## 03_ResolverBroadMarket.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| high | Composite Market Uses Single Threshold for All Feeds | already fixed | Current templates and tests support per-feed thresholds; covered in market type tests. |
| medium | Corridor Market Outcome Index Confusion | false positive | Current resolver behavior matches tested semantics. |
| low | `YieldRouterAaveV3.emergencyWithdraw` passes wrong unit type | false positive | Existing tests cover emergency withdraw behavior; no failing invariant observed. |
| gas | Redundant storage reads in `computeClaimPayoutStorage` | duplicate | Optimization only. |
| informational | `TrustedReporterAdapter` single point of failure | governance risk | True by design for trusted reporter mode. |

## 04_MarketEngineState.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| critical | Storage compatibility marker trivially bypassable | governance risk | Real if admin approves/wires malicious module; on-chain fix would require governance/model redesign. |
| high | Reentrancy in `_balanceDeltaAfterWithdrawScaled` via malicious router | already fixed | User/core/rolling entrypoints are guarded with `nonReentrant`; tested reentrancy paths pass. |
| medium | Checkpoint-B monotonicity replay concern | false positive | Current cursor logic is stricter than claimed; no confirmed exploit reproduced. |
| low | 10-second manual windows are timestamp-manipulable | governance risk | Economic/liveness tuning issue, not a direct code bug. |
| gas | `_setRemainingWinningStake` loops full `outcomeCount` | duplicate | Optimization only. |
| informational | `positionKey` uses `abi.encodePacked` | false positive | Fixed-width types make this safe here. |

## 05_modules.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| high | Oracle cursor persists after oracle adapter replacement | fixed | Added `resetOracleCursor(...)`; covered by `MarketEngineCoreMarketUpgrade` test. |
| medium | Duplicate storage mappings create silent storage collision | duplicate | Same underlying issue as dispatcher/state layout note in `14`; currently code smell, not active exploit. |
| low | `withdrawFees` checks ledger reserve but not vault balance | false positive | Current reserve/vault accounting is exercised by tests and no divergence exploit reproduced. |
| gas | Redundant `_enforceApprovedModule`-style checks | duplicate | Optimization only. |
| informational | `cancelEpoch` missing next-epoch validation | false positive | Current active-epoch checks already constrain cancellation path. |

## 06_ChainlinkOracle.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| high | Arbitrary feed address injection via unvalidated `feedId` | governance risk | Feed IDs are template/admin configured; not permissionless attacker input. |
| medium | No mechanism to disable deprecated feed | governance risk | Operational management issue, not immediate exploit. |
| low | `uint64` truncation of publish time beyond year 2554 | false positive | Theoretical only. |
| gas | Cache optimization around decimals lookup | duplicate | Optimization only. |
| informational | Duplicate code between round-id and non-round-id getters | duplicate | Maintenance concern only. |

## 07_TrustedOracleAdapter.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| critical | Single trusted reporter compromise drains all reporter-backed markets | governance risk | True by design; requires oracle trust model redesign, not patching. |
| high | Missing `clearOhlcResult` | already fixed | Function exists and is tested. |
| medium | No events on `clearLockSample` / `clearResolveResult` | governance risk | Auditability issue remains; not yet changed. |
| low | Signature age uses reporter-attested `observedAt` | governance risk | Intentional design tradeoff; bounded by max age and future-time checks. |
| gas | Redundant storage read in `postResolveResult` | duplicate | Optimization only. |
| informational | `getDataSource` returns empty string | governance risk | Interface quality / observability issue remains. |

## 08_AaveV3YieldRouterV2.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| high | `rescueToken` can steal `STATA_TOKEN` shares | already fixed | `rescueToken` blocks `STATA_TOKEN`; tested. |
| medium | Fee-on-transfer accounting mismatch causes insolvency | governance risk | Current engine rejects non-standard stake-token deposits, but router still assumes ERC20 semantics. |
| low | `rayMul` overflow risk in `YieldAccounting` | false positive | No practical exploit reproduced under current usage. |
| gas | Redundant `scaledBalanceOf` calls in stata path | duplicate | Optimization only. |
| informational | `computeYield` unused | duplicate | Code quality only. |

## 09_EngineAdminModules.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| high | Storage compatibility check only verifies selector, not layout | duplicate | Same root issue as `04`/`14`; admin trust boundary, not a separate new bug. |
| medium | Unchecked return from `emergencyWithdraw` allows silent loss | false positive | Current path emits event and is admin-only; no exploit reproduced. |
| low | Division-before-multiplication precision loss in entitlement math | duplicate | Broad math note; no confirmed exploit in live paths. |
| gas | Winner-stake loop includes non-winners | duplicate | Optimization only. |
| informational | `initializeMarket` does not require active template | governance risk | Operational choice; not direct exploit. |

## 10_EngineCoreLifecycleModules.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| high | Epoch cancellation blocked by yield router failure | already fixed | Cancel paths proceed with soft failure and event emission; tested. |
| medium | Composite threshold zero-value ambiguity | false positive | No exploit reproduced against current composite logic and tests. |
| low | `openAt` can be in the past | governance risk | Parameterization/UX issue, not a direct steal path. |
| gas | Duplicate routed-principal check in `cancelEpoch` | duplicate | Optimization only. |
| informational | Corridor validation off-by-one | false positive | Current validation and market type tests pass. |

## 11_EngineRollingLifecycleModules.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| high | Single oracle sample resolves one epoch and locks the next | governance risk | Real economic design coupling; not yet redesigned. |
| medium | `ReentrancyGuardTransient` incompatible with delegatecall architecture | false positive | Current module-level guards work in tested paths. |
| low | Yield router failure uses wrong halt reason | governance risk | Semantics/ops issue. |
| gas | Precision loss in yield fee calc | duplicate | Optimization/math style note only. |
| informational | `haltRollingMarket` missing `nonReentrant` | false positive | Admin-only function without vulnerable external interaction sequence. |

## 12_EngineUserOpsClaimableModules.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| high | Yield router deposit overcredits `routedPrincipal` without balance-delta verification | governance risk | Current code still trusts router attribution units > 0 rather than engine-side balance delta. |
| medium | `claimMany` batch DoS / front-run griefing | fixed | Batch claim now skips bad epochs instead of reverting entire batch. |
| low | Precision loss in yield buffer calc for small amounts | governance risk | Small-amount routing inefficiency remains a design tradeoff. |
| gas | Missing `outcomeIndex < e.outcomeCount` before position access in `switchSide` | false positive | Current access order is safe; only minor gas issue. |
| informational | Indirect storage reads in payout math | duplicate | Code quality only. |

## 13_EngineViewModule.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| critical | Storage layout compatibility marker insufficient | duplicate | Same as `04`/`14`; admin/module trust boundary. |
| high | Reentrancy risk in `_balanceDeltaAfterWithdrawScaled` | duplicate | Same as `04`; guarded in current callers and tested. |
| medium | Checkpoint A allows stale price data before lock | governance risk | Market/oracle design choice; no direct bypass confirmed. |
| low | Missing zero-address validation for critical params | false positive | Critical setters validate zero address where needed; claimed issue is overstated for current code. |
| gas | Redundant reads in `_applyResolveAccounting` | duplicate | Optimization only. |
| informational | Gap size may be insufficient for future upgrades | governance risk | Upgrade planning concern, not live exploit. |

## 14_MarketEngineDispatcher.md
| Severity | Finding | Status | Note |
|---|---|---|---|
| critical | No timelock on critical admin operations | governance risk | True and unresolved; requires governance redesign. |
| high | Duplicate selector mappings in ERC-7201 and linear storage | duplicate | Same issue as `05`; maintenance hazard, not confirmed active exploit. |
| medium | Root-owned selector collision risk from hardcoded constants | false positive | No mismatch observed in live code/tests. |
| low | Missing zero-address validation for oracle updates | false positive | Oracle setters already reject zero address. |
| gas | Redundant module storage compatibility call | duplicate | Optimization only. |
| informational | `__gap` size may be insufficient after dispatcher state additions | governance risk | Future upgrade capacity issue, not current exploit. |

## Overall determination
- Confirmed code-level issues are either `fixed` or `already fixed`.
- Remaining unresolved items are mostly `governance risk`.
- `01`, `02`, and parts of `03` are not suitable as canonical remediation tables because they are broad, duplicate, or hypothetical.
- The repo is **well reconciled and regression-tested against Hashlock**, but it is **not “fully audited” in the sense of eliminating governance and trust-model risk**.
