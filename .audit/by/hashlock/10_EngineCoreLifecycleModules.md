DeFi Prediction Market / Structured Outcome Protocol

RetroPick MarketEngine is a sophisticated prediction market / structured outcome betting protocol built on a UUPS proxy pattern with a dispatcher/module architecture. The system allows users to stake tokens on various market outcomes (Direction, Threshold, RangeClose, Velocity, Ladder, Convergence, Composite, Corridor, Cascade) across discrete epochs. Each market template defines the oracle source, outcome structure, fee parameters, and execution mode (Manual or Rolling). The engine integrates with Chainlink-style price oracles and trusted reporter event oracles, supports yield routing via an external yield router (Aave/ERC4626), and implements a comprehensive settlement logic with pro-rata payout distribution, settlement fees, and a last-claimer remainder rule.

Show less
Access Control
role_based


Privileged Roles
1
admin
2
treasury
3
workerAuthority
4
depositExecutor
5
dispatcher (UUPS proxy)

External Calls
1
IPriceOracle / IPriceOracleWithRoundId
2
IEventOracle
3
IYieldRouterV2
4
IERC20 (stakeToken)

External Systems
1
Chainlink Oracle Network
2
Yield Protocol (Aave/ERC4626)
3
Trusted Reporter / Event Oracle

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


high Severity
4
1

MarketEngineCoreLifecycleModule.sol
Epoch Cancellation Blocked by Yield Router Failure - Permanent Fund Lock
In `cancelEpoch`, if the yield router's `withdrawScaled` call fails (returns false or reverts), the function reverts with `YieldWithdrawFailed`, making it impossible to cancel the epoch. This creates a critical DoS scenario where user funds can be permanently locked if the yield router is paused, compromised, or has a bug. The admin/worker cannot cancel the epoch to refund users, and since the epoch is neither Resolved nor Cancelled, users cannot claim refunds either. The `_tryWithdrawRoutedForCancel` function returns `false` on failure, and `cancelEpoch` then reverts unconditionally.


Hide Details
Impact
User funds can be permanently locked in the protocol if the yield router fails. The epoch cannot be cancelled, users cannot claim refunds, and the protocol has no recovery path. This is especially critical during emergency scenarios (e.g., Aave pause, yield router exploit) where cancellation is most needed.
Scenario
1. Admin sets up a yield router and an epoch with routedPrincipal > 0
2. Yield router becomes paused or compromised (e.g., Aave emergency pause)
3. Admin attempts to call cancelEpoch to protect users
4. _tryWithdrawRoutedForCancel calls r.withdrawScaled which reverts
5. _tryWithdrawRoutedForCancel returns false
6. cancelEpoch reverts with YieldWithdrawFailed
7. Epoch remains in Open/Locked state indefinitely
8. Users cannot claim refunds as epoch is not in Cancelled/Voided state
9. Funds are permanently locked
Affected code
function cancelEpoch(bytes32 templateId, uint64 epochId, MarketTypes.CancelReason reason, bool voided)
external
nonReentrant
{
// ...
IYieldRouterV2 r = yieldRouter;
if (address(r) != address(0) && e.routedPrincipal > 0) {
uint256 routedPrincipal = e.routedPrincipal;
if (routedPrincipal > 0) {
if (!_tryWithdrawRoutedForCancel(r, templateId, epochId, routedPrincipal, ledger)) {
emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
revert YieldWithdrawFailed();
}
}
}
// ...
}
Proposed fix
Add an admin-only emergency override that allows cancellation even when yield withdrawal fails, accepting the principal loss as a protocol risk. The routedPrincipal should be written off and the epoch cancelled:
function cancelEpoch(bytes32 templateId, uint64 epochId, MarketTypes.CancelReason reason, bool voided)
    external
    nonReentrant
{
    _authAdminOrWorker();
    if (globalPaused && msg.sender != admin) revert ProtocolPaused();
    // ... existing checks ...
    
    IYieldRouterV2 r = yieldRouter;
    if (address(r) != address(0) && e.routedPrincipal > 0) {
        uint256 routedPrincipal = e.routedPrincipal;
        if (!_tryWithdrawRoutedForCancel(r, templateId, epochId, routedPrincipal, ledger)) {
            emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
            // Admin can force-cancel even if yield withdrawal fails
            if (msg.sender != admin) revert YieldWithdrawFailed();
            // Write off the routed principal - accept loss
            e.routedPrincipal = 0;
            // Adjust refund liability to only cover what's actually in the vault
        }
    }
    // ... rest of cancellation logic ...
}
2

MarketEngineCoreLifecycleModule.sol
Oracle Cursor Monotonicity Not Reset on Oracle Adapter Change - Stale Data Bypass
The `_enforceAndUpdateOracleCursor` function maintains per-template-per-feed cursors (`lastOracleCursorByTemplateFeed`) tracking the last seen `roundId` and `publishTime`. When the admin replaces an oracle adapter (e.g., `priceOracle`, `rateOracle`), the cursor state from the old adapter persists. A new oracle adapter may have lower roundIds or publishTimes than the old one, causing all reads from the new adapter to revert with `OracleSampleNotMonotonic`. Conversely, if the new adapter has higher roundIds, it could bypass the monotonicity check even if the data is stale relative to the old adapter's last reading. This creates a DoS risk on oracle adapter upgrades and a potential stale data acceptance risk.


Hide Details
Impact
1. DoS: After oracle adapter replacement, all epoch lock/resolve operations for affected templates will revert if the new adapter has lower roundIds or publishTimes than the old adapter's last reading. This permanently blocks epoch resolution until admin manually resets cursors (no reset mechanism exists). 2. Stale data acceptance: If new adapter has higher roundIds, stale data could pass monotonicity checks.
Scenario
1. Template T uses priceOracle adapter A with roundId cursor at 1000, publishTime at T1
2. Admin upgrades priceOracle to adapter B (new Chainlink aggregator)
3. New adapter B starts at roundId 1 (new aggregator)
4. Worker calls lockEpoch for template T
5. _readOracleOrRevert calls adapter B which returns roundId=1
6. _enforceAndUpdateOracleCursor checks: roundId(1) < c.roundId(1000) → reverts OracleSampleNotMonotonic
7. Epoch can never be locked or resolved
8. User funds locked until admin intervention (no admin reset function exists in scope)
Affected code
function _enforceAndUpdateOracleCursor(
bytes32 templateId,
bytes32 feedId,
uint80 oracleRoundId,
uint64 publishTime,
bool supportsRoundId
) internal {
OracleCursor storage c = lastOracleCursorByTemplateFeed[templateId][feedId];
bool priorUsesRoundId = oracleCursorUsesRoundId[templateId][feedId];

// Prevent cursor mode downgrades/upgrades after initialization
if (c.publishTime != 0 && priorUsesRoundId != supportsRoundId) {
revert InvalidOracleFeed();
}
if (supportsRoundId && oracleRoundId < c.roundId) {
revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
}
if (publishTime < c.publishTime) {
revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
}
// ...
}
Proposed fix
Add an admin function to reset oracle cursors for specific template-feed pairs when oracle adapters are legitimately replaced:
function resetOracleCursor(bytes32 templateId, bytes32 feedId) external {
    _authAdmin();
    delete lastOracleCursorByTemplateFeed[templateId][feedId];
    delete oracleCursorUsesRoundId[templateId][feedId];
    emit OracleCursorReset(templateId, feedId);
}
Also emit an event when oracle adapters are changed so off-chain monitoring can detect when cursor resets may be needed.
3

MarketEngineCoreLifecycleModule.sol
Yield Router Withdrawal Failure Silently Skips Principal Recovery - Incorrect Settlement
In `_withdrawRoutedPrincipalOnResolve`, when the yield router's `withdrawScaled` call fails (caught by try/catch), the function emits `YieldRouterWithdrawFailed`, records a failure, and returns 0 (no gross yield). However, the `routedPrincipal` is NOT reset to 0 in the failure path. The epoch resolution continues with `grossYield = 0`, meaning the settlement proceeds as if the principal was never routed. The `effectiveTotalPool` in `SettlementLogic.compute` will be `e.totalPool + 0`, but `e.totalPool` already includes the routed principal (it was deposited into the pool). This means the settlement will try to pay out `totalPool` worth of claims from the vault, but the vault's `active` balance is short by `routedPrincipal` (since it was sent to the yield router and not returned). This can cause `VaultInsufficientActive` reverts or incorrect accounting.


Hide Details
Impact
When yield router withdrawal fails during epoch resolution: 1) The vault's `active` balance is less than `totalPool` by `routedPrincipal`, causing `VaultInsufficientActive` revert in `_applyResolveAccounting`, permanently blocking epoch resolution. 2) User funds are locked as the epoch cannot be resolved or cancelled (cancelEpoch also fails if yield router is down). 3) The protocol enters an unrecoverable state for that epoch.
Scenario
1. Epoch has totalPool = 1000 tokens, routedPrincipal = 800 tokens sent to yield router
2. Vault active balance = 200 tokens (1000 - 800 routed out)
3. Yield router fails (paused/exploited)
4. resolveEpoch called → _withdrawRoutedPrincipalOnResolve catches failure, returns 0
5. grossYield = 0, netYield = 0
6. SettlementLogic.compute uses effectiveTotalPool = 1000 + 0 = 1000
7. Computes claimLiabilityTotal ≈ 1000 (assuming all on winning side)
8. _applyResolveAccounting checks: vault.active(200) < totalDeduction(1000) → VaultInsufficientActive revert
9. Epoch permanently stuck - cannot resolve, cannot cancel (yield router down)
Affected code
function _withdrawRoutedPrincipalOnResolve(bytes32 templateId, uint64 epochId)
internal
returns (uint256 grossYield)
{
// ...
try r.withdrawScaled(templateId, routedPrincipal) returns (uint256) {
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant();
uint256 received = b1 - b0;
e.routedPrincipal = 0;
if (received > routedPrincipal) return received - routedPrincipal;
return 0;
} catch {
emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
_recordYieldRouterFailure();
return 0; // routedPrincipal NOT reset, vault balance not restored
}
}
Proposed fix
When yield router withdrawal fails during resolution, the protocol should either: (a) allow resolution with reduced pool (write off the routed principal), or (b) allow admin to force-resolve with manual accounting. At minimum, the `routedPrincipal` should be tracked as lost:
} catch {
    emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
    _recordYieldRouterFailure();
    // Mark principal as lost - adjust vault accounting
    e.routedPrincipal = 0;
    // Reduce totalPool to reflect actual available funds
    if (e.totalPool >= routedPrincipal) {
        e.totalPool -= routedPrincipal;
        // Also reduce outcomePools proportionally or handle via refund mode
    }
    return 0;
}
Alternatively, trigger refund mode when yield router fails to ensure users can always recover their funds.
4

MarketEngineCoreLifecycleModule.sol
Yield Router Excess Yield on Cancel Bypasses Vault Accounting - Ledger Inconsistency
In `_tryWithdrawRoutedForCancel`, when the yield router returns more than the `routedPrincipal` (i.e., there is yield), the excess is added directly to `_vaults[templateId].fees` and `ledger.feeReserveTotal`. However, this excess yield is NOT added to `_vaults[templateId].active` first before being moved to fees. The vault's `active` balance was already reduced when the principal was routed out (during deposit). When the principal is returned, the vault's `active` balance is not restored before the fee accounting. This creates a discrepancy between `_vaults[templateId].active` and the actual token balance, as the yield tokens are received by the contract but not reflected in `active`.


Hide Details
Impact
The vault's `active` balance becomes inconsistent with the actual token balance held by the contract. The yield tokens are received but only tracked in `fees`, not in `active`. This means `_vaults[templateId].active + _vaults[templateId].claims + _vaults[templateId].fees` will not equal the actual token balance. Over time, this accounting drift can cause `VaultInsufficientActive` reverts for legitimate operations or allow more fees to be withdrawn than should be available.
Scenario
1. Epoch has routedPrincipal = 1000 tokens
2. vault.active = 500 (remaining after routing)
3. Yield router returns 1100 tokens (100 yield)
4. received = 1100, gy = 100
5. vault.fees += 100 → vault.fees = 100
6. ledger.feeReserveTotal += 100
7. BUT vault.active is still 500, not 1500 (500 + 1000 principal returned)
8. The 1000 principal returned is not reflected in vault.active
9. cancelEpoch then does: vault.active -= refundLiability (totalPool)
10. If totalPool > 500, this underflows/reverts even though tokens are available
Affected code
function _tryWithdrawRoutedForCancel(
IYieldRouterV2 r,
bytes32 templateId,
uint64 epochId,
uint256 routedPrincipal,
MarketTypes.Ledger storage ledger
) private returns (bool) {
MarketTypes.Epoch storage ep = _epochs[templateId][epochId];
uint256 b0 = stakeToken.balanceOf(address(this));
try r.withdrawScaled(templateId, routedPrincipal) returns (uint256) {
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant();
uint256 received = b1 - b0;
ep.routedPrincipal = 0;
if (received > routedPrincipal) {
uint256 gy = received - routedPrincipal;
_vaults[templateId].fees += gy; // Added to fees without going through active
ledger.feeReserveTotal += gy;
}
return true;
} catch {
return false;
}
}
Proposed fix
Follow the same pattern as `_applyGrossYield` - first add the full received amount to `active`, then move the yield portion to fees:
if (received > routedPrincipal) {
    uint256 gy = received - routedPrincipal;
    // First add gross yield to active (principal was already accounted for)
    _vaults[templateId].active += gy;
    ledger.activeCollateralTotal += gy;
    // Then move yield fee to fees
    _vaults[templateId].active -= gy;
    _vaults[templateId].fees += gy;
    MarketMath.reserveFeesFromActive(ledger, gy);
}
// Also restore principal to active accounting
_vaults[templateId].active += routedPrincipal;
ledger.activeCollateralTotal += routedPrincipal;

medium Severity
7
1

SettlementLogic.sol
Composite Market Threshold Zero-Value Ambiguity Enables Incorrect Settlement
In `SettlementLogic.compute` for Composite market types, the code checks if ALL `compositeAbsoluteThresholdsE8` entries are zero to determine whether to use the fallback `absoluteThresholdValueE8`. However, a legitimate threshold of exactly zero (e.g., for a market asking 'will price be above/below 0?') would be incorrectly treated as 'unset', causing the system to use `absoluteThresholdValueE8` instead. This is a semantic ambiguity that can lead to incorrect outcome determination. Furthermore, if `absoluteThresholdValueE8` is also zero (which is valid for some market types), the settlement could produce unexpected results.


Hide Details
Impact
For Composite markets where a legitimate threshold of zero is intended for any feed, the settlement will incorrectly use `absoluteThresholdValueE8` as the threshold for ALL feeds instead of the intended per-feed zero threshold. This can cause incorrect winner determination, leading to wrong payouts or refunds. Users who bet on the correct outcome may lose their stake.
Scenario
1. Admin creates a Composite market with 2 feeds:
- Feed 1: threshold = 0 (price above/below zero)
- Feed 2: threshold = 100e8
2. compositeAbsoluteThresholdsE8 = [0, 100e8, 0, 0]
3. allUnset check: compositeAbsoluteThresholdsE8[0] == 0, compositeAbsoluteThresholdsE8[1] != 0 → allUnset = false
4. thresholds[0] = compositeAbsoluteThresholdsE8[0] = 0 (correct)
5. BUT: if both feeds have threshold 0: allUnset = true → uses absoluteThresholdValueE8 for both
6. If absoluteThresholdValueE8 != 0, wrong threshold used → incorrect settlement
Affected code
} else if (e.marketType == MarketTypes.MarketType.Composite) {
int256[4] memory thresholds;
bool allUnset = true;
for (uint256 i = 0; i < e.compositeFeedCount; i++) {
if (e.compositeAbsoluteThresholdsE8[i] != 0) allUnset = false;
}
for (uint256 i = 0; i < e.compositeFeedCount; i++) {
thresholds[i] = allUnset ? e.absoluteThresholdValueE8 : e.compositeAbsoluteThresholdsE8[i];
}
// ...
}
Proposed fix
Use an explicit 'set' flag or sentinel value instead of zero-check. Consider using a separate boolean array to indicate which thresholds are explicitly set:
// In Template/Epoch struct, add:
bool[4] compositeThresholdsExplicitlySet;

// In SettlementLogic.compute:
for (uint256 i = 0; i < e.compositeFeedCount; i++) {
    thresholds[i] = e.compositeThresholdsExplicitlySet[i] 
        ? e.compositeAbsoluteThresholdsE8[i] 
        : e.absoluteThresholdValueE8;
}
Alternatively, document clearly that zero thresholds are not supported for Composite markets and add validation in `upsertTemplate` to reject zero composite thresholds.
2

MarketEngineCoreLifecycleModule.sol
Oracle Fallback Path Allows Mode Downgrade on First Read - Monotonicity Bypass
In `_readOracleOrRevert`, the function first tries `getNormalizedPriceWithRoundId` (roundId-aware path). If this reverts, it falls back to `getNormalizedPrice` (publishTime-only path). The `_enforceAndUpdateOracleCursor` is called with `supportsRoundId=true` on success and `supportsRoundId=false` on fallback. The cursor mode switch prevention only applies when `c.publishTime != 0` (i.e., after the first read). On the FIRST read for a template-feed pair, if the roundId path succeeds and sets `oracleCursorUsesRoundId=true`, subsequent reads that fall back to the publishTime path will be rejected with `InvalidOracleFeed`. However, if the FIRST read uses the fallback path (publishTime-only), subsequent reads using the roundId path will also be rejected. This creates a permanent lock-in to whichever path was used first, which may not be the intended behavior if the oracle adapter is upgraded.


Hide Details
Impact
If the oracle adapter temporarily fails to support `getNormalizedPriceWithRoundId` (e.g., due to a transient error or interface mismatch) on the first read for a template-feed pair, the cursor is permanently set to publishTime-only mode. Future reads using the roundId path will revert with `InvalidOracleFeed`, potentially blocking epoch resolution. Conversely, a transient success on the first read locks the template into roundId mode, blocking fallback usage.
Scenario
1. New template T created with Chainlink oracle feed F
2. First lockEpoch call: getNormalizedPriceWithRoundId transiently reverts (e.g., gas issue)
3. Fallback path used: oracleCursorUsesRoundId[T][F] = false, cursor set with publishTime
4. Oracle adapter fixed, now supports getNormalizedPriceWithRoundId
5. resolveEpoch called: getNormalizedPriceWithRoundId succeeds, returns roundId
6. _enforceAndUpdateOracleCursor: c.publishTime != 0, priorUsesRoundId=false, supportsRoundId=true → revert InvalidOracleFeed
7. Epoch cannot be resolved
Affected code
function _readOracleOrRevert(
bytes32 templateId,
MarketTypes.OracleClass oracleClass,
bytes32 feedId,
uint64 maxDelay,
uint64 nowTs
)
internal
returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId)
{
IPriceOracleWithRoundId oracle = IPriceOracleWithRoundId(address(_resolveOracleByClass(oracleClass)));
try oracle
.getNormalizedPriceWithRoundId(feedId, maxDelay, nowTs) returns (
uint80 rid, int256 p, uint64 pt, uint256 c
) {
_enforceAndUpdateOracleCursor(templateId, feedId, rid, pt, true);
return (p, pt, c, rid);
} catch {
(priceE8, publishTime, confidenceE8) =
_resolveOracleByClass(oracleClass).getNormalizedPrice(feedId, maxDelay, nowTs);
_enforceAndUpdateOracleCursor(templateId, feedId, 0, publishTime, false);
return (priceE8, publishTime, confidenceE8, 0);
}
}
Proposed fix
Consider allowing mode upgrades (publishTime → roundId) but not downgrades (roundId → publishTime), as roundId provides stronger monotonicity guarantees. Alternatively, make the fallback path only used when the oracle genuinely doesn't implement the roundId interface (check via ERC165 or try/catch on a view call during registration):
// Only lock into publishTime mode if roundId interface is definitively not supported
// Use a separate flag set during oracle registration rather than first-read detection
3

MarketEngineCoreLifecycleModule.sol
ReentrancyGuardTransient Incompatibility with Delegatecall Architecture
The `MarketEngineCoreLifecycleModule` inherits from `ReentrancyGuardTransient` (OpenZeppelin's transient storage-based reentrancy guard). When this module is called via `delegatecall` from the dispatcher proxy, the transient storage slot used by `ReentrancyGuardTransient` is accessed in the context of the PROXY's storage, not the module's storage. This is correct behavior for transient storage (it's per-transaction, per-address). However, if multiple modules use `ReentrancyGuardTransient` and they share the same transient storage slot (which they will, since the slot is derived from a constant in the OpenZeppelin implementation), a `nonReentrant` call to one module will block `nonReentrant` calls to ALL other modules within the same transaction. This could cause unexpected reverts when legitimate cross-module calls are made within a single transaction.


Hide Details
Impact
If the dispatcher routes multiple `nonReentrant` function calls within a single transaction (e.g., via multicall or batch operations), the transient storage reentrancy guard will block the second call even if it's a legitimate non-reentrant operation. This could cause DoS for batch operations that include multiple nonReentrant functions. Additionally, if the guard is set in one module's context and another module checks it, the behavior may be unexpected.
Scenario
1. User calls a multicall function that batches: resolveEpoch(T1, E1) + resolveEpoch(T2, E2)
2. First resolveEpoch sets transient storage REENTRANCY_GUARD_SLOT = ENTERED
3. First resolveEpoch completes, sets REENTRANCY_GUARD_SLOT = NOT_ENTERED
4. Second resolveEpoch proceeds normally (transient storage reset after first call)
5. Actually this works correctly for sequential calls
6. BUT: if resolveEpoch internally calls another nonReentrant function via delegatecall, it would revert
7. More critically: if the dispatcher itself has a nonReentrant guard sharing the same slot, conflicts arise
Affected code
contract MarketEngineCoreLifecycleModule is MarketEngineState, ReentrancyGuardTransient {
// ...
function resolveEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
// ...
}

function cancelEpoch(...) external nonReentrant {
// ...
}
}
Proposed fix
Verify that the transient storage slot used by `ReentrancyGuardTransient` does not conflict across modules when called via delegatecall. Consider using a module-specific slot or ensuring the dispatcher's reentrancy guard uses a different slot than the modules'. Document the interaction between the dispatcher's reentrancy protection and module-level guards:
// Use a module-specific reentrancy guard slot
abstract contract ModuleReentrancyGuard {
    bytes32 private constant SLOT = keccak256("retropick.lifecycle.module.reentrancy");
    // ...
}
4

MarketEngineCoreLifecycleModule.sol
Worker Authority Can Open/Lock/Resolve Epochs When Protocol is Paused
The `globalPaused` check in `openEpoch`, `lockEpoch`, `lockEpochsBatch`, `openEpochsBatch` reverts for ALL callers when paused. However, `resolveEpoch` and `resolveEpochsBatch` also check `globalPaused` and revert for all callers including admin. The `cancelEpoch` function has a special carve-out: `if (globalPaused && msg.sender != admin) revert ProtocolPaused()` - allowing admin to cancel when paused. But `resolveEpoch` does NOT have this carve-out, meaning admin cannot resolve epochs when the protocol is paused. This asymmetry means that during a pause, epochs can be cancelled by admin but not resolved, which may not be the intended behavior for emergency scenarios where resolution is needed to unlock user funds.


Hide Details
Impact
During a protocol pause, admin can cancel epochs (triggering refunds) but cannot resolve epochs (triggering payouts). If an epoch has already been locked and the oracle data is available, admin cannot resolve it to pay winners - they can only cancel it (forcing refunds). This could be used to deny winners their payouts by pausing the protocol and cancelling instead of resolving. It also means legitimate resolution is blocked during pauses even when it would be safe.
Scenario
1. Epoch is in Locked state, oracle data available, winners determined
2. Admin pauses protocol (globalPaused = true)
3. Admin calls resolveEpoch → reverts ProtocolPaused
4. Admin calls cancelEpoch → succeeds (admin carve-out)
5. Winners receive refunds instead of their winning payouts
6. Admin can selectively cancel winning epochs while paused
Affected code
function resolveEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
_authAdminOrWorker();
if (globalPaused) revert ProtocolPaused(); // No admin carve-out
_resolveEpoch(templateId, epochId);
}

// vs cancelEpoch:
function cancelEpoch(...) external nonReentrant {
_authAdminOrWorker();
if (globalPaused && msg.sender != admin) revert ProtocolPaused(); // Admin carve-out
// ...
}
Proposed fix
Add admin carve-out to resolveEpoch and resolveEpochsBatch, consistent with cancelEpoch:
function resolveEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
    _authAdminOrWorker();
    if (globalPaused && msg.sender != admin) revert ProtocolPaused();
    _resolveEpoch(templateId, epochId);
}

function resolveEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external nonReentrant {
    _authAdminOrWorker();
    if (globalPaused && msg.sender != admin) revert ProtocolPaused();
    // ...
}
5

MarketTypes.sol
Velocity Market Checkpoint B Monotonicity Not Enforced Against Checkpoint A
For Velocity markets, `validateCheckpointBPublishTime` checks monotonicity of checkpoint B's publishTime against checkpoint A's publishTime only if `e.checkpointA.written`. For Velocity markets, checkpoint A IS written at lock time (since `requiresCheckpointAOnLock` returns true for Velocity). However, the monotonicity check only ensures `publishTime >= checkpointA.publishTime`, not that the price data is from a LATER oracle round. If the oracle returns the same publishTime for both checkpoint A and B (e.g., the oracle hasn't updated between lock and resolve), the velocity calculation would use the same price for both checkpoints, resulting in zero velocity and potentially incorrect outcome determination.


Hide Details
Impact
For Velocity markets, if the oracle publishTime hasn't changed between lock and resolve (same oracle round used), checkpoint B will have the same price as checkpoint A. The velocity calculation will show zero movement, potentially causing incorrect outcome determination. Users who bet on price movement will lose their stake even if the price actually moved (but the oracle hasn't updated).
Scenario
1. Velocity market with 1-hour epoch
2. lockEpoch called: oracle returns price=100, publishTime=T1, roundId=500
3. resolveEpoch called 1 hour later: oracle still returns publishTime=T1 (no update)
4. validateCheckpointBPublishTime: publishTime(T1) >= checkpointA.publishTime(T1) → valid
5. checkpointB.valueE8 = 100 (same as checkpointA)
6. Velocity = 0, outcome determined by zero-velocity bucket
7. Users who bet on price increase/decrease lose despite oracle staleness
Affected code
function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
internal
view
returns (bool)
{
if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
return true; // Allows publishTime == checkpointA.publishTime
}
Proposed fix
For Velocity markets, enforce strict monotonicity (publishTime > checkpointA.publishTime) to ensure the oracle has actually updated:
function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
    internal
    view
    returns (bool)
{
    if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
    if (e.checkpointA.written) {
        // For velocity markets, require strict monotonicity
        if (e.marketType == MarketType.Velocity) {
            if (publishTime <= e.checkpointA.publishTime) return false;
        } else {
            if (publishTime < e.checkpointA.publishTime) return false;
        }
    }
    return true;
}
6

MarketEngineCoreLifecycleModule.sol
Convergence Market Checkpoint B_B Not Validated for Monotonicity Against Checkpoint A_B
For Convergence markets, checkpoint A_B is captured at lock time (second feed price at lock) and checkpoint B_B is captured at resolve time (second feed price at resolve). The `_resolveConvergenceCheckpointB` function reads the second feed and stores it as `checkpointB_B`, but does NOT validate that `checkpointB_B.publishTime >= checkpointA_B.publishTime`. The main checkpoint B is validated against checkpoint A via `validateCheckpointBPublishTime`, but the secondary feed's checkpoint B is not validated for monotonicity against the secondary feed's checkpoint A. This means the second feed could use a stale price from before the lock time.


Hide Details
Impact
For Convergence markets, the second feed's resolve-time price could be from before the lock time, making the convergence calculation use a price that predates the lock. This could cause incorrect convergence/divergence determination, leading to wrong winner selection. Users who bet on the correct outcome could lose their stake.
Scenario
1. Convergence market with feeds F1 and F2
2. lockEpoch: F1 price at T1=1000, F2 price at T2=1000 (both at same time)
3. resolveEpoch: F1 price at T3=2000 (fresh), F2 oracle hasn't updated, returns T2=1000
4. _resolveConvergenceCheckpointB: t2=1000, no check against checkpointA_B.publishTime=1000
5. checkpointB_B uses same price as checkpointA_B (no movement on F2)
6. Convergence calculation uses stale F2 data
7. Incorrect outcome determination
Affected code
function _resolveConvergenceCheckpointB(
bytes32 templateId,
MarketTypes.Epoch storage e,
uint64 maxDelay,
uint16 maxConf,
uint64 nowTs
) internal {
(int256 p2, uint64 t2, uint256 c2,) = _readOracleOrRevert(templateId, e.oracleClass, e.oracleFeedIdB, maxDelay, nowTs);
_enforceConfidence(p2, c2, maxConf);
e.checkpointB_B =
MarketTypes.OracleCheckpoint({valueE8: p2, publishTime: t2, confidenceE8: _toConf128(c2), written: true});
// No check: t2 >= e.checkpointA_B.publishTime
}
Proposed fix
Add monotonicity validation for the secondary feed's checkpoint B against checkpoint A_B:
function _resolveConvergenceCheckpointB(
    bytes32 templateId,
    MarketTypes.Epoch storage e,
    uint64 maxDelay,
    uint16 maxConf,
    uint64 nowTs
) internal {
    (int256 p2, uint64 t2, uint256 c2,) = _readOracleOrRevert(templateId, e.oracleClass, e.oracleFeedIdB, maxDelay, nowTs);
    _enforceConfidence(p2, c2, maxConf);
    // Validate monotonicity against checkpoint A_B
    if (e.checkpointA_B.written && t2 < e.checkpointA_B.publishTime) {
        revert InvalidOraclePublishTime();
    }
    e.checkpointB_B = MarketTypes.OracleCheckpoint({valueE8: p2, publishTime: t2, confidenceE8: _toConf128(c2), written: true});
}
7

MarketEngineCoreLifecycleModule.sol
Composite Market Checkpoint A Not Validated for Monotonicity in resolveCompositeCheckpointB
Similar to the Convergence issue, for Composite markets, `_resolveCompositeCheckpointB` reads prices for all composite feeds and stores them as `compositeCheckpointsB`. However, there is no validation that `compositeCheckpointsB[i].publishTime >= compositeCheckpointsA[i].publishTime`. The oracle cursor monotonicity check in `_enforceAndUpdateOracleCursor` ensures global monotonicity per template-feed pair, but does not specifically enforce that the resolve-time reading is newer than the lock-time reading for the same epoch. If the oracle cursor was updated by another epoch's lock between this epoch's lock and resolve, the cursor could be ahead of this epoch's checkpoint A, but the checkpoint B could still be from before checkpoint A.


Hide Details
Impact
For Composite markets, individual feed checkpoint B prices could be from before the lock time, leading to incorrect composite condition evaluation. This could cause wrong winner determination for Composite markets.
Scenario
1. Composite market with 2 feeds F1, F2
2. lockEpoch: F1 at T1=1000, F2 at T2=1000
3. resolveEpoch: F1 at T3=2000 (fresh), F2 oracle stale, returns T2=1000
4. _resolveCompositeCheckpointB: no check tI >= compositeCheckpointsA[i].publishTime
5. compositeCheckpointsB[1] uses same price as compositeCheckpointsA[1]
6. Composite condition evaluated with stale F2 data
Affected code
function _resolveCompositeCheckpointB(
bytes32 templateId,
MarketTypes.Epoch storage e,
uint64 maxDelay,
uint16 maxConf,
uint64 nowTs
) internal {
for (uint256 i = 0; i < e.compositeFeedCount; i++) {
(int256 pI, uint64 tI, uint256 cI,) =
_readOracleOrRevert(templateId, e.oracleClass, e.compositeFeedIds[i], maxDelay, nowTs);
_enforceConfidence(pI, cI, maxConf);
e.compositeCheckpointsB[i] =
MarketTypes.OracleCheckpoint({valueE8: pI, publishTime: tI, confidenceE8: _toConf128(cI), written: true});
// No check: tI >= e.compositeCheckpointsA[i].publishTime
}
}
Proposed fix
Add per-feed monotonicity validation in `_resolveCompositeCheckpointB`:
for (uint256 i = 0; i < e.compositeFeedCount; i++) {
    (int256 pI, uint64 tI, uint256 cI,) =
        _readOracleOrRevert(templateId, e.oracleClass, e.compositeFeedIds[i], maxDelay, nowTs);
    _enforceConfidence(pI, cI, maxConf);
    // Validate monotonicity against checkpoint A
    if (e.compositeCheckpointsA[i].written && tI < e.compositeCheckpointsA[i].publishTime) {
        revert InvalidOraclePublishTime();
    }
    e.compositeCheckpointsB[i] = MarketTypes.OracleCheckpoint({
        valueE8: pI, publishTime: tI, confidenceE8: _toConf128(cI), written: true
    });
}

low Severity
4
1

MarketEngineCoreLifecycleModule.sol
Missing Validation: openAt Can Be in the Past - Epoch Immediately Bettable Without Notice
In `_openEpoch`, the timing validation checks `lockAt <= nowTs` (reverts if lock time is in the past) and `lockAt - openAt >= MIN_MANUAL_DEPOSIT_WINDOW`, but does NOT check that `openAt >= nowTs` or `openAt >= block.timestamp`. This means an epoch can be opened with `openAt` set to a past timestamp, making the epoch immediately open for betting (or even already past the open window). While this may be intentional for flexibility, it allows the admin/worker to open epochs with retroactive start times, which could be used to manipulate the betting window or create epochs that appear to have been open longer than they actually were.


Hide Details
Impact
Admin/worker can create epochs with retroactive open times, potentially: 1) Reducing the effective betting window without users being aware, 2) Creating epochs where the open window has already partially or fully elapsed, 3) Enabling front-running by opening an epoch with a past openAt after observing market conditions. This is a centralization risk that could disadvantage users.
Scenario
1. Current time: T = 1000
2. Admin calls openEpoch with openAt=500, lockAt=1100, resolveAt=1200
3. Validation passes: lockAt(1100) > nowTs(1000), lockAt-openAt(600) >= 10, etc.
4. Epoch is opened with openAt=500 (500 seconds in the past)
5. Users who check the epoch see openAt=500 and may think they missed the window
6. Or admin opens with openAt=999, lockAt=1010, resolveAt=1020 - only 10 second window
7. Admin already knows oracle price direction before opening
Affected code
function _openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) internal {
if (_templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();
uint64 nowTs = uint64(block.timestamp);
if (lockAt <= nowTs) revert InvalidTiming(); // Only lockAt is checked against nowTs
if (lockAt - openAt < MIN_MANUAL_DEPOSIT_WINDOW) revert InvalidTiming();
if (resolveAt - lockAt < MIN_MANUAL_LOCK_WINDOW) revert InvalidTiming();
if (resolveAt - openAt > MAX_MANUAL_EPOCH_DURATION) revert InvalidTiming();
// openAt can be any past timestamp
// ...
}
Proposed fix
Add a check that `openAt` is not excessively in the past, or require `openAt >= nowTs`:
// Option 1: Require openAt to be current or future
if (openAt < nowTs) revert InvalidTiming();

// Option 2: Allow some grace period for past openAt (e.g., 1 hour)
if (nowTs > openAt && nowTs - openAt > 3600) revert InvalidTiming();
2

MarketMath.sol
Precision Loss in Pro-Rata Payout Calculation Can Systematically Underpay Winners
In `MarketMath.computeClaimPayoutStorage`, the pro-rata entitlement is computed as: `entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool`. The integer division `(userWinningStake_ * distributableLosing) / winningPool` truncates the result. For large winning pools with many small winners, each winner loses a small amount to rounding. The last-claimer remainder rule only helps the LAST claimer - all other claimers systematically receive slightly less than their fair share. The total underpayment accumulates in the claims reserve and is captured by the last claimer, creating an unfair distribution where the last claimer receives a windfall.


Hide Details
Impact
Early claimers systematically receive slightly less than their fair share due to integer division truncation. The last claimer receives a windfall equal to the accumulated rounding dust. While the total payout is correct (no funds lost), the distribution is unfair. For high-frequency markets with many small positions, this could be a meaningful amount. The last-claimer advantage could also be exploited by MEV bots to always be the last claimer.
Scenario
1. Epoch with winningPool = 3, distributableLosing = 10
2. Three winners each with stake = 1
3. Each winner's entitlement = 1 + (1 * 10) / 3 = 1 + 3 = 4 (truncated from 4.33)
4. First two claimers each get 4 tokens
5. Last claimer gets remainingClaimsForEpoch = 12 - 4 - 4 = 4 tokens (same, but could be more)
6. Total paid = 12, but fair share would be 4.33 each
7. In practice with larger numbers, last claimer gets a windfall
Affected code
function computeClaimPayoutStorage(
MarketTypes.Epoch storage epoch,
uint256[8] memory stakes,
uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
// ...
uint256 distributableLosing = _distributableLosingPoolForClaimsStorage(epoch, winningPool);
uint256 entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool;

if (epoch.remainingWinningStake == userWinningStake_) {
payout = remainingClaimsForEpoch;
} else {
payout = entitlement;
}
return (payout, userWinningStake_);
}
Proposed fix
This is an inherent limitation of integer arithmetic. The last-claimer remainder rule is the correct mitigation. Document this behavior clearly. Consider adding a maximum windfall cap for the last claimer to prevent MEV exploitation:
// Cap last-claimer windfall to prevent MEV exploitation
if (epoch.remainingWinningStake == userWinningStake_) {
    uint256 fairEntitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool;
    // Allow up to 2x fair entitlement as windfall cap
    payout = remainingClaimsForEpoch > fairEntitlement * 2 ? fairEntitlement * 2 : remainingClaimsForEpoch;
}
Alternatively, document this as intended behavior and ensure users understand the last-claimer advantage.
3

MarketEngineCoreLifecycleModule.sol
Template Update Can Change Market Type of Active Epoch - Settlement Mismatch
The `upsertTemplate` function allows the admin to update ALL template parameters including `marketType`, `condition`, `thresholdRule`, `outcomeCount`, and oracle parameters. When an epoch is opened, it snapshots template parameters into epoch storage. However, if `upsertTemplate` is called AFTER an epoch is opened but BEFORE it is resolved, the epoch's stored parameters (snapshotted at open time) will be used for settlement. This is correct behavior. BUT: the `_validateTemplate` function is called on the UPDATED template, not the epoch. If the template's `marketType` is changed from Direction to Threshold (for example), future epochs will use the new type, but existing open epochs use the old type. The risk is that the admin can change template parameters in ways that affect the oracle cursor (shared per template-feed pair), potentially invalidating the cursor for existing epochs.


Hide Details
Impact
If admin changes `oracleFeedId` or `oracleClass` in a template while an epoch is active, the oracle cursor (tracked per template-feed pair) may become inconsistent. The active epoch uses the old feedId (snapshotted at open), but the cursor is shared. If the new feedId has a different cursor state, it could cause monotonicity violations when the active epoch tries to read the oracle. This is a lower-severity issue since the epoch uses its own snapshotted feedId, but the cursor sharing creates subtle interactions.
Scenario
1. Template T has oracleFeedId = F1, epoch E1 opened (snapshots F1)
2. Admin calls upsertTemplate changing oracleFeedId to F2
3. Epoch E1 still uses F1 for lock/resolve (correct - snapshotted)
4. Oracle cursor for (T, F1) was set during E1's lock
5. New epoch E2 opened with F2
6. E2 uses F2 for lock/resolve
7. Oracle cursor for (T, F2) starts fresh - no issue here
8. But if admin changes back to F1 for E3, cursor for (T, F1) has old state from E1
Affected code
function upsertTemplate(UpsertTemplateParams calldata p) external {
_authAdmin();
// ... validation ...
bytes32 tid = templateIdFromSlug(p.slug);
MarketTypes.Template storage t = _templates[tid];
// All parameters updated, including marketType, oracleFeedId, etc.
t.marketType = p.marketType;
t.oracleFeedId = p.oracleFeedId;
t.oracleClass = p.oracleClass;
// ...
_validateTemplate(t);
emit TemplateUpserted(...);
}
Proposed fix
Add a check that prevents template updates when there is an active (unresolved) epoch:
function upsertTemplate(UpsertTemplateParams calldata p) external {
    _authAdmin();
    bytes32 tid = templateIdFromSlug(p.slug);
    MarketTypes.Ledger storage ledger = _ledgers[tid];
    // Prevent updates to critical parameters when epoch is active
    if (ledger.initialized && ledger.activeEpochId != ledger.lastResolvedEpochId) {
        // Only allow non-critical updates (e.g., active flag, fees)
        // Revert if trying to change marketType, oracleFeedId, etc.
        revert ActiveEpochExists();
    }
    // ...
}
4

MarketEngineState.sol
Missing Validation: maxOutcomes Can Be Set to 0 - Blocking All Template Creation
The `maxOutcomes` state variable is set during initialization and used in `upsertTemplate` to validate `p.outcomeCount <= maxOutcomes`. If `maxOutcomes` is set to 0 (either by mistake or maliciously), the check `p.outcomeCount == 0 || p.outcomeCount > maxOutcomes` will always revert for any `outcomeCount > 0` (since any positive count > 0 = maxOutcomes). This would permanently block all template creation. While this is an admin configuration issue, there's no validation that `maxOutcomes >= 2` (the minimum for any market type) when it's set.


Hide Details
Impact
If `maxOutcomes` is set to 0 or 1, no templates can be created (all market types require at least 2 outcomes). This would be a DoS on template creation. While recoverable by admin (can update maxOutcomes), it represents a configuration risk.
Scenario
1. Admin initializes protocol with maxOutcomes = 0 (or updates it to 0)
2. Admin calls upsertTemplate with outcomeCount = 2
3. Check: outcomeCount(2) > maxOutcomes(0) → revert TooManyOutcomes
4. No templates can be created
Affected code
// In upsertTemplate:
if (p.outcomeCount == 0 || p.outcomeCount > maxOutcomes) revert TooManyOutcomes();

// maxOutcomes is set during initialization with no minimum validation visible in scope
Proposed fix
Add validation when setting `maxOutcomes` to ensure it's at least 2:
// In the initialization or setter function:
if (maxOutcomes < 2 || maxOutcomes > MarketTypes.MAX_OUTCOMES) revert InvalidTemplate();

gas Severity
2
1

MarketEngineCoreLifecycleModule.sol
Duplicate routedPrincipal Check in cancelEpoch - Dead Code
In `cancelEpoch`, there is a redundant double-check for `routedPrincipal > 0`. The outer condition checks `address(r) != address(0) && e.routedPrincipal > 0`, and then immediately inside that block, there is another `if (routedPrincipal > 0)` check. Since `routedPrincipal` is assigned from `e.routedPrincipal` which was already checked to be > 0 in the outer condition, the inner check is always true and is dead code. This is a minor code quality issue but indicates a copy-paste error.


Hide Details
Impact
No security impact. Dead code that wastes gas and reduces code clarity.
Scenario
The inner `if (routedPrincipal > 0)` is always true because the outer condition already checks `e.routedPrincipal > 0` and `routedPrincipal = e.routedPrincipal`.
Affected code
IYieldRouterV2 r = yieldRouter;
if (address(r) != address(0) && e.routedPrincipal > 0) {
uint256 routedPrincipal = e.routedPrincipal;
if (routedPrincipal > 0) { // Always true - dead code
if (!_tryWithdrawRoutedForCancel(r, templateId, epochId, routedPrincipal, ledger)) {
emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
revert YieldWithdrawFailed();
}
}
}
Proposed fix
Remove the redundant inner check:
IYieldRouterV2 r = yieldRouter;
if (address(r) != address(0) && e.routedPrincipal > 0) {
    uint256 routedPrincipal = e.routedPrincipal;
    if (!_tryWithdrawRoutedForCancel(r, templateId, epochId, routedPrincipal, ledger)) {
        emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
        revert YieldWithdrawFailed();
    }
}
2

MarketEngineCoreLifecycleModule.sol
Yield Fee Calculation Uses Integer Division That Can Systematically Under-Collect Fees
In `_applyGrossYield`, the yield fee calculation uses a split approach to avoid overflow: `yieldFee = (q * bps) + ((r * bps) / 10_000)` where `q = grossYield / 10_000` and `r = grossYield % 10_000`. The second term `(r * bps) / 10_000` truncates, meaning the fee is always rounded DOWN. For small `grossYield` values (< 10_000), `q = 0` and the entire fee is `(grossYield * bps) / 10_000`, which truncates. This is the standard floor rounding for fees, but it means the protocol systematically under-collects yield fees. While this is a minor precision issue, it's worth noting that the switch fee uses CEILING rounding (to avoid under-collection) while the yield fee uses FLOOR rounding.


Hide Details
Impact
The protocol under-collects yield fees by up to 1 wei per yield event. For high-frequency markets with many small yield events, this could accumulate to a meaningful amount over time. The under-collected amount benefits users (higher netYield) at the expense of the protocol treasury. This is a minor economic issue.
Scenario
grossYield = 9999, yieldFeeBps = 1000 (10%)
q = 0, r = 9999
yieldFee = 0 + (9999 * 1000) / 10000 = 9999000 / 10000 = 999 (truncated from 999.9)
Expected fee = 9999 * 10% = 999.9 → should be 1000 with ceiling
Actual fee = 999 → under-collects by 1 wei
Affected code
function _applyGrossYield(bytes32 templateId, MarketTypes.Ledger storage ledger, uint256 grossYield)
internal
returns (uint256 yieldFee, uint256 netYield)
{
if (grossYield < 1) return (0, 0);

_vaults[templateId].active += grossYield;
ledger.increaseActiveCollateral(grossYield);

uint256 bps = uint256(yieldFeeBps);
uint256 q = grossYield / 10_000;
uint256 r = grossYield % 10_000;
yieldFee = (q * bps) + ((r * bps) / 10_000); // Floor rounding
netYield = grossYield - yieldFee;
// ...
}
Proposed fix
For consistency with the switch fee ceiling rounding, consider using ceiling rounding for yield fees as well:
// Ceiling rounding for yield fee
yieldFee = (grossYield * bps + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
Or document that floor rounding is intentional for yield fees (benefiting users) while ceiling rounding is used for switch fees (benefiting protocol).

informational Severity
3
1

MarketEngineCoreLifecycleModule.sol
Corridor Market Validation Loop Off-By-One - Insufficient Bound Checking
In `_validateTemplate` for Corridor market type, the validation loop for range bounds has an off-by-one issue. The code checks `rangeBoundsE8[0] < rangeBoundsE8[1]` (lower < upper bound), then runs a loop `for (uint256 i = 2; i < uint256(t.outcomeCount) - 1; i++)`. Since Corridor markets require exactly 3 outcomes (`outcomeCount == 3`), the loop condition is `i < 2`, which means the loop body NEVER executes. The loop is effectively dead code for the required 3-outcome Corridor market. While the initial check `rangeBoundsE8[0] < rangeBoundsE8[1]` is correct for the two bounds needed, the loop suggests an intent to validate additional bounds that is never realized.


Hide Details
Impact
The dead loop code is misleading and suggests incomplete validation. While for the current 3-outcome Corridor market the two bounds are correctly validated by the explicit check, if the market type is ever extended to support more outcomes, the loop logic would still be incorrect. This is a code quality issue that could lead to maintenance errors.
Scenario
For outcomeCount = 3:
- Loop condition: i < uint256(3) - 1 = i < 2
- Starting i = 2: 2 < 2 is false → loop never executes
- The loop is dead code
Affected code
} else if (t.marketType == MarketTypes.MarketType.Corridor) {
// `Resolvers.resolveCorridor` uses outcomes 0=in-band, 1=upper breach, 2=lower breach.
if (t.outcomeCount != 3) revert InvalidTemplate();
if (!(t.rangeBoundsE8[0] < t.rangeBoundsE8[1])) revert InvalidTemplate();
for (uint256 i = 2; i < uint256(t.outcomeCount) - 1; i++) { // i < 2, never executes
if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
}
}
Proposed fix
Remove the dead loop or fix the loop bounds to correctly validate all range bounds:
} else if (t.marketType == MarketTypes.MarketType.Corridor) {
    if (t.outcomeCount != 3) revert InvalidTemplate();
    // Corridor uses exactly 2 bounds: [0]=lower, [1]=upper
    if (!(t.rangeBoundsE8[0] < t.rangeBoundsE8[1])) revert InvalidTemplate();
    // Remove the dead loop - no additional bounds needed for 3-outcome Corridor
}
2

MarketEngineCoreLifecycleModule.sol
Cascade Market Validation Only Checks Bounds Starting from Index 1 - First Bound Unchecked
In `_validateTemplate` for Cascade market type, the validation loop starts at `i = 1` and checks `rangeBoundsE8[i-1] < rangeBoundsE8[i]`. This means it checks bounds[0] < bounds[1], bounds[1] < bounds[2], etc. However, the loop runs from `i=1` to `i < maxLevels` where `maxLevels = outcomeCount - 1`. For a 2-outcome Cascade market (minimum), `maxLevels = 1`, so the loop runs from `i=1` to `i < 1`, which means the loop NEVER executes. A 2-outcome Cascade market has no bound validation at all. The first bound (bounds[0]) is never validated to be within any reasonable range.


Hide Details
Impact
For 2-outcome Cascade markets, no range bound validation is performed. Admin can create a Cascade market with any value for `rangeBoundsE8[0]`, including values that could cause unexpected settlement behavior. For 3+ outcome Cascade markets, the validation is correct but the first bound is still not validated against any absolute constraint.
Scenario
1. Admin creates Cascade market with outcomeCount=2
2. maxLevels = 1, loop: i=1, condition i < 1 is false → loop never runs
3. rangeBoundsE8[0] can be any value (e.g., type(int256).max)
4. Settlement uses this unchecked bound value
5. Unexpected behavior in Resolvers.resolveCascade
Affected code
} else if (t.marketType == MarketTypes.MarketType.Cascade) {
if (t.outcomeCount < 2) revert InvalidTemplate();
uint256 maxLevels = uint256(t.outcomeCount) - 1;
for (uint256 i = 1; i < maxLevels; i++) { // For outcomeCount=2: i < 1, never executes
if (t.cascadeDownward) {
if (!(t.rangeBoundsE8[i] < t.rangeBoundsE8[i - 1])) revert InvalidTemplate();
} else {
if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
}
}
}
Proposed fix
Fix the loop to validate all necessary bounds:
} else if (t.marketType == MarketTypes.MarketType.Cascade) {
    if (t.outcomeCount < 2) revert InvalidTemplate();
    uint256 numBounds = uint256(t.outcomeCount) - 1;
    // For outcomeCount=2, numBounds=1, only one bound exists, no ordering to check
    // For outcomeCount>=3, check ordering between consecutive bounds
    for (uint256 i = 1; i < numBounds; i++) {
        if (t.cascadeDownward) {
            if (!(t.rangeBoundsE8[i] < t.rangeBoundsE8[i - 1])) revert InvalidTemplate();
        } else {
            if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
        }
    }
}
Note: The current loop logic is actually correct for 3+ outcomes. For 2-outcome Cascade, there's only one bound and no ordering constraint needed. Document this explicitly.
3

MarketEngineCoreLifecycleModule.sol
Epoch ID Overflow Risk in _requireCanOpenNextEpoch
In `_requireCanOpenNextEpoch`, the check `epochId != ledger.activeEpochId + 1` uses unchecked addition on `uint64`. If `ledger.activeEpochId` is at `type(uint64).max`, adding 1 would overflow to 0. This means the next valid epochId would be 0, which could conflict with the initial state (where `activeEpochId = 0` and `lastResolvedEpochId = 0`). While reaching `type(uint64).max` epochs is practically impossible (would require billions of epochs), the overflow behavior is worth noting. More practically, the initial state check `ledger.activeEpochId != ledger.lastResolvedEpochId` would pass when both are 0, and `epochId != 0 + 1 = 1` would require the first epoch to be ID 1.


Hide Details
Impact
Practically negligible - reaching uint64 max epochs is impossible. However, the initial state requires the first epoch to be ID 1 (since activeEpochId=0, lastResolvedEpochId=0, so epochId must be 0+1=1). This is an implicit constraint that should be documented.
Scenario
Initial state: activeEpochId=0, lastResolvedEpochId=0
First openEpoch call with epochId=0: 0 != 0+1=1 → revert EpochAlreadyExists
First openEpoch call with epochId=1: 1 == 0+1=1 → passes
This means epoch IDs must start at 1, which is an undocumented constraint.
Affected code
function _requireCanOpenNextEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
if (ledger.activeEpochId != ledger.lastResolvedEpochId) revert PreviousEpochUnresolved();
if (epochId != ledger.activeEpochId + 1) revert EpochAlreadyExists(); // Unchecked uint64 addition
}
Proposed fix
Document that epoch IDs must start at 1 (not 0) for each template. Consider adding a comment:
/// @dev epochId must be activeEpochId + 1. Since activeEpochId starts at 0,
/// the first epoch for any template must have epochId = 1.
function _requireCanOpenNextEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
    if (ledger.activeEpochId != ledger.lastResolvedEpochId) revert PreviousEpochUnresolved();
    if (epochId != ledger.activeEpochId + 1) revert EpochAlreadyExists();
}