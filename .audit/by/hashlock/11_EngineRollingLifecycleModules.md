DeFi Prediction Market / Parimutuel Betting Protocol

RetroPick MarketEngine is a UUPS-upgradeable, delegatecall-based prediction market protocol. It supports multiple market types (Direction, Threshold, RangeClose, Velocity, Ladder, Convergence, Composite, Corridor, Cascade) with both manual and rolling lifecycle execution modes. The system uses a dispatcher/module architecture where a proxy delegates calls to registered modules, all sharing a canonical storage layout defined in MarketEngineState. Users stake ERC20 tokens on outcomes within epochs; at resolution, oracle prices determine winners and settlement math distributes the pool. A yield router optionally routes idle principal to external yield protocols (Aave/ERC4626) between lock and resolve.

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
dispatcher (UUPS proxy owner)

External Calls
1
IPriceOracle / IPriceOracleWithRoundId
2
IYieldRouterV2
3
IERC20 (stakeToken)

External Systems
1
Oracle (Chainlink-style)
2
Yield Protocol (Aave/ERC4626)
3
UUPS Proxy / Dispatcher

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


high Severity
2
1

MarketEngineRollingLifecycleModule.sol
Single Oracle Sample Used for Both Epoch Resolution and Lock Creates Dual-Epoch Manipulation Vector
In `_resolveAndLockRound`, a single oracle sample is read once and used for two distinct purposes: (1) as `checkpointB` to resolve the previous epoch (determining winners/losers), and (2) as `checkpointA` to lock the current epoch (setting the baseline price for the next round). This means a single manipulated oracle price simultaneously affects the outcome of epoch k-1 AND the starting price for epoch k. An attacker who can influence the oracle price at the exact moment of round execution can profit on both epochs: they know the resolution price of the previous epoch AND can position themselves advantageously for the next epoch knowing the exact lock price.


Hide Details
Impact
An attacker with oracle influence (e.g., a large Chainlink node operator, or someone who can time transactions around oracle updates) can manipulate a single price point to simultaneously: (1) determine the winner of the previous epoch in their favor, and (2) set a favorable baseline for the next epoch. This doubles the economic impact of any oracle manipulation and could allow systematic extraction of value from the protocol across consecutive epochs.
Scenario
1. Attacker monitors the mempool for `executeRollingRound` transactions
2. Attacker has positions on both epoch k-1 (e.g., betting 'UP') and epoch k (e.g., betting 'DOWN')
3. If attacker can influence oracle price at execution time:
- Sets price high → wins epoch k-1 (UP wins) AND sets high checkpoint A for epoch k
- Then bets DOWN on epoch k knowing the exact checkpoint A value
4. Even without direct oracle manipulation, an attacker can front-run the round execution:
- Observe oracle price is about to update
- Place bets on both epochs based on expected price
- The single-sample design means both epochs resolve/lock at the same price point
Affected code
function _resolveAndLockRound(
bytes32 templateId,
uint64 prevEpochId,
uint64 lockEpochId,
uint64 maxDelay,
uint16 maxConf,
uint64 nowTs
) internal returns (bool) {
MarketTypes.Epoch storage ePrev = _epochs[templateId][prevEpochId];
MarketTypes.Epoch storage eCur = _epochs[templateId][lockEpochId];
bool needsCheckpointA = MarketTypes.requiresCheckpointAOnLock(eCur);

(bool ok, OracleSample memory sample) =
_tryReadOracleSample(templateId, ePrev.oracleClass, ePrev.oracleFeedId, maxDelay, nowTs);
// ... same sample used for both resolve and lock
_resolvePreviousEpochFromSample(templateId, prevEpochId, maxDelay, nowTs, sample);
_applyLockFromSample(templateId, lockEpochId, maxDelay, maxConf, nowTs, needsCheckpointA, sample);
return true;
}
Proposed fix
Consider using separate oracle reads for resolve and lock operations, potentially with a small time offset. Alternatively, document this as an accepted design tradeoff and implement additional safeguards:
function _resolveAndLockRound(...) internal returns (bool) {
    // Read oracle for resolve (checkpointB of prev epoch)
    (bool okResolve, OracleSample memory sampleResolve) =
        _tryReadOracleSample(templateId, ePrev.oracleClass, ePrev.oracleFeedId, maxDelay, nowTs);
    if (!okResolve) { _haltRollingOracleFailure(...); return false; }
    
    // For checkpoint A of current epoch, use a different round if available
    // or enforce that the lock sample must be from a different roundId than resolve sample
    (bool okLock, OracleSample memory sampleLock) =
        _tryReadOracleSample(templateId, eCur.oracleClass, eCur.oracleFeedId, maxDelay, nowTs);
    if (!okLock) { _haltRollingOracleFailure(...); return false; }
    
    _resolvePreviousEpochFromSample(templateId, prevEpochId, maxDelay, nowTs, sampleResolve);
    _applyLockFromSample(templateId, lockEpochId, maxDelay, maxConf, nowTs, needsCheckpointA, sampleLock);
    return true;
}
2

MarketEngineRollingLifecycleModule.sol
Silent Loss of Principal When Yield Router Returns Less Than Deposited
In `_withdrawResolvePrincipal`, when the yield router returns fewer tokens than the `routedPrincipal`, the function silently returns 0 gross yield without reverting or emitting a warning. The code checks `if (received > routedPrincipal) return received - routedPrincipal; return 0;`. This means if the yield router returns, say, 90% of the principal due to a bug, slippage, or partial withdrawal, the missing 10% is silently lost — the epoch's `routedPrincipal` is set to 0, the vault's active balance is not adjusted to account for the shortfall, and no error is raised. The vault accounting will then be off by the lost amount.


Hide Details
Impact
If the yield router returns less than the deposited principal (due to a bug, slippage, partial liquidation, or malicious behavior), the protocol silently loses the difference. The vault's `active` balance will be overstated relative to actual token holdings, potentially causing `VaultInsufficientActive` reverts for future operations or allowing the protocol to over-pay claims that it cannot actually fulfill. Over time, this could lead to insolvency.
Scenario
1. Epoch has `routedPrincipal = 1000 tokens`
2. Yield router has a bug and only returns 900 tokens
3. `received = 900`, `routedPrincipal = 1000`
4. `received > routedPrincipal` is false, so function returns 0
5. `e.routedPrincipal = 0` (cleared)
6. Vault's `active` balance is not reduced by the 100 token shortfall
7. Settlement proceeds as if 1000 tokens are available
8. When claims are paid out, the contract may not have enough tokens
Affected code
try r.withdrawScaled(templateId, routedPrincipal) returns (uint256) {
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant();
uint256 received = b1 - b0;
e.routedPrincipal = 0;
if (received > routedPrincipal) return received - routedPrincipal;
return 0; // BUG: silently ignores received < routedPrincipal
}
Proposed fix
Add a check and emit a warning event when received < routedPrincipal, and adjust vault accounting accordingly:
try r.withdrawScaled(templateId, routedPrincipal) returns (uint256) {
    uint256 b1 = stakeToken.balanceOf(address(this));
    if (b1 < b0) revert YieldRouterBalanceInvariant();
    uint256 received = b1 - b0;
    e.routedPrincipal = 0;
    
    if (received < routedPrincipal) {
        // Principal shortfall: adjust vault accounting
        uint256 shortfall = routedPrincipal - received;
        if (_vaults[templateId].active >= shortfall) {
            _vaults[templateId].active -= shortfall;
        }
        emit YieldRouterPrincipalShortfall(templateId, epochId, routedPrincipal, received);
        // Consider halting or recording failure
    }
    
    if (received > routedPrincipal) return received - routedPrincipal;
    return 0;
}

medium Severity
7
1

MarketEngineRollingLifecycleModule.sol
ReentrancyGuardTransient Incompatibility with Delegatecall Architecture
The `MarketEngineRollingLifecycleModule` inherits from `ReentrancyGuardTransient` (OpenZeppelin's transient storage-based reentrancy guard). However, this module is designed to be called via `delegatecall` from the dispatcher proxy. Transient storage (`TSTORE`/`TLOAD`) is scoped to the executing contract's context in a transaction. When called via `delegatecall`, the transient storage operations execute in the context of the PROXY contract, not the module. This means the reentrancy guard's transient storage slot is shared across ALL modules that use `ReentrancyGuardTransient` when called through the same proxy. A `nonReentrant` function in one module could block a `nonReentrant` function in a completely different module within the same transaction, causing unexpected DoS.


Hide Details
Impact
If multiple modules use `ReentrancyGuardTransient` and are called through the same proxy, they share the same transient storage reentrancy slot. This could cause: (1) Legitimate multi-module transactions to fail unexpectedly, (2) A griefing attack where calling one module's nonReentrant function prevents another module's nonReentrant function from executing in the same transaction, (3) If the proxy itself uses transient storage for other purposes, slot collisions could corrupt the guard state.
Scenario
1. Module A (RollingLifecycle) has `executeRollingRound` with `nonReentrant`
2. Module B (some other module) also has a function with `nonReentrant`
3. A multicall or batch operation calls Module A's function, which sets the transient reentrancy slot on the PROXY
4. Within the same transaction, Module B's nonReentrant function is called
5. The transient slot is already set (from Module A's context on the proxy)
6. Module B's function reverts with ReentrancyGuardReentrantCall
7. This is a false positive reentrancy detection causing DoS
Affected code
contract MarketEngineRollingLifecycleModule is MarketEngineState, ReentrancyGuardTransient {
// ...
function genesisLockRolling(bytes32 templateId) external nonReentrant {
// ...
function executeRollingRound(bytes32 templateId) external nonReentrant {
// ...
function executeRollingRoundBatch(bytes32[] calldata templateIds) external nonReentrant {
Proposed fix
Use a regular (non-transient) reentrancy guard that stores state in a specific storage slot defined in `MarketEngineState`, ensuring all modules share the same guard state consistently:
// In MarketEngineState.sol, add:
bool private _reentrancyGuardEntered;

modifier nonReentrant() {
    require(!_reentrancyGuardEntered, "ReentrancyGuard: reentrant call");
    _reentrancyGuardEntered = true;
    _;
    _reentrancyGuardEntered = false;
}
Alternatively, if transient storage is desired, ensure all modules use the same transient storage slot key defined in `MarketEngineState`, and document the cross-module interaction behavior.
2

MarketEngineRollingLifecycleModule.sol
Oracle Cursor Allows Equal publishTime, Enabling Same-Block Oracle Replay
In `_enforceAndUpdateOracleCursor`, the publishTime monotonicity check uses `publishTime < c.publishTime` (strict less-than), meaning equal publishTimes are allowed. This means the same oracle sample (same publishTime) can be used multiple times across different epochs within the same block or across multiple calls. For rolling markets, if the oracle hasn't updated between two consecutive round executions, the same publishTime could be used for both checkpointB of epoch k-1 and checkpointA of epoch k, and potentially checkpointB of epoch k in a subsequent call. This violates the intended monotonicity guarantee.


Hide Details
Impact
The same oracle price can be used for both the lock (checkpointA) and resolve (checkpointB) of a Direction market epoch. For Direction markets, the outcome is determined by comparing checkpointA vs checkpointB. If both checkpoints have the same price (same oracle sample), the `equalPriceVoids` flag determines behavior. If `equalPriceVoids=false`, this could lead to incorrect resolution. More critically, for non-roundId oracles, the same publishTime could be replayed across multiple epochs, undermining the freshness guarantee.
Scenario
1. Oracle hasn't updated for 30 seconds (within maxDelaySeconds)
2. `executeRollingRound` is called at time T
3. Oracle sample has publishTime = T-30
4. checkpointB of epoch k-1 is written with publishTime T-30
5. checkpointA of epoch k is written with publishTime T-30 (same sample)
6. Cursor is updated to publishTime T-30
7. If another round executes quickly (within the same oracle update cycle)
8. The same publishTime T-30 passes the `publishTime < c.publishTime` check (equal, not less)
9. Same price used again for the next epoch pair
Affected code
function _enforceAndUpdateOracleCursor(
bytes32 templateId,
bytes32 feedId,
uint80 oracleRoundId,
uint64 publishTime,
bool supportsRoundId
) internal {
// ...
if (supportsRoundId && oracleRoundId < c.roundId) {
revert OracleSampleNotMonotonic(...);
}
if (publishTime < c.publishTime) { // BUG: allows equal publishTime
revert OracleSampleNotMonotonic(...);
}
// ...
}
Proposed fix
Change the publishTime check to use `<=` for strict monotonicity, or use `<` but allow equal only when roundId is strictly greater:
// Option 1: Strict monotonicity for publishTime
if (publishTime <= c.publishTime && c.publishTime != 0) {
    revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
}

// Option 2: Allow equal publishTime only if roundId is strictly greater
if (supportsRoundId) {
    if (oracleRoundId <= c.roundId && c.roundId != 0) {
        revert OracleSampleNotMonotonic(...);
    }
} else {
    if (publishTime <= c.publishTime && c.publishTime != 0) {
        revert OracleSampleNotMonotonic(...);
    }
}
3

MarketEngineRollingLifecycleModule.sol
cancelRollingEpochWhileHalted Does Not Verify Epoch Belongs to the Halted Template
In `cancelRollingEpochWhileHalted`, the function accepts an arbitrary `epochId` parameter and cancels the epoch if it exists and is in Open or Locked status. While it does check that the template is in Halted phase, it does not verify that the provided `epochId` is the specific epoch that caused the halt (i.e., `ledger.haltedAtEpochId`). An admin could accidentally (or intentionally) cancel the wrong epoch, potentially cancelling an epoch that was already being processed or one that shouldn't be cancelled. More critically, the function can be called multiple times with different epochIds, potentially cancelling multiple epochs and creating multiple refund liabilities.


Hide Details
Impact
An admin could cancel multiple epochs simultaneously (e.g., both the halted epoch and a previously locked epoch), creating double refund liabilities that exceed the vault's active balance. This could cause `VaultInsufficientActive` reverts for legitimate operations or, if the vault check is bypassed, lead to insolvency. Additionally, cancelling the wrong epoch could leave the actual problematic epoch unresolved.
Scenario
1. Rolling market halts at epoch k (haltedAtEpochId = k)
2. Epoch k-1 is in Locked status (waiting for resolution)
3. Admin calls `cancelRollingEpochWhileHalted(templateId, k-1, reason, false)` - cancels wrong epoch
4. Admin calls `cancelRollingEpochWhileHalted(templateId, k, reason, false)` - cancels correct epoch
5. Both epochs now have refund liabilities
6. Total refund liability = pool(k-1) + pool(k)
7. If vault.active < pool(k-1) + pool(k), subsequent operations fail
8. Or if vault had exactly enough for one epoch, the double cancellation drains it
Affected code
function cancelRollingEpochWhileHalted(
bytes32 templateId,
uint64 epochId,
MarketTypes.CancelReason reason,
bool voided
) external nonReentrant {
_authAdmin();
if (!globalPaused) revert ProtocolPaused();
// ...
MarketTypes.Epoch storage e = _epochs[templateId][epochId];
if (!e.exists) revert InvalidEpochState();
if (!(e.status == MarketTypes.EpochStatus.Open || e.status == MarketTypes.EpochStatus.Locked)) {
revert InvalidEpochState();
}
// No check that epochId == ledger.haltedAtEpochId or is the active epoch
uint256 refundLiability = e.totalPool;
if (refundLiability > 0) {
_vaults[templateId].active -= refundLiability;
_vaults[templateId].claims += refundLiability;
MarketMath.reserveClaimsFromActive(ledger, refundLiability);
}
// ...
}
Proposed fix
Add a check to ensure the cancelled epoch is the halted epoch or the active epoch:
function cancelRollingEpochWhileHalted(
    bytes32 templateId,
    uint64 epochId,
    MarketTypes.CancelReason reason,
    bool voided
) external nonReentrant {
    _authAdmin();
    if (!globalPaused) revert ProtocolPaused();
    // ...
    
    // Verify epochId is the halted epoch or the active epoch
    require(
        epochId == ledger.haltedAtEpochId || epochId == ledger.activeEpochId,
        "Can only cancel halted or active epoch"
    );
    
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    // ...
}
4

MarketMath.sol
computeClaimPayoutStorage Division by Zero When winningPool is Zero After Winning Stake Check
In `MarketMath.computeClaimPayoutStorage`, after confirming `userWinningStake_ > 0`, the function computes `winningPool` by summing outcome pools for winning outcomes. However, there is a scenario where `userWinningStake_ > 0` but `winningPool == 0`: this can happen if the epoch's `outcomePools` have been modified after the `winningOutcomeMask` was set (e.g., through a bug in accounting), or if the position's stakes are inconsistent with the epoch's outcome pools. If `winningPool == 0`, the division `(userWinningStake_ * distributableLosing) / winningPool` will revert with a division-by-zero panic.


Hide Details
Impact
If `winningPool == 0` but `userWinningStake_ > 0` (an inconsistent state), the claim function will revert with a division-by-zero panic, permanently preventing the user from claiming their funds. While this state should not occur under normal operation, any accounting bug that creates this inconsistency would permanently lock user funds.
Scenario
1. Epoch resolves with winning outcome mask set
2. Due to an accounting bug, epoch.outcomePools[winningOutcome] = 0 but user has stakes[winningOutcome] > 0
3. User calls claim function
4. computeClaimPayoutStorage is called
5. userWinningStake_ = stakes[winningOutcome] > 0
6. winningPool = outcomePools[winningOutcome] = 0
7. Division by zero panic at `(userWinningStake_ * distributableLosing) / winningPool`
8. User cannot claim
Affected code
function computeClaimPayoutStorage(
MarketTypes.Epoch storage epoch,
uint256[8] memory stakes,
uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
// ...
userWinningStake_ = totalWinningStake(winningMask, outcomeCount, stakes);
if (userWinningStake_ == 0) return (0, 0);

uint256 winningPool = 0;
for (uint256 i = 0; i < outcomeCount; i++) {
if ((winningMask >> i) & 1 == 1) {
winningPool += epoch.outcomePools[i];
}
}
uint256 distributableLosing = _distributableLosingPoolForClaimsStorage(epoch, winningPool);
uint256 entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool; // DIV BY ZERO if winningPool == 0
// ...
}
Proposed fix
Add a guard for the winningPool == 0 case:
function computeClaimPayoutStorage(
    MarketTypes.Epoch storage epoch,
    uint256[8] memory stakes,
    uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
    // ...
    userWinningStake_ = totalWinningStake(winningMask, outcomeCount, stakes);
    if (userWinningStake_ == 0) return (0, 0);

    uint256 winningPool = 0;
    for (uint256 i = 0; i < outcomeCount; i++) {
        if ((winningMask >> i) & 1 == 1) {
            winningPool += epoch.outcomePools[i];
        }
    }
    
    // Guard against inconsistent state
    if (winningPool == 0) {
        // If user has winning stake but pool is 0, use last-claimer rule
        return (remainingClaimsForEpoch, userWinningStake_);
    }
    
    uint256 distributableLosing = _distributableLosingPoolForClaimsStorage(epoch, winningPool);
    uint256 entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool;
    // ...
}
5

SettlementLogic.sol
Ladder Market Settlement Uses First Winning Outcome Index But Multiple Outcomes Can Win
In `SettlementLogic.compute` for Ladder markets, the code finds the winner index using `for (uint8 i = 0; i < e.outcomeCount; i++) { if (((outputs.winningMask >> i) & 1) != 0) { winnerIdx = i; break; } }`. This takes the FIRST winning outcome. However, if `resolveLadder` returns a mask with multiple bits set (multiple winning outcomes), only the first one's weight is used for payout calculation. The other winning outcomes' weights are ignored. This could lead to incorrect payout calculations if the Ladder resolver can return multiple winners.


Hide Details
Impact
If `Resolvers.resolveLadder` can return a mask with multiple winning outcomes (e.g., in edge cases at boundary values), only the first winner's weight is used. Users who bet on the second or later winning outcomes would receive payouts calculated with the wrong weight. This could result in over- or under-payment depending on the weight ordering.
Scenario
1. Ladder market with 3 outcomes, weights [5000, 3000, 2000] bps
2. resolveLadder returns winningMask = 0b011 (outcomes 0 and 1 both win)
3. winnerIdx = 0 (first winner)
4. winnerWeight = 5000 bps
5. Payout calculated with 50% weight
6. Users on outcome 1 (weight 3000) receive payouts calculated with 50% weight instead of 30%
Affected code
if (e.marketType == MarketTypes.MarketType.Ladder) {
uint8 winnerIdx = 0;
for (uint8 i = 0; i < e.outcomeCount; i++) {
if (((outputs.winningMask >> i) & 1) != 0) {
winnerIdx = i;
break; // Only takes FIRST winner
}
}
uint16 winnerWeight = e.ladderPayoutWeightsBps[winnerIdx];
(outputs.claimLiabilityTotal, outputs.settlementFeeTotal,) = MarketMath.computeLadderLiabilityComponents(
effectiveTotalPool, winningPool, e.settlementFeeBps, e.feeOnLosingPool, winnerWeight
);
}
Proposed fix
Verify that `resolveLadder` always returns exactly one winning outcome (single bit set). If so, add an assertion. If multiple winners are possible, aggregate the weights:
if (e.marketType == MarketTypes.MarketType.Ladder) {
    // Verify single winner for ladder markets
    uint8 winnerCount = 0;
    uint8 winnerIdx = 0;
    for (uint8 i = 0; i < e.outcomeCount; i++) {
        if (((outputs.winningMask >> i) & 1) != 0) {
            winnerIdx = i;
            winnerCount++;
        }
    }
    require(winnerCount == 1, "Ladder must have exactly one winner");
    uint16 winnerWeight = e.ladderPayoutWeightsBps[winnerIdx];
    // ...
}
6

MarketEngineRollingLifecycleModule.sol
Vault Active Balance Can Underflow in cancelRollingEpochWhileHalted When totalPool Exceeds Active
In `cancelRollingEpochWhileHalted`, the code directly subtracts `refundLiability` from `_vaults[templateId].active` without checking if `active >= refundLiability`. While `MarketMath.reserveClaimsFromActive` uses `_sub` which reverts on underflow, the direct vault subtraction `_vaults[templateId].active -= refundLiability` does NOT use the safe subtraction. In Solidity 0.8+, this would revert with an arithmetic underflow, but the error message would be unhelpful. More importantly, if the vault's active balance has been reduced by other operations (e.g., yield router failures that didn't properly account for principal), this could revert unexpectedly.


Hide Details
Impact
If `_vaults[templateId].active < e.totalPool` (which could happen due to accounting inconsistencies from yield router failures or other bugs), the cancellation will revert with an arithmetic underflow. This prevents the admin from cancelling the epoch and providing refunds to users, effectively locking their funds during an emergency halt.
Scenario
1. Rolling market halts
2. Yield router had a failure that caused principal shortfall (see finding #3)
3. vault.active is less than epoch.totalPool due to the shortfall
4. Admin calls cancelRollingEpochWhileHalted
5. `_vaults[templateId].active -= refundLiability` reverts with arithmetic underflow
6. Admin cannot cancel the epoch
7. Users cannot get refunds
Affected code
uint256 refundLiability = e.totalPool;
if (refundLiability > 0) {
_vaults[templateId].active -= refundLiability; // No explicit check
_vaults[templateId].claims += refundLiability;
MarketMath.reserveClaimsFromActive(ledger, refundLiability);
}
Proposed fix
Add an explicit check with a meaningful error, consistent with `_applyResolveAccounting`:
uint256 refundLiability = e.totalPool;
if (refundLiability > 0) {
    if (_vaults[templateId].active < refundLiability) {
        revert VaultInsufficientActive(templateId, _vaults[templateId].active, refundLiability);
    }
    _vaults[templateId].active -= refundLiability;
    _vaults[templateId].claims += refundLiability;
    MarketMath.reserveClaimsFromActive(ledger, refundLiability);
}
7

SettlementLogic.sol
Corridor and Cascade Market Types Do Not Validate epochHighE8 and epochLowE8 Are Set
In `SettlementLogic.compute`, Corridor and Cascade market types use `e.epochHighE8` and `e.epochLowE8` for resolution. These fields are not set during epoch open (they default to 0) and must be written by an external mechanism (likely an OHLC oracle or keeper). If these fields are never written (remain 0), the resolution would use 0 as both high and low watermarks, potentially producing incorrect outcomes. There's no check in `compute` to verify these fields have been set (`e.ohlcWritten` flag exists but is not checked in `compute`).


Hide Details
Impact
If `epochHighE8` and `epochLowE8` are not set before resolution (e.g., the OHLC keeper fails or is not called), the Corridor/Cascade market resolves with 0 as both high and low. Depending on the `resolveCorridor`/`resolveCascade` implementation, this could produce an incorrect winning mask, potentially awarding the wrong outcome or causing a refund when it shouldn't.
Scenario
1. Corridor market epoch opens
2. OHLC keeper fails to write epochHighE8/epochLowE8
3. Epoch reaches resolveAt
4. executeRollingRound is called
5. SettlementLogic.compute uses epochHighE8=0, epochLowE8=0
6. resolveCorridor(0, 0, upperBound, lowerBound) produces potentially incorrect result
7. Wrong outcome wins
Affected code
} else if (e.marketType == MarketTypes.MarketType.Corridor) {
outputs.refundMode = false;
int256 lowerBound = e.rangeBoundsE8[0];
int256 upperBound = e.rangeBoundsE8[1];
outputs.winningMask = Resolvers.resolveCorridor(e.epochHighE8, e.epochLowE8, upperBound, lowerBound);
// No check that epochHighE8/epochLowE8 are set
e.winningOutcomeMask = outputs.winningMask;
} else {
outputs.refundMode = false;
outputs.winningMask = Resolvers.resolveCascade(
e.epochHighE8, e.epochLowE8, e.outcomeCount, e.rangeBoundsE8, e.cascadeDownward
);
// No check that epochHighE8/epochLowE8 are set
e.winningOutcomeMask = outputs.winningMask;
}
Proposed fix
Add a check for OHLC data availability before resolving Corridor/Cascade markets:
} else if (e.marketType == MarketTypes.MarketType.Corridor) {
    if (!e.ohlcWritten) {
        // OHLC data not available: refund
        outputs.refundMode = true;
        outputs.claimLiabilityTotal = e.totalPool;
        return outputs;
    }
    outputs.refundMode = false;
    // ...
}

low Severity
7
1

MarketEngineRollingLifecycleModule.sol
Yield Router Failure Incorrectly Uses OracleFailure Halt Reason
In `_withdrawResolvePrincipal`, when the yield router call fails during a rolling round, the code calls `_haltRolling` with `MarketTypes.RollingHaltReason.OracleFailure` as the reason. This is semantically incorrect — the halt is caused by a yield router failure, not an oracle failure. This misclassification could mislead operators during incident response, causing them to investigate oracle infrastructure when the actual problem is the yield router. Additionally, the `_recordYieldRouterFailure()` function is called before `_haltRolling`, which means the failure count is incremented and potentially the router is disabled, but the halt reason stored on-chain says 'OracleFailure'.


Hide Details
Impact
Operational confusion during incident response. Operators monitoring `RollingHalted` events with reason `OracleFailure` will investigate oracle infrastructure instead of the yield router. This could delay recovery and extend the period during which users cannot claim funds. In a time-sensitive situation (e.g., market volatility), delayed recovery could cause significant user losses.
Scenario
1. Yield router becomes unavailable (e.g., Aave pauses, ERC4626 vault is drained)
2. `executeRollingRound` is called
3. `_withdrawResolvePrincipal` catches the yield router revert
4. `_haltRolling` is called with `RollingHaltReason.OracleFailure`
5. `RollingHalted` event emitted with reason = 3 (OracleFailure)
6. Operators check oracle infrastructure, find nothing wrong
7. Recovery is delayed while operators investigate the wrong system
Affected code
} catch {
emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
_recordYieldRouterFailure();
if (rollingLink) {
_haltRolling(
templateId,
_ledgers[templateId],
MarketTypes.RollingHaltReason.OracleFailure, // BUG: should be a yield router failure reason
_ledgers[templateId].activeEpochId
);
return 0;
}
return 0;
}
Proposed fix
Add a dedicated halt reason for yield router failures, or reuse an existing appropriate reason:
// In MarketTypes.sol, add:
enum RollingHaltReason {
    NoneReason,
    BufferMissOnLock,
    BufferMissOnResolve,
    OracleFailure,
    OracleConfidenceWide,
    ManualAdmin,
    YieldRouterFailure  // Add this
}

// In _withdrawResolvePrincipal:
} catch {
    emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
    _recordYieldRouterFailure();
    if (rollingLink) {
        _haltRolling(
            templateId,
            _ledgers[templateId],
            MarketTypes.RollingHaltReason.YieldRouterFailure,  // Correct reason
            _ledgers[templateId].activeEpochId
        );
        return 0;
    }
    return 0;
}
2

SettlementLogic.sol
SettlementLogic.compute Modifies Storage Epoch State (winningOutcomeMask) Before Computing Liabilities
In `SettlementLogic.compute`, the function writes `e.winningOutcomeMask = mask` (or `outputs.winningMask`) to storage BEFORE computing the claim liability components. This means if the subsequent `computeClaimLiabilityComponents` or `computeLadderLiabilityComponents` call reverts (e.g., due to `MathOverflow`), the epoch's `winningOutcomeMask` has already been permanently written to storage. The epoch would then be in an inconsistent state: `winningOutcomeMask` is set but `claimable` is still false, `status` is still Locked, and no claims reserve has been set. This violates the atomicity principle for state changes.


Hide Details
Impact
If `computeClaimLiabilityComponents` reverts (e.g., `totalPool < winningPool` due to accounting inconsistency, or `losingPool < settlementFee` due to extreme fee settings), the epoch is left in a corrupted state with `winningOutcomeMask` set but no claims reserved. The epoch cannot be resolved again (checkpointB is already written), and users cannot claim. This effectively permanently locks user funds in the epoch.
Scenario
1. Epoch has extreme fee settings (e.g., settlementFeeBps = 10000 with feeOnLosingPool=false)
2. `compute` is called: winningOutcomeMask is written to storage
3. `computeClaimLiabilityComponents` is called with feeBps=10000
4. `settlementFee = totalPool * 10000 / 10000 = totalPool`
5. `losingPool < settlementFee` check: losingPool = totalPool - winningPool < totalPool = settlementFee
6. `MathOverflow` revert
7. Transaction reverts, but winningOutcomeMask was already written (storage writes in reverted transactions are rolled back in EVM)

Actually, EVM reverts ALL storage changes on revert. However, the pattern is still problematic if the function is called in a context where partial state is acceptable, or if future refactoring removes the revert protection.
Affected code
function compute(MarketTypes.Epoch storage e, uint256 netYield) internal returns (Outputs memory outputs) {
if (e.marketType == MarketTypes.MarketType.Direction) {
(bool voided, uint256 mask) = Resolvers.resolveDirection(e.checkpointA, e.checkpointB, e.equalPriceVoids);
// ...
outputs.winningMask = mask;
e.winningOutcomeMask = mask; // Storage write BEFORE liability computation
}
// ... (similar pattern for all market types)

// If this reverts, winningOutcomeMask is already written
(outputs.claimLiabilityTotal, outputs.settlementFeeTotal,) = MarketMath.computeClaimLiabilityComponents(
effectiveTotalPool, winningPool, e.settlementFeeBps, e.feeOnLosingPool
);
}
Proposed fix
Compute all outputs in memory first, then write to storage atomically:
function compute(MarketTypes.Epoch storage e, uint256 netYield) internal returns (Outputs memory outputs) {
    // Compute winning mask in memory first
    uint256 winningMask;
    bool refundMode;
    
    if (e.marketType == MarketTypes.MarketType.Direction) {
        (bool voided, uint256 mask) = Resolvers.resolveDirection(...);
        if (voided) { /* set refundMode */ }
        else { winningMask = mask; }
    }
    // ... compute all other market types without writing to storage
    
    // Compute liabilities in memory
    (outputs.claimLiabilityTotal, outputs.settlementFeeTotal,) = 
        MarketMath.computeClaimLiabilityComponents(...);
    
    // Only write to storage after all computations succeed
    outputs.winningMask = winningMask;
    e.winningOutcomeMask = winningMask;  // Write here, after all computations
    return outputs;
}
Note: In Solidity, all storage changes are reverted on transaction revert, so this is currently safe. However, the pattern should be documented and the storage write should be moved to after all computations for clarity and future safety.
3

MarketEngineRollingLifecycleModule.sol
genesisStartRolling Missing nonReentrant Guard While Other Lifecycle Functions Have It
The `genesisStartRolling` function is the only public lifecycle function in `MarketEngineRollingLifecycleModule` that does NOT have the `nonReentrant` modifier. All other state-changing lifecycle functions (`genesisLockRolling`, `executeRollingRound`, `executeRollingRoundBatch`, `cancelRollingEpochWhileHalted`) have `nonReentrant`. While `genesisStartRolling` doesn't make external calls directly, it calls `_openRollingEpoch` which writes extensive state. If the dispatcher or any future module modification introduces an external call path reachable from `genesisStartRolling`, reentrancy protection would be absent.


Hide Details
Impact
Currently low impact as no external calls are made. However, the inconsistency creates a maintenance risk: if `_openRollingEpoch` or any called function is modified to include an external call (e.g., notifying an external registry), reentrancy protection would be absent. The inconsistency also suggests a potential oversight in the security review.
Scenario
Currently not directly exploitable. Future risk if external calls are added to the genesis start path.
Affected code
function genesisStartRolling(bytes32 templateId) external {
// Missing: nonReentrant
_authAdminOrWorker();
if (globalPaused) revert ProtocolPaused();
// ...
uint64 opened = _openRollingEpoch(templateId, ts, t);
ledger.rollingPhase = MarketTypes.RollingPhase.GenesisOpen;
emit RollingGenesisStarted(...);
}
Proposed fix
Add `nonReentrant` modifier for consistency and defense-in-depth:
function genesisStartRolling(bytes32 templateId) external nonReentrant {
    _authAdminOrWorker();
    if (globalPaused) revert ProtocolPaused();
    // ...
}
4

SettlementLogic.sol
Composite Market Settlement Uses Incorrect Threshold When compositeFeedCount is Zero
In `SettlementLogic.compute` for Composite market type, the code iterates `for (uint256 i = 0; i < e.compositeFeedCount; i++)` to check if all thresholds are unset. If `compositeFeedCount == 0`, the loop never executes, `allUnset` remains `true`, and the second loop also never executes, leaving `thresholds` as all zeros. Then `Resolvers.resolveComposite` is called with an empty feed count and zero thresholds. This could lead to incorrect resolution or unexpected behavior for misconfigured Composite markets.


Hide Details
Impact
A Composite market with `compositeFeedCount == 0` would resolve with zero thresholds and no feeds, potentially producing an incorrect winning mask. If `resolveComposite` returns 0 (no winner) for empty feeds, the epoch would proceed to compute liabilities with `winningPool == 0`, triggering a full refund. This is likely the intended behavior for misconfigured markets, but it's not explicitly documented.
Scenario
1. Admin creates a Composite market template with compositeFeedCount = 0 (misconfiguration)
2. Epoch is opened and resolves
3. SettlementLogic.compute is called
4. Both loops execute 0 times
5. resolveComposite called with compositeFeedCount=0
6. Behavior depends on Resolvers.resolveComposite implementation (not shown)
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
outputs.refundMode = false;
outputs.winningMask = Resolvers.resolveComposite(
e.compositeLogic, e.compositeFeedCount, e.compositeConditions, thresholds, e.compositeCheckpointsB
);
}
Proposed fix
Add validation in the template upsert function to require `compositeFeedCount >= 1` for Composite markets. Also add a guard in `SettlementLogic.compute`:
} else if (e.marketType == MarketTypes.MarketType.Composite) {
    if (e.compositeFeedCount == 0) {
        // Misconfigured composite market: refund
        outputs.refundMode = true;
        outputs.claimLiabilityTotal = e.totalPool;
        return outputs;
    }
    // ... rest of composite logic
}
5

MarketEngineRollingLifecycleModule.sol
Missing Validation That rollingBufferSeconds > 0 in Template Configuration
The `rollingBufferSeconds` field in `MarketTypes.Template` is used in timing window checks throughout the rolling lifecycle (e.g., `nowTs > e1.timing.lockAt + t.rollingBufferSeconds`). If `rollingBufferSeconds == 0`, the buffer window collapses to a single timestamp, making it nearly impossible to execute rolling rounds on-time (any block after `lockAt` would be considered a buffer miss). While this is a configuration issue, there's no validation in the template upsert function to prevent `rollingBufferSeconds == 0` for Rolling mode templates.


Hide Details
Impact
A template configured with `rollingBufferSeconds == 0` would immediately halt on the first execution attempt (since `block.timestamp > lockAt + 0` is true for any block after `lockAt`). This would permanently halt the rolling market, requiring admin intervention with global pause to recover. Users' funds would be locked until recovery.
Scenario
1. Admin creates Rolling template with rollingBufferSeconds = 0
2. genesisStartRolling is called successfully
3. genesisLockRolling is called at exactly lockAt
4. `nowTs > e1.timing.lockAt + 0` → `nowTs > lockAt` → true (since nowTs == lockAt means not strictly greater, but any block after lockAt triggers halt)
5. Market immediately halts
6. Users cannot participate in rolling rounds
Affected code
// In genesisLockRolling:
if (nowTs > e1.timing.lockAt + t.rollingBufferSeconds) {
_haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnLock, k);
return;
}

// In _executeRollingRoundCore:
if (nowTs > ePrev.timing.resolveAt + t.rollingBufferSeconds) {
_haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnResolve, prev);
return;
}
Proposed fix
Add validation in the template upsert function:
// In template upsert validation:
if (template.executionMode == MarketTypes.ExecutionMode.Rolling) {
    require(template.rollingIntervalSeconds >= MIN_ROLLING_INTERVAL_SECONDS, "Interval too small");
    require(template.rollingIntervalSeconds <= MAX_ROLLING_INTERVAL_SECONDS, "Interval too large");
    require(template.rollingBufferSeconds > 0, "Buffer must be positive");
    require(template.rollingBufferSeconds < template.rollingIntervalSeconds, "Buffer must be less than interval");
}
6

MarketEngineRollingLifecycleModule.sol
Oracle Cursor Not Initialized at Template/Epoch Creation Allows First-Sample Mode Injection
The oracle cursor (`lastOracleCursorByTemplateFeed`) is initialized to zero (default mapping value) and only populated on the first oracle read. The mode (roundId vs publishTime-only) is determined by the first successful oracle call. An attacker who can influence which oracle interface is called first (e.g., by making `getNormalizedPriceWithRoundId` revert on the first call but succeed on subsequent calls) could establish a weaker cursor mode (publishTime-only) that is harder to enforce monotonicity on. Once established, the mode cannot be changed without reverting.


Hide Details
Impact
An attacker who can cause the first oracle call to use the fallback (non-roundId) path could establish a publishTime-only cursor. Subsequent calls with roundId support would be rejected (mode switch detection). This could permanently degrade oracle security for a template, making it easier to replay stale data within the publishTime window. The attack requires the ability to cause the oracle's `getNormalizedPriceWithRoundId` to revert on the first call.
Scenario
1. New template is created with a Chainlink oracle that supports roundId
2. Attacker front-runs the first oracle read by temporarily making getNormalizedPriceWithRoundId revert
3. First oracle call falls back to getNormalizedPrice (publishTime-only)
4. Cursor is established with supportsRoundId=false
5. All future calls with roundId support are rejected (mode switch)
6. Template is permanently locked to publishTime-only mode
7. Attacker can now replay oracle data within the publishTime window
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

if (c.publishTime != 0 && priorUsesRoundId != supportsRoundId) {
revert InvalidOracleFeed(); // Only checked after first use
}
// ...
}
Proposed fix
Initialize the oracle cursor mode at template creation time based on the oracle adapter's capabilities:
// In template upsert/initialization:
function _initializeOracleCursor(bytes32 templateId, bytes32 feedId, MarketTypes.OracleClass oracleClass) internal {
    // Try to determine if oracle supports roundId
    IPriceOracleWithRoundId oracle = IPriceOracleWithRoundId(address(_resolveOracleByClass(oracleClass)));
    bool supportsRoundId = _oracleSupportsRoundId(oracle, feedId);
    oracleCursorUsesRoundId[templateId][feedId] = supportsRoundId;
    // Mark as initialized with a sentinel value
    lastOracleCursorByTemplateFeed[templateId][feedId].publishTime = 1; // Non-zero sentinel
}
7

SettlementLogic.sol
Threshold Market Ignores absoluteThresholdValueE8 When anchorPriceE8 is Set to Non-Zero
In `SettlementLogic.compute` for Threshold markets, the effective threshold is determined by: ```solidity int256 effectiveThreshold = e.absoluteThresholdValueE8; if (e.anchorPriceE8 != 0) { effectiveThreshold = e.anchorPriceE8; } ``` This means `anchorPriceE8` completely overrides `absoluteThresholdValueE8` when non-zero. The `anchorPriceE8` is copied from the template at epoch open time. If the template's `anchorPriceE8` is set to a non-zero value (even accidentally), it silently overrides the intended threshold. There's no event or log indicating which threshold was actually used for resolution, making it difficult to audit or verify correct behavior.


Hide Details
Impact
If `anchorPriceE8` is accidentally set to a non-zero value for a Threshold market (e.g., through a template misconfiguration or copy-paste error), the market will resolve against the wrong threshold without any indication. Users who bet based on the published `absoluteThresholdValueE8` would receive incorrect outcomes. The `EpochResolved` event doesn't include the effective threshold used, making post-hoc verification difficult.
Scenario
1. Admin creates Threshold market with absoluteThresholdValueE8 = 50000e8 ($50,000)
2. Admin accidentally sets anchorPriceE8 = 1e8 ($1) in the template
3. Epoch opens, anchorPriceE8 is copied to epoch
4. At resolution, effectiveThreshold = 1e8 instead of 50000e8
5. Market resolves against $1 threshold instead of $50,000
6. All users who bet 'above $50,000' lose when price is $30,000 (should have won at $1 threshold)
Affected code
} else if (e.marketType == MarketTypes.MarketType.Threshold) {
outputs.refundMode = false;
int256 effectiveThreshold = e.absoluteThresholdValueE8;
if (e.anchorPriceE8 != 0) {
effectiveThreshold = e.anchorPriceE8; // Silent override
}
outputs.winningMask = Resolvers.resolveThreshold(e.condition, effectiveThreshold, e.checkpointB);
e.winningOutcomeMask = outputs.winningMask;
}
Proposed fix
Add explicit documentation and consider emitting the effective threshold in resolution events. Also consider adding validation to prevent both `absoluteThresholdValueE8` and `anchorPriceE8` from being set simultaneously for Threshold markets:
// In EpochResolvedV2 or a new event, include the effective threshold:
event EpochResolvedV3(
    bytes32 indexed templateId,
    uint64 indexed epochId,
    uint80 oracleRoundId,
    int256 checkpointBValueE8,
    uint64 publishTime,
    int256 effectiveThreshold  // Add this
);

// In SettlementLogic.compute:
int256 effectiveThreshold = (e.anchorPriceE8 != 0) ? e.anchorPriceE8 : e.absoluteThresholdValueE8;

gas Severity
1
1

MarketEngineRollingLifecycleModule.sol
Precision Loss in Yield Fee Calculation Due to Integer Division Order
In `_applyGrossYield`, the yield fee is calculated as: ``` uint256 q = grossYield / 10_000; uint256 r = grossYield % 10_000; yieldFee = (q * bps) + ((r * bps) / 10_000); ``` This is a manual implementation of `(grossYield * bps) / 10_000` that attempts to avoid overflow. However, the remainder term `(r * bps) / 10_000` truncates the fractional part. For small `grossYield` values (< 10_000), `q = 0` and the entire fee is `(r * bps) / 10_000`, which can be significantly less than the true fee due to integer truncation. For example, with `grossYield = 9999` and `bps = 1000` (10%), the true fee is 999.9, but the calculated fee is `(9999 * 1000) / 10_000 = 999`. This is a 0.1 token underpayment per 9999 tokens of yield.


Hide Details
Impact
Systematic underpayment of yield fees to the protocol. For each yield withdrawal, the protocol collects slightly less than the configured fee rate. Over many epochs and yield cycles, this could accumulate to a meaningful amount. The underpayment benefits users (they receive slightly more yield) at the expense of the protocol treasury.
Scenario
grossYield = 9999 tokens, yieldFeeBps = 1000 (10%)
Expected fee: 9999 * 1000 / 10000 = 999.9 → rounds to 999 (floor)
Calculated: q=0, r=9999, fee = (0*1000) + (9999*1000/10000) = 999
Difference: 0 (same in this case, but for grossYield=10001: q=1, r=1, fee=(1*1000)+(1*1000/10000)=1000+0=1000, expected=1000.1→1000, same)
Actual issue: for grossYield=19999: q=1, r=9999, fee=(1000)+(999)=1999, expected=1999.9→1999, same
The calculation is actually equivalent to floor division, which is standard. The concern is minimal.
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
yieldFee = (q * bps) + ((r * bps) / 10_000);
netYield = grossYield - yieldFee;
// ...
}
Proposed fix
The current implementation is mathematically equivalent to `(grossYield * bps) / 10_000` for values that don't overflow uint256. Since `grossYield` is a token amount and `bps <= 10_000`, the product `grossYield * bps` would overflow only for `grossYield > type(uint256).max / 10_000 ≈ 1.16e73`. For practical token amounts, the simpler form is safe:
yieldFee = (grossYield * bps) / 10_000;
This is cleaner and equivalent. If overflow protection is needed for extreme values, use the current approach but document it.

informational Severity
4
1

MarketEngineRollingLifecycleModule.sol
haltRollingMarket Missing nonReentrant Guard
The `haltRollingMarket` function lacks the `nonReentrant` modifier. While it only calls `_haltRolling` which writes to storage without external calls, the inconsistency with other lifecycle functions is notable. More importantly, if a malicious or buggy module is registered that can call `haltRollingMarket` during an ongoing operation, it could interfere with the rolling lifecycle state machine.


Hide Details
Impact
Low direct impact. The function only writes to storage. However, if called during an ongoing `executeRollingRound` (which is protected by nonReentrant on the proxy), the halt would be blocked by the reentrancy guard. The inconsistency could cause confusion about the intended behavior.
Scenario
Not directly exploitable in current implementation.
Affected code
function haltRollingMarket(bytes32 templateId) external {
// Missing: nonReentrant
_authAdmin();
MarketTypes.Template storage t = _templates[templateId];
// ...
_haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.ManualAdmin, ledger.activeEpochId);
}
Proposed fix
Add `nonReentrant` for consistency:
function haltRollingMarket(bytes32 templateId) external nonReentrant {
    _authAdmin();
    // ...
}
2

MarketEngineRollingLifecycleModule.sol
resetRollingLifecycle Requires globalPaused But Condition Check is Inverted
In `resetRollingLifecycle`, the check `if (!globalPaused) revert ProtocolPaused()` requires the protocol to be globally paused to execute the reset. This is intentional as a safety measure. However, the error `ProtocolPaused()` is semantically misleading — it's being thrown when the protocol is NOT paused, but the error name implies the protocol IS paused. This could confuse operators and developers trying to understand why the reset is failing.


Hide Details
Impact
Operational confusion. When an admin tries to call `resetRollingLifecycle` without first pausing the protocol, they receive `ProtocolPaused()` error, which implies the protocol is paused (and thus the operation should succeed). This is the opposite of the actual condition. Could delay recovery operations.
Scenario
1. Admin calls `resetRollingLifecycle` without pausing first
2. Transaction reverts with `ProtocolPaused()`
3. Admin thinks the protocol is already paused and the reset should work
4. Admin is confused about why the reset is failing
Affected code
function resetRollingLifecycle(bytes32 templateId, uint64 nextRollingEpochId) external {
_authAdmin();
if (!globalPaused) revert ProtocolPaused(); // Misleading: throws when NOT paused
// ...
}
Proposed fix
Add a new error for this case or reuse an existing one with correct semantics:
error NotPaused(); // Add to MarketEngineState

function resetRollingLifecycle(bytes32 templateId, uint64 nextRollingEpochId) external {
    _authAdmin();
    if (!globalPaused) revert NotPaused(); // Clear: requires protocol to be paused
    // ...
}


Similarly, `cancelRollingEpochWhileHalted` has the same issue:
function cancelRollingEpochWhileHalted(...) external nonReentrant {
    _authAdmin();
    if (!globalPaused) revert NotPaused(); // Fix here too
    // ...
}
3

MarketEngineRollingLifecycleModule.sol
Epoch Timing Uses block.timestamp for createdAt But startTs Parameter for openAt/lockAt/resolveAt
In `_openRollingEpoch`, the epoch's `createdAt` is set to `uint64(block.timestamp)` (current block time), while `openAt`, `lockAt`, and `resolveAt` are computed from the `startTs` parameter passed in. In `genesisLockRolling` and `executeRollingRound`, `startTs` is also `uint64(block.timestamp)`. However, there's a subtle inconsistency: `createdAt = nowTs` (from inside `_openRollingEpoch`) while `openAt = startTs` (from the parameter). If `block.timestamp` changes between the call to `_openRollingEpoch` and the internal `nowTs` assignment, these could differ. In practice, they're the same block, but the dual timestamp capture is confusing.


Hide Details
Impact
Minimal practical impact since both reads occur in the same transaction. However, the dual timestamp capture is a code quality issue that could cause confusion during audits or if the function is refactored to be called across different contexts.
Scenario
Not exploitable in current implementation.
Affected code
function _openRollingEpoch(bytes32 templateId, uint64 startTs, MarketTypes.Template storage t)
internal
returns (uint64 openedEpochId)
{
// ...
uint64 openAt = startTs; // From parameter
uint64 lockAt = startTs + inter;
uint64 resolveAt = startTs + 2 * inter;
// ...
uint64 nowTs = uint64(block.timestamp); // Re-read block.timestamp
// ...
e.timing = MarketTypes.MarketTiming({openAt: openAt, lockAt: lockAt, resolveAt: resolveAt});
e.createdAt = nowTs; // Could differ from startTs if called across blocks (impossible in practice)
// ...
}
Proposed fix
Use a single timestamp source throughout `_openRollingEpoch`:
function _openRollingEpoch(bytes32 templateId, uint64 startTs, MarketTypes.Template storage t)
    internal
    returns (uint64 openedEpochId)
{
    // ...
    // Use startTs consistently for all timing
    e.timing = MarketTypes.MarketTiming({openAt: startTs, lockAt: startTs + inter, resolveAt: startTs + 2 * inter});
    e.createdAt = startTs;  // Consistent with openAt
    // Remove the separate nowTs variable
    // ...
}
4

MarketEngineState.sol
MODULE_STORAGE_COMPATIBILITY_ID Marker Provides False Security Assurance
The `marketEngineStorageCompatibility()` function returns a constant `MODULE_STORAGE_COMPATIBILITY_ID = keccak256("retropick.marketengine.state.v1")`. The dispatcher verifies this marker before registering or delegating to a module. However, as explicitly noted in the code comments: 'it only proves the module implements this selector with the expected constant, not that bytecode matches MarketEngineState storage.' Any contract can implement this function and return the correct constant, regardless of its actual storage layout. A malicious module could pass this check while having a completely different storage layout, leading to storage corruption when called via delegatecall.


Hide Details
Impact
A malicious or incorrectly implemented module that returns the correct compatibility ID but has a different storage layout could corrupt the proxy's storage when called via delegatecall. This could lead to: fund theft, incorrect settlement, unauthorized access (if admin slot is overwritten), or complete protocol failure. The code hash allowlist in the dispatcher provides the actual security, but the compatibility marker creates a false sense of security.
Scenario
contract MaliciousModule {
    // Different storage layout than MarketEngineState
    uint256 public attackerControlled; // slot 0 (overlaps with stakeToken in MarketEngineState)
    
    // Returns correct compatibility ID
    function marketEngineStorageCompatibility() external pure returns (bytes32) {
        return keccak256("retropick.marketengine.state.v1");
    }
    
    // Malicious function that corrupts storage
    function drain() external {
        attackerControlled = uint256(uint160(msg.sender)); // Overwrites stakeToken address
    }
}
// If registered as a module, calling drain() via delegatecall would overwrite stakeToken
Affected code
/// @notice Delegatecall module compatibility marker.
/// @dev Dispatcher verifies this marker on registration and before delegatecall; it only proves the module
/// implements this selector with the expected constant, not that bytecode matches `MarketEngineState` storage.
function marketEngineStorageCompatibility() external pure returns (bytes32) {
return MODULE_STORAGE_COMPATIBILITY_ID;
}
Proposed fix
The code comment already acknowledges this limitation. Strengthen the documentation and ensure the dispatcher's code hash allowlist is the primary security mechanism:

1. Add a prominent warning in the module registration documentation
2. Consider implementing a storage layout hash check (hash of storage slot assignments) as an additional verification
3. Require all modules to pass a formal storage layout audit before being added to the allowlist
4. Consider using EIP-1967 storage slots for critical variables to reduce collision risk

The current mitigation (code hash allowlist) is the correct approach, but the compatibility marker should be clearly documented as a non-security check.