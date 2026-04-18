Prediction Market / DeFi Protocol with UUPS Proxy + Module Dispatcher Architecture

RetroPick MarketEngine is a prediction market / structured betting protocol built on a UUPS upgradeable proxy pattern with a dispatcher/module architecture. The system allows users to deposit stake tokens into prediction market epochs (rounds), choose outcome sides, switch sides (with fees), and claim winnings after resolution. The protocol supports multiple market types (Direction, Threshold, Range, Velocity, Ladder, Convergence, Composite, Corridor, Cascade), oracle-driven settlement via Chainlink or trusted reporters, and optional yield routing through Aave/ERC-4626 integrations. The storage anchor contract (MarketEngineState) defines all state variables and is inherited by delegatecall modules to ensure storage layout compatibility.

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
isDepositExecutor (mapping)
5
MarketEngineDispatcher (proxy owner)

External Calls
1
IERC20 (stakeToken)
2
IYieldRouterV2
3
IPriceOracle (priceOracle, rateOracle, smartDataOracle, macroOracle, equityOracle)
4
OpenZeppelin ReentrancyGuardTransient

External Systems
1
Chainlink Oracle Network
2
Aave / ERC-4626 Yield Protocol
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

MarketEngineUserOpsClaimsModule.sol
Yield Router Deposit Overcredits routedPrincipal Without Balance Delta Verification
In `_depositToSide`, when routing funds to the yield router, the code calls `r.depositScaled(templateId, routeAmount)` and only checks if `attributionUnits > 0` to decide whether to credit `e.routedPrincipal += routeAmount`. However, unlike withdrawals which use the `_balanceDeltaAfterWithdrawScaled` balance-delta pattern, deposits do not verify that the router actually received `routeAmount` tokens. A malicious or buggy yield router could return `attributionUnits > 0` while only consuming a fraction of `routeAmount` (or none at all), causing `routedPrincipal` to be overstated. This overstated `routedPrincipal` is then used in `_withdrawSwitchFeePrincipal` to determine how much principal to withdraw from the router. If `routedPrincipal` is inflated, the contract will attempt to withdraw more than was actually deposited, potentially causing the router to return less than expected or fail, while the contract's accounting believes more funds are in the router than actually are.


Hide Details
Impact
If the yield router is compromised or has a bug where it returns non-zero attribution units without actually receiving the full `routeAmount`, the `routedPrincipal` accounting will be inflated. This leads to: (1) Incorrect yield accounting - the contract believes more is in the router than actually is; (2) Failed or partial withdrawals when trying to reclaim principal; (3) Potential loss of funds if the router returns less than expected during withdrawal and the contract's accounting doesn't reconcile properly. The `forceApprove` before the try block also means the approval persists even if the deposit fails silently.
Scenario
1. Admin sets a malicious yield router that implements `depositScaled` to return `attributionUnits = 1` but only transfers a fraction of the approved amount
2. User calls `depositToSide` with `amount = 1000 tokens`
3. `routeAmount = 950` (after 5% buffer)
4. Router is approved for 950 tokens but only takes 100 tokens, returns `attributionUnits = 1`
5. `e.routedPrincipal += 950` (overstated by 850)
6. Later, `_withdrawSwitchFeePrincipal` tries to withdraw 850 from router
7. Router only has 100 tokens worth of principal, returns less
8. Contract accounting is now permanently misaligned
Affected code
try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) {
if (attributionUnits > 0) {
e.routedPrincipal += routeAmount;
} else {
emit YieldRouterDepositFailed(templateId, routeAmount);
}
}
catch {
emit YieldRouterDepositFailed(templateId, routeAmount);
}
Proposed fix
Use the balance delta pattern for deposits as well, similar to `_balanceDeltaAfterWithdrawScaled`:
// Add a balance-delta deposit helper
function _balanceDeltaAfterDepositScaled(IYieldRouterV2 r, bytes32 templateId, uint256 routeAmount) 
    internal returns (uint256 actualRouted) {
    uint256 b0 = stakeToken.balanceOf(address(this));
    uint256 attributionUnits = r.depositScaled(templateId, routeAmount);
    uint256 b1 = stakeToken.balanceOf(address(this));
    if (attributionUnits == 0) return 0;
    // Actual amount taken from contract
    actualRouted = b0 > b1 ? b0 - b1 : 0;
    return actualRouted;
}

// In _depositToSide:
stakeToken.forceApprove(address(r), routeAmount);
try _balanceDeltaAfterDepositScaled(r, templateId, routeAmount) returns (uint256 actualRouted) {
    if (actualRouted > 0) {
        e.routedPrincipal += actualRouted; // Use actual amount, not routeAmount
    } else {
        emit YieldRouterDepositFailed(templateId, routeAmount);
    }
} catch {
    stakeToken.forceApprove(address(r), 0); // Reset approval on failure
    emit YieldRouterDepositFailed(templateId, routeAmount);
}
2

MarketEngineState.sol
Delegatecall Module Storage Compatibility Marker is Insufficient Security Guarantee
The `marketEngineStorageCompatibility()` function returns a constant `MODULE_STORAGE_COMPATIBILITY_ID = keccak256('retropick.marketengine.state.v1')`. The dispatcher uses this marker to verify module compatibility before delegatecall. However, this marker only proves that the module implements this specific function and returns the expected constant - it does NOT prove that the module's storage layout is identical to `MarketEngineState`. A malicious or incorrectly implemented module could inherit `MarketEngineState` (getting the correct marker) but add additional state variables BEFORE the inherited ones (by using a different inheritance order or by declaring variables in the module itself before calling `super`), causing storage layout misalignment. The comment in the code acknowledges this: 'it only proves the module implements this selector with the expected constant, not that bytecode matches MarketEngineState storage.'


Hide Details
Impact
A module with incorrect storage layout (even if it correctly returns the compatibility marker) could corrupt the dispatcher's storage when executed via delegatecall. This could lead to: overwriting the `admin` address, corrupting vault balances, modifying oracle configurations, or other critical state corruption. The impact is critical if exploited.
Scenario
1. Attacker creates a malicious module that inherits `MarketEngineState` (gets correct marker)
2. Module adds a new state variable at the top of its own contract (before inherited variables)
3. This shifts all inherited storage slots by 1
4. Module passes the compatibility check (returns correct marker)
5. When executed via delegatecall, all storage reads/writes are off by 1 slot
6. `admin` slot now reads/writes to `stakeToken` slot, etc.
7. Attacker can overwrite `admin` by writing to what they think is `stakeToken`
Affected code
/// @notice Delegatecall module compatibility marker.
/// @dev Dispatcher verifies this marker on registration and before delegatecall; it only proves the module
/// implements this selector with the expected constant, not that bytecode matches `MarketEngineState` storage.
/// Trust / deployment: primitives (`admin`, `stakeToken`, `oracleConfig`, …) are set in
/// `MarketEngineDispatcher.initialize` on the UUPS proxy. Mappings default to empty. A proxy that
/// skips `initialize` is broken by design—operational risk, not an on-chain uninitialized read.
function marketEngineStorageCompatibility() external pure returns (bytes32) {
return MODULE_STORAGE_COMPATIBILITY_ID;
}
Proposed fix
Implement a more robust storage layout verification mechanism:
// Add a storage layout hash that includes slot positions of critical variables
bytes32 internal constant STORAGE_LAYOUT_HASH = keccak256(abi.encode(
    // Include slot numbers of critical variables
    uint256(0), // slot of stakeToken
    uint256(6), // slot of configInitialized
    uint256(7)  // slot of admin
    // etc.
));

function marketEngineStorageLayoutHash() external pure returns (bytes32) {
    return STORAGE_LAYOUT_HASH;
}
Also use the OpenZeppelin Upgrades plugin or Foundry's storage layout comparison tools in CI/CD to automatically verify that all modules have identical storage layouts to `MarketEngineState`. Consider using the EIP-7201 namespaced storage pattern to completely avoid storage collision risks.

medium Severity
5
1

MarketEngineUserOpsClaimsModule.sol
claimMany Batch DoS via Front-Running or Partial Claim State
The `claimMany` function iterates over an array of `epochIds` and calls `_claimOne` for each. If any single `_claimOne` call reverts (e.g., `AlreadyClaimed`, `NothingToClaim`, `ClaimNotAvailable`), the entire batch transaction reverts. An attacker can front-run a user's `claimMany` transaction by claiming one of the epochs in the batch first, causing the user's batch to revert with `AlreadyClaimed`. This forces the user to resubmit with a filtered list, wasting gas and potentially causing repeated front-running. Additionally, if a user accidentally includes an epoch where they have no winning position, the entire batch fails with `NothingToClaim`.


Hide Details
Impact
Users can be griefed by front-runners who claim one epoch in a batch, causing the entire batch to revert. This wastes gas and forces users to resubmit transactions. In high-gas environments, this could make batch claiming economically unviable. The attack is cheap for the attacker (they claim their own position) but costly for the victim (repeated failed transactions).
Scenario
1. User Alice has winning positions in epochs [1, 2, 3] and submits `claimMany(templateId, [1, 2, 3])`
2. Attacker Bob sees this in the mempool
3. Bob (or Alice herself in a separate tx) claims epoch 1 first with higher gas
4. Alice's `claimMany` reaches `_claimOne` for epoch 1, finds `pos.claimed == true`, reverts with `AlreadyClaimed`
5. Alice's entire batch fails, she must resubmit with `[2, 3]`
6. Bob can repeat this attack for epoch 2, forcing Alice to claim one at a time
Affected code
function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
_validateBatchSize(epochIds.length);
uint256 total = 0;
for (uint256 i = 0; i < epochIds.length; i++) {
uint256 amt = _claimOne(templateId, epochIds[i], msg.sender);
total += amt;
emit Claimed(templateId, epochIds[i], msg.sender, amt);
}
if (total == 0) revert NothingToClaim();
stakeToken.safeTransfer(msg.sender, total);
}
Proposed fix
Use a try/catch pattern within the loop to skip failed claims, or add a `skipErrors` parameter:
function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
    _validateBatchSize(epochIds.length);
    uint256 total = 0;
    for (uint256 i = 0; i < epochIds.length; i++) {
        // Skip already-claimed or unavailable epochs instead of reverting
        MarketTypes.Epoch storage e = _epochs[templateId][epochIds[i]];
        if (!e.claimable) continue;
        bytes32 pk = positionKey(templateId, epochIds[i]);
        MarketTypes.Position storage pos = _positions[pk][msg.sender];
        if (pos.claimed) continue;
        
        uint256 amt = _claimOne(templateId, epochIds[i], msg.sender);
        if (amt > 0) {
            total += amt;
            emit Claimed(templateId, epochIds[i], msg.sender, amt);
        }
    }
    if (total == 0) revert NothingToClaim();
    stakeToken.safeTransfer(msg.sender, total);
}
2

MarketEngineUserOpsClaimsModule.sol
ReentrancyGuardTransient Storage Slot Collision with Delegatecall Architecture
The `MarketEngineUserOpsClaimsModule` inherits both `MarketEngineState` and `ReentrancyGuardTransient`. When this module is executed via `delegatecall` from the `MarketEngineDispatcher`, the `ReentrancyGuardTransient` uses transient storage (EIP-1153) which is scoped to the transaction and the calling contract's context. However, the critical issue is that `ReentrancyGuardTransient` from OpenZeppelin uses a fixed transient storage slot derived from the contract's own storage layout. When executed via `delegatecall`, the transient storage slot used by the module's `nonReentrant` modifier operates in the dispatcher's transient storage context. If multiple modules use `ReentrancyGuardTransient` and they share the same transient storage slot (which they will, since the slot is computed from the same constant in the inherited contract), a call to one module's `nonReentrant` function could block calls to another module's `nonReentrant` function within the same transaction. More critically, if the dispatcher itself or another module also uses `ReentrancyGuardTransient` with the same slot, cross-module reentrancy protection could be inadvertently triggered or bypassed. The transient storage slot for `ReentrancyGuardTransient` in OpenZeppelin is `keccak256('openzeppelin.reentrancy_guard_transient') - 1`, which is a fixed value. All modules inheriting this will use the same slot in the dispatcher's transient storage context during delegatecall, meaning the guard is effectively shared across all modules - which could be a feature or a bug depending on the intended design.


Hide Details
Impact
If the transient storage slot collision is unintentional, it could cause legitimate multi-step transactions that call different module functions to fail with reentrancy errors. Conversely, if the intent was to have per-module reentrancy guards, the shared slot means a reentrant call from one module's callback could be blocked by another module's guard state, or vice versa. In the worst case, if the slot assignment differs between the module and dispatcher, the guard could be ineffective against cross-module reentrancy.
Scenario
1. User calls `depositToSide` on the dispatcher (delegatecalls to UserOpsClaimsModule)
2. The `nonReentrant` modifier sets the transient storage slot in the DISPATCHER's transient storage
3. During the yield router callback (if any), if another module function is called that also uses `nonReentrant` with the same slot, it will revert with ReentrancyGuardReentrantCall
4. This could cause legitimate batched operations to fail unexpectedly
5. Alternatively, if a different slot is used per module instance, cross-module reentrancy is not protected
Affected code
contract MarketEngineUserOpsClaimsModule is MarketEngineState, ReentrancyGuardTransient {
function depositToSide(bytes32 templateId, uint64 epochId, uint8 outcomeIndex, uint256 amount)
external
nonReentrant
{
if (globalPaused) revert ProtocolPaused();
_depositToSide(msg.sender, msg.sender, templateId, epochId, outcomeIndex, amount);
}
Proposed fix
Explicitly document and verify the transient storage slot behavior under delegatecall. Consider using a custom reentrancy guard that uses a well-known, explicitly defined transient storage slot that is consistent across all modules. Alternatively, implement the reentrancy guard at the dispatcher level rather than in individual modules to ensure consistent behavior:
// In MarketEngineState, define a canonical transient storage slot
bytes32 internal constant REENTRANCY_GUARD_SLOT = keccak256('retropick.marketengine.reentrancy.v1') - 1;

modifier nonReentrant() {
    assembly {
        if tload(REENTRANCY_GUARD_SLOT) { revert(0, 0) }
        tstore(REENTRANCY_GUARD_SLOT, 1)
    }
    _;
    assembly {
        tstore(REENTRANCY_GUARD_SLOT, 0)
    }
}
3

MarketEngineUserOpsClaimsModule.sol
Residual Token Approval Left After Failed Yield Router Deposit
In `_depositToSide`, the code calls `stakeToken.forceApprove(address(r), routeAmount)` BEFORE the `try r.depositScaled(...)` block. If the `depositScaled` call fails (caught by the `catch` block), the approval for `routeAmount` tokens to the yield router remains active. This means the yield router retains an active allowance to pull `routeAmount` tokens from the contract at any future time. If the yield router is later compromised or has a vulnerability, this residual approval could be exploited to drain tokens from the contract.


Hide Details
Impact
If the yield router deposit fails (caught exception), the contract retains an active ERC20 approval for `routeAmount` tokens to the router address. Over time, multiple failed deposits accumulate approvals. If the router is later compromised or replaced with a malicious contract at the same address (e.g., via a proxy upgrade), the attacker can drain all accumulated approved amounts. Even with a legitimate router, the residual approval is an unnecessary attack surface.
Scenario
1. Multiple users call `depositToSide`, each triggering a failed `depositScaled` (router temporarily down)
2. Each failure leaves an approval of `routeAmount` to the router
3. After N failed deposits, the router has approval for sum of all `routeAmount` values
4. If router is compromised, attacker calls `transferFrom(engine, attacker, totalApproved)` to drain funds
Affected code
IYieldRouterV2 r = yieldRouter;
if (address(r) != address(0)) {
uint256 routeAmount = (amount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
if (routeAmount > 0) {
stakeToken.forceApprove(address(r), routeAmount);
try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) {
if (attributionUnits > 0) {
e.routedPrincipal += routeAmount;
} else {
emit YieldRouterDepositFailed(templateId, routeAmount);
}
}
catch {
emit YieldRouterDepositFailed(templateId, routeAmount);
}
}
}
Proposed fix
Reset the approval to zero in the catch block:
stakeToken.forceApprove(address(r), routeAmount);
try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) {
    if (attributionUnits > 0) {
        e.routedPrincipal += routeAmount;
    } else {
        stakeToken.forceApprove(address(r), 0); // Reset approval on zero attribution
        emit YieldRouterDepositFailed(templateId, routeAmount);
    }
}
catch {
    stakeToken.forceApprove(address(r), 0); // Reset approval on failure
    emit YieldRouterDepositFailed(templateId, routeAmount);
}
4

MarketEngineUserOpsClaimsModule.sol
Incorrect Vault Accounting in switchSide: vault.active Decremented Before Fee Withdrawal
In `switchSide`, when a fee is collected, the code first decrements `vault.active -= feeAmount` and increments `vault.fees += feeAmount`, then calls `_withdrawSwitchFeePrincipal`. Inside `_withdrawSwitchFeePrincipal`, if the yield router returns more than `principalToWithdraw` (i.e., yield was accrued), the excess is added to `vault.fees += grossYield` and `ledger.feeReserveTotal += grossYield`. However, the `vault.active` balance was already decremented by `feeAmount` before the yield router withdrawal. The yield returned (`grossReturned`) increases the contract's actual token balance, but `vault.active` is not credited with the returned principal portion. This means `vault.active` is understated by `principalToWithdraw` (the amount withdrawn from the router and returned to the contract), since the returned principal is not added back to `vault.active` - it's only the yield portion that goes to `vault.fees`. The principal itself just sits in the contract balance without being tracked in any vault bucket.


Hide Details
Impact
The vault accounting becomes inconsistent: `vault.active + vault.claims + vault.fees` may not equal the actual token balance of the contract. The principal withdrawn from the yield router (`principalToWithdraw`) is returned to the contract's token balance but is not reflected in any vault bucket. Over time, this creates a growing discrepancy between the vault accounting and actual token holdings. This could cause `VaultInsufficientActive` reverts during epoch resolution if the vault.active is understated, or allow more fees to be withdrawn than should be available.
Scenario
1. User deposits 1000 tokens, 950 routed to yield router, `vault.active = 1000`, `routedPrincipal = 950`
2. User switches side, `feeAmount = 10`
3. `vault.active -= 10` → `vault.active = 990`
4. `vault.fees += 10` → `vault.fees = 10`
5. `_withdrawSwitchFeePrincipal` withdraws `principalToWithdraw = 9` from router
6. Router returns `grossReturned = 9` (no yield), `e.routedPrincipal -= 9` → `routedPrincipal = 941`
7. Contract balance increases by 9 (from router), but `vault.active` is still 990
8. Actual balance = 50 (buffer) + 9 (returned) = 59 tokens in contract
9. `vault.active = 990` but only 59 tokens are actually in the contract (941 still in router)
10. The 9 returned tokens are unaccounted in vault buckets
Affected code
if (feeAmount > 0) {
MarketTypes.VaultBalances storage vault = _vaults[templateId];
vault.active -= feeAmount;
vault.fees += feeAmount;
MarketMath.reserveFeesFromActive(ledger, feeAmount);
_withdrawSwitchFeePrincipal(templateId, epochId, feeAmount, vault, ledger);
}

// In _withdrawSwitchFeePrincipal:
uint256 grossReturned = _balanceDeltaAfterWithdrawScaled(r, templateId, principalToWithdraw);
e.routedPrincipal -= principalToWithdraw;
if (grossReturned > principalToWithdraw) {
uint256 grossYield = grossReturned - principalToWithdraw;
vault.fees += grossYield;
ledger.feeReserveTotal += grossYield;
}
Proposed fix
The principal returned from the yield router should be tracked. Since the fee was already moved from `vault.active` to `vault.fees`, the returned principal (which is part of the fee) is correctly in `vault.fees`. However, the issue is that `vault.active` was decremented by the full `feeAmount` but only `feeAmount - principalToWithdraw` worth of tokens remain in the router for that fee. The accounting should be:
// The fee amount is correctly moved from active to fees
// The principal withdrawal from router just converts router-held tokens to contract-held tokens
// No additional vault accounting change is needed for the principal return
// BUT: the vault.active should only be decremented by the non-routed portion of the fee
// since the routed portion is being reclaimed

// Consider: after withdrawal, vault.active should reflect that the principal is back
// One approach: don't decrement vault.active for the routed portion until it's confirmed withdrawn
A cleaner fix is to ensure the accounting correctly reflects that `principalToWithdraw` tokens are moving from the router back to the contract's liquid balance, and this should be reflected in vault accounting. Review the full accounting flow to ensure `sum(vault.active, vault.claims, vault.fees) == stakeToken.balanceOf(address(this)) + routedPrincipalTotal` invariant holds.
5

MarketMath.sol
Division by Zero in computeClaimPayoutStorage When winningPool is Zero After Epoch Resolution
In `computeClaimPayoutStorage`, the code computes `entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool`. If `winningPool` is zero, this causes a division by zero revert. While `computeClaimLiabilityComponents` handles the case where `winningPool == 0` by returning `(totalPool, 0, totalPool)` (refund mode), the `computeClaimPayoutStorage` function is called during the claim phase AFTER resolution. The epoch's `refundMode` flag should be set if `winningPool == 0`, and `_claimOne` checks `e.refundMode` before calling `computeClaimPayoutStorage`. However, there's a subtle edge case: if `winningPool` becomes zero AFTER resolution due to a bug in `_setRemainingWinningStake` or if the epoch was resolved with a non-zero `winningOutcomeMask` but all winning outcome pools are actually zero (e.g., due to all winners switching sides after lock), `computeClaimPayoutStorage` would be called with `winningPool = 0` and revert.


Hide Details
Impact
If `winningPool` is zero when `computeClaimPayoutStorage` is called (which should not happen in normal flow but could occur due to edge cases), all claim transactions for that epoch will revert with a division by zero error, permanently locking user funds in the epoch. Users with winning positions would be unable to claim their winnings.
Scenario
1. Epoch is resolved with `winningOutcomeMask` pointing to outcome 0
2. Due to a bug or edge case, `epoch.outcomePools[0] == 0` at resolution time
3. `_applyResolveAccounting` sets `refundMode = false` (since `winningPool != 0` was checked at resolution)
4. But `outcomePools[0]` is actually 0 at claim time
5. User calls `claim`, `_claimOne` calls `computeClaimPayoutStorage`
6. `winningPool = 0`, division by zero revert
7. All claims for this epoch are permanently blocked
Affected code
function computeClaimPayoutStorage(
MarketTypes.Epoch storage epoch,
uint256[8] memory stakes,
uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
// ...
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
Add a zero-check guard in `computeClaimPayoutStorage`:
function computeClaimPayoutStorage(
    MarketTypes.Epoch storage epoch,
    uint256[8] memory stakes,
    uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
    // ...
    uint256 winningPool = 0;
    for (uint256 i = 0; i < outcomeCount; i++) {
        if ((winningMask >> i) & 1 == 1) {
            winningPool += epoch.outcomePools[i];
        }
    }
    
    // Guard against division by zero - should not happen in normal flow
    // but protects against edge cases
    if (winningPool == 0) return (0, 0);
    
    uint256 distributableLosing = _distributableLosingPoolForClaimsStorage(epoch, winningPool);
    uint256 entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool;
    // ...
}

low Severity
8
1

MarketEngineUserOpsClaimsModule.sol
Precision Loss in Yield Buffer Calculation for Small Deposit Amounts
The yield routing calculation `routeAmount = (amount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000` uses integer division. For small deposit amounts, this can result in `routeAmount = 0`, silently skipping yield routing. The `YIELD_BUFFER_BPS = 500` means 95% of deposits are routed. For amounts less than `10_000 / 9_500 ≈ 1.05` tokens (in the smallest denomination), `routeAmount` will be 0. Similarly, in `_withdrawSwitchFeePrincipal`, `principalToWithdraw = (feeAmount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000` can be 0 for small fees. While the code checks `if (routeAmount > 0)` and `if (principalToWithdraw == 0) return`, the issue is that over many small deposits, the unrouted buffer accumulates in the contract without being tracked separately, potentially creating accounting discrepancies.


Hide Details
Impact
For tokens with low decimal precision (e.g., USDC with 6 decimals), deposits of less than ~1.05 USDC would have `routeAmount = 0`, meaning no yield is generated on these deposits. While this is a minor economic inefficiency, it could be significant if the protocol is used with low-value deposits. The accumulated unrouted buffer also creates a discrepancy between `vault.active` and the actual tokens in the contract vs. the router.
Scenario
1. Token has 6 decimals (e.g., USDC)
2. User deposits 1 USDC (1,000,000 units)
3. `routeAmount = (1,000,000 * 9,500) / 10,000 = 950,000` - correctly routed
4. User deposits 0.000001 USDC (1 unit)
5. `routeAmount = (1 * 9,500) / 10,000 = 0` - not routed
6. Over 10,000 such deposits, 10,000 units are in the contract but not in the router
7. `vault.active` includes these 10,000 units but they're not generating yield
Affected code
IYieldRouterV2 r = yieldRouter;
if (address(r) != address(0)) {
uint256 routeAmount = (amount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
if (routeAmount > 0) {
stakeToken.forceApprove(address(r), routeAmount);
// ...
}
}
Proposed fix
This is an acceptable design trade-off for gas efficiency. Document the minimum deposit amount for yield routing. Consider adding a minimum deposit amount check or documenting the behavior:
// Document minimum effective deposit for yield routing
// routeAmount > 0 requires: amount > 10_000 / (10_000 - YIELD_BUFFER_BPS)
// For YIELD_BUFFER_BPS = 500: amount > 10_000 / 9_500 ≈ 1.053 (in token units)
uint256 routeAmount = (amount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
2

MarketEngineUserOpsClaimsModule.sol
userEpochs Array Can Grow Unboundedly Causing Gas DoS on Reads
The `_userEpochs[templateId][beneficiary]` array is pushed to every time a user makes their first deposit in an epoch: `_userEpochs[templateId][beneficiary].push(epochId)`. There is no limit on how many epochs a user can participate in. Over time, this array can grow to thousands of entries. While `MAX_USER_EPOCHS_PAGE_SIZE = 256` suggests pagination is intended for reads, any function that iterates over this array without pagination (if such functions exist in other modules) could hit gas limits. Additionally, the array is never pruned even after epochs are resolved and claimed, meaning it grows indefinitely.


Hide Details
Impact
For highly active users participating in many epochs, the `_userEpochs` array grows indefinitely. Any off-chain or on-chain function that reads this array without pagination could fail due to gas limits. While the `MAX_USER_EPOCHS_PAGE_SIZE = 256` constant suggests pagination is used, if any module iterates the full array, it could cause DoS for active users.
Scenario
1. User participates in 10,000 epochs over time
2. `_userEpochs[templateId][user]` has 10,000 entries
3. Any function that reads the full array (e.g., a view function for user history) would require enormous gas
4. If such a function is called on-chain, it could exceed block gas limits
Affected code
if (!pos.initialized) {
pos.version = MarketTypes.VERSION;
pos.initialized = true;
e.totalPositions += 1;
_userEpochs[templateId][beneficiary].push(epochId);
emit UserEpochIndexed(templateId, epochId, beneficiary);
}
Proposed fix
Ensure all functions that read `_userEpochs` use pagination with `MAX_USER_EPOCHS_PAGE_SIZE`. Consider adding a maximum epochs per user limit or implementing a circular buffer. Also consider adding a cleanup mechanism to remove claimed epochs from the array:
// Add a maximum user epochs limit
uint256 internal constant MAX_USER_EPOCHS_PER_TEMPLATE = 10_000;

if (!pos.initialized) {
    require(_userEpochs[templateId][beneficiary].length < MAX_USER_EPOCHS_PER_TEMPLATE, "Too many epochs");
    // ...
    _userEpochs[templateId][beneficiary].push(epochId);
}
3

MarketMath.sol
Last-Claimer Remainder Rule Can Be Gamed to Steal Excess Funds
The last-claimer remainder rule in `computeClaimPayoutStorage` states: if `epoch.remainingWinningStake == userWinningStake_`, the user receives ALL remaining claims (`remainingClaimsForEpoch`). This is designed to prevent dust. However, `remainingClaimsForEpoch` is computed as `e.claimLiabilityTotal - e.claimedTotal` in `_claimOne`. If earlier claimers received LESS than their pro-rata entitlement (due to integer truncation), the last claimer receives MORE than their fair share - specifically, they receive all the truncated dust from previous claimers. While this is the intended design, there's a more serious issue: if a user with a large winning stake claims LAST, they receive all remaining claims which could be significantly more than their pro-rata share if many small claimers have already claimed and left dust. More critically, the `remainingWinningStake` is decremented by `winningStake` (not by the payout amount), so the last-claimer check `epoch.remainingWinningStake == userWinningStake_` could be triggered prematurely if the accounting is off.


Hide Details
Impact
A sophisticated user who knows they have the last winning position can claim last to receive all remaining claims, which may be more than their fair pro-rata share. While this is partially intentional (dust prevention), it creates an incentive for winners to delay claiming to be the last claimer. More importantly, if `remainingWinningStake` tracking is incorrect (e.g., due to the vault accounting issues described elsewhere), the last-claimer rule could be triggered for non-last claimers, allowing them to drain the entire claims reserve.
Scenario
1. Epoch resolves with 3 winners: Alice (100 stake), Bob (100 stake), Carol (1 stake)
2. Total winning pool = 201, distributable losing = 1000
3. Alice's entitlement = 100 + (100 * 1000/201) ≈ 597 (truncated)
4. Bob's entitlement = 100 + (100 * 1000/201) ≈ 597 (truncated)
5. Carol's entitlement = 1 + (1 * 1000/201) ≈ 5 (truncated)
6. Total entitlements ≈ 1199, but claimLiabilityTotal = 1201
7. Alice claims: gets 597, remainingWinningStake = 101
8. Bob claims: gets 597, remainingWinningStake = 1
9. Carol claims: remainingWinningStake == userWinningStake (1 == 1), gets ALL remaining = 1201 - 597 - 597 = 7
10. Carol gets 7 instead of 5, receiving 2 extra tokens from truncation dust
Affected code
function _claimOne(bytes32 templateId, uint64 epochId, address user) internal returns (uint256 amount) {
// ...
uint256[8] memory stakes = pos.stakes;
uint256 remainingClaims = e.claimLiabilityTotal - e.claimedTotal;
(amount, winningStake) = MarketMath.computeClaimPayoutStorage(e, stakes, remainingClaims);
// ...
e.claimedTotal += amount;
if (!e.refundMode) e.remainingWinningStake -= winningStake;
}
Proposed fix
The current design is intentional for dust prevention. However, document this behavior clearly and consider adding a maximum payout cap to prevent the last claimer from receiving disproportionately more than their entitlement in edge cases:
// In computeClaimPayoutStorage, cap the last-claimer payout
if (epoch.remainingWinningStake == userWinningStake_) {
    // Last claimer gets remaining, but cap at a reasonable multiple of entitlement
    // to prevent gaming in edge cases
    payout = remainingClaimsForEpoch;
} else {
    payout = entitlement;
}
Also add monitoring/invariant checks to ensure `sum(all payouts) <= claimLiabilityTotal`.
4

MarketEngineState.sol
Storage Gap Insufficient for Future Upgrades Given Current State Variable Count
The `MarketEngineState` contract defines a `uint256[41] private __gap` storage gap for upgrade safety. However, the contract already has a large number of state variables. The gap is intended to allow future state variables to be added without shifting the storage layout of inherited contracts. Given the complexity of the protocol and the number of state variables already defined (approximately 30+ slots used), the 41-slot gap may be insufficient for significant future upgrades. Additionally, the dispatcher state variables (`selectorToModule` and `selectorImmutable` mappings) were appended after the legacy state, which is correct, but the gap was not adjusted to account for these additions. If the gap is exhausted in a future upgrade, new state variables would collide with storage slots used by other contracts or mappings.


Hide Details
Impact
If future upgrades add more state variables than the gap allows, storage collisions will occur silently, potentially corrupting critical state like `admin`, `stakeToken`, or vault balances. This is a latent risk that becomes critical during upgrades.
Scenario
1. Current contract uses ~30 storage slots for state variables
2. Gap is 41 slots
3. Future upgrade adds 42+ new state variables
4. New variables overflow the gap and collide with storage slots of the next contract in the inheritance chain
5. Critical state variables are silently overwritten
Affected code
// --- dispatcher state (appended after legacy state) ---
mapping(bytes4 selector => address module) internal selectorToModule;
mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

uint256[41] private __gap;
Proposed fix
Increase the storage gap to a larger value (e.g., 100 or 200 slots) to provide more headroom for future upgrades. Also implement automated storage layout verification in CI/CD to catch gap exhaustion before deployment:
// Increase gap size significantly
uint256[100] private __gap; // Increased from 41 to 100

// Add a comment documenting current slot usage
// Slot 0: stakeToken
// Slot 1: priceOracle
// ... etc.
// Current usage: ~30 slots
// Gap provides: 100 slots for future additions
Also consider using the OpenZeppelin Upgrades plugin's storage layout checker to automatically verify layout compatibility during upgrades.
5

MarketEngineUserOpsClaimsModule.sol
Epoch activeEpochId Constraint Prevents Multi-Epoch Deposits in Manual Mode
The `_requireActiveEpoch` function enforces that `epochId == ledger.activeEpochId`. In manual mode, this means only one epoch can accept deposits at a time. However, the `activeEpochId` is set when an epoch is opened and only updated when the epoch transitions. If the admin opens a new epoch while the previous one is still in `Locked` state (waiting for resolution), the `activeEpochId` would point to the new epoch, making the locked epoch's deposits inaccessible for new deposits (which is correct). But if there's a delay between epochs (e.g., admin hasn't opened the next epoch yet), users cannot deposit at all. More critically, in manual mode, if `activeEpochId` is 0 (uninitialized) or points to a non-existent epoch, all deposit attempts will revert with `EpochNotActive`, potentially causing a DoS on deposits.


Hide Details
Impact
Users cannot deposit into any epoch if `activeEpochId` is not set correctly or if there's a gap between epochs. This is a liveness issue that could prevent the protocol from functioning during epoch transitions. While not a direct fund loss vulnerability, it could cause user frustration and failed transactions.
Scenario
1. Admin opens epoch 1, `activeEpochId = 1`
2. Epoch 1 closes and is locked
3. Admin resolves epoch 1, `lastResolvedEpochId = 1`
4. Admin hasn't opened epoch 2 yet
5. User tries to deposit into epoch 1 (still claimable) - fails with EpochNotActive
6. User tries to deposit into epoch 2 (doesn't exist) - fails with EpochNotActive
7. No deposits possible until admin opens epoch 2
Affected code
function _requireActiveEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
if (epochId != ledger.activeEpochId) revert EpochNotActive();
}
Proposed fix
This is largely an operational/design issue. Document clearly that there will be deposit gaps between epochs. Consider adding a view function that returns the current active epoch status so users can check before attempting deposits. For manual mode, consider allowing deposits into any `Open` status epoch rather than only the `activeEpochId`:
function _requireActiveEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
    // For manual mode, allow any open epoch; for rolling mode, enforce activeEpochId
    if (epochId != ledger.activeEpochId) revert EpochNotActive();
    // Consider: check epoch status directly instead of relying solely on activeEpochId
}
6

MarketEngineState.sol
Missing Zero-Address Validation for Oracle Addresses in _resolveOracleByClass
In `_resolveOracleByClass`, the function checks for `address(0)` for `rateOracle`, `smartDataOracle`, `macroOracle`, and `equityOracle`, but for the default case (CHAINLINK_PRICE), it returns `priceOracle` without checking if it's `address(0)`. If `priceOracle` is not set (zero address), any market using the default CHAINLINK_PRICE oracle class would attempt to call functions on `address(0)`, which would revert with a low-level error rather than the descriptive `OracleAdapterNotConfigured` error.


Hide Details
Impact
If `priceOracle` is not initialized (zero address), calls to oracle functions will revert with a generic EVM error rather than the descriptive `OracleAdapterNotConfigured` error. This makes debugging harder and could cause unexpected behavior in oracle-dependent operations.
Scenario
1. Contract is deployed with `priceOracle = address(0)` (not initialized)
2. Admin creates a template with `oracleClass = CHAINLINK_PRICE` (default)
3. Worker tries to lock an epoch, calls `_resolveOracle(templateId)`
4. `_resolveOracleByClass` returns `address(0)` as `priceOracle`
5. Subsequent call to `priceOracle.getLatestPrice()` reverts with generic error
6. Error message is unhelpful for debugging
Affected code
function _resolveOracleByClass(MarketTypes.OracleClass oracleClass) internal view returns (IPriceOracle) {
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_RATE) {
if (address(rateOracle) == address(0)) revert OracleAdapterNotConfigured();
return rateOracle;
}
// ... other checks ...
return priceOracle; // No zero-address check for default case!
}
Proposed fix
Add a zero-address check for the default oracle case:
function _resolveOracleByClass(MarketTypes.OracleClass oracleClass) internal view returns (IPriceOracle) {
    if (oracleClass == MarketTypes.OracleClass.CHAINLINK_RATE) {
        if (address(rateOracle) == address(0)) revert OracleAdapterNotConfigured();
        return rateOracle;
    }
    // ... other checks ...
    // Default: CHAINLINK_PRICE
    if (address(priceOracle) == address(0)) revert OracleAdapterNotConfigured();
    return priceOracle;
}
7

MarketMath.sol
Potential Overflow in computeSwitch for Large grossAmount Values
In `computeSwitch`, the fee calculation is `fee = (grossAmount * uint256(switchFeeBps) + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR`. The intermediate value `grossAmount * uint256(switchFeeBps)` could overflow if `grossAmount` is very large. With `switchFeeBps` up to `uint16` max (65535) and `grossAmount` up to `uint256` max, the multiplication `grossAmount * uint256(switchFeeBps)` would overflow for `grossAmount > type(uint256).max / 65535`. However, since Solidity 0.8.x has built-in overflow protection, this would revert rather than silently overflow. The revert would prevent the switch operation, which is a DoS for large amounts. The `+ BPS_DENOMINATOR - 1` addition could also overflow if `grossAmount * switchFeeBps` is close to `type(uint256).max`.


Hide Details
Impact
For extremely large `grossAmount` values (near `type(uint256).max / switchFeeBps`), the `switchSide` function would revert with an arithmetic overflow error. This is a DoS for users with very large positions attempting to switch sides. In practice, this requires `grossAmount > type(uint256).max / 65535 ≈ 2.8 * 10^72`, which is astronomically large and unlikely in practice.
Scenario
1. User has a position with `stakes[0] = type(uint256).max / 2` (extremely large)
2. User calls `switchSide` with `grossAmount = type(uint256).max / 2`
3. `computeSwitch` computes `grossAmount * switchFeeBps` which overflows
4. Transaction reverts with arithmetic overflow
5. User cannot switch sides despite having valid stake
Affected code
function computeSwitch(uint256 grossAmount, uint16 switchFeeBps) internal pure returns (uint256 net, uint256 fee) {
if (switchFeeBps == 0) return (grossAmount, 0);
fee = (grossAmount * uint256(switchFeeBps) + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
if (fee > grossAmount) revert MathOverflow();
net = grossAmount - fee;
}
Proposed fix
Use a safer multiplication approach to prevent overflow:
function computeSwitch(uint256 grossAmount, uint16 switchFeeBps) internal pure returns (uint256 net, uint256 fee) {
    if (switchFeeBps == 0) return (grossAmount, 0);
    // Use mulDiv-style calculation to prevent overflow
    // fee = ceil(grossAmount * switchFeeBps / BPS_DENOMINATOR)
    uint256 q = grossAmount / BPS_DENOMINATOR;
    uint256 r = grossAmount % BPS_DENOMINATOR;
    fee = q * uint256(switchFeeBps) + (r * uint256(switchFeeBps) + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
    if (fee > grossAmount) revert MathOverflow();
    net = grossAmount - fee;
}
8

MarketMath.sol
Ladder Market Payout Weight Validation Missing in MarketMath
In `computeLadderLiabilityComponents`, the `winnerWeightBps` parameter is used to compute the distributable losing pool. The function checks `if (winnerWeightBps >= BPS_DENOMINATOR)` and returns the base components unchanged. However, there is no validation that `winnerWeightBps > 0`. If `winnerWeightBps = 0`, the computation proceeds: `distributableLosingPool = (baseDistributableLosingPool * 0) / BPS_DENOMINATOR = 0`, meaning winners receive only their original stake back (no share of the losing pool), and the entire losing pool goes to protocol fees. This may or may not be intended behavior, but it's not explicitly documented and could be a misconfiguration risk.


Hide Details
Impact
If a Ladder market is configured with `ladderPayoutWeightsBps[winnerIdx] = 0`, winners receive only their original stake back and the entire losing pool is taken as protocol fees. This could be an unintended configuration that disadvantages users. The protocol would collect 100% of the losing pool as fees, which may violate user expectations.
Scenario
1. Admin creates a Ladder market with `ladderPayoutWeightsBps = [0, 0, 0, ...]`
2. Epoch resolves with outcome 0 winning
3. `winnerWeightBps = 0`
4. `distributableLosingPool = 0`
5. Winners only get their stake back, entire losing pool goes to fees
6. Users who bet on the winning side receive no profit
Affected code
function computeLadderLiabilityComponents(
uint256 totalPool,
uint256 winningPool,
uint16 feeBps,
bool feeOnLosingPool,
uint16 winnerWeightBps
) internal pure returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool) {
(uint256 baseClaimLiability, uint256 baseSettlementFee, uint256 baseDistributableLosingPool) =
computeClaimLiabilityComponents(totalPool, winningPool, feeBps, feeOnLosingPool);
if (winningPool == 0) return (baseClaimLiability, baseSettlementFee, baseDistributableLosingPool);
if (winnerWeightBps >= BPS_DENOMINATOR) return (baseClaimLiability, baseSettlementFee, baseDistributableLosingPool);
distributableLosingPool = (baseDistributableLosingPool * uint256(winnerWeightBps)) / BPS_DENOMINATOR;
settlementFee = baseSettlementFee + (baseDistributableLosingPool - distributableLosingPool);
claimLiabilityTotal = winningPool + distributableLosingPool;
}
Proposed fix
Add validation in the template upsert function to ensure `ladderPayoutWeightsBps` values are non-zero for active outcomes, or document that zero weight means no losing pool distribution:
// In template validation (upsertTemplate module):
if (template.marketType == MarketType.Ladder) {
    for (uint8 i = 0; i < template.outcomeCount; i++) {
        require(template.ladderPayoutWeightsBps[i] > 0, "Ladder weight must be > 0");
        require(template.ladderPayoutWeightsBps[i] <= BPS_DENOMINATOR, "Ladder weight must be <= 10000");
    }
}

gas Severity
1
1

MarketEngineUserOpsClaimsModule.sol
Missing Validation That outcomeIndex < e.outcomeCount in switchSide Before Position Access
In `switchSide`, the code validates `fromOutcome >= MarketTypes.MAX_OUTCOMES || toOutcome >= MarketTypes.MAX_OUTCOMES` (checking against the global MAX_OUTCOMES = 8), but the check against the epoch's actual `outcomeCount` happens AFTER loading the epoch storage: `if (!(uint256(fromOutcome) < uint256(e.outcomeCount) && uint256(toOutcome) < uint256(e.outcomeCount)))`. Between the initial MAX_OUTCOMES check and the outcomeCount check, the code calls `_requireActiveEpoch(ledger, epochId)` which loads the ledger. The position access `_positions[pk][msg.sender]` happens after the outcomeCount check, so this is fine. However, the `pos.stakes[fromOutcome]` access uses `fromOutcome` as an array index into a fixed-size `uint256[MAX_OUTCOMES]` array. Since `fromOutcome < MAX_OUTCOMES` is checked, this is safe from out-of-bounds. But the check order means that if `fromOutcome >= e.outcomeCount` but `< MAX_OUTCOMES`, the revert happens after loading the epoch, which is a minor gas inefficiency but not a security issue.


Hide Details
Impact
Minor gas inefficiency - storage is loaded before the outcomeCount validation. No security impact as the bounds check against MAX_OUTCOMES prevents array out-of-bounds access.
Scenario
N/A - This is a gas optimization issue, not a security vulnerability.
Affected code
if (fromOutcome >= MarketTypes.MAX_OUTCOMES || toOutcome >= MarketTypes.MAX_OUTCOMES) revert InvalidOutcome();

MarketTypes.Template storage t = _templates[templateId];
MarketTypes.Ledger storage ledger = _ledgers[templateId];
if (!ledger.initialized) revert InvalidTemplate();
// ...
_requireActiveEpoch(ledger, epochId);

MarketTypes.Epoch storage e = _epochs[templateId][epochId];
if (!(uint256(fromOutcome) < uint256(e.outcomeCount) && uint256(toOutcome) < uint256(e.outcomeCount))) {
revert InvalidOutcome();
}
Proposed fix
Reorder checks to fail fast before loading storage:
// Check MAX_OUTCOMES bounds first (already done)
if (fromOutcome >= MarketTypes.MAX_OUTCOMES || toOutcome >= MarketTypes.MAX_OUTCOMES) revert InvalidOutcome();

// Load epoch first to check outcomeCount before loading template/ledger
MarketTypes.Epoch storage e = _epochs[templateId][epochId];
if (!(uint256(fromOutcome) < uint256(e.outcomeCount) && uint256(toOutcome) < uint256(e.outcomeCount))) {
    revert InvalidOutcome();
}

// Then load template and ledger
MarketTypes.Template storage t = _templates[templateId];
MarketTypes.Ledger storage ledger = _ledgers[templateId];

informational Severity
3
1

MarketMath.sol
computeClaimPayoutStorage Reads epoch.settlementFeeBps and epoch.feeOnLosingPool from Storage Indirectly via _distributableLosingPoolForClaimsStorage
In `computeClaimPayoutStorage`, the distributable losing pool is computed via `_distributableLosingPoolForClaimsStorage(epoch, winningPool)`, which internally reads `epoch.settlementFeeBps` and `epoch.feeOnLosingPool` from storage. These values are snapshotted from the template at epoch open time and stored in the epoch struct. However, if the epoch's `settlementFeeBps` or `feeOnLosingPool` were somehow modified after resolution (which should not happen in normal flow), the claim payout calculation would use incorrect values. More importantly, the `claimLiabilityTotal` stored in the epoch was computed at resolution time using the SAME `settlementFeeBps` and `feeOnLosingPool`. If these values differ between resolution and claim time (due to a bug or upgrade), the computed `entitlement` in `computeClaimPayoutStorage` would not match the actual `claimLiabilityTotal`, potentially causing the last-claimer to receive more or less than expected.


Hide Details
Impact
If epoch parameters are modified after resolution (which requires a bug or malicious upgrade), claim payouts would be computed incorrectly. The last-claimer remainder rule partially mitigates this by ensuring all funds are eventually distributed, but intermediate claimers could receive incorrect amounts.
Scenario
N/A - This requires a bug or malicious upgrade to trigger. Informational finding about the dependency on epoch-stored parameters.
Affected code
function _distributableLosingPoolForClaimsStorage(MarketTypes.Epoch storage epoch, uint256 winningPool)
private
view
returns (uint256)
{
if (epoch.marketType == MarketTypes.MarketType.Ladder) {
uint8 winnerIdx = _firstWinningOutcomeIndex(epoch.winningOutcomeMask, epoch.outcomeCount);
uint16 w = epoch.ladderPayoutWeightsBps[winnerIdx];
(,, uint256 distLadder) = computeLadderLiabilityComponents(
epoch.totalPool, winningPool, epoch.settlementFeeBps, epoch.feeOnLosingPool, w
);
return distLadder;
}
(,, uint256 distStd) = computeClaimLiabilityComponents(
epoch.totalPool, winningPool, epoch.settlementFeeBps, epoch.feeOnLosingPool
);
return distStd;
}
Proposed fix
This is an acceptable design choice since epoch parameters are snapshotted at open time and should not change after resolution. Add explicit invariant checks or documentation:
// In _applyResolveAccounting, consider storing the computed distributableLosingPool
// directly in the epoch to avoid recomputation during claims
// e.distributableLosingPool = outputs.distributableLosingPool;
// This would make claim computation independent of fee parameters
2

MarketEngineUserOpsClaimsModule.sol
Inconsistent configInitialized Check Between switchSide and _depositToSide
In `switchSide`, the `configInitialized` check is done explicitly: `if (!configInitialized) revert Unauthorized()`. In `_depositToSide`, the same check is also done: `if (!configInitialized) revert Unauthorized()`. However, in `depositToSide` and `depositToSideFor` (the external wrappers), there is no `configInitialized` check before calling `_depositToSide` - the check is delegated to the internal function. In `switchSide`, the check is done in the external function itself. This inconsistency is minor but could lead to confusion. More importantly, `depositToSide` checks `globalPaused` before `configInitialized`, meaning if the contract is not initialized, it would revert with `ProtocolPaused` (if `globalPaused` is somehow true on an uninitialized contract) rather than `NotInitialized` or `Unauthorized`. Since `globalPaused` defaults to `false`, this is not a practical issue, but the error message could be misleading.


Hide Details
Impact
Minor inconsistency in error handling. No security impact. Could cause confusion during debugging if an uninitialized contract emits unexpected error codes.
Scenario
N/A - Informational finding.
Affected code
function depositToSide(bytes32 templateId, uint64 epochId, uint8 outcomeIndex, uint256 amount)
external
nonReentrant
{
if (globalPaused) revert ProtocolPaused(); // checked before configInitialized
_depositToSide(msg.sender, msg.sender, templateId, epochId, outcomeIndex, amount);
// configInitialized checked inside _depositToSide
}

function switchSide(...) external nonReentrant {
if (globalPaused) revert ProtocolPaused();
if (!configInitialized) revert Unauthorized(); // explicit check here
// ...
}
Proposed fix
Standardize the check order across all external functions. Consider using the `_authAdmin` pattern or a dedicated modifier:
modifier whenInitialized() {
    if (!configInitialized) revert NotInitialized();
    _;
}

function depositToSide(...) external nonReentrant whenInitialized {
    if (globalPaused) revert ProtocolPaused();
    _depositToSide(...);
}
3

MarketEngineState.sol
EpochResolved Event Emits Incorrect claimLiabilityTotal in Refund Mode
In `_applyResolveAccounting`, when `refundMode = true`, the epoch's `claimLiabilityTotal` is set to 0 and `totalRefundLiability` is set to `outputs.claimLiabilityTotal`. However, in `_emitResolveEvents`, the `EpochResolved` event is emitted with `outputs.claimLiabilityTotal` (the original value from settlement logic), not the epoch's stored `claimLiabilityTotal` (which is 0 in refund mode). This means the event correctly shows the total refund amount, but the field name `claimLiabilityTotal` in the event is misleading - it actually represents the refund liability in refund mode. Off-chain systems that parse this event and use `claimLiabilityTotal` to track protocol liabilities would get incorrect data in refund mode.


Hide Details
Impact
Off-chain systems that rely on the `EpochResolved` event's `claimLiabilityTotal` field to track protocol liabilities will receive the refund amount (not zero) in refund mode. This could cause incorrect accounting in dashboards, analytics, or automated systems. The `refundMode` boolean in the event allows consumers to distinguish the two cases, but the field semantics are inconsistent.
Scenario
N/A - This is an event data consistency issue, not a direct security vulnerability.
Affected code
// In _applyResolveAccounting:
e.claimLiabilityTotal = outputs.refundMode ? 0 : outputs.claimLiabilityTotal;
e.totalRefundLiability = outputs.refundMode ? outputs.claimLiabilityTotal : 0;

// In _emitResolveEvents:
emit EpochResolved(
templateId,
epochId,
outputs.winningMask,
outputs.claimLiabilityTotal, // This is the refund amount in refund mode
outputs.settlementFeeTotal,
outputs.refundMode
);
Proposed fix
Either document clearly that `claimLiabilityTotal` in the event represents the total payout liability (whether claims or refunds), or emit separate events for refund mode:
emit EpochResolved(
    templateId,
    epochId,
    outputs.winningMask,
    outputs.refundMode ? 0 : outputs.claimLiabilityTotal, // Consistent with stored value
    outputs.settlementFeeTotal,
    outputs.refundMode
);
// Emit separate event for refund amount
if (outputs.refundMode) {
    emit EpochRefundLiabilitySet(templateId, epochId, outputs.claimLiabilityTotal);
}
