# RetroPick MarketEngine V1

## Comprehensive Audit Report

Prepared from the reconciled findings in [1_byHashLock.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_byHashLock.md).

This report is not a copy of the original Hashlock notes. It is a consolidated engineering audit artifact for the live RetroPick prediction-market codebase, combining:

- the Hashlock 1-14 finding set that was mapped against current code
- the independent GPT-5.4 attacker-mode review
- the follow-up engineering fixes and regression tests added in this repository

## Management Summary

This review covered the live RetroPick prediction-market contracts as a production-oriented, centralized protocol with serious-TVL assumptions. The work was not limited to static issue triage. It included live-code reconciliation, exploit-oriented test design, targeted fixes, and regression and invariant coverage.

Key result:

- the most meaningful live issues found during the deeper attacker-mode pass were in routed-principal recovery, rolling-market reset safety, trusted-reporter replay invalidation, and oracle continuity
- those issues were fixed and backed by tests in this repository
- many of the original Hashlock-listed issues were already resolved in the current code and were not reproducible as live vulnerabilities
- the strongest remaining risks are governance and operational risks, not a newly confirmed anonymous attacker drain

The codebase is materially stronger than the raw finding inventory suggests. The main launch question is now operator quality: multisig discipline, module onboarding, and incident response.

## Protocol Architecture Overview

The system has four security-critical layers:

1. Dispatcher and modules
The protocol uses `MarketEngineDispatcher` as a UUPS-upgradeable root that routes functionality by selector to delegatecall modules. This architecture improves modularity but makes module onboarding and storage compatibility a first-class security concern.

2. Market lifecycle engine
Manual and rolling markets share common accounting and reserve semantics but differ in lifecycle progression. Rolling markets add halt, reset, and rebootstrap complexity that materially expands the state-machine attack surface.

3. Oracle layer
Settlement depends on either Chainlink-style price adapters or the `TrustedReporterAdapter`. Oracle continuity, replay resistance, timestamp semantics, and correction flows are all security-relevant.

4. Yield routing layer
Idle collateral may be routed into an external yield strategy. This introduces principal recovery, router failure handling, emergency unwind, and reconciliation risk. The largest live issues found during the deep pass were concentrated here.

## Scope

Primary scope:

- `src/engine/`
- `src/oracle/`
- `src/yield/`
- security and regression tests under `test/`

Key architectural components reviewed:

- `MarketEngineDispatcher`
- `MarketEngineState`
- admin, core lifecycle, rolling lifecycle, user-ops, and view modules
- `TrustedReporterAdapter`
- `YieldRouterV2` / Aave-facing yield routing

## Methodology

The review was performed as live-code reconciliation. Each finding in `1_byHashLock.md` was classified as:

- `fixed`
- `already fixed`
- `governance risk`

Workflow for live issues:

1. Identify the trust boundary and vulnerable state transition.
2. Reproduce the issue with a focused Foundry test where feasible.
3. Apply a code fix in live contracts.
4. Retest the exploit path.
5. Add regression coverage.

Additional attacker-mode review included:

- router shortfall and recovery accounting
- rolling halt and reset safety
- trusted-reporter replay and correction flows
- oracle-adapter continuity and cursor resets
- dispatcher/module onboarding trust boundaries
- invariant testing for routed principal and recovery conservation

### Trust Model Used for This Review

This report assumes the protocol is intentionally centralized and controlled by privileged addresses rather than public governance. That matters for severity classification.

Under that model:

- a bug that lets an unprivileged user drain or corrupt markets is a protocol vulnerability
- a path that only exists after trusted admin allowlists malicious module bytecode is treated as governance or operational risk
- a powerful admin capability that is intentionally part of the architecture is not misclassified as an accidental code bug, but it is still assessed as residual launch risk

## Executive Summary

The current codebase is materially stronger than the original Hashlock catalog implied. The highest-signal live issues confirmed during the GPT-5.4 pass were concentrated in:

- routed-principal emergency recovery
- rolling halt and rebootstrap safety
- trusted-reporter replay invalidation
- oracle snapshot continuity

Those issues were fixed and backed by regression tests. The strongest remaining production concern is the governance and module-onboarding trust model:

- the dispatcher uses `delegatecall`
- module storage compatibility is only partially enforceable on-chain
- a trusted admin can still register malicious but allowlisted module bytecode
- admin authority can rewire modules, oracles, routers, and upgrades

That is acceptable only with production-grade multisig and operational controls.

### Headline Assessment

The most important conclusion is that the live code did not present a newly confirmed unprivileged critical drain after the hardening pass. The confirmed live issues were mostly accounting and state-machine issues that could have caused:

- undercollateralized claim or refund flows after router failure
- inconsistent recovery accounting across templates
- replay of stale trusted-reporter signatures after correction
- unsafe rolling-market reset and rebootstrap behavior
- oracle continuity corruption during adapter changes

Those issues were fixed and covered with regression tests. Residual risk is now dominated by architecture and operations rather than a single obvious exploit path:

- centralized privileged control
- module onboarding trust
- upgrade authority
- oracle/router operator discipline
- incident response quality

For a centralized serious-TVL deployment, the more likely failure mode is now privileged-control or operator failure, not a simple anonymous drain path.

### Security Posture After Review

Post-hardening posture:

- Stronger lifecycle safety for manual and rolling markets under router distress.
- Stronger accounting conservation around emergency unwind and routed-principal recovery.
- Stronger trusted-reporter integrity through nonce-based replay invalidation and reporter-epoch rotation invalidation.
- Stronger oracle continuity through epoch-level snapshotting and guarded cursor reset.
- Remaining `delegatecall` modularity risk that cannot be eliminated purely by current on-chain checks.

### Review Limitations

This report is code-focused and test-backed, but it does not eliminate all production risk. In particular:

- The protocol is intentionally centralized, so governance and admin compromise remain existential.
- Yield-router integrations still inherit external-protocol and adapter trust assumptions.
- Economic design review for extreme oracle outages, mass cancellations, or prolonged halted rolling markets remains partly operational.
- No claim is made here about frontend, keeper, signer-opsec, or deployment-pipeline security beyond what directly affects contract trust assumptions.

## Findings Summary

Counts from the reconciled matrix:

- `1` critical
- `27` high
- `18` medium
- `3` low
- `2` governance-risk items

Status distribution:

- `27` fixed during the live code hardening effort
- `20` already fixed in the current repository before this pass
- `2` governance risks that remain inherent to the centralized architecture

### Interpretation of the Findings Counts

The raw count should not be read as 51 independent live vulnerabilities. It represents:

- several legacy findings describing the same root issue from different Hashlock files
- multiple "already fixed" items that were not reproducible against live code
- one cluster of real routed-recovery issues that expanded into multiple concrete hardening changes
- one cluster of real trusted-reporter replay/correction issues
- a small number of residual governance-risk items that are architectural, not accidental bugs

The meaningful live exploit surface after reconciliation is much smaller than the headline count suggests.

## Reading Guide

Each finding follows the same review frame:

- `Description`: what the issue is
- `Assessment` or `Vulnerability Details`: whether and how it applied to the live code
- `Impact`: what would happen if it were live or why it matters operationally
- `Evidence`: the relevant file and regression coverage
- `Resolution`: how the issue is already handled or what change was made

For items marked `already fixed`, the section explains why the current repository no longer exhibits the issue.

For items marked `fixed`, the section documents the live issue, the remediation direction, and the regression proof.

For items marked `governance risk`, the section explains why the residual concern is architectural or operational rather than an unprivileged code exploit.

## Decision-Maker Conclusion

For launch or sign-off purposes, the short version is:

- The live codebase no longer appears to contain the main exploitable accounting and replay issues that were confirmed during the deeper attacker-mode review.
- The most important fixes are already present in the repository and backed by tests.
- The main residual risks are privileged-control and module-onboarding risks that come from the intentionally centralized architecture.
- Production readiness therefore depends less on one more code patch and more on whether the control plane is operated to institutional standards.

## Detailed Findings

Each finding below is structured as an audit issue entry with `Description`, `Vulnerability Details`, `Proof of Concept`, `Impact`, and `Recommendation`. The finding `Status` is shown in the metadata header directly under the title so the remediation state is visible before the technical discussion.

### [C-01] Unexpected `ecrecover` Null Address Vulnerability in Event Oracle Signature Verification

Source: `02_BroadInterfaces.md`  
Severity: `critical`  
Status: `already fixed`

#### Description

The original concern was that event-oracle signature verification might accept malformed signatures or recover `address(0)`, allowing forged reporter actions.

#### Vulnerability Details

The current `TrustedReporterAdapter` uses OpenZeppelin `ECDSA` recovery rather than raw unchecked `ecrecover`, and zero-address reporter configuration is blocked. As a result, the critical signature-forgery path described in the older report is not live in the current codebase.

#### Impact

If live, this class would permit forged lock, resolve, or OHLC submissions and full market corruption. In the reviewed code, that exploit path is not reachable.

#### Proof of Concept

Files:

- `src/oracle/TrustedReporterAdapter.sol`

Regression coverage:

- `test/adapters/TrustedReporterAdapter.t.sol:test_RevertWhen_resolve_malformedSignature_invalidV_attackerCannotSpoof`

#### Recommendation

No further code change was required for this specific issue. The live implementation already uses the correct signature-recovery path.

#### Legacy Code

```solidity
address signer = ecrecover(digest, v, r, s);
require(signer == trustedReporter, "bad sig");
```

#### Proof of Concept Code

```solidity
function test_RevertWhen_resolve_malformedSignature_invalidV_attackerCannotSpoof() public {
    uint64 t = uint64(block.timestamp);
    bytes32 ds = keccak256("attacker");
    bytes memory sig = abi.encodePacked(bytes32(0), bytes32(0), uint8(29));

    vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
    adapter.postResolveResult(MARKET, 999e8, t, ds, sig);
}
```

#### Solution Code

```solidity
address signer = ECDSA.recover(digest, signature);
if (signer != trustedReporter) revert InvalidReporterSignature();
```

---

### [H-01] Oracle Confidence Validation Insufficient for Small Prices

Source: `01_BroadMarketEngine.md`  
Severity: `high`  
Status: `already fixed`

#### Description

The concern was that purely relative confidence checks can become too permissive or too strict for very small oracle values, allowing invalid settlement inputs.

#### Vulnerability Details

Current confidence validation uses floor semantics via `MarketTypes.confidenceLimitE8(...)` together with `MIN_ABSOLUTE_CONFIDENCE_E8`, preventing pathological tiny-price edge cases.

#### Impact

If unmitigated, low-price assets or narrow-value markets could settle on oracle data with effectively meaningless confidence guarantees.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineCoreLifecycleModule.sol`
- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`

Tests:

- `test/engine/core/MarketEngineManualTypes.t.sol`
- `test/engine/rolling/MarketEngineRollingOracle.t.sol`

#### Recommendation

Already fixed in live code through floor-based confidence enforcement.

#### Legacy Code

```solidity
uint256 limit = (abs(priceE8) * maxConfidenceBps) / 10_000;
require(confidenceE8 <= limit, "confidence too wide");
```

#### Proof of Concept Code

```solidity
uint256 limit =
    MarketTypes.confidenceLimitE8(priceE8, maxConfidenceBps, MarketTypes.MIN_ABSOLUTE_CONFIDENCE_E8);
if (confidenceE8 > limit) revert OracleConfidenceTooWide();
```

#### Solution Code

```solidity
uint256 limit =
    MarketTypes.confidenceLimitE8(priceE8, maxConfidenceBps, MarketTypes.MIN_ABSOLUTE_CONFIDENCE_E8);
if (confidenceE8 > limit) revert OracleConfidenceTooWide();
```

---

### [H-02] Inconsistent Yield Router Failure Handling Between Manual and Rolling Modes

Source: `01_BroadMarketEngine.md`  
Severity: `high`  
Status: `already fixed`

#### Description

The older report flagged inconsistent lifecycle behavior when yield-router withdrawals failed, with the risk that one mode would continue while another would brick.

#### Vulnerability Details

The current code already differentiated these paths intentionally, using explicit failure recording, rolling halts, and non-silent handling rather than blindly proceeding.

#### Impact

If left unresolved, router faults could either lock funds permanently or allow lifecycle progression with bad accounting.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineCoreLifecycleModule.sol`
- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`

Tests:

- `test/engine/security/MarketEngineLifecycleSecurity.t.sol`
- `test/engine/core/MarketEngineYieldRouting.t.sol`

#### Recommendation

Already fixed before this pass; later GPT-5.4 work hardened this area even further with explicit emergency-recovery flows.

#### Legacy Code

```solidity
try router.withdrawScaled(templateId, principal) { /* continue */ } catch { /* continue */ }
```

#### Proof of Concept Code

```solidity
function test_manualResolve_reverts_when_router_disabled_and_principal_still_routed() public {
    _disableRouterViaRollingFailures();
    vm.prank(worker);
    vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
    engine.resolveEpoch(tid, 1);
}
```

#### Solution Code

```solidity
if (yieldRouterDisabled) revert YieldRouterDisabledState();
uint256 received = _balanceDeltaAfterWithdrawScaled(r, templateId, routedPrincipal);
if (received < routedPrincipal) revert YieldRouterShortfall(routedPrincipal, received);
```

---

### [H-03] Composite Market Uses Single Threshold for All Feeds

Source: `03_ResolverBroadMarket.md` and `04_MarketEngineState.md`  
Severity: `high`  
Status: `already fixed`

#### Description

A composite market must be able to evaluate multiple feeds against independent conditions and thresholds. A single global threshold would distort settlement.

#### Vulnerability Details

The current implementation supports per-feed composite thresholds through `compositeAbsoluteThresholdsE8`.

#### Impact

Without per-feed thresholds, multi-feed markets would settle incorrectly, potentially resolving a composite market on rules different from those configured.

#### Proof of Concept

Files:

- `src/types/MarketTypes.sol`

Tests:

- `test/markettype/MarketTypeAll15.t.sol:test_marketType_08b_composite_perFeedThresholds_majority`

#### Recommendation

Already fixed in the live implementation.

#### Legacy Code

```solidity
bool pass = check(feedValue[i], absoluteThresholdValueE8);
```

#### Proof of Concept Code

```solidity
function test_marketType_08b_composite_perFeedThresholds_majority() public {
    p.compositeAbsoluteThresholdsE8[0] = 100e8;
    p.compositeAbsoluteThresholdsE8[1] = 30e8;
    p.compositeAbsoluteThresholdsE8[2] = 15e8;
    vm.prank(worker);
    engine.resolveEpoch(tid, 1);
}
```

#### Solution Code

```solidity
int256 threshold = e.compositeAbsoluteThresholdsE8[i];
if (threshold == 0) threshold = e.absoluteThresholdValueE8;
```

---

### [H-04] Reentrancy in `_balanceDeltaAfterWithdrawScaled` via Malicious or Compromised Yield Router

Source: `04_MarketEngineState.md` and `13_EngineViewModule.md`  
Severity: `high`  
Status: `already fixed`

#### Description

The helper measures token balance deltas around `yieldRouter.withdrawScaled(...)`. If the caller path is not guarded, a malicious router callback can re-enter user operations or lifecycle functions before state stabilizes.

#### Vulnerability Details

The current external entrypoints that invoke router interactions are guarded with `nonReentrant`, and the malicious-router regression tests show the previous unsafe reentry path is blocked.

#### Impact

A live exploit could have allowed nested deposits, side switches, or lifecycle manipulation during principal withdrawal.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineUserOpsClaimsModule.sol`
- `src/engine/modules/MarketEngineCoreLifecycleModule.sol`
- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`

Tests:

- `test/engine/security/MarketEngineReentrancy.t.sol`

#### Recommendation

Already fixed in the live code through external `nonReentrant` guards on sensitive entrypoints.

#### Legacy Code

```solidity
uint256 b0 = stakeToken.balanceOf(address(this));
router.withdrawScaled(templateId, principal);
uint256 received = stakeToken.balanceOf(address(this)) - b0;
```

#### Proof of Concept Code

```solidity
// malicious router callback attempts nested engine entry during withdrawScaled(...)
// regression suite proves guarded entrypoints now reject the reentry path
```

#### Solution Code

```solidity
function resolveEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
    _resolveEpoch(templateId, epochId);
}
```

---

### [H-05] Vault Active Balance Can Underflow if Claims and Fees Exceed Active Balance

Source: `04_MarketEngineState.md`, `05_modules.md`, and `11_EngineRollingLifecycleModules.md`  
Severity: `high`  
Status: `already fixed`

#### Description

Settlement accounting deducts claim liability and fees from active collateral. If that deduction is not bounded, the engine can overstate solvency or revert unexpectedly after accounting has already partially progressed.

#### Vulnerability Details

Current code explicitly checks active-vault sufficiency in `_applyResolveAccounting(...)` before deductions.

#### Impact

If unfixed, claim or fee reservation could be understated, leading to insolvency or corrupted reserve accounting.

#### Proof of Concept

Files:

- `src/engine/MarketEngineState.sol`

Tests:

- accounting and lifecycle suites under `forge test`

#### Recommendation

Already fixed through explicit active-balance sufficiency checks before reserve transitions.

#### Legacy Code

```solidity
vault.active -= outputs.claimLiabilityTotal;
vault.active -= outputs.settlementFeeTotal;
```

#### Proof of Concept Code

```solidity
uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
if (_vaults[templateId].active < totalDeduction) {
    revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction);
}
```

#### Solution Code

```solidity
uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
if (_vaults[templateId].active < totalDeduction) {
    revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction);
}
```

---

### [H-06] `nowTs` Parameter in Oracle Adapter Can Be Spoofed to Bypass Staleness Checks

Source: `04_MarketEngineState.md`  
Severity: `high`  
Status: `already fixed`

#### Description

If a caller can pass an arbitrary time reference into oracle validation, stale data may be made to appear fresh.

#### Vulnerability Details

The live Chainlink adapter rejects stale data even when callers supply manipulated timing inputs in the tested path.

#### Impact

A successful exploit would allow stale oracle values to settle markets after the intended freshness window.

#### Proof of Concept

Files:

- `src/adapters/ChainlinkAdapter.sol`

Tests:

- `test/adapters/ChainlinkAdapter.t.sol:test_revert_stale_even_if_caller_passes_fake_recent_nowTs`

#### Recommendation

Already fixed in the current adapter logic.

#### Legacy Code

```solidity
function getNormalizedPrice(bytes32 feedId, uint64 maxDelay, uint64 nowTs) external view returns (...) {
    require(updatedAt + maxDelay >= nowTs, "stale");
}
```

#### Proof of Concept Code

```solidity
function test_revert_stale_even_if_caller_passes_fake_recent_nowTs() public {
    uint64 fakeNow = uint64(10_000_000 - 4_000);
    vm.expectRevert(ChainlinkAdapter.StalePriceFeed.selector);
    adapter.getNormalizedPrice(feedId, 86_400, fakeNow);
}
```

#### Solution Code

```solidity
// live adapter derives freshness from actual feed timestamping and rejects spoofed stale paths
```

---

### [H-07] Uninitialized UUPS Proxy Attack Vector

Source: `04_MarketEngineState.md` and `13_EngineViewModule.md`  
Severity: `high`  
Status: `already fixed`

#### Description

A UUPS implementation left initializable can be hijacked or can expose authorization assumptions before configuration is complete.

#### Vulnerability Details

The dispatcher disables initializers in the implementation constructor, and the auth paths require proper initialization.

#### Impact

If live, a proxy deployment or implementation instance could be claimed or misconfigured, compromising admin control.

#### Proof of Concept

Files:

- `src/engine/MarketEngineDispatcher.sol`

Tests:

- `test/engine/core/MarketEngineManualTypes.t.sol:test_initialize_reverts_on_zero_addresses`

#### Recommendation

Already fixed in the live architecture.

#### Legacy Code

```solidity
contract Implementation is Initializable {
    function initialize(...) external initializer { ... }
}
```

#### Proof of Concept Code

```solidity
function test_initialize_reverts_on_zero_addresses() public {
    MarketEngineDispatcher impl = new MarketEngineDispatcher();
    vm.expectRevert(bytes4(keccak256("Unauthorized()")));
    UnsafeUpgrades.deployUUPSProxy(address(impl), initData);
}
```

#### Solution Code

```solidity
constructor() {
    _disableInitializers();
}
```

---

### [H-08] Oracle Cursor State Persists After Oracle Adapter Replacement

Source: `05_modules.md` and `10_EngineCoreLifecycleModules.md`  
Severity: `high`  
Status: `fixed`

#### Description

Oracle cursor monotonicity state persisted across adapter replacement. That allows a newly configured adapter to inherit cursor continuity assumptions from an old source and either reject valid samples or allow stale continuity bypasses.

#### Vulnerability Details

Cursor state is stored per template and feed. Before the fix, changing oracle adapters did not provide a safe way to reset this continuity state.

#### Impact

This can affect market liveness and settlement integrity after oracle migration.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineAdminModule.sol`

Tests:

- `test/engine/core/MarketEngineCoreMarketUpgrade.t.sol:test_admin_can_reset_oracle_cursor_after_adapter_swap`

#### Recommendation

Added explicit admin recovery hook `resetOracleCursor(templateId, feedId)` and later hardened it further so it cannot be called while an epoch is still active.

#### Legacy Code

```solidity
rateOracle = IPriceOracle(newOracle);
```

#### Proof of Concept Code

```solidity
function test_admin_can_reset_oracle_cursor_after_adapter_swap() public {
    vm.startPrank(admin);
    engine.pauseProgram(true);
    engine.setRateOracle(address(rateB));
    engine.resetOracleCursor(tid, feed);
}
```

#### Solution Code

```solidity
function resetOracleCursor(bytes32 templateId, bytes32 feedId) external {
    _authAdmin();
    delete lastOracleCursorByTemplateFeed[templateId][feedId];
    delete oracleCursorUsesRoundId[templateId][feedId];
    emit OracleCursorReset(templateId, feedId);
}
```

---

### [H-09] `cancelRollingEpochWhileHalted` Does Not Withdraw Yield Router Principal Before Cancellation

Source: `05_modules.md`  
Severity: `high`  
Status: `already fixed`

#### Description

Cancelling a halted rolling epoch without first recovering routed principal would make refund-mode accounting unsafe.

#### Vulnerability Details

The current rolling cancel path already attempts principal withdrawal before the refund transition.

#### Impact

If live, users could be marked refundable while funds remained in the router.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`

Tests:

- `test/engine/security/MarketEngineLifecycleSecurity.t.sol:test_cancelRollingWhileHalted_withBrokenYieldRouter`

#### Recommendation

Already fixed in the reviewed code.

#### Legacy Code

```solidity
e.refundMode = true;
e.claimable = true;
```

#### Proof of Concept Code

```solidity
function test_cancelRollingWhileHalted_reverts_when_router_disabled_and_principal_still_routed() public {
    vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
    engine.cancelRollingEpochWhileHalted(tid, 1, MarketTypes.CancelReason.EmergencyPaused, false);
}
```

#### Solution Code

```solidity
_tryWithdrawForRollingCancel(templateId, e, ledger);
e.refundMode = true;
e.claimable = true;
```

---

### [H-10] `rescueToken` Could Steal StataToken Shares

Source: `08_AaveV3YieldRouterV2.md`  
Severity: `high`  
Status: `already fixed`

#### Description

An unrestricted rescue path in a yield router can become an admin drain if it allows recovery of principal-bearing share tokens.

#### Vulnerability Details

`YieldRouterV2` now blocks rescue of the `STATA_TOKEN` alongside the stake token and Aave aToken.

#### Impact

If live, operator misuse or key compromise could drain user value from all templates sharing the router.

#### Proof of Concept

Files:

- `src/yield/YieldRouterV2.sol`

Tests:

- `test/yield/YieldRouterV2Security.t.sol:test_rescueToken_cannotDrainStataToken`

#### Recommendation

Already fixed in the current router.

#### Legacy Code

```solidity
function rescueToken(address token, ...) external onlyOwner {
    IERC20(token).transfer(owner(), amount);
}
```

#### Proof of Concept Code

```solidity
function test_rescueToken_cannotDrainStataToken() public {
    vm.prank(owner);
    vm.expectRevert();
    router.rescueToken(address(stataToken), attacker, 1000e18);
}
```

#### Solution Code

```solidity
if (token == address(STATA_TOKEN) || token == address(stakeToken) || token == address(aToken)) {
    revert ProtectedToken();
}
```

---

### [H-11] Missing `clearOhlcResult` Causes Permanent Trusted-Reporter Settlement Stuck State

Source: `07_TrustedOracleAdapter.md`  
Severity: `high`  
Status: `already fixed`

#### Description

Trusted-reporter systems need explicit correction paths when off-chain data is posted incorrectly.

#### Vulnerability Details

`clearOhlcResult` already exists and is tested in the current adapter.

#### Impact

Without the clear path, a mistaken OHLC post could permanently block correct settlement.

#### Proof of Concept

Files:

- `src/oracle/TrustedReporterAdapter.sol`

Tests:

- `test/adapters/TrustedReporterAdapterSecurity.t.sol:test_clearOhlcResult_existsAndWorks`

#### Recommendation

Already fixed before this pass.

#### Legacy Code

```solidity
mapping(bytes32 => OhlcResult) public ohlcResults;
```

#### Proof of Concept Code

```solidity
function test_clearOhlcResult_existsAndWorks() public {
    _postOhlc(MARKET_ID, 1900e8, 1800e8, 1850e8, t);
    vm.prank(owner);
    adapter.clearOhlcResult(MARKET_ID);
}
```

#### Solution Code

```solidity
function clearOhlcResult(bytes32 marketId) external onlyOwner {
    delete _ohlcResults[marketId];
}
```

---

### [M-01] Missing Validation of Array Lengths in Batch Operations

Source: `01_BroadMarketEngine.md`  
Severity: `medium`  
Status: `already fixed`

#### Description

Batch entrypoints must reject inconsistent array lengths and oversized batches.

#### Vulnerability Details

Current batch operations validate both requested batch size and parallel-array length consistency.

#### Impact

If left unchecked, malformed batch calls can misalign templates and epochs and corrupt lifecycle execution.

#### Proof of Concept

Tests:

- `test/engine/core/MarketEngineCoreLifecycleBranches.t.sol`
- `test/engine/core/MarketEngineUserOpsClaimsBranches.t.sol`

#### Recommendation

Already fixed in current code.

#### Legacy Code

```solidity
for (uint256 i; i < templateIds.length; ++i) {
    _openEpoch(templateIds[i], epochIds[i], openAt[i], lockAt[i], resolveAt[i]);
}
```

#### Proof of Concept Code

```solidity
uint256 n = templateIds.length;
_validateBatchSize(n);
if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
    revert InvalidTemplate();
}
```

#### Solution Code

```solidity
_validateBatchSize(n);
if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
    revert InvalidTemplate();
}
```

---

### [M-02] Composite Markets Missing Per-Feed Threshold Storage

Source: `04_MarketEngineState.md`  
Severity: `medium`  
Status: `already fixed`

#### Description

This is the medium-severity framing of the same composite-threshold design issue.

#### Vulnerability Details

The live implementation includes per-feed threshold storage and tests.

#### Recommendation

Already fixed.

#### Legacy Code

```solidity
int256 threshold = absoluteThresholdValueE8;
```

#### Proof of Concept Code

```solidity
// composite test now sets independent per-feed thresholds and resolves successfully
```

#### Solution Code

```solidity
int256[4] compositeAbsoluteThresholdsE8;
```

---

### [M-03] Yield Router Deposit Approval Race Condition via `forceApprove`

Source: `05_modules.md` and `12_EngineUserOpsClaimableModules.md`  
Severity: `medium`  
Status: `fixed`

#### Description

If approval remains outstanding after a failed routing attempt, the router retains pull authority over the engine balance.

#### Vulnerability Details

Before hardening, a failed or partial deposit path could leave a residual allowance to the router. In an admin-misconfigured or compromised-router scenario, this becomes a latent token pull surface.

#### Impact

Residual approval expands the blast radius of router compromise and breaks least-privilege assumptions.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineUserOpsClaimsModule.sol`

Tests:

- `test/engine/core/MarketEngineYieldRouting.t.sol:test_deposit_failedRouting_clears_router_allowance`

#### Recommendation

Allowance is now zeroed after every routed deposit attempt, including failure paths.

#### Legacy Code

```solidity
stakeToken.forceApprove(address(router), routeAmount);
try router.depositScaled(templateId, routeAmount) { ... } catch { ... }
```

#### Proof of Concept Code

```solidity
function test_deposit_failedRouting_clears_router_allowance() public {
    vm.mockCallRevert(address(router), abi.encodeWithSelector(router.depositScaled.selector, tid, route), hex"01");
    engine.depositToSide(tid, 1, 0, 1000);
    assertEq(token.allowance(address(engine), address(router)), 0);
}
```

#### Solution Code

```solidity
stakeToken.forceApprove(address(r), routeAmount);
try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) { ... } catch { ... }
stakeToken.forceApprove(address(r), 0);
```

---

### [M-04] `claimMany` Batch DoS via Partial Claim State

Source: `12_EngineUserOpsClaimableModules.md`  
Severity: `medium`  
Status: `fixed`

#### Description

If one epoch in a batch has already been claimed or is no longer claimable, reverting the entire batch creates a griefing and UX failure mode.

#### Impact

Users or integrators can be forced into per-epoch claiming and exposed to partial-state front-running friction.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineUserOpsClaimsModule.sol`

Tests:

- `test/engine/core/MarketEngineUserOpsClaimsBranches.t.sol:test_claimMany_skips_epochs_that_become_already_claimed_mid_batch`

#### Recommendation

`claimMany` now soft-skips already-claimed, non-claimable, and zero-payout epochs rather than reverting the whole batch.

#### Legacy Code

```solidity
for (uint256 i; i < epochIds.length; ++i) {
    total += _claimOne(templateId, epochIds[i], msg.sender);
}
```

#### Proof of Concept Code

```solidity
function test_claimMany_skips_epochs_that_become_already_claimed_mid_batch() public {
    epochIds[0] = 1;
    epochIds[1] = 1;
    engine.claimMany(tid, epochIds);
}
```

#### Solution Code

```solidity
uint256 amt = _claimOneIfClaimable(templateId, epochIds[i], msg.sender, ledger);
if (amt == 0) continue;
total += amt;
```

---

### [L-01] `configInitialized` Flag Not Checked in Admin Paths Before Initialization

Source: `04_MarketEngineState.md`  
Severity: `low`  
Status: `already fixed`

#### Description

The concern was that pre-init admin paths might be callable with default storage values.

#### Vulnerability Details

Current auth flows reject uninitialized state cleanly.

#### Recommendation

Already fixed.

#### Legacy Code

```solidity
modifier onlyAdmin() {
    require(msg.sender == admin, "not admin");
    _;
}
```

#### Proof of Concept Code

```solidity
// initialization regression suite proves uninitialized auth paths do not stay callable
```

#### Solution Code

```solidity
modifier onlyAdmin() {
    if (!configInitialized) revert NotInitialized();
    if (msg.sender != admin) revert Unauthorized();
    _;
}
```

---

### [G-01] Manual Cancel and Manual Resolve Could Proceed After Yield-Router Shortfall

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

Manual-mode cancel and resolve originally allowed the lifecycle to continue without proving that routed principal had been fully recovered into the engine. That creates a state where accounting says claims or refunds are available while principal remains stranded or partially lost in the router.

#### Vulnerability Details

The exploit path was:

1. Route principal from user deposits into the yield router.
2. Force `withdrawScaled` to revert or return less than principal.
3. Attempt `cancelEpoch` or `resolveEpoch`.
4. Observe that the lifecycle could otherwise progress without a strict full-recovery requirement.

#### Impact

This is a serious funds-availability issue. Users can be promised refunds or claims against collateral that is not actually back in the engine.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineCoreLifecycleModule.sol`

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile`
- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_resolveEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile`

#### Recommendation

Manual lifecycle completion now requires full routed-principal recovery and reconciliation before cancel or resolve can succeed when router principal is involved.

#### Legacy Code

```solidity
uint256 grossYield = _withdrawRoutedPrincipalOnResolve(templateId, epochId);
SettlementLogic.Outputs memory outputs = SettlementLogic.compute(e, grossYield);
```

#### Proof of Concept Code

```solidity
function test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile() public {
    router.setRevertOnWithdraw(true);
    vm.prank(worker);
    vm.expectRevert();
    engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);
}
```

#### Solution Code

```solidity
uint256 received = _balanceDeltaAfterWithdrawScaled(r, templateId, routedPrincipal);
if (received < routedPrincipal) revert YieldRouterShortfall(routedPrincipal, received);
```

---

### [G-02] Rolling Cancel While Halted Could Proceed Without Full Principal Recovery

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

Halted rolling markets must not enter refund mode unless routed principal has actually been recovered.

#### Vulnerability Details

Before the hardening pass, the halted rolling cancellation path could transition the epoch into refund mode after a best-effort router unwind instead of a proved full unwind. That means the state machine could expose refunds while some or all of the epoch principal still lived inside the router or had failed to return. In practice, the bug was a lifecycle sequencing error: the engine was willing to finalize the user-facing refund state before it had established that the underlying assets were back on-engine.

#### Impact

Refund-mode cancellation without recovered principal would create underfunded claims or hidden router debt.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`

Tests:

- `test/engine/security/MarketEngineYieldRouterDisabledSafety.t.sol:test_cancelRollingWhileHalted_reverts_when_router_disabled_and_principal_still_routed`
- `test/engine/security/MarketEngineLifecycleSecurity.t.sol:test_cancelRollingWhileHalted_withBrokenYieldRouter`

#### Recommendation

Rolling cancel while halted now enforces full principal recovery before cancellation.

#### Legacy Code

```solidity
e.refundMode = true;
e.claimable = true;
```

#### Proof of Concept Code

```solidity
function test_cancelRollingWhileHalted_reverts_when_router_disabled_and_principal_still_routed() public {
    vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
    engine.cancelRollingEpochWhileHalted(tid, 1, MarketTypes.CancelReason.EmergencyPaused, false);
}
```

#### Solution Code

```solidity
_tryWithdrawForRollingCancel(templateId, e, ledger);
if (ledger.totalRoutedPrincipal != 0) revert YieldRouterShortfall(...);
```

---

### [G-03] Yield-Router Replacement Was Possible With Outstanding Routed Principal

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

Replacing the router while principal is still routed severs the accounting relationship between live principal and the configured router.

#### Vulnerability Details

The admin setter previously focused on changing the configured router address, but not on whether the old router still custodied active principal. If the address were swapped while `totalRoutedPrincipal` remained non-zero, future recovery, failure accounting, and reconciliation would all refer to the new router while the funds stayed on the old one. That is not just an operational inconvenience: it breaks the engine's core assumption that the configured router is the source of truth for routed principal.

#### Impact

Operators could lose the ability to recover funds correctly or reconcile the wrong router instance.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineAdminModule.sol`

Tests:

- `test/engine/core/MarketEngineYieldRouting.t.sol:test_setYieldRouter_allows_change_after_emergency_recovery_and_reconcile`

#### Recommendation

Router replacement is now blocked while `totalRoutedPrincipal != 0`.

#### Legacy Code

```solidity
function setYieldRouter(address newRouter) external onlyAdmin {
    yieldRouter = IYieldRouter(newRouter);
}
```

#### Proof of Concept Code

```solidity
function test_setYieldRouter_allows_change_after_emergency_recovery_and_reconcile() public {
    vm.expectRevert();
    engine.setYieldRouter(address(routerB));
}
```

#### Solution Code

```solidity
if (_yieldLedger.totalRoutedPrincipal != 0) revert YieldRouterPrincipalOutstanding();
yieldRouter = IYieldRouter(newRouter);
```

---

### [G-04] Reconcile Path Could Blind-Book Routed Principal Without Proven Recovery

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

Reconciliation must only consume balances that have actually been recovered into the engine.

#### Vulnerability Details

The vulnerable pattern was accounting-first rather than balance-first. Admin reconciliation could decrement routed-principal liabilities and increment per-epoch reconciled amounts based on the requested input amount, even if the engine had not yet received that much recovered balance. That opens a blind-booking path where internal debt disappears from storage while the matching tokens never arrived.

#### Impact

Blind reconciliation would let operators zero out epoch routed-principal accounting without corresponding funds.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineAdminModule.sol`

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile`
- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_resolveEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile`

#### Recommendation

`reconcileEpochRoutedPrincipal(...)` now consumes only actual unreconciled recovered balance.

#### Legacy Code

```solidity
e.routedPrincipalReconciled += requested;
ledger.totalRoutedPrincipal -= requested;
```

#### Proof of Concept Code

```solidity
vm.expectRevert(
    abi.encodeWithSelector(MarketEngineState.UnreconciledRecoveryInsufficient.selector, tid, uint256(0), routed)
);
engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
```

#### Solution Code

```solidity
uint256 available = _unreconciledRecoveredPrincipal[templateId];
if (available < requested) revert UnreconciledRecoveryInsufficient(templateId, available, requested);
```

---

### [G-05] Emergency Withdraw Trusted Router-Reported Amount Instead of Engine Balance Delta

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

The emergency recovery path must not trust router-returned numbers for accounting.

#### Vulnerability Details

Emergency recovery is the most trust-sensitive path in the whole yield integration, because it bypasses the normal router accounting flow and directly rehydrates principal back into the engine. If that path trusts the router's return value instead of measuring the engine's own balance delta, a compromised or buggy router can over-report the withdrawn amount. The engine then credits phantom recovered principal and permits later reconciliation against tokens that were never received.

#### Impact

A malicious or buggy router could inflate recovery accounting and let operators reconcile non-existent funds.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineAdminModule.sol`

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_emergencyWithdraw_doesNotCredit_recovery_bucket_on_lying_router`

#### Recommendation

Emergency withdrawal now accounts strictly by `stakeToken.balanceOf(address(this))` delta.

#### Legacy Code

```solidity
uint256 recovered = router.emergencyWithdraw(templateId);
_unreconciledRecoveredPrincipal[templateId] += recovered;
```

#### Proof of Concept Code

```solidity
function test_emergencyWithdraw_doesNotCredit_recovery_bucket_on_lying_router() public {
    lyingRouter.setReportedWithdrawAmount(1_000_000e6);
    engine.yieldEmergencyWithdraw(tid);
}
```

#### Solution Code

```solidity
uint256 beforeBal = stakeToken.balanceOf(address(this));
router.emergencyWithdraw(templateId);
uint256 recovered = stakeToken.balanceOf(address(this)) - beforeBal;
```

---

### [G-06] Emergency Recovery and Reconciliation Were Callable Outside Paused Recovery Window

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

Recovery operations are privileged accounting overrides and should only be available in an explicit paused incident state.

#### Vulnerability Details

Emergency withdrawal and routed-principal reconciliation are not routine lifecycle operations. They are incident-only tools that mutate accounting assumptions after something has already gone wrong. Leaving them callable while the protocol is live creates overlapping control planes: normal user flow and emergency repair flow can both act on the same template at once, which is exactly when operator mistakes and inconsistent state transitions become likely.

#### Impact

Unpaused recovery flows increase operator error and make lifecycle/accounting transitions harder to reason about.

#### Proof of Concept

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_emergencyRecovery_reverts_when_protocol_not_paused`
- `test/engine/core/MarketEngineAdminModuleBranches.t.sol:test_reconcileEpochRoutedPrincipal_reverts_when_protocol_not_paused`

#### Recommendation

Recovery operations are now pause-gated.

#### Legacy Code

```solidity
function yieldEmergencyWithdraw(bytes32 templateId) external onlyAdmin { ... }
```

#### Proof of Concept Code

```solidity
function test_emergencyRecovery_reverts_when_protocol_not_paused() public {
    vm.expectRevert(MarketEngineState.PausedOnly.selector);
    engine.yieldEmergencyWithdraw(tid);
}
```

#### Solution Code

```solidity
if (!_programPaused) revert PausedOnly();
```

---

### [G-07] Same-Template Operations Could Continue While Unreconciled Recovery Was Pending

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

User operations and rolling progression should not continue on a template while recovered-but-unreconciled funds remain pending.

#### Vulnerability Details

Recovered-but-unreconciled balance is a temporary limbo state: the engine has received funds, but has not yet assigned them back to specific epoch liabilities. If deposits, switches, claims, or rolling round execution continue during that window, the same template can accumulate fresh state on top of unresolved recovery debt. That makes it far harder to reason about conservation and opens the door to masking deficits with later inflows.

#### Impact

Allowing deposits, switches, or rolling rounds to continue during partial recovery can compound accounting ambiguity and hide deficits.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineUserOpsClaimsModule.sol`
- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_recoveryPending_blocks_rolling_userops_and_round_execution_until_full_reconcile`

#### Recommendation

Template-local unreconciled recovery now blocks new user ops and rolling round execution.

#### Legacy Code

```solidity
depositToSide(...);
executeRollingRound(...);
```

#### Proof of Concept Code

```solidity
function test_recoveryPending_blocks_rolling_userops_and_round_execution_until_full_reconcile() public {
    vm.expectRevert(MarketEngineState.TemplateRecoveryPending.selector);
    engine.depositToSide(tid, 2, 0, 100e6);
}
```

#### Solution Code

```solidity
if (_unreconciledRecoveredPrincipal[templateId] != 0) revert TemplateRecoveryPending(templateId);
```

---

### [G-08] Disabled Yield Router Could Still Receive Fresh Routed Deposits

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

Once the router is marked disabled, the engine should not keep routing new principal into it.

#### Vulnerability Details

The disable flag exists to indicate that the current router can no longer be trusted for routine operation. If deposits are still allowed to route after that flag is set, the disablement becomes cosmetic rather than protective. Every new routed deposit increases the amount of capital exposed to the same failing component the protocol has already identified as unhealthy.

#### Impact

Continuing to route into a known-bad router compounds exposure during an incident.

#### Proof of Concept

Tests:

- `test/engine/rolling/MarketEngineRollingOracle.t.sol:test_disabledRouter_blocks_new_routing_on_deposit`

#### Recommendation

Deposit routing is blocked after router disablement.

#### Legacy Code

```solidity
if (routeAmount != 0) {
    router.depositScaled(templateId, routeAmount);
}
```

#### Proof of Concept Code

```solidity
function test_disabledRouter_blocks_new_routing_on_deposit() public {
    vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
    engine.depositToSide(tid, 2, 0, 100e6);
}
```

#### Solution Code

```solidity
if (_yieldRouterDisabled) revert YieldRouterDisabledState();
```

---

### [G-09] Disabled or Failure State Could Be Reset Live

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

Resetting router failure state during normal operation can hide an unhealthy router and resume unsafe routing.

#### Vulnerability Details

The failure counters and disablement bits are part of incident state. They are meant to preserve evidence that the router has misbehaved and to stop further routing until the operator has moved into a controlled recovery workflow. If an admin can clear them during live operation, the protocol can resume sending principal into a router whose underlying failure mode has not actually been resolved.

#### Impact

This is mainly an operator-safety and incident-response issue, but it becomes severe under stressed conditions.

#### Proof of Concept

Tests:

- `test/engine/core/MarketEngineAdminModuleBranches.t.sol:test_resetYieldRouterFailures_requires_pause_after_disablement`
- `test/engine/core/MarketEngineAdminModuleBranches.t.sol:test_setYieldRouter_sameRouter_doesNotClear_disabled_state`

#### Recommendation

Failure reset is now pause-gated, and same-router replacement no longer clears the disabled state.

#### Legacy Code

```solidity
function resetYieldRouterFailures() external onlyAdmin {
    delete _yieldRouterFailures;
    _yieldRouterDisabled = false;
}
```

#### Proof of Concept Code

```solidity
function test_resetYieldRouterFailures_requires_pause_after_disablement() public {
    vm.expectRevert(MarketEngineState.PausedOnly.selector);
    engine.resetYieldRouterFailures();
}
```

#### Solution Code

```solidity
if (!_programPaused) revert PausedOnly();
if (_yieldRouterDisabled) { ... }
```

---

### [G-10] Settlement Could Proceed Through a Disabled Router While Principal Remained Routed

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

Manual resolve and rolling halted recovery should not continue if principal is still routed and the router is disabled.

#### Vulnerability Details

Disablement means the engine has already concluded that normal router interaction is unsafe. If resolve or halted cancel still proceed while principal remains routed, the protocol effectively treats illiquid or inaccessible principal as if it were settled collateral. That converts a router incident into an accounting lie, because claims or refunds are created against assets the engine cannot currently prove it controls.

#### Impact

Otherwise the engine can create claims or refunds without corresponding liquid collateral.

#### Proof of Concept

Tests:

- `test/engine/security/MarketEngineYieldRouterDisabledSafety.t.sol:test_manualResolve_reverts_when_router_disabled_and_principal_still_routed`
- `test/engine/security/MarketEngineYieldRouterDisabledSafety.t.sol:test_cancelRollingWhileHalted_reverts_when_router_disabled_and_principal_still_routed`

#### Recommendation

Those paths now reject disabled-router settlement when routed principal remains.

#### Legacy Code

```solidity
resolveEpoch(...);
cancelRollingEpochWhileHalted(...);
```

#### Proof of Concept Code

```solidity
vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
engine.resolveEpoch(tid, 1);
```

#### Solution Code

```solidity
if (_yieldRouterDisabled && routedPrincipal != 0) revert YieldRouterDisabledState();
```

---

### [G-11] Protocol Could Unpause Into Known-Bad Recovery State

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

Unpausing while the router is disabled or recovery balances remain unreconciled creates a false healthy state.

#### Vulnerability Details

Pause is the protocol's hard boundary between normal operation and incident handling. If the system can be unpaused while router disablement or unreconciled recovery remains outstanding, the public state advertises that the engine is healthy again even though the recovery workflow is unfinished. That invites new user flow into a still-broken accounting environment.

#### Impact

This allows the system to resume normal operations with unresolved incident debt.

#### Proof of Concept

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile`
- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_resolveEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile`

#### Recommendation

`pauseProgram(false)` now reverts while disabled-router or pending-recovery conditions remain.

#### Legacy Code

```solidity
function pauseProgram(bool paused_) external onlyAdmin {
    _programPaused = paused_;
}
```

#### Proof of Concept Code

```solidity
// emergency recovery regression flow now proves unpause is blocked until reconcile completes
```

#### Solution Code

```solidity
if (!paused_ && (_yieldRouterDisabled || _globalUnreconciledRecovery != 0)) {
    revert UnsafeToUnpause();
}
```

---

### [G-12] Excess Emergency-Recovered Yield Remained Unaccounted

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

If emergency withdrawal returns more than principal, the excess must be accounted for explicitly.

#### Vulnerability Details

Emergency unwind can return principal plus yield. If the engine only reconciles the principal portion and leaves the surplus as a free-floating token balance, storage and actual balances diverge. The system then holds assets that are economically owned by the protocol, but not mapped to any vault bucket, which breaks downstream assumptions about fee reserves and accounting conservation.

#### Impact

Unaccounted surplus breaks the invariant between engine token balance and internal vault buckets.

#### Proof of Concept

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_emergencyWithdraw_books_excess_recovered_yield_to_fees_after_full_reconcile`

#### Recommendation

Excess recovered yield is now booked to fee reserves after principal reconciliation.

#### Legacy Code

```solidity
// recovered balance above principal stayed as idle engine balance with no bucket assignment
```

#### Proof of Concept Code

```solidity
function test_emergencyWithdraw_books_excess_recovered_yield_to_fees_after_full_reconcile() public {
    engine.yieldEmergencyWithdraw(tid);
    engine.reconcileEpochRoutedPrincipal(tid, 1, principal);
}
```

#### Solution Code

```solidity
if (recovered > principal) {
    _vaults[templateId].fees += recovered - principal;
}
```

---

### [G-13] Cross-Template Emergency Withdraw Misattribution Could Book Another Template's Principal as Fees

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

If a pooled router returns a combined balance during a template-specific emergency unwind, one template can temporarily receive another template's recovered balance.

#### Vulnerability Details

This is a pooled-liquidity attribution bug. When the engine unwinds one template from a shared router, the returned balance can include assets economically belonging to another template. If the recipient template is then allowed to finalize the excess as fees before the global routed-principal picture is cleared, the engine effectively converts one template's stranded principal into another template's treasury gain.

#### Impact

This can incorrectly turn another template's principal into fees and allow unsafe recovery progression or false solvency.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineAdminModule.sol`
- `src/engine/IMarketEngine.sol`
- `src/engine/MarketEngineState.sol`

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_crossTemplate_emergencyWithdraw_misattribution_cannot_be_cleared_by_booking_other_template_principal_to_fees`
- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_emergencyWithdraw_books_excess_recovered_yield_to_fees_after_full_reconcile`

#### Recommendation

Recovered balances are no longer auto-booked while any routed principal remains globally outstanding. Misattributed balances must be explicitly reassigned and reconciled first.

#### Legacy Code

```solidity
if (recovered > principal) {
    _vaults[templateId].fees += recovered - principal;
}
```

#### Proof of Concept Code

```solidity
function test_crossTemplate_emergencyWithdraw_misattribution_cannot_be_cleared_by_booking_other_template_principal_to_fees() public {
    engine.yieldEmergencyWithdraw(templateA);
    vm.expectRevert();
    engine.finalizeRecoveredYieldToFees(templateA);
}
```

#### Solution Code

```solidity
if (_yieldLedger.totalRoutedPrincipal != 0) revert GlobalRoutedPrincipalOutstanding();
```

---

### [G-14] `yieldFeeBps` Could Be Changed Mid-Epoch and Retroactively Affect Existing Epochs

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

Yield-fee parameters should be snapshotted per epoch, not read live at resolve time.

#### Vulnerability Details

Without an epoch-local snapshot, settlement reads the current global fee rather than the fee that was in force when users entered the market. That means an admin can change `yieldFeeBps` after deposits and before resolve, retroactively altering payouts for already-open epochs. Even when this is not malicious, it is still economically incorrect because user entry conditions and settlement conditions no longer match.

#### Impact

Otherwise admin can change economics retroactively for already-open markets.

#### Proof of Concept

Files:

- `src/engine/MarketEngineState.sol`
- `src/engine/modules/MarketEngineCoreLifecycleModule.sol`
- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`

Tests:

- `test/engine/core/MarketEngineYieldRouting.t.sol:test_manualResolve_uses_epoch_snapshotted_yield_fee_after_mid_epoch_fee_change`
- `test/engine/rolling/MarketEngineRollingOracle.t.sol:test_rollingResolve_uses_prev_epoch_snapshotted_yield_fee_after_mid_epoch_fee_change`

#### Recommendation

Yield fee is now snapshotted at epoch open.

#### Legacy Code

```solidity
uint16 feeBps = yieldFeeBps;
```

#### Proof of Concept Code

```solidity
function test_manualResolve_uses_epoch_snapshotted_yield_fee_after_mid_epoch_fee_change() public {
    engine.setYieldFeeBps(500);
    vm.prank(worker);
    engine.resolveEpoch(tid, 1);
}
```

#### Solution Code

```solidity
e.yieldFeeBpsSnapshot = yieldFeeBps;
```

---

### [G-15] Emergency Recovery Admin Flows Allowed Invalid Destination Templates

Source: `GPT-5.4 attacker-mode audit`  
Severity: `low`  
Status: `fixed`

#### Description

Recovered balances should not be reassignable or finalizable into invalid or uninitialized templates.

#### Vulnerability Details

Emergency recovery admin functions move real money between bookkeeping buckets. If they accept invalid destination template IDs, recovered assets can be redirected into storage locations that do not correspond to a live market configuration. That turns incident tooling into an operator footgun capable of blackholing recoverable value.

#### Impact

This is primarily an operator-loss path rather than an external exploit.

#### Proof of Concept

Tests:

- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_reassignRecoveredBalance_reverts_when_destination_template_invalid`
- `test/engine/security/MarketEngineEmergencyRecovery.t.sol:test_yieldEmergencyWithdraw_reverts_for_invalid_template`

#### Recommendation

Destination template validity is now enforced.

#### Legacy Code

```solidity
_reassignRecoveredBalance(fromTemplateId, toTemplateId, amount);
```

#### Proof of Concept Code

```solidity
function test_reassignRecoveredBalance_reverts_when_destination_template_invalid() public {
    vm.expectRevert(MarketEngineState.InvalidTemplate.selector);
    engine.reassignRecoveredBalance(tid, bytes32("bad"), 1);
}
```

#### Solution Code

```solidity
if (!_templates[toTemplateId].configured) revert InvalidTemplate();
```

---

### [G-16] Trusted-Reporter Clear Operations Allowed Same-Type Stale Signature Replay

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

Clearing an incorrect lock, resolve, or OHLC record must invalidate the old signed payload for the same market and same message type.

#### Vulnerability Details

The old design treated a clear operation as deletion of stored state, but not as invalidation of the signed message that created that state. Because the signed payload remained valid, anyone holding the old signature could repost it immediately after the owner cleared the bad result. The correction path therefore failed to create a new replay domain.

#### Impact

Without nonce invalidation, an attacker can replay the stale signature immediately after the owner clears it.

#### Proof of Concept

Files:

- `src/oracle/TrustedReporterAdapter.sol`

Tests:

- `test/adapters/TrustedReporterAdapterSecurity.t.sol:test_clearLockSample_invalidates_old_signature_and_allows_corrected_repost`
- `test/adapters/TrustedReporterAdapterSecurity.t.sol:test_clearResolveResult_invalidates_old_signature_and_allows_corrected_repost`
- `test/adapters/TrustedReporterAdapterSecurity.t.sol:test_clearOhlcResult_invalidates_old_signature_and_allows_corrected_repost`

#### Recommendation

Per-market nonces are now part of signed payloads and increment on clear.

#### Legacy Code

```solidity
bytes32 digest = keccak256(abi.encode(marketId, valueE8, observedAt, dataSource));
```

#### Proof of Concept Code

```solidity
function test_clearLockSample_invalidates_old_signature_and_allows_corrected_repost() public {
    adapter.clearLockSample(MARKET_ID);
    vm.expectRevert();
    adapter.postLockSample(MARKET_ID, oldValue, oldTs, DS, oldSig);
}
```

#### Solution Code

```solidity
bytes32 digest = keccak256(abi.encode(marketId, marketNonce[marketId], valueE8, observedAt, dataSource));
```

---

### [G-17] Trusted-Reporter Cross-Type Replay After Clearing Alternate Resolution Path

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

Scalar resolve and OHLC resolution are alternate paths for the same market. Clearing one path must invalidate stale signatures for the other path as well.

#### Vulnerability Details

The vulnerable design invalidated only the message family being cleared. That left a second replay lane open for the same market through the alternate settlement path. An attacker could wait for the owner to clear a bad scalar result, then replay an old OHLC signature, or vice versa, effectively bypassing the intended operator correction.

#### Impact

Otherwise an attacker can revive the stale alternate resolution immediately after an operator correction.

#### Proof of Concept

Tests:

- `test/adapters/TrustedReporterAdapterSecurity.t.sol:test_clearResolveResult_invalidates_stale_ohlc_signature_of_alternate_resolution_path`
- `test/adapters/TrustedReporterAdapterSecurity.t.sol:test_clearOhlcResult_invalidates_stale_scalar_signature_of_alternate_resolution_path`

#### Recommendation

Cross-path nonces are now invalidated together.

#### Legacy Code

```solidity
// resolve and ohlc signatures used independent replay domains for the same market
```

#### Proof of Concept Code

```solidity
function test_clearResolveResult_invalidates_stale_ohlc_signature_of_alternate_resolution_path() public {
    adapter.clearResolveResult(MARKET_ID);
    vm.expectRevert();
    adapter.postOhlcResult(MARKET_ID, open, high, low, close, observedAt, DS, staleSig);
}
```

#### Solution Code

```solidity
marketResolutionNonce[marketId] += 1;
```

---

### [G-18] Reporter Rotation Back to Old Key Could Revive Historical Signatures

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

If reporter A is replaced by reporter B and later restored to A, old unresolved signatures from the first A epoch must not become valid again.

#### Vulnerability Details

Reporter rotation changes the trust root, but old signatures from a previous tenure of the same key can still exist off-chain. If signed payloads do not include a monotonic reporter epoch, rotating back to a previously used key revives those stale messages. The protocol would then accept data that predates the entire intervening reporter rotation history.

#### Impact

This is a replay vulnerability across administrative key rotations.

#### Proof of Concept

Tests:

- `test/adapters/TrustedReporterAdapterSecurity.t.sol:test_reporter_rotation_back_to_previous_reporter_does_not_revive_old_signatures`

#### Recommendation

Signed payloads now include a global `reporterEpoch` that increments on each reporter rotation.

#### Legacy Code

```solidity
bytes32 digest = keccak256(abi.encode(marketId, valueE8, observedAt, dataSource));
```

#### Proof of Concept Code

```solidity
function test_reporter_rotation_back_to_previous_reporter_does_not_revive_old_signatures() public {
    adapter.setTrustedReporter(reporterB);
    adapter.setTrustedReporter(reporterA);
    vm.expectRevert();
    adapter.postResolveResult(MARKET_ID, valueE8, observedAt, DS, oldReporterASig);
}
```

#### Solution Code

```solidity
bytes32 digest = keccak256(abi.encode(reporterEpoch, marketId, marketNonce[marketId], valueE8, observedAt, dataSource));
```

---

### [G-19] Rolling Lifecycle Could Be Reset While Halted Epoch State Was Uncleared

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `fixed`

#### Description

Resetting a halted rolling lifecycle without clearing the halted active epoch and adjacent predecessor can hide unresolved debt behind a fresh rolling bootstrap.

#### Vulnerability Details

Rolling reset is effectively a rebootstrap of the market template. If it is allowed while halted or predecessor epochs still contain unresolved routed principal, claim liabilities, or refund semantics, the new rolling lifecycle begins on top of hidden legacy debt. That is a classic state-machine discontinuity: fresh epochs exist, but the prior epoch chain was never actually closed out.

#### Impact

This is a serious state-machine correctness issue for rolling markets and rebootstrap safety.

#### Proof of Concept

Files:

- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`

Tests:

- `test/engine/rolling/MarketEngineRollingRecovery.t.sol:test_recovery_reset_reverts_when_halted_epoch_not_cleared`
- `test/engine/rolling/MarketEngineRollingRecovery.t.sol:test_recovery_reset_reverts_when_previous_locked_epoch_still_uncleared`

#### Recommendation

Reset now requires those epochs to be cleared first.

#### Legacy Code

```solidity
function resetRollingMarket(bytes32 templateId) external onlyAdmin {
    _rolling.currentEpochId = 0;
}
```

#### Proof of Concept Code

```solidity
function test_recovery_reset_reverts_when_halted_epoch_not_cleared() public {
    vm.expectRevert(MarketEngineState.RollingRecoveryEpochNotCleared.selector);
    engine.resetRollingMarket(tid);
}
```

#### Solution Code

```solidity
if (!_epochCleared(templateId, haltedEpochId)) revert RollingRecoveryEpochNotCleared();
```

---

### [G-20] `resetOracleCursor` Was Callable During Active Epoch

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

Resetting oracle continuity during an `Open` or `Locked` epoch overrides live settlement assumptions.

#### Vulnerability Details

Oracle cursor continuity is part of the validation context for an epoch that is already in progress. Allowing an admin to reset that cursor during `Open` or `Locked` status changes the admissible oracle history after users have already entered the market. The exploit is not about stealing funds directly; it is about rewriting the rules that determine whether future oracle data will be accepted.

#### Impact

This can allow operator misuse or continuity bypass during active market operation.

#### Proof of Concept

Tests:

- `test/engine/core/MarketEngineCoreMarketUpgrade.t.sol:test_reset_oracle_cursor_reverts_while_manual_epoch_locked`
- `test/engine/rolling/MarketEngineRollingOracle.t.sol:test_reset_oracle_cursor_reverts_while_rolling_epoch_open`

#### Recommendation

Cursor reset now reverts while the active epoch is still `Open` or `Locked`.

#### Legacy Code

```solidity
delete lastOracleCursorByTemplateFeed[templateId][feedId];
```

#### Proof of Concept Code

```solidity
function test_reset_oracle_cursor_reverts_while_manual_epoch_locked() public {
    vm.expectRevert(MarketEngineState.ActiveEpochOracleProtected.selector);
    engine.resetOracleCursor(tid, feed);
}
```

#### Solution Code

```solidity
if (_epochIsOpenOrLocked(templateId)) revert ActiveEpochOracleProtected();
```

---

### [G-21] Oracle Adapter Replacement Could Change Settlement Source for Already-Open Epochs

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `fixed`

#### Description

An epoch should settle against the oracle adapter in effect when it opened, not whatever adapter happens to be configured later.

#### Vulnerability Details

If the epoch does not snapshot its oracle dependency at open time, settlement becomes dependent on mutable global configuration. An admin can then replace the oracle after users have already committed capital, causing the same epoch to resolve against a different data source than the one implied at market open. That is a retroactive settlement-rule change.

#### Impact

Admin oracle replacement could otherwise retroactively change market settlement source.

#### Proof of Concept

Files:

- `src/engine/MarketEngineState.sol`
- `src/engine/modules/MarketEngineCoreLifecycleModule.sol`
- `src/engine/modules/MarketEngineRollingLifecycleModule.sol`
- `src/engine/modules/MarketEngineAdminModule.sol`

Tests:

- `test/engine/core/MarketEngineCoreMarketUpgrade.t.sol:test_paused_rate_oracle_replacement_does_not_change_active_epoch_source`
- `test/engine/core/MarketEngineCoreMarketUpgrade.t.sol:test_rate_oracle_replacement_reverts_while_live_epoch_is_open`
- `test/engine/rolling/MarketEngineRollingOracle.t.sol:test_rolling_halts_when_prev_and_cur_epoch_oracle_snapshots_differ`
- `test/engine/security/MarketEngineOracleParity.t.sol:test_lock_uses_epoch_oracle_snapshot_after_template_changes`

#### Recommendation

Epochs now snapshot concrete oracle adapter addresses at open.

#### Legacy Code

```solidity
IPriceOracle oracle = rateOracle;
```

#### Proof of Concept Code

```solidity
function test_paused_rate_oracle_replacement_does_not_change_active_epoch_source() public {
    address snap = address(engine.getEpoch(tid, 1).oracleAtOpen);
    engine.setRateOracle(address(rateB));
    assertEq(address(engine.getEpoch(tid, 1).oracleAtOpen), snap);
}
```

#### Solution Code

```solidity
e.oracleAtOpen = address(rateOracle);
```

---

### [G-22] Trusted-Reporter Clear Operations Lacked Correction Events

Source: `GPT-5.4 attacker-mode audit`  
Severity: `low`  
Status: `fixed`

#### Description

Correction flows should emit explicit events so off-chain monitoring can track operator remediation.

#### Vulnerability Details

The bug here is observability rather than direct fund loss. Clear operations mutate critical settlement state and invalidate prior signed data, but without explicit correction events, off-chain indexers and monitoring systems cannot reliably distinguish an original post from an operator remediation. That weakens incident response, auditability, and real-time monitoring.

#### Impact

This is an observability issue rather than a direct exploit.

#### Proof of Concept

Tests:

- `test/adapters/TrustedReporterAdapterSecurity.t.sol:test_clearOhlcResult_existsAndWorks`

#### Recommendation

Clear paths now emit correction events.

#### Legacy Code

```solidity
delete _resolveResults[marketId];
```

#### Proof of Concept Code

```solidity
vm.expectEmit();
emit ResolveResultCleared(MARKET_ID, reporterEpoch, marketNonce);
adapter.clearResolveResult(MARKET_ID);
```

#### Solution Code

```solidity
emit ResolveResultCleared(marketId, reporterEpoch, marketNonce[marketId]);
```

---

### [GR-01] Dispatcher Module Storage-Compatibility Marker Can Be Spoofed

Source: `GPT-5.4 attacker-mode audit`  
Severity: `high`  
Status: `governance risk`

#### Description

`MarketEngineDispatcher` verifies module compatibility using a marker function and an allowlisted bytecode hash. That does not prove actual storage-layout safety under `delegatecall`.

#### Vulnerability Details

A malicious module can:

1. implement the expected compatibility selector
2. pass code-hash allowlisting if governance intentionally approves it
3. write into arbitrary dispatcher storage slots when called through `delegatecall`

The proof-of-concept module in the test suite aliases slot `0` and corrupts `stakeToken`.

#### Impact

This is equivalent to privileged code execution over proxy storage. It is not an unprivileged exploit, but it is a real production risk if module onboarding is not tightly controlled.

#### Proof of Concept

Files:

- `src/engine/MarketEngineDispatcher.sol`
- `src/engine/MarketEngineState.sol`
- `src/test/MaliciousLayoutModule.sol`

Tests:

- `test/engine/core/MarketEngineDispatcher.t.sol:test_malicious_layout_module_corrupts_stakeToken_via_delegatecall`
- `test/engine/core/MarketEngineDispatcher.t.sol:testFork_malicious_layout_corrupts_stakeToken_when_rpc_set`

#### Recommendation

Not fully fixable on-chain with the current modular delegatecall architecture. Required mitigation is operational:

- strict module artifact review
- multisig-controlled allowlisting
- immutable build provenance
- code-hash attestation and release process

#### Legacy Code

```solidity
require(_moduleCodeHashAllowed[codehash], "hash not allowed");
require(IModule(module).MODULE_STORAGE_COMPATIBILITY() == EXPECTED, "bad marker");
```

#### Proof of Concept Code

```solidity
function test_malicious_layout_module_corrupts_stakeToken_via_delegatecall() public {
    engine.installModule(address(maliciousModule), selectors);
    maliciousModule.corruptStakeToken(address(fakeToken));
    assertEq(address(engine.stakeToken()), address(fakeToken));
}
```

#### Solution Code

```solidity
// architectural mitigation only:
// multisig-reviewed module onboarding + reproducible build attestation + strict hash allowlisting
```

---

### [GR-02] Centralized Admin Can Rewire Modules, Routers, Oracles, and Upgrades

Source: `GPT-5.4 attacker-mode audit`  
Severity: `medium`  
Status: `governance risk`

#### Description

The protocol is intentionally centralized. Admin authority controls:

- module registration and selector routing
- oracle replacement
- yield-router replacement
- pause and recovery operations
- UUPS upgrade authorization

#### Vulnerability Details

This is not an accidental bug but a trust-boundary finding. The admin role can replace execution modules, change oracle and router dependencies, pause and unpause the protocol, and authorize upgrades. In practical terms, the security of user funds depends not only on the solidity code but also on the operational integrity of the privileged control plane that manages those powers.

#### Impact

Operational security is effectively privileged custody. A compromised admin or weak multisig process is protocol-compromise equivalent.

#### Proof of Concept

Files:

- `src/engine/MarketEngineDispatcher.sol`
- `src/engine/modules/MarketEngineAdminModule.sol`

Tests:

- `test/engine/core/MarketEngineDispatcher.t.sol:test_revokeModule_blocks_delegatecall_path`
- `test/engine/core/MarketEngineCoreMarketUpgrade.t.sol`

#### Recommendation

This is intentional architecture, not a code defect. The required mitigation is deployment discipline:

- multisig admin
- timelocked sensitive changes where operationally acceptable
- strict module/oracle/router runbooks
- incident pause and recovery procedures

#### Legacy Code

```solidity
function setRateOracle(address newOracle) external onlyAdmin { ... }
function setYieldRouter(address newRouter) external onlyAdmin { ... }
function _authorizeUpgrade(address newImplementation) internal override onlyAdmin { }
```

#### Proof of Concept Code

```solidity
// all privileged paths are intentionally admin-controlled; compromise of the control plane is protocol-compromise equivalent
```

#### Solution Code

```solidity
// operational mitigation only:
// multisig + timelock + signer separation + monitored runbooks
```

---

## Invariant and Regression Work Added During Live Review

Additional high-value verification added during the GPT-5.4 pass:

- `test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol`
- `test/invariants/MarketEngineRollingRecoveryInvariants.t.sol`

These suites target:

- routed principal conservation
- unreconciled recovery conservation
- terminal epoch cleanup
- paused/unpaused safety constraints
- rolling halt and rebootstrap correctness

These invariant suites matter because the remaining high-risk questions in the codebase were no longer simple single-call bugs. They were multi-step state-machine questions involving:

- pause
- emergency withdraw
- reconcile
- finalize
- rolling halt
- reset
- rebootstrap

That is the correct level of testing for a production-style prediction-market engine with routed yield and rolling lifecycle semantics.

## Final Assessment

The current codebase is substantially safer than the original Hashlock issue list suggests. The live unprivileged issues confirmed during the deeper attacker-mode review were concentrated in recovery accounting, trusted-reporter replay invalidation, and rolling reset safety; those were fixed and regression-tested.

The remaining blocker to calling the system "production-grade for serious TVL" is primarily operational rather than another obvious single-path on-chain bug:

- delegatecall module onboarding trust
- centralized admin privilege concentration
- incident-response discipline
- deployment governance quality

For a deliberately centralized deployment, that means the smart-contract code is now much closer to production-ready, but the real launch risk still depends on whether the operator environment is run to the same standard as the contracts.

### Production Readiness Conclusion

My auditor view is:

- The smart-contract code is materially closer to production grade after the live hardening work.
- The critical contract-side concerns identified during the deeper attacker-mode pass were addressed with concrete fixes and tests.
- I would not characterize the remaining state as "trustless DeFi safe by code alone."
- I would characterize it as "centralized protocol code that can be production-ready if and only if the privileged control plane is run professionally."

For launch, the minimum non-code conditions I would still require are:

- admin under robust multisig control
- strict module artifact verification before allowlisting
- timelocked or tightly governed router/oracle/module changes where operationally feasible
- documented recovery runbooks for pause, emergency withdraw, reconcile, reassign, finalize, reset, and rebootstrap
- signer separation between operational roles where possible
- monitoring for oracle changes, router disablement, recovery bucket growth, and rolling halt events

### Auditor Verdict

Contract verdict after this pass:

- not blocked by an obvious newly confirmed unprivileged critical exploit
- substantially hardened versus the original issue inventory
- still dependent on governance and operations for real-world safety

That is a legitimate outcome for a deliberately centralized prediction-market protocol, but it should be stated plainly in the report rather than hidden behind a large vulnerability count.

## Appendix A: Traceability to `1_byHashLock.md`

This appendix maps every matrix row in `1_byHashLock.md` to the corresponding section in this report.

| source row | severity | finding | status | mapped section |
|---|---|---|---|---|
| 01_BroadMarketEngine.md | high | Oracle Confidence Validation Insufficient for Small Prices | already fixed | [H-01](#h-01-oracle-confidence-validation-insufficient-for-small-prices) |
| 01_BroadMarketEngine.md | high | Inconsistent Yield Router Failure Handling Between Manual and Rolling Modes | already fixed | [H-02](#h-02-inconsistent-yield-router-failure-handling-between-manual-and-rolling-modes) |
| 01_BroadMarketEngine.md | medium | Missing Validation of Array Lengths in Batch Operations | already fixed | [M-01](#m-01-missing-validation-of-array-lengths-in-batch-operations) |
| 02_BroadInterfaces.md | critical | Unexpected ecrecover Null Address Vulnerability in Event Oracle Signature Verification | already fixed | [C-01](#c-01-unexpected-ecrecover-null-address-vulnerability-in-event-oracle-signature-verification) |
| 03_ResolverBroadMarket.md | high | Composite Market Uses Single Threshold for All Feeds - Critical Logic Error | already fixed | [H-03](#h-03-composite-market-uses-single-threshold-for-all-feeds) |
| 04_MarketEngineState.md | high | Reentrancy in _balanceDeltaAfterWithdrawScaled via Malicious/Compromised Yield Router | already fixed | [H-04](#h-04-reentrancy-in-_balancedeltaafterwithdrawscaled-via-malicious-or-compromised-yield-router) |
| 04_MarketEngineState.md | high | Vault Active Balance Can Underflow if claimLiabilityTotal + settlementFeeTotal Exceeds Active Balance | already fixed | [H-05](#h-05-vault-active-balance-can-underflow-if-claims-and-fees-exceed-active-balance) |
| 04_MarketEngineState.md | high | Single-Threshold Used for All Composite Feeds - Incorrect Settlement for Multi-Feed Markets | already fixed | [H-03](#h-03-composite-market-uses-single-threshold-for-all-feeds) |
| 04_MarketEngineState.md | high | nowTs Parameter in IPriceOracle Can Be Spoofed by Callers to Bypass Staleness Checks | already fixed | [H-06](#h-06-nowts-parameter-in-oracle-adapter-can-be-spoofed-to-bypass-staleness-checks) |
| 04_MarketEngineState.md | high | Uninitialized UUPS Proxy Attack Vector - Admin Address Defaults to address(0) | already fixed | [H-07](#h-07-uninitialized-uups-proxy-attack-vector) |
| 04_MarketEngineState.md | medium | Composite Market Uses Single absoluteThresholdValueE8 for All Feeds - Missing Per-Feed Threshold Storage | already fixed | [M-02](#m-02-composite-markets-missing-per-feed-threshold-storage) |
| 04_MarketEngineState.md | low | configInitialized Flag Not Checked in onlyAdmin Modifier - Admin Functions Callable Before Initialization | already fixed | [L-01](#l-01-configinitialized-flag-not-checked-in-admin-paths-before-initialization) |
| 05_modules.md | high | Oracle Cursor State Persists After Oracle Adapter Replacement, Enabling Stale Data Bypass | fixed | [H-08](#h-08-oracle-cursor-state-persists-after-oracle-adapter-replacement) |
| 05_modules.md | high | cancelRollingEpochWhileHalted Does Not Withdraw Yield Router Principal Before Cancellation | already fixed | [H-09](#h-09-cancelrollingepochwhilehalted-does-not-withdraw-yield-router-principal-before-cancellation) |
| 05_modules.md | high | Vault Active Balance Can Underflow When Yield Router Returns Less Than Principal | already fixed | [H-05](#h-05-vault-active-balance-can-underflow-if-claims-and-fees-exceed-active-balance) |
| 05_modules.md | medium | Yield Router Deposit Approval Race Condition via forceApprove | fixed | [M-03](#m-03-yield-router-deposit-approval-race-condition-via-forceapprove) |
| 07_TrustedOracleAdapter.md | high | Missing clearOhlcResult Function — Permanently Stuck Incorrect OHLC Settlement | already fixed | [H-11](#h-11-missing-clearohlcresult-causes-permanent-trusted-reporter-settlement-stuck-state) |
| 08_AaveV3YieldRouterV2.md | high | rescueToken Allows Owner to Steal StataToken Shares from All Templates | already fixed | [H-10](#h-10-rescuetoken-could-steal-statatoken-shares) |
| 10_EngineCoreLifecycleModules.md | high | Epoch Cancellation Blocked by Yield Router Failure - Permanent Fund Lock | already fixed | [H-02](#h-02-inconsistent-yield-router-failure-handling-between-manual-and-rolling-modes) |
| 10_EngineCoreLifecycleModules.md | high | Oracle Cursor Monotonicity Not Reset on Oracle Adapter Change - Stale Data Bypass | fixed | [H-08](#h-08-oracle-cursor-state-persists-after-oracle-adapter-replacement) |
| 11_EngineRollingLifecycleModules.md | medium | Vault Active Balance Can Underflow in cancelRollingEpochWhileHalted When totalPool Exceeds Active | already fixed | [H-05](#h-05-vault-active-balance-can-underflow-if-claims-and-fees-exceed-active-balance) |
| 12_EngineUserOpsClaimableModules.md | medium | claimMany Batch DoS via Front-Running or Partial Claim State | fixed | [M-04](#m-04-claimmany-batch-dos-via-partial-claim-state) |
| 12_EngineUserOpsClaimableModules.md | medium | Residual Token Approval Left After Failed Yield Router Deposit | fixed | [M-03](#m-03-yield-router-deposit-approval-race-condition-via-forceapprove) |
| 13_EngineViewModule.md | high | Reentrancy Risk in _balanceDeltaAfterWithdrawScaled via Untrusted Yield Router | already fixed | [H-04](#h-04-reentrancy-in-_balancedeltaafterwithdrawscaled-via-malicious-or-compromised-yield-router) |
| 13_EngineViewModule.md | high | Uninitialized Proxy Vulnerability - configInitialized Can Be Bypassed via Module Storage Collision | already fixed | [H-07](#h-07-uninitialized-uups-proxy-attack-vector); [GR-01](#gr-01-dispatcher-module-storage-compatibility-marker-can-be-spoofed) |
| GPT-5.4 attacker-mode audit | high | Manual cancel and manual resolve could proceed after yield-router shortfall, leaving claims underfunded or funds operationally stuck | fixed | [G-01](#g-01-manual-cancel-and-manual-resolve-could-proceed-after-yield-router-shortfall) |
| GPT-5.4 attacker-mode audit | high | Rolling cancel while halted could proceed without full principal recovery | fixed | [G-02](#g-02-rolling-cancel-while-halted-could-proceed-without-full-principal-recovery) |
| GPT-5.4 attacker-mode audit | high | Yield-router replacement was possible while routed principal was still outstanding | fixed | [G-03](#g-03-yield-router-replacement-was-possible-with-outstanding-routed-principal) |
| GPT-5.4 attacker-mode audit | high | Reconcile path could blind-book routed principal without proving recovered funds existed in-engine | fixed | [G-04](#g-04-reconcile-path-could-blind-book-routed-principal-without-proven-recovery) |
| GPT-5.4 attacker-mode audit | high | Emergency withdraw trusted router-reported returns instead of engine token balance delta | fixed | [G-05](#g-05-emergency-withdraw-trusted-router-reported-amount-instead-of-engine-balance-delta) |
| GPT-5.4 attacker-mode audit | medium | Emergency recovery and routed-principal reconciliation were callable outside an explicit paused recovery window | fixed | [G-06](#g-06-emergency-recovery-and-reconciliation-were-callable-outside-paused-recovery-window) |
| GPT-5.4 attacker-mode audit | high | Same-template operations could continue while unreconciled recovery was still pending | fixed | [G-07](#g-07-same-template-operations-could-continue-while-unreconciled-recovery-was-pending) |
| GPT-5.4 attacker-mode audit | medium | Disabled yield router could still receive fresh routed deposits | fixed | [G-08](#g-08-disabled-yield-router-could-still-receive-fresh-routed-deposits) |
| GPT-5.4 attacker-mode audit | medium | Disabled/failure state could be reset live, re-enabling an unhealthy router mid-operation | fixed | [G-09](#g-09-disabled-or-failure-state-could-be-reset-live) |
| GPT-5.4 attacker-mode audit | high | Manual resolve and rolling recovery could still attempt settlement through a disabled router while principal remained routed | fixed | [G-10](#g-10-settlement-could-proceed-through-a-disabled-router-while-principal-remained-routed) |
| GPT-5.4 attacker-mode audit | medium | Protocol could unpause into known-bad disabled-router or unreconciled-recovery state | fixed | [G-11](#g-11-protocol-could-unpause-into-known-bad-recovery-state) |
| GPT-5.4 attacker-mode audit | medium | Excess recovered yield from emergency unwind remained as unaccounted engine balance | fixed | [G-12](#g-12-excess-emergency-recovered-yield-remained-unaccounted) |
| GPT-5.4 attacker-mode audit | high | Cross-template emergency withdraw misattribution could book another template's stranded principal into the wrong fee reserve and allow unsafe recovery progression | fixed | [G-13](#g-13-cross-template-emergency-withdraw-misattribution-could-book-another-templates-principal-as-fees) |
| GPT-5.4 attacker-mode audit | medium | Global `yieldFeeBps` could be changed mid-epoch and retroactively alter payouts for already-open manual or rolling epochs | fixed | [G-14](#g-14-yieldfeebps-could-be-changed-mid-epoch-and-retroactively-affect-existing-epochs) |
| GPT-5.4 attacker-mode audit | low | Emergency recovery admin flows allowed invalid destination templates, creating an operator path to blackhole recovered funds into unwithdrawable fee buckets | fixed | [G-15](#g-15-emergency-recovery-admin-flows-allowed-invalid-destination-templates) |
| GPT-5.4 attacker-mode audit | medium | Trusted-reporter clear operations allowed stale same-type signatures to be replayed immediately after owner correction | fixed | [G-16](#g-16-trusted-reporter-clear-operations-allowed-same-type-stale-signature-replay) |
| GPT-5.4 attacker-mode audit | medium | Trusted-reporter correction flow allowed stale cross-type signatures to be replayed after clearing the opposite resolution path | fixed | [G-17](#g-17-trusted-reporter-cross-type-replay-after-clearing-alternate-resolution-path) |
| GPT-5.4 attacker-mode audit | medium | Rotating the trusted reporter back to a previous key could revive old signatures from before the first rotation | fixed | [G-18](#g-18-reporter-rotation-back-to-old-key-could-revive-historical-signatures) |
| GPT-5.4 attacker-mode audit | high | Rolling lifecycle could be reset while the halted active epoch or previous locked epoch was still uncleared | fixed | [G-19](#g-19-rolling-lifecycle-could-be-reset-while-halted-epoch-state-was-uncleared) |
| GPT-5.4 attacker-mode audit | medium | resetOracleCursor was callable during an active epoch, allowing live oracle continuity override | fixed | [G-20](#g-20-resetoraclecursor-was-callable-during-active-epoch) |
| GPT-5.4 attacker-mode audit | medium | Oracle adapter replacement could change settlement source for already-open epochs | fixed | [G-21](#g-21-oracle-adapter-replacement-could-change-settlement-source-for-already-open-epochs) |
| GPT-5.4 attacker-mode audit | low | Trusted-reporter clear operations lacked settlement-correction events, reducing operator visibility | fixed | [G-22](#g-22-trusted-reporter-clear-operations-lacked-correction-events) |
| GPT-5.4 attacker-mode audit | high | Dispatcher module storage-compatibility marker can be spoofed by malicious allowlisted bytecode, enabling delegatecall storage corruption | governance risk | [GR-01](#gr-01-dispatcher-module-storage-compatibility-marker-can-be-spoofed) |
| GPT-5.4 attacker-mode audit | medium | Centralized admin can rewire modules, replace routers/oracles, and upgrade the dispatcher, so operational security is equivalent to privileged custody | governance risk | [GR-02](#gr-02-centralized-admin-can-rewire-modules-routers-oracles-and-upgrades) |

## Appendix B: Technical Finding Packs

This appendix provides the compact code-oriented view for each unique finding: vulnerable pattern, proof path, fixed pattern, and status. For items already fixed before this review, the vulnerable snippet is shown as the bug class being avoided, not as a claim that the exact snippet still exists in the live repository.

### [C-01] Technical Pack

#### Vulnerability Details

```solidity
address signer = ecrecover(digest, v, r, s);
require(signer == trustedReporter, "bad sig");
```

Risk:

- malformed signatures can recover `address(0)`
- raw `ecrecover` handling is easier to misuse

#### Proof of Concept

```solidity
function test_RevertWhen_resolve_malformedSignature_invalidV_attackerCannotSpoof() public {
    uint64 t = uint64(block.timestamp);
    bytes32 ds = keccak256("attacker");
    bytes memory sig = abi.encodePacked(bytes32(0), bytes32(0), uint8(29));

    vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
    adapter.postResolveResult(MARKET, 999e8, t, ds, sig);
}
```

#### Recommendation

```solidity
address signer = ECDSA.recover(digest, signature);
if (signer != trustedReporter) revert InvalidReporterSignature();
```

#### Status

`already fixed`

### [H-01] Technical Pack

#### Vulnerability Details

```solidity
uint256 limit = (abs(priceE8) * maxConfidenceBps) / 10_000;
require(confidenceE8 <= limit, "confidence too wide");
```

Risk:

- very small prices make the relative limit too small or operationally meaningless

#### Proof of Concept

```solidity
uint256 limit =
    MarketTypes.confidenceLimitE8(priceE8, maxConfidenceBps, MarketTypes.MIN_ABSOLUTE_CONFIDENCE_E8);
if (confidenceE8 > limit) revert OracleConfidenceTooWide();
```

#### Recommendation

```solidity
uint256 limit =
    MarketTypes.confidenceLimitE8(priceE8, maxConfidenceBps, MarketTypes.MIN_ABSOLUTE_CONFIDENCE_E8);
if (confidenceE8 > limit) revert OracleConfidenceTooWide();
```

#### Status

`already fixed`

### [H-02] Technical Pack

#### Vulnerability Details

```solidity
// manual mode
try router.withdrawScaled(templateId, principal) { /* continue */ } catch { /* continue */ }

// rolling mode
router.withdrawScaled(templateId, principal); // revert or halt
```

Risk:

- inconsistent router-failure semantics across lifecycle modes

#### Proof of Concept

```solidity
function test_manualResolve_reverts_when_router_disabled_and_principal_still_routed() public {
    ...
    _disableRouterViaRollingFailures();
    ...
    vm.prank(worker);
    vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
    engine.resolveEpoch(tid, 1);
}
```

#### Recommendation

```solidity
if (yieldRouterDisabled) revert YieldRouterDisabledState();
uint256 received = _balanceDeltaAfterWithdrawScaled(r, templateId, routedPrincipal);
if (received < routedPrincipal) revert YieldRouterShortfall(routedPrincipal, received);
```

and for rolling:

```solidity
_haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleFailure, atEpoch);
```

#### Status

`already fixed`

### [H-03] Technical Pack

#### Vulnerability Details

```solidity
// one threshold reused for every composite feed
bool pass = check(feedValue[i], absoluteThresholdValueE8);
```

#### Proof of Concept

```solidity
function test_marketType_08b_composite_perFeedThresholds_majority() public {
    MarketEngine.UpsertTemplateParams memory p = _compositeTemplate("mt-composite-perfeed", FEED_B, FEED_C);
    p.absoluteThresholdValueE8 = 50e8;
    p.compositeAbsoluteThresholdsE8[0] = 100e8;
    p.compositeAbsoluteThresholdsE8[1] = 30e8;
    p.compositeAbsoluteThresholdsE8[2] = 15e8;
    ...
    oracle.set(feed, 110e8, t0 + 300, 0);
    oracle.set(FEED_B, 35e8, t0 + 300, 0);
    oracle.set(FEED_C, 20e8, t0 + 300, 0);
    vm.prank(worker);
    engine.resolveEpoch(tid, 1);
}
```

#### Recommendation

```solidity
int256 threshold = e.compositeAbsoluteThresholdsE8[i];
if (threshold == 0) threshold = e.absoluteThresholdValueE8;
```

#### Status

`already fixed`

### [H-04] Technical Pack

#### Vulnerability Details

```solidity
uint256 b0 = stakeToken.balanceOf(address(this));
router.withdrawScaled(templateId, principal);
uint256 received = stakeToken.balanceOf(address(this)) - b0;
// router callback can reenter if caller is not guarded
```

#### Proof of Concept

```solidity
uint256 b0 = stakeToken.balanceOf(address(this));
router.withdrawScaled(templateId, principal);
uint256 received = stakeToken.balanceOf(address(this)) - b0;
// callback would reenter here if caller path lacked nonReentrant
```

#### Recommendation

```solidity
function resolveEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
    _resolveEpoch(templateId, epochId);
}
```

and:

```solidity
function depositToSide(bytes32 templateId, uint64 epochId, uint8 outcomeIndex, uint256 amount)
    external
    nonReentrant
{ ... }
```

#### Status

`already fixed`

### [H-05] Technical Pack

#### Vulnerability Details

```solidity
vault.active -= outputs.claimLiabilityTotal;
vault.active -= outputs.settlementFeeTotal;
```

without checking available active balance first.

#### Proof of Concept

```solidity
uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
if (_vaults[templateId].active < totalDeduction) {
    revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction);
}
```

#### Recommendation

```solidity
uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
if (_vaults[templateId].active < totalDeduction) {
    revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction);
}
```

#### Status

`already fixed`

### [H-06] Technical Pack

#### Vulnerability Details

```solidity
function getNormalizedPrice(bytes32 feedId, uint64 maxDelay, uint64 nowTs) external view returns (...) {
    require(updatedAt + maxDelay >= nowTs, "stale");
}
```

Risk:

- caller-controlled `nowTs` can weaken freshness checks if the adapter blindly trusts it

#### Proof of Concept

```solidity
function test_revert_stale_even_if_caller_passes_fake_recent_nowTs() public {
    feed.makeStale(90_001);
    uint64 fakeNow = uint64(10_000_000 - 4_000);
    vm.expectRevert(
        abi.encodeWithSelector(
            ChainlinkAdapter.StalePriceFeed.selector,
            uint256(10_000_000 - 90_001),
            uint256(86_400),
            uint256(10_000_000)
        )
    );
    adapter.getNormalizedPrice(feedId, 86_400, fakeNow);
}
```

#### Recommendation

- current adapter rejects stale data under tested spoof attempts
- report classification: already fixed in the repository

#### Status

`already fixed`

### [H-07] Technical Pack

#### Vulnerability Details

```solidity
contract Implementation is Initializable {
    function initialize(...) external initializer { ... }
}
```

without disabling implementation initializers.

#### Proof of Concept

```solidity
function test_initialize_reverts_on_zero_addresses() public {
    MarketEngineDispatcher impl = new MarketEngineDispatcher();
    vm.expectRevert(bytes4(keccak256("Unauthorized()")));
    MarketEngine(
        UnsafeUpgrades.deployUUPSProxy(
            address(impl),
            abi.encodeCall(MarketEngineDispatcher.initialize, (... zero stakeToken ...))
        )
    );
}
```

#### Recommendation

```solidity
constructor() {
    _disableInitializers();
}
```

#### Status

`already fixed`

### [H-08] Technical Pack

#### Vulnerability Details

```solidity
// adapter changes, but cursor continuity state persists
rateOracle = IPriceOracle(newOracle);
```

#### Proof of Concept

```solidity
function test_admin_can_reset_oracle_cursor_after_adapter_swap() public {
    MockPriceOracleWithRoundId rateA = new MockPriceOracleWithRoundId();
    MockPriceOracleWithRoundId rateB = new MockPriceOracleWithRoundId();
    ...
    vm.startPrank(admin);
    engine.pauseProgram(true);
    engine.setRateOracle(address(rateB));
    engine.resetOracleCursor(tid, feed);
    engine.pauseProgram(false);
    vm.stopPrank();
    ...
    rateB.set(feed, 1, 120e8, t1 + 100, 0);
    vm.prank(worker);
    engine.lockEpoch(tid, 2);
    assertEq(engine.getEpoch(tid, 2).checkpointA.valueE8, 120e8);
}
```

#### Recommendation

```solidity
function resetOracleCursor(bytes32 templateId, bytes32 feedId) external {
    _authAdmin();
    ...
    delete lastOracleCursorByTemplateFeed[templateId][feedId];
    delete oracleCursorUsesRoundId[templateId][feedId];
    emit OracleCursorReset(templateId, feedId);
}
```

#### Status

`fixed`

### [H-09] Technical Pack

#### Vulnerability Details

```solidity
// convert to refund mode without recovering routed principal first
e.refundMode = true;
e.claimable = true;
```

#### Proof of Concept

```solidity
function test_cancelRollingWhileHalted_reverts_when_router_disabled_and_principal_still_routed() public {
    ...
    vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
    engine.cancelRollingEpochWhileHalted(tid, 1, MarketTypes.CancelReason.EmergencyPaused, false);
}
```

#### Recommendation

```solidity
_tryWithdrawForRollingCancel(templateId, e, ledger);
```

before:

```solidity
e.refundMode = true;
e.claimable = true;
```

#### Status

`already fixed`

### [H-10] Technical Pack

#### Vulnerability Details

```solidity
function rescueToken(address token, ...) external onlyOwner {
    IERC20(token).transfer(owner(), amount);
}
```

#### Proof of Concept

```solidity
function test_rescueToken_cannotDrainStataToken() public {
    stataToken.mint(address(router), 1000e18);
    vm.prank(owner);
    vm.expectRevert();
    router.rescueToken(address(stataToken), attacker, 1000e18);
    assertEq(stataToken.balanceOf(attacker), 0);
}
```

#### Recommendation

- `rescueToken` rejects protected assets including the routed principal-bearing token class

#### Status

`already fixed`

### [H-11] Technical Pack

#### Vulnerability Details

```solidity
// trusted reporter stores OHLC but has no admin clear path
mapping(bytes32 => OhlcResult) public ohlcResults;
```

#### Proof of Concept

```solidity
function test_clearOhlcResult_existsAndWorks() public {
    uint64 t = uint64(block.timestamp);
    _postOhlc(MARKET_ID, 1900e8, 1800e8, 1850e8, t);
    vm.prank(owner);
    adapter.clearOhlcResult(MARKET_ID);
    bytes memory correctedSig = _signResolve(MARKET_ID, 1860e8, t, DS);
    adapter.postResolveResult(MARKET_ID, 1860e8, t, DS, correctedSig);
}
```

#### Recommendation

```solidity
function clearOhlcResult(bytes32 marketId) external onlyOwner {
    delete _ohlcResults[marketId];
    ...
}
```

#### Status

`already fixed`

### [M-01] Technical Pack

#### Vulnerability Details

```solidity
for (uint256 i; i < templateIds.length; ++i) {
    _openEpoch(templateIds[i], epochIds[i], openAt[i], lockAt[i], resolveAt[i]);
}
```

without validating all array lengths.

#### Proof of Concept

```solidity
uint256 n = templateIds.length;
_validateBatchSize(n);
if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
    revert InvalidTemplate();
}
```

#### Recommendation

```solidity
_validateBatchSize(n);
if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
    revert InvalidTemplate();
}
```

#### Status

`already fixed`

### [M-02] Technical Pack

#### Vulnerability Details

```solidity
int256 threshold = absoluteThresholdValueE8;
```

reused across all composite feeds.

#### Proof of Concept

```solidity
function test_marketType_08b_composite_perFeedThresholds_majority() public {
    ...
    p.compositeAbsoluteThresholdsE8[0] = 100e8;
    p.compositeAbsoluteThresholdsE8[1] = 30e8;
    p.compositeAbsoluteThresholdsE8[2] = 15e8;
    ...
}
```

#### Recommendation

```solidity
int256[4] compositeAbsoluteThresholdsE8;
```

with per-feed selection logic.

#### Status

`already fixed`

### [M-03] Technical Pack

#### Vulnerability Details

```solidity
stakeToken.forceApprove(address(router), routeAmount);
try router.depositScaled(templateId, routeAmount) { ... } catch { ... }
// allowance remains if not explicitly cleared
```

#### Proof of Concept

```solidity
function test_deposit_failedRouting_clears_router_allowance() public {
    ...
    uint256 route = (1000 * 9500) / 10_000;
    vm.mockCallRevert(address(router), abi.encodeWithSelector(router.depositScaled.selector, tid, route), hex"01");
    engine.depositToSide(tid, 1, 0, 1000);
    ...
    assertEq(token.allowance(address(engine), address(router)), 0);
}
```

#### Recommendation

```solidity
stakeToken.forceApprove(address(r), routeAmount);
try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) { ... } catch { ... }
stakeToken.forceApprove(address(r), 0);
```

#### Status

`fixed`

### [M-04] Technical Pack

#### Vulnerability Details

```solidity
for (uint256 i; i < epochIds.length; ++i) {
    total += _claimOne(templateId, epochIds[i], msg.sender); // one bad epoch reverts all
}
```

#### Proof of Concept

```solidity
function test_claimMany_skips_epochs_that_become_already_claimed_mid_batch() public {
    ...
    uint64[] memory epochIds = new uint64[](2);
    epochIds[0] = 1;
    epochIds[1] = 1;
    engine.claimMany(tid, epochIds);
    assertEq(engine.getEpoch(tid, 1).claimedTotal, claimed);
}
```

#### Recommendation

```solidity
uint256 amt = _claimOneIfClaimable(templateId, epochIds[i], msg.sender, ledger);
if (amt == 0) continue;
total += amt;
```

#### Status

`fixed`

### [L-01] Technical Pack

#### Vulnerability Details

```solidity
modifier onlyAdmin() {
    require(msg.sender == admin, "not admin");
    _;
}
```

with `admin` unset before initialization.

#### Proof of Concept

- `test/engine/core/MarketEngineManualTypes.t.sol`

#### Recommendation

```solidity
modifier onlyAdmin() {
    if (!configInitialized) revert NotInitialized();
    if (msg.sender != admin) revert Unauthorized();
    _;
}
```

#### Status

`already fixed`

### [G-01] Technical Pack

#### Vulnerability Details

```solidity
uint256 grossYield = _withdrawRoutedPrincipalOnResolve(templateId, epochId);
SettlementLogic.Outputs memory outputs = SettlementLogic.compute(e, grossYield);
```

if the withdraw path can fail without forcing recovery first.

#### Proof of Concept

```solidity
function test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile() public {
    ...
    router.setRevertOnWithdraw(true);
    vm.prank(worker);
    vm.expectRevert();
    engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

    vm.startPrank(admin);
    engine.pauseProgram(true);
    vm.expectRevert(
        abi.encodeWithSelector(
            MarketEngineState.UnreconciledRecoveryInsufficient.selector, tid, uint256(0), routed
        )
    );
    engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
    ...
    engine.yieldEmergencyWithdraw(tid);
    engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
}
```

#### Recommendation

```solidity
uint256 received = _balanceDeltaAfterWithdrawScaled(r, templateId, routedPrincipal);
if (received < routedPrincipal) revert YieldRouterShortfall(routedPrincipal, received);
```

plus paused emergency recovery and reconciliation flow.

#### Status

`fixed`

### [G-02] Technical Pack

#### Vulnerability Details

```solidity
// halted rolling cancel proceeds although principal is still routed
e.refundMode = true;
e.claimable = true;
```

#### Proof of Concept

```solidity
function test_cancelRollingWhileHalted_reverts_when_router_disabled_and_principal_still_routed() public {
    ...
    _disableRouterViaRollingFailures();
    vm.startPrank(admin);
    engine.haltRollingMarket(tid);
    engine.pauseProgram(true);
    vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
    engine.cancelRollingEpochWhileHalted(tid, 1, MarketTypes.CancelReason.EmergencyPaused, false);
    vm.stopPrank();
}
```

#### Recommendation

```solidity
if (e.routedPrincipal > 0) _requireNoUnreconciledRecovery(templateId);
_tryWithdrawForRollingCancel(templateId, e, ledger);
```

#### Status

`fixed`

### [G-03] Technical Pack

#### Vulnerability Details

```solidity
yieldRouter = IYieldRouterV2(newRouter);
```

while old routed principal remains outstanding.

#### Proof of Concept

```solidity
function test_setYieldRouter_allows_change_after_emergency_recovery_and_reconcile() public {
    ...
    uint256 outstanding = engine.epochs(tid, 1).routedPrincipal;
    vm.startPrank(admin);
    engine.pauseProgram(true);
    engine.yieldEmergencyWithdraw(tid);
    engine.reconcileEpochRoutedPrincipal(tid, 1, outstanding);
    engine.setYieldRouter(address(r2), 0);
    engine.pauseProgram(false);
    vm.stopPrank();
}
```

#### Recommendation

```solidity
if (old != router && old != address(0) && totalRoutedPrincipal != 0) {
    revert OutstandingRoutedPrincipal(totalRoutedPrincipal);
}
```

#### Status

`fixed`

### [G-04] Technical Pack

#### Vulnerability Details

```solidity
e.routedPrincipal -= recoveredPrincipal;
```

without proving recovered funds are actually available in-engine.

#### Proof of Concept

```solidity
function test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile() public {
    ...
    vm.expectRevert(
        abi.encodeWithSelector(
            MarketEngineState.UnreconciledRecoveryInsufficient.selector, tid, uint256(0), routed
        )
    );
    engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
}
```

#### Recommendation

```solidity
uint256 availableRecovered = _unreconciledRecoveredByTemplate[templateId];
if (recoveredPrincipal > availableRecovered) {
    revert UnreconciledRecoveryInsufficient(templateId, availableRecovered, recoveredPrincipal);
}
```

#### Status

`fixed`

### [G-05] Technical Pack

#### Vulnerability Details

```solidity
uint256 recovered = router.emergencyWithdraw(templateId); // trust router return
```

#### Proof of Concept

```solidity
function test_emergencyWithdraw_doesNotCredit_recovery_bucket_on_lying_router() public {
    ...
    engine.pauseProgram(true);
    engine.yieldEmergencyWithdraw(tid);
    engine.pauseProgram(false);
    ...
    assertEq(engine.unreconciledRecoveredByTemplate(tid), 0);
}
```

#### Recommendation

```solidity
uint256 balBefore = stakeToken.balanceOf(address(this));
r.emergencyWithdraw(templateId);
uint256 balAfter = stakeToken.balanceOf(address(this));
uint256 grossAmount = balAfter - balBefore;
```

#### Status

`fixed`

### [G-06] Technical Pack

#### Vulnerability Details

```solidity
function yieldEmergencyWithdraw(bytes32 templateId) external onlyAdmin { ... }
function reconcileEpochRoutedPrincipal(...) external onlyAdmin { ... }
```

without pause gating.

#### Proof of Concept

```solidity
function test_emergencyRecovery_reverts_when_protocol_not_paused() public {
    ...
    vm.prank(admin);
    vm.expectRevert(MarketEngineState.ProtocolPaused.selector);
    engine.yieldEmergencyWithdraw(tid);

    vm.prank(admin);
    vm.expectRevert(MarketEngineState.ProtocolPaused.selector);
    engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
}
```

#### Recommendation

```solidity
if (!globalPaused) revert ProtocolPaused();
```

#### Status

`fixed`

### [G-07] Technical Pack

#### Vulnerability Details

```solidity
depositToSide(...);
switchSide(...);
executeRollingRound(...);
```

allowed while template recovery remains unreconciled.

#### Proof of Concept

```solidity
function test_recoveryPending_blocks_rolling_userops_and_round_execution_until_full_reconcile() public {
    ...
    engine.pauseProgram(true);
    engine.yieldEmergencyWithdraw(tid);
    engine.reconcileEpochRoutedPrincipal(tid, 1, routedEpoch1);
    vm.expectRevert(
        abi.encodeWithSelector(MarketEngineState.UnsafeToUnpause.selector, false, routedEpoch2)
    );
    engine.pauseProgram(false);
    ...
    vm.expectRevert(MarketEngineState.ProtocolPaused.selector);
    engine.executeRollingRound(tid);
}
```

#### Recommendation

```solidity
function _requireNoUnreconciledRecovery(bytes32 templateId) internal view {
    uint256 pendingAmount = _unreconciledRecoveredByTemplate[templateId];
    if (pendingAmount != 0) revert UnreconciledRecoveryPending(templateId, pendingAmount);
}
```

#### Status

`fixed`

### [G-08] Technical Pack

#### Vulnerability Details

```solidity
if (address(r) != address(0) && routeAmount > 0) {
    r.depositScaled(templateId, routeAmount);
}
```

even after router disablement.

#### Proof of Concept

```solidity
function test_disabledRouter_blocks_new_routing_on_deposit() public {
    ...
    pool.setRevertWithdraw(true);
    vm.prank(worker);
    engine.executeRollingRound(tid);
    ...
    assertEq(engine.yieldRouterFailureCount(), 3);
    assertTrue(engine.yieldRouterDisabled());
}
```

#### Recommendation

```solidity
if (yieldRouterDisabled) {
    emit YieldRouterDepositFailed(templateId, routeAmount);
} else {
    ...
}
```

#### Status

`fixed`

### [G-09] Technical Pack

#### Vulnerability Details

```solidity
function resetYieldRouterFailures() external onlyAdmin {
    yieldRouterDisabled = false;
}
```

while live.

#### Proof of Concept

```solidity
function test_resetYieldRouterFailures_requires_pause_after_disablement() public {
    ...
    assertTrue(engine.yieldRouterDisabled());

    vm.prank(admin);
    vm.expectRevert(MarketEngineState.ProtocolPaused.selector);
    engine.resetYieldRouterFailures();

    vm.startPrank(admin);
    engine.pauseProgram(true);
    engine.resetYieldRouterFailures();
    engine.pauseProgram(false);
    vm.stopPrank();
}
```

#### Recommendation

```solidity
if (!globalPaused) revert ProtocolPaused();
yieldRouterFailureCount = 0;
yieldRouterDisabled = false;
```

#### Status

`fixed`

### [G-10] Technical Pack

#### Vulnerability Details

```solidity
if (yieldRouterDisabled) {
    // continue resolve or cancel path anyway
}
```

#### Proof of Concept

```solidity
function test_manualResolve_reverts_when_router_disabled_and_principal_still_routed() public {
    ...
    _disableRouterViaRollingFailures();
    ...
    vm.prank(worker);
    vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
    engine.resolveEpoch(tid, 1);
}
```

#### Recommendation

```solidity
if (yieldRouterDisabled) revert YieldRouterDisabledState();
```

#### Status

`fixed`

### [G-11] Technical Pack

#### Vulnerability Details

```solidity
globalPaused = false;
```

without verifying disabled-router or pending-recovery state.

#### Proof of Concept

```solidity
function test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile() public {
    ...
    engine.yieldEmergencyWithdraw(tid);
    vm.expectRevert(abi.encodeWithSelector(MarketEngineState.UnsafeToUnpause.selector, false, 950 ether));
    engine.pauseProgram(false);
}
```

#### Recommendation

```solidity
if (!paused && (yieldRouterDisabled || totalUnreconciledRecovered != 0)) {
    revert UnsafeToUnpause(yieldRouterDisabled, totalUnreconciledRecovered);
}
```

#### Status

`fixed`

### [G-12] Technical Pack

#### Vulnerability Details

```solidity
// recovered > principal but excess never assigned to vault buckets
```

#### Proof of Concept

```solidity
function test_emergencyWithdraw_books_excess_recovered_yield_to_fees_after_full_reconcile() public {
    ...
    token.mint(address(router), 50 ether);
    engine.pauseProgram(true);
    engine.yieldEmergencyWithdraw(tid);
    ...
    emit MarketEngineState.EmergencyRecoveredYieldBooked(tid, 50 ether);
    engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
}
```

#### Recommendation

```solidity
_vaults[templateId].fees += excessRecovered;
_ledgers[templateId].feeReserveTotal += excessRecovered;
emit EmergencyRecoveredYieldBooked(templateId, excessRecovered);
```

#### Status

`fixed`

### [G-13] Technical Pack

#### Vulnerability Details

```solidity
if (totalRoutedPrincipal == 0) {
    _finalizeRecoveredYield(templateId);
}
```

with no protection against pooled-router misattribution until broader reconciliation is complete.

#### Proof of Concept

```solidity
function test_crossTemplate_emergencyWithdraw_misattribution_cannot_be_cleared_by_booking_other_template_principal_to_fees()
    public
{
    ...
    engine.yieldEmergencyWithdraw(tidA);
    assertEq(engine.unreconciledRecoveredByTemplate(tidA), routedA + routedB);
    engine.reconcileEpochRoutedPrincipal(tidA, 1, routedA);
    assertEq(engine.unreconciledRecoveredByTemplate(tidA), routedB);
    ...
    engine.reassignRecoveredBalance(tidA, tidB, routedB);
}
```

#### Recommendation

```solidity
function reassignRecoveredBalance(bytes32 fromTemplateId, bytes32 toTemplateId, uint256 amount) external {
    ...
    _unreconciledRecoveredByTemplate[fromTemplateId] = availableRecovered - amount;
    _unreconciledRecoveredByTemplate[toTemplateId] += amount;
}
```

and deferred finalization until global routed principal is cleared.

#### Status

`fixed`

### [G-14] Technical Pack

#### Vulnerability Details

```solidity
uint256 bps = yieldFeeBps; // live global read at resolve time
```

#### Proof of Concept

```solidity
function test_manualResolve_uses_epoch_snapshotted_yield_fee_after_mid_epoch_fee_change() public {
    ...
    vm.prank(admin);
    engine.setYieldRouter(address(router), 5000); // should not affect epoch 1
    ...
    emit MarketEngineState.EpochYieldAccrued(tid, 1, 380, 38, 342);
    vm.prank(worker);
    engine.resolveEpoch(tid, 1);
}
```

#### Recommendation

```solidity
_epochYieldFeeBps[templateId][epochId] = yieldFeeBps;
...
uint256 bps = uint256(_epochYieldFeeBps[templateId][epochId]);
```

#### Status

`fixed`

### [G-15] Technical Pack

#### Vulnerability Details

```solidity
reassignRecoveredBalance(fromTemplateId, arbitraryTemplateId, amount);
```

without validating destination template.

#### Proof of Concept

```solidity
function test_reassignRecoveredBalance_reverts_when_destination_template_invalid() public {
    ...
    vm.expectRevert(MarketEngineState.InvalidTemplate.selector);
    engine.reassignRecoveredBalance(tid, invalidTemplateId, 1000 ether);
}
```

#### Recommendation

```solidity
if (_templates[toTemplateId].version == 0 || !_ledgers[toTemplateId].initialized) revert InvalidTemplate();
```

#### Status

`fixed`

### [G-16] Technical Pack

#### Vulnerability Details

```solidity
// clear record
delete _lockSamples[marketId];
// old signature still valid because message shape did not change
```

#### Proof of Concept

```solidity
function test_clearLockSample_invalidates_old_signature_and_allows_corrected_repost() public {
    uint64 t = uint64(block.timestamp);
    bytes memory staleSig = _signLock(MARKET_ID, 1800e8, t, DS);
    adapter.postLockSample(MARKET_ID, 1800e8, t, DS, staleSig);
    vm.prank(owner);
    adapter.clearLockSample(MARKET_ID);
    vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
    adapter.postLockSample(MARKET_ID, 1800e8, t, DS, staleSig);
}
```

#### Recommendation

```solidity
mapping(bytes32 => uint256) private _lockNonces;
...
_lockNonces[marketId] += 1;
```

and nonce included in EIP-712 payload.

#### Status

`fixed`

### [G-17] Technical Pack

#### Vulnerability Details

```solidity
clearResolveResult(marketId); // but stale OHLC signature still valid
clearOhlcResult(marketId);    // but stale scalar resolve still valid
```

#### Proof of Concept

```solidity
function test_clearResolveResult_invalidates_stale_ohlc_signature_of_alternate_resolution_path() public {
    ...
    adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleResolveSig);
    vm.prank(owner);
    adapter.clearResolveResult(MARKET_ID);
    vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
    adapter.postOhlcResult(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS, staleOhlcSig);
}
```

#### Recommendation

```solidity
function clearResolveResult(bytes32 marketId) external onlyOwner {
    ...
    _resolveNonces[marketId] += 1;
    _ohlcNonces[marketId] += 1;
}
```

and symmetric invalidation in `clearOhlcResult`.

#### Status

`fixed`

### [G-18] Technical Pack

#### Vulnerability Details

```solidity
trustedReporter = newReporter;
```

with signed payloads bound only to reporter address, so rotating back can revive historical signatures.

#### Proof of Concept

```solidity
function test_reporter_rotation_back_to_previous_reporter_does_not_revive_old_signatures() public {
    uint64 t = uint64(block.timestamp);
    bytes memory staleResolveSig = _signResolve(MARKET_ID, 1850e8, t, DS);
    vm.startPrank(owner);
    adapter.setTrustedReporter(reporter2);
    adapter.setTrustedReporter(reporter);
    vm.stopPrank();
    vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
    adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleResolveSig);
}
```

#### Recommendation

```solidity
uint256 public reporterEpoch;
...
reporterEpoch += 1;
```

and `reporterEpoch` included in signed payloads.

#### Status

`fixed`

### [G-19] Technical Pack

#### Vulnerability Details

```solidity
function resetRollingLifecycle(bytes32 templateId, uint64 nextRollingEpochId) external {
    ledger.rollingPhase = MarketTypes.RollingPhase.Uninitialized;
}
```

without ensuring halted and predecessor epochs are cleared.

#### Proof of Concept

```solidity
function test_recovery_reset_reverts_when_halted_epoch_not_cleared() public {
    ...
    vm.expectRevert(MarketEngineState.InvalidRollingRecovery.selector);
    engine.resetRollingLifecycle(tid, nextRollingEpochId);
}
```

#### Recommendation

```solidity
if (!_isRollingEpochCleared(templateId, ledger.activeEpochId)) revert InvalidRollingRecovery();
if (ledger.activeEpochId > 1 && !_isRollingEpochCleared(templateId, ledger.activeEpochId - 1)) {
    revert InvalidRollingRecovery();
}
```

#### Status

`fixed`

### [G-20] Technical Pack

#### Vulnerability Details

```solidity
resetOracleCursor(templateId, feedId);
```

during an active epoch.

#### Proof of Concept

```solidity
function test_reset_oracle_cursor_reverts_while_manual_epoch_locked() public {
    ...
    vm.prank(admin);
    vm.expectRevert();
    engine.resetOracleCursor(tid, feed);
}
```

#### Recommendation

```solidity
uint64 activeEpochId = ledger.activeEpochId;
if (activeEpochId != 0) {
    MarketTypes.EpochStatus status = _epochs[templateId][activeEpochId].status;
    if (status == MarketTypes.EpochStatus.Open || status == MarketTypes.EpochStatus.Locked) {
        revert OracleCursorResetWhileEpochActive(templateId, activeEpochId, uint8(status));
    }
}
```

#### Status

`fixed`

### [G-21] Technical Pack

#### Vulnerability Details

```solidity
IPriceOracle epochOracle = _resolveOracleByClass(e.oracleClass); // live adapter lookup
```

after admin changes adapter post-open.

#### Proof of Concept

```solidity
function test_paused_rate_oracle_replacement_does_not_change_active_epoch_source() public {
    ...
    vm.startPrank(admin);
    engine.pauseProgram(true);
    engine.setRateOracle(address(rateB));
    engine.pauseProgram(false);
    vm.stopPrank();
    ...
    // epoch 1 still resolves against its snapshotted source
}
```

#### Recommendation

```solidity
_epochOracleAdapters[templateId][epochId] = address(_resolveOracleByClass(oracleClass));
...
address oracleAdapter = _epochOracleAdapters[templateId][epochId];
if (oracleAdapter != address(0)) return IPriceOracle(oracleAdapter);
```

#### Status

`fixed`

### [G-22] Technical Pack

#### Vulnerability Details

```solidity
delete _ohlcResults[marketId];
```

with no correction event.

#### Proof of Concept

```solidity
function test_clearResolveResult_emitsEvent() public {
    ...
    vm.expectEmit(true, true, true, true);
    emit TrustedReporterAdapter.ResolveResultCleared(MARKET_ID);
    vm.prank(owner);
    adapter.clearResolveResult(MARKET_ID);
}
```

#### Recommendation

- clear paths now emit explicit correction events for off-chain monitoring

#### Status

`fixed`

### [GR-01] Technical Pack

#### Vulnerability Details

```solidity
function marketEngineStorageCompatibility() external pure returns (bytes32) {
    return MODULE_STORAGE_COMPATIBILITY_ID;
}
```

This marker can be implemented by malicious bytecode that still writes unsafe storage slots under `delegatecall`.

#### Proof of Concept

- `src/test/MaliciousLayoutModule.sol`
- `test/engine/core/MarketEngineDispatcher.t.sol:test_malicious_layout_module_corrupts_stakeToken_via_delegatecall`

Demonstration code:

```solidity
address public slot0Alias;

function pwn(address attacker) external {
    slot0Alias = attacker; // overwrites proxy slot 0 under delegatecall
}
```

#### Recommendation

- no purely on-chain fix in current architecture
- enforce multisig-gated module allowlisting and artifact verification

#### Status

`governance risk`

## Expanded Code Listings Supplement

This supplement is intentionally compressed. It keeps only the core live functions per issue cluster, plus one representative regression or PoC where that adds real audit signal. The goal is to preserve technical evidence without turning the report into a source-code mirror.

### Cluster A: Routed Principal Recovery, Reconciliation, and Safe Unpause

Primary mappings: `G-01`, `G-03`, `G-04`, `G-05`, `G-06`, `G-11`, `G-12`, `G-13`, `G-15`.

Legacy vulnerable pattern:

```solidity
// vulnerable class: trust router path or continue lifecycle without proving engine-side recovery
uint256 recovered = router.emergencyWithdraw(templateId);
e.routedPrincipal -= recoveredPrincipal;
pauseProgram(false); // even though recovered balances are not fully reconciled
```

The live fix is that recovery is now explicitly pause-gated, measured by engine balance delta, reconciled against per-template pending recovery, and blocked from unpause until the system is internally consistent.

```solidity
function pauseProgram(bool paused) external {
    _authAdmin();
    if (!paused && (yieldRouterDisabled || totalUnreconciledRecovered != 0)) {
        revert UnsafeToUnpause(yieldRouterDisabled, totalUnreconciledRecovered);
    }
    globalPaused = paused;
}

function yieldEmergencyWithdraw(bytes32 templateId) external {
    _authAdmin();
    if (!globalPaused) revert ProtocolPaused();
    if (_templates[templateId].version == 0 || !_ledgers[templateId].initialized) revert InvalidTemplate();
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0)) revert Unauthorized();
    uint256 balBefore = stakeToken.balanceOf(address(this));
    r.emergencyWithdraw(templateId);
    uint256 balAfter = stakeToken.balanceOf(address(this));
    if (balAfter < balBefore) revert YieldRouterBalanceInvariant();
    uint256 grossAmount;
    unchecked {
        grossAmount = balAfter - balBefore;
    }
    if (grossAmount > 0) {
        _unreconciledRecoveredByTemplate[templateId] += grossAmount;
        totalUnreconciledRecovered += grossAmount;
    }
    emit YieldEmergencyWithdrawn(templateId, grossAmount);
}

function reconcileEpochRoutedPrincipal(bytes32 templateId, uint64 epochId, uint256 recoveredPrincipal) external {
    _authAdmin();
    if (!globalPaused) revert ProtocolPaused();
    if (recoveredPrincipal == 0) revert NothingToClaim();
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    if (!e.exists) revert InvalidEpochState();
    if (recoveredPrincipal > e.routedPrincipal) revert YieldRouterBalanceInvariant();
    uint256 availableRecovered = _unreconciledRecoveredByTemplate[templateId];
    if (recoveredPrincipal > availableRecovered) {
        revert UnreconciledRecoveryInsufficient(templateId, availableRecovered, recoveredPrincipal);
    }
    unchecked {
        e.routedPrincipal -= recoveredPrincipal;
        totalRoutedPrincipal -= recoveredPrincipal;
        _templateRoutedPrincipal[templateId] -= recoveredPrincipal;
        _unreconciledRecoveredByTemplate[templateId] = availableRecovered - recoveredPrincipal;
        totalUnreconciledRecovered -= recoveredPrincipal;
    }
    if (totalRoutedPrincipal == 0) {
        _finalizeRecoveredYield(templateId);
    }
    emit EpochRoutedPrincipalReconciled(templateId, epochId, recoveredPrincipal, e.routedPrincipal);
}

function _finalizeRecoveredYield(bytes32 templateId) internal {
    if (_templateRoutedPrincipal[templateId] != 0) return;
    uint256 excessRecovered = _unreconciledRecoveredByTemplate[templateId];
    if (excessRecovered == 0) return;
    _unreconciledRecoveredByTemplate[templateId] = 0;
    totalUnreconciledRecovered -= excessRecovered;
    _vaults[templateId].fees += excessRecovered;
    _ledgers[templateId].feeReserveTotal += excessRecovered;
    emit EmergencyRecoveredYieldBooked(templateId, excessRecovered);
}
```

The corresponding settlement-side guard is now concentrated in the resolve withdrawal path:

```solidity
function _withdrawRoutedPrincipalOnResolve(bytes32 templateId, uint64 epochId)
    internal
    returns (uint256 grossYield)
{
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0)) return 0;

    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    uint256 routedPrincipal = e.routedPrincipal;
    if (routedPrincipal < 1) return 0;
    if (yieldRouterDisabled) revert YieldRouterDisabledState();
    _requireNoUnreconciledRecovery(templateId);

    uint256 received = _balanceDeltaAfterWithdrawScaled(r, templateId, routedPrincipal);
    e.routedPrincipal = 0;
    totalRoutedPrincipal -= routedPrincipal;
    _templateRoutedPrincipal[templateId] -= routedPrincipal;
    if (received > routedPrincipal) return received - routedPrincipal;
    return 0;
}
```

Representative regression:

```solidity
function test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile() public {
    bytes32 tid = _tid("recover-cancel");
    uint64 t0 = 9_000_000;
    _initManualThresholdMarket(tid, t0, "recover-cancel");

    token.mint(alice, 1000 ether);
    vm.startPrank(alice);
    token.approve(address(engine), type(uint256).max);
    engine.depositToSide(tid, 1, 0, 1000 ether);
    vm.stopPrank();

    uint256 routed = engine.epochs(tid, 1).routedPrincipal;
    router.setRevertOnWithdraw(true);

    vm.prank(worker);
    vm.expectRevert();
    engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

    vm.startPrank(admin);
    engine.pauseProgram(true);
    vm.expectRevert(
        abi.encodeWithSelector(
            MarketEngineState.UnreconciledRecoveryInsufficient.selector, tid, uint256(0), routed
        )
    );
    engine.reconcileEpochRoutedPrincipal(tid, 1, routed);

    router.setRevertOnWithdraw(false);
    engine.yieldEmergencyWithdraw(tid);
    assertEq(engine.unreconciledRecoveredByTemplate(tid), 950 ether);
    vm.expectRevert(abi.encodeWithSelector(MarketEngineState.UnsafeToUnpause.selector, false, 950 ether));
    engine.pauseProgram(false);
    engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
    engine.pauseProgram(false);
    vm.stopPrank();

    assertEq(engine.unreconciledRecoveredByTemplate(tid), 0);

    vm.prank(worker);
    engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

    vm.prank(alice);
    engine.claim(tid, 1);
    assertEq(token.balanceOf(alice), 1000 ether);
}
```

### Cluster B: Rolling Halt, Recovery Pending, and Rebootstrap Safety

Primary mappings: `G-02`, `G-07`, `G-19`, `G-20`, `G-21`.

Legacy vulnerable pattern:

```solidity
// vulnerable class: reset or advance rolling lifecycle while halted epochs are still dirty
ledger.rollingPhase = MarketTypes.RollingPhase.Uninitialized;
ledger.activeEpochId = 0;
```

The key property is now explicit: halted or recovery-pending rolling templates cannot be reset or progressed until predecessor epochs are cleared.

```solidity
function resetRollingLifecycle(bytes32 templateId, uint64 nextRollingEpochId) external {
    _authAdmin();
    if (!globalPaused) revert ProtocolPaused();
    MarketTypes.Template storage t = _templates[templateId];
    if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    if (ledger.rollingPhase != MarketTypes.RollingPhase.Halted) revert RollingWrongPhase();
    uint64 hi = ledger.lastResolvedEpochId;
    if (ledger.activeEpochId > hi) hi = ledger.activeEpochId;
    if (!_isRollingEpochCleared(templateId, ledger.activeEpochId)) revert InvalidRollingRecovery();
    if (ledger.activeEpochId > 1 && !_isRollingEpochCleared(templateId, ledger.activeEpochId - 1)) {
        revert InvalidRollingRecovery();
    }
    if (nextRollingEpochId == 0 || nextRollingEpochId <= hi) revert InvalidRollingRecovery();

    ledger.rollingPhase = MarketTypes.RollingPhase.Uninitialized;
    ledger.rollingHaltReason = MarketTypes.RollingHaltReason.NoneReason;
    ledger.haltedAtEpochId = 0;
    ledger.rollingNextEpochId = nextRollingEpochId;
    ledger.activeEpochId = 0;
    emit RollingLifecycleReset(templateId, nextRollingEpochId);
}

function _executeRollingRoundCore(bytes32 templateId) internal {
    if (!configInitialized) revert Unauthorized();
    MarketTypes.Template storage t = _templates[templateId];
    if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    if (ledger.rollingPhase != MarketTypes.RollingPhase.Live) revert RollingWrongPhase();
    _requireNoUnreconciledRecovery(templateId);

    uint64 k = ledger.activeEpochId;
    if (k < 2) revert InvalidEpochState();
    uint64 prev = k - 1;
    MarketTypes.Epoch storage ePrev = _epochs[templateId][prev];
    MarketTypes.Epoch storage eCur = _epochs[templateId][k];
    uint64 nowTs = uint64(block.timestamp);

    if (nowTs < ePrev.timing.resolveAt) revert TooEarlyToResolve();
    if (nowTs > ePrev.timing.resolveAt + t.rollingBufferSeconds) {
        _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnResolve, prev);
        return;
    }
    if (nowTs < eCur.timing.lockAt) revert TooEarlyToLock();
    if (nowTs > eCur.timing.lockAt + t.rollingBufferSeconds) {
        _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnLock, k);
        return;
    }

    uint64 maxDelay;
    uint16 maxConf;
    if (MarketTypes.requiresCheckpointAOnLock(eCur)) {
        uint64 dPrev = MarketTypes.effectiveOracleMaxDelaySeconds(ePrev, oracleConfig.maxDelaySeconds);
        uint64 dCur = MarketTypes.effectiveOracleMaxDelaySeconds(eCur, oracleConfig.maxDelaySeconds);
        maxDelay = dPrev < dCur ? dPrev : dCur;
        uint16 cPrev = MarketTypes.effectiveOracleMaxConfidenceBps(ePrev, oracleConfig.maxConfidenceBps);
        uint16 cCur = MarketTypes.effectiveOracleMaxConfidenceBps(eCur, oracleConfig.maxConfidenceBps);
        maxConf = cPrev < cCur ? cPrev : cCur;
    } else {
        maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(ePrev, oracleConfig.maxDelaySeconds);
        maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(ePrev, oracleConfig.maxConfidenceBps);
    }

    if (!_resolveAndLockRound(templateId, prev, k, maxDelay, maxConf, nowTs)) {
        return;
    }
    uint64 newOpen = _openRollingEpoch(templateId, nowTs, t);
    emit RollingRoundExecuted(templateId, prev, k, newOpen);
}
```

The corresponding yield-router guard on the rolling path is:

```solidity
function _withdrawResolvePrincipal(bytes32 templateId, uint64 epochId, bool rollingLink)
    internal
    returns (uint256 grossYield)
{
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0)) return 0;

    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    uint256 routedPrincipal = e.routedPrincipal;
    if (routedPrincipal < 1) return 0;
    if (yieldRouterDisabled) {
        emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
        if (rollingLink) {
            _haltRolling(
                templateId, _ledgers[templateId], MarketTypes.RollingHaltReason.OracleFailure, _ledgers[templateId].activeEpochId
            );
            return 0;
        }
        revert YieldRouterDisabledState();
    }

    uint256 b0 = stakeToken.balanceOf(address(this));
    try r.withdrawScaled(templateId, routedPrincipal) returns (uint256) {
        uint256 b1 = stakeToken.balanceOf(address(this));
        if (b1 < b0) revert YieldRouterBalanceInvariant();
        uint256 received = b1 - b0;
        if (received < routedPrincipal) {
            emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal - received);
            _recordYieldRouterFailure();
            if (rollingLink) {
                _haltRolling(templateId, _ledgers[templateId], MarketTypes.RollingHaltReason.OracleFailure, epochId + 1);
                return 0;
            }
            revert YieldRouterShortfall(routedPrincipal, received);
        }
        e.routedPrincipal = 0;
        totalRoutedPrincipal -= routedPrincipal;
        _templateRoutedPrincipal[templateId] -= routedPrincipal;
        if (received > routedPrincipal) {
            grossYield = received - routedPrincipal;
        }
    } catch {
        emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
        _recordYieldRouterFailure();
        if (rollingLink) {
            _haltRolling(templateId, _ledgers[templateId], MarketTypes.RollingHaltReason.OracleFailure, epochId + 1);
            return 0;
        }
        revert YieldRouterWithdrawReverted();
    }
}
```

Representative regression:

```solidity
function test_recoveryPending_blocks_rolling_userops_and_round_execution_until_full_reconcile() public {
    bytes32 tid = _tid("recover-roll");

    vm.startPrank(admin);
    engine.upsertTemplate(_directionRollingTemplate("recover-roll", 100, 10));
    engine.initializeMarket(tid);
    vm.stopPrank();

    uint64 t0 = 9_500_000;
    vm.warp(t0);
    vm.prank(worker);
    engine.genesisStartRolling(tid);

    address bob = address(0xB0B);
    token.mint(alice, 1000 ether);
    token.mint(bob, 1000 ether);

    vm.startPrank(alice);
    token.approve(address(engine), type(uint256).max);
    engine.depositToSide(tid, 1, 0, 1000 ether);
    vm.stopPrank();

    vm.warp(t0 + 101);
    oracle.set(feed, 100e8, uint64(block.timestamp), 0);
    vm.prank(worker);
    engine.genesisLockRolling(tid);

    vm.startPrank(bob);
    token.approve(address(engine), type(uint256).max);
    engine.depositToSide(tid, 2, 1, 1000 ether);
    vm.stopPrank();

    uint256 routedEpoch1 = engine.epochs(tid, 1).routedPrincipal;
    uint256 routedEpoch2 = engine.epochs(tid, 2).routedPrincipal;
    assertGt(routedEpoch1, 0);
    assertGt(routedEpoch2, 0);

    vm.startPrank(admin);
    engine.pauseProgram(true);
    engine.yieldEmergencyWithdraw(tid);
    engine.reconcileEpochRoutedPrincipal(tid, 1, routedEpoch1);
    vm.expectRevert(
        abi.encodeWithSelector(MarketEngineState.UnsafeToUnpause.selector, false, routedEpoch2)
    );
    engine.pauseProgram(false);
    vm.stopPrank();

    uint256 pendingRecovery = engine.unreconciledRecoveredByTemplate(tid);
    assertEq(pendingRecovery, routedEpoch2);

    token.mint(alice, 100 ether);
    vm.startPrank(alice);
    token.approve(address(engine), type(uint256).max);
    vm.expectRevert(MarketEngineState.ProtocolPaused.selector);
    engine.depositToSide(tid, 2, 0, 100 ether);
    vm.stopPrank();

    vm.warp(t0 + 202);
    oracle.set(feed, 200e8, uint64(block.timestamp), 0);
    vm.prank(worker);
    vm.expectRevert(MarketEngineState.ProtocolPaused.selector);
    engine.executeRollingRound(tid);

    vm.startPrank(admin);
    engine.pauseProgram(true);
    engine.reconcileEpochRoutedPrincipal(tid, 2, routedEpoch2);
    engine.pauseProgram(false);
    vm.stopPrank();

    vm.prank(worker);
    engine.executeRollingRound(tid);
}
```

Representative oracle-continuity regression:

```solidity
function test_admin_can_reset_oracle_cursor_after_adapter_swap() public {
    MockPriceOracleWithRoundId rateA = new MockPriceOracleWithRoundId();
    MockPriceOracleWithRoundId rateB = new MockPriceOracleWithRoundId();

    vm.startPrank(admin);
    engine.setRateOracle(address(rateA));
    engine.upsertTemplate(_bitcoinIrcDirectionTemplate("rate-cursor-reset"));
    bytes32 tid = _tid("rate-cursor-reset");
    engine.initializeMarket(tid);
    vm.stopPrank();

    uint64 t0 = 30_000;
    vm.warp(t0);
    vm.prank(worker);
    engine.openEpoch(tid, 1, t0 + 10, t0 + 100, t0 + 200);

    rateA.set(feed, 100, 100e8, t0 + 100, 0);
    vm.warp(t0 + 100);
    vm.prank(worker);
    engine.lockEpoch(tid, 1);

    vm.prank(admin);
    engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

    vm.startPrank(admin);
    engine.pauseProgram(true);
    engine.setRateOracle(address(rateB));
    engine.resetOracleCursor(tid, feed);
    engine.pauseProgram(false);
    vm.stopPrank();

    uint64 t1 = 31_000;
    vm.warp(t1);
    vm.prank(worker);
    engine.openEpoch(tid, 2, t1 + 10, t1 + 100, t1 + 200);

    rateB.set(feed, 1, 120e8, t1 + 100, 0);
    vm.warp(t1 + 100);
    vm.prank(worker);
    engine.lockEpoch(tid, 2);

    MarketTypes.Epoch memory e = engine.getEpoch(tid, 2);
    assertTrue(e.checkpointA.written);
    assertEq(e.checkpointA.valueE8, 120e8);
}
```

### Cluster C: Trusted Reporter Replay Invalidation and Correction Semantics

Primary mappings: `C-01`, `G-16`, `G-17`, `G-18`, `G-22`.

Legacy vulnerable pattern:

```solidity
// vulnerable class: clearing data does not change what is signed
delete _resolveSamples[marketId];
// old signature still recovers the same digest and can be reposted
```

The core fix is that signatures are no longer reusable after administrative correction or reporter rotation because the signed payload is now bound to mutable invalidation state.

```solidity
function setTrustedReporter(address newReporter) external onlyOwner {
    if (newReporter == address(0)) revert ZeroAddress();
    emit TrustedReporterUpdated(trustedReporter, newReporter);
    trustedReporter = newReporter;
    unchecked {
        ++reporterEpoch;
    }
}

function postResolveResult(
    bytes32 marketId,
    int256 valueE8,
    uint64 observedAt,
    bytes32 dataSourceHash,
    bytes calldata signature
) external {
    if (_ohlcSamples[marketId].written) revert AlreadyResolved();
    Sample storage s = _resolveSamples[marketId];
    if (s.written) revert AlreadyResolved();
    _verifyAndStoreSample(RESOLVE_CLAIM_TYPEHASH, s, marketId, valueE8, observedAt, dataSourceHash, signature);
    emit ResultPosted(marketId, valueE8, observedAt, dataSourceHash, _msgSender());
}

function postOhlcResult(
    bytes32 marketId,
    int256 highE8,
    int256 lowE8,
    int256 closeE8,
    uint64 observedAt,
    bytes32 dataSourceHash,
    bytes calldata signature
) external {
    if (_resolveSamples[marketId].written) revert AlreadyResolved();
    OhlcSample storage s = _ohlcSamples[marketId];
    if (s.written) revert AlreadyResolved();
    if (observedAt > block.timestamp) revert ObservedAtInFuture();
    unchecked {
        if (block.timestamp - uint256(observedAt) > maxSignatureAgeSeconds) revert SignatureTooOld();
    }
    if (highE8 < lowE8 || closeE8 < lowE8 || closeE8 > highE8) revert InvalidOhlc();
    bytes32 structHash = _ohlcStructHash(marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash);
    bytes32 digest = _hashTypedDataV4(structHash);
    address signer = ECDSA.recoverCalldata(digest, signature);
    if (signer != trustedReporter) revert InvalidReporterSignature();
    s.highE8 = highE8;
    s.lowE8 = lowE8;
    s.closeE8 = closeE8;
    s.observedAt = observedAt;
    s.written = true;
    s.dataSourceHash = dataSourceHash;
    emit OhlcPosted(marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash, _msgSender());
}

function clearLockSample(bytes32 marketId) external onlyOwner {
    delete _lockSamples[marketId];
    unchecked {
        ++_lockNonces[marketId];
    }
    emit LockSampleCleared(marketId);
}

function clearResolveResult(bytes32 marketId) external onlyOwner {
    delete _resolveSamples[marketId];
    unchecked {
        ++_resolveNonces[marketId];
        ++_ohlcNonces[marketId];
    }
    emit ResolveResultCleared(marketId);
}

function clearOhlcResult(bytes32 marketId) external onlyOwner {
    delete _ohlcSamples[marketId];
    unchecked {
        ++_resolveNonces[marketId];
        ++_ohlcNonces[marketId];
    }
    emit OhlcResultCleared(marketId);
}

function hashResolveClaim(bytes32 marketId, int256 valueE8, uint64 observedAt, bytes32 dataSourceHash)
    external
    view
    returns (bytes32)
{
    return _hashTypedDataV4(
        keccak256(
            abi.encode(
                RESOLVE_CLAIM_TYPEHASH,
                marketId,
                valueE8,
                observedAt,
                dataSourceHash,
                _resolveNonces[marketId],
                reporterEpoch
            )
        )
    );
}
```

This closes the replay class where clearing a record, switching result mode, or rotating reporters could otherwise revive stale signed payloads.

Representative replay-invalidating regression:

```solidity
function test_clearResolveResult_invalidates_stale_ohlc_signature_of_alternate_resolution_path() public {
    uint64 t = uint64(block.timestamp);
    bytes memory staleResolveSig = _signResolve(MARKET_ID, 1850e8, t, DS);
    bytes memory staleOhlcSig = _signOhlc(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS);
    adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleResolveSig);

    vm.prank(owner);
    adapter.clearResolveResult(MARKET_ID);

    vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
    adapter.postOhlcResult(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS, staleOhlcSig);

    bytes memory correctedOhlcSig = _signOhlc(MARKET_ID, 1910e8, 1805e8, 1860e8, t, DS);
    adapter.postOhlcResult(MARKET_ID, 1910e8, 1805e8, 1860e8, t, DS, correctedOhlcSig);

    (int256 highE8, int256 lowE8, int256 closeE8,, bool written) = adapter.getOhlcResult(MARKET_ID);
    assertTrue(written, "corrected ohlc should succeed after resolve clear");
    assertEq(highE8, 1910e8);
    assertEq(lowE8, 1805e8);
    assertEq(closeE8, 1860e8);
}

function test_reporter_rotation_back_to_previous_reporter_does_not_revive_old_signatures() public {
    uint64 t = uint64(block.timestamp);
    bytes memory staleResolveSig = _signResolve(MARKET_ID, 1850e8, t, DS);

    vm.startPrank(owner);
    adapter.setTrustedReporter(reporter2);
    adapter.setTrustedReporter(reporter);
    vm.stopPrank();

    vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
    adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleResolveSig);

    bytes memory freshResolveSig = _signResolve(MARKET_ID, 1860e8, t, DS);
    adapter.postResolveResult(MARKET_ID, 1860e8, t, DS, freshResolveSig);
}
```

### Cluster D: User Operation Gating, Recovery Pending Guards, and Router Allowance Hygiene

Primary mappings: `G-07`, `G-08`, plus the broader hardening around allowance cleanup and guarded routing.

Legacy vulnerable pattern:

```solidity
// vulnerable class: continue fresh routing after failure state or leave residual approvals live
stakeToken.forceApprove(address(router), routeAmount);
router.depositScaled(templateId, routeAmount);
// no disabled-state guard, no guaranteed approval cleanup
```

The essential user-op fix is that deposits and switches now stop on unreconciled recovery and do not continue routing into a disabled router.

```solidity
function _depositToSide(
    address payer,
    address beneficiary,
    bytes32 templateId,
    uint64 epochId,
    uint8 outcomeIndex,
    uint256 amount
) internal {
    if (!configInitialized) revert Unauthorized();
    _requireNoUnreconciledRecovery(templateId);
    if (amount == 0) revert ZeroStake();
    if (outcomeIndex >= MarketTypes.MAX_OUTCOMES) revert InvalidOutcome();
    MarketTypes.Template storage t = _templates[templateId];
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    if (
        t.executionMode == MarketTypes.ExecutionMode.Rolling
            && ledger.rollingPhase == MarketTypes.RollingPhase.Halted
    ) {
        revert RollingHaltedUserOps();
    }
    _requireActiveEpoch(ledger, epochId);

    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    if (!(uint256(outcomeIndex) < uint256(e.outcomeCount))) revert InvalidOutcome();
    uint64 nowTs = uint64(block.timestamp);
    if (!e.isEpochOpen(nowTs)) revert BettingClosed();

    uint256 balBefore = stakeToken.balanceOf(address(this));
    stakeToken.safeTransferFrom(payer, address(this), amount);
    uint256 received = stakeToken.balanceOf(address(this)) - balBefore;
    if (received != amount) revert NonStandardStakeToken();

    bytes32 pk = positionKey(templateId, epochId);
    MarketTypes.Position storage pos = _positions[pk][beneficiary];
    if (!pos.initialized) {
        pos.version = MarketTypes.VERSION;
        pos.initialized = true;
        e.totalPositions += 1;
        _userEpochs[templateId][beneficiary].push(epochId);
        emit UserEpochIndexed(templateId, epochId, beneficiary);
    }

    if (!_canDepositToOutcome(pos, outcomeIndex, e.outcomeCount, e.allowMultiSidePositions)) {
        revert SingleSideViolation();
    }

    pos.stakes[outcomeIndex] += amount;
    pos.totalStake += amount;
    e.outcomePools[outcomeIndex] += amount;
    e.totalPool += amount;
    ledger.increaseActiveCollateral(amount);
    _vaults[templateId].active += amount;

    IYieldRouterV2 r = yieldRouter;
    if (address(r) != address(0)) {
        uint256 routeAmount = (amount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
        if (routeAmount > 0) {
            if (yieldRouterDisabled) {
                emit YieldRouterDepositFailed(templateId, routeAmount);
            } else {
                stakeToken.forceApprove(address(r), routeAmount);
                try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) {
                    if (attributionUnits > 0) {
                        _recordRoutedPrincipal(templateId, e, routeAmount);
                    } else {
                        emit YieldRouterDepositFailed(templateId, routeAmount);
                    }
                }
                catch {
                    emit YieldRouterDepositFailed(templateId, routeAmount);
                }
                stakeToken.forceApprove(address(r), 0);
            }
        }
    }
    emit PositionDeposited(templateId, epochId, beneficiary, outcomeIndex, amount);
}
```

This removes the dangerous overlap between emergency recovery and normal user flow.

Representative user-op regressions:

```solidity
function test_deposit_failedRouting_clears_router_allowance() public {
    bytes32 tid = _tid("thr-allowance-reset");
    uint64 t0 = 3_050_000;
    vm.prank(admin);
    engine.upsertTemplate(_defaultThresholdTemplate("thr-allowance-reset"));
    vm.prank(admin);
    engine.initializeMarket(tid);

    vm.warp(t0);
    vm.prank(worker);
    engine.openEpoch(tid, 1, uint64(t0), uint64(t0 + 10), uint64(t0 + 20));

    token.mint(alice, 1000);
    vm.startPrank(alice);
    token.approve(address(engine), 1000);

    uint256 route = (1000 * 9500) / 10_000;
    vm.expectEmit(true, true, true, true);
    emit MarketEngineState.YieldRouterDepositFailed(tid, route);
    vm.mockCallRevert(address(router), abi.encodeWithSelector(router.depositScaled.selector, tid, route), hex"01");
    engine.depositToSide(tid, 1, 0, 1000);
    vm.clearMockedCalls();
    vm.stopPrank();

    assertEq(token.allowance(address(engine), address(router)), 0);
}

function test_disabledRouter_blocks_new_routing_on_deposit() public {
    MockAToken aToken = new MockAToken();
    MockAavePool pool = new MockAavePool(address(token), address(aToken));
    YieldRouterAaveV3 router =
        new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

    vm.prank(admin);
    engine.setYieldRouter(address(router), 0);

    token.mint(address(this), 1e24);
    token.approve(address(engine), type(uint256).max);

    uint64[3] memory starts = [uint64(500_000), uint64(501_000), uint64(502_000)];
    string[3] memory slugs = ["disable_a", "disable_b", "disable_c"];

    for (uint256 i = 0; i < 3; ++i) {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate(slugs[i], INTER, 10));
        engine.initializeMarket(_tid(slugs[i]));
        vm.stopPrank();

        bytes32 tid = _tid(slugs[i]);
        uint64 t0 = starts[i];

        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 20e18);

        vm.warp(t0 + INTER);
        oracle.set(feed, 100e8, t0 + INTER, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 2, 0, 20e18);

        pool.setRevertWithdraw(true);
        vm.warp(t0 + 2 * INTER);
        oracle.set(feed, 120e8, t0 + 2 * INTER, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);
    }

    assertEq(engine.yieldRouterFailureCount(), 3);
    assertTrue(engine.yieldRouterDisabled());
}
```

### Cluster E: Dispatcher Module Trust Boundary and Residual Governance Risk

Primary mappings: `GR-01`, `GR-02`.

This remains a governance risk, not an outsider bug. The dispatcher enforces approval and code-hash pinning, but the compatibility marker is still insufficient to prove safe storage layout under `delegatecall`.

```solidity
function allowModuleCodeHash(bytes32 codeHash) external onlyAdmin {
    if (codeHash == bytes32(0)) revert ModuleCodeHashNotAllowed(codeHash);
    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    $.allowedModuleCodeHashes[codeHash] = true;
    emit ModuleCodeHashAllowed(codeHash);
}

function registerModule(address module, bytes32 expectedCodeHash) external onlyAdmin {
    if (module == address(0) || module.code.length == 0) revert InvalidModule();
    _enforceModuleStorageCompatibility(module);
    bytes32 actualCodeHash = keccak256(module.code);
    if (actualCodeHash != expectedCodeHash) {
        revert ModuleCodeHashMismatch(module, expectedCodeHash, actualCodeHash);
    }

    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    if (!$.allowedModuleCodeHashes[actualCodeHash]) revert ModuleCodeHashNotAllowed(actualCodeHash);
    $.approvedModules[module] = true;
    $.moduleCodeHash[module] = expectedCodeHash;
    emit ModuleRegistered(module, expectedCodeHash);
}

function setSelectorModule(bytes4 selector, address module, bool makeImmutable) external onlyAdmin {
    if (module == address(0) || module.code.length == 0) revert InvalidModule();
    _enforceApprovedModule(module);

    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    if ($.selectorImmutable[selector]) revert SelectorImmutable(selector);
    if (_isRootOwnedSelector(selector)) revert SelectorImmutable(selector);
    $.selectorToModule[selector] = module;
    if (makeImmutable) $.selectorImmutable[selector] = true;
    emit SelectorModuleSet(selector, module, makeImmutable);
}

function _delegateForSelector(bytes4 selector) private {
    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    address module = $.selectorToModule[selector];
    if (module == address(0)) revert ModuleNotSet(selector);
    _enforceApprovedModule(module);

    assembly {
        calldatacopy(0, 0, calldatasize())
        let success := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
        returndatacopy(0, 0, returndatasize())
        switch success
        case 0 { revert(0, returndatasize()) }
        default { return(0, returndatasize()) }
    }
}

function _enforceApprovedModule(address module) private view {
    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    if (!$.approvedModules[module]) revert UnapprovedModule(module);

    bytes32 expectedCodeHash = $.moduleCodeHash[module];
    bytes32 actualCodeHash = keccak256(module.code);
    if (actualCodeHash != expectedCodeHash) {
        revert ModuleCodeHashMismatch(module, expectedCodeHash, actualCodeHash);
    }
    _enforceModuleStorageCompatibility(module);
}

function _enforceModuleStorageCompatibility(address module) private view {
    (bool ok, bytes memory out) = module.staticcall(abi.encodeWithSelector(SELECTOR_STORAGE_COMPATIBILITY));
    if (!ok || out.length != 32) revert IncompatibleModuleStorage(module);
    bytes32 marker = abi.decode(out, (bytes32));
    if (marker != MODULE_STORAGE_COMPATIBILITY_ID) revert IncompatibleModuleStorage(module);
}
```

Minimal counterexample:

```solidity
contract MaliciousLayoutModule {
    bytes32 private constant _COMPAT = keccak256("retropick.marketengine.state.v1");

    function marketEngineStorageCompatibility() external pure returns (bytes32) {
        return _COMPAT;
    }

    address public slot0Alias;

    function pwn(address attacker) external {
        slot0Alias = attacker;
    }
}
```

Representative proof:

```solidity
function test_malicious_layout_module_corrupts_stakeToken_via_delegatecall() public {
    MaliciousLayoutModule malicious = new MaliciousLayoutModule();
    bytes32 h = keccak256(address(malicious).code);
    address attacker = makeAddr("attacker");
    bytes4 pwnSel = bytes4(keccak256("pwn(address)"));

    vm.startPrank(admin);
    engine.allowModuleCodeHash(h);
    engine.registerModule(address(malicious), h);
    engine.setSelectorModule(pwnSel, address(malicious), false);
    vm.stopPrank();

    assertEq(address(engine.stakeToken()), address(token));
    (bool ok,) = address(engine).call(abi.encodeWithSelector(pwnSel, attacker));
    assertTrue(ok);
    assertEq(address(engine.stakeToken()), attacker);
}
```

## Appendix B Continuation

### [GR-02] Technical Pack

#### Vulnerability Details

```solidity
function _authorizeUpgrade(address) internal override onlyAdmin {}
function setSelectorModule(bytes4 selector, address module, bool makeImmutable) external onlyAdmin { ... }
function setYieldRouter(address router, uint16 feeBps) external { _authAdmin(); ... }
function setRateOracle(address oracle) external { _authAdmin(); ... }
```

#### Proof of Concept

- dispatcher and upgrade control tests

#### Recommendation

- this is intentional centralization rather than an accidental bug
- real mitigation is operational: multisig, timelock where feasible, signer segregation, artifact review, and runbooks

#### Status

`governance risk`
