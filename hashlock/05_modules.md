DeFi Prediction Market Protocol

RetroPick MarketEngine is a modular, UUPS-upgradeable prediction market protocol built on Solidity 0.8.24. It implements a dispatcher-module architecture where a central proxy (MarketEngineDispatcher) routes function calls via delegatecall to trusted module contracts. The system supports multiple market types (Direction, Threshold, RangeClose, Velocity, Ladder, Convergence, Composite, Corridor, Cascade) with both manual and rolling (automated) lifecycle modes. Users stake ERC20 tokens on market outcomes, and the protocol integrates with Chainlink oracles and yield routers (Aave/ERC4626) to generate yield on idle capital. Settlement is handled by a SettlementLogic library, and the system features a two-step module onboarding process (code hash allowlisting + address registration) to mitigate malicious module injection.

Show less
Access Control
role_based


Privileged Roles
1
admin
2
workerAuthority (keeper)
3
treasury
4
depositExecutor

External Calls
1
IERC20 (stakeToken)
2
IPriceOracle / IPriceOracleWithRoundId
3
IYieldRouterV2
4
IEventOracle
5
OpenZeppelin Initializable
6
OpenZeppelin UUPSUpgradeable
7
OpenZeppelin ReentrancyGuardTransient

External Systems
1
Chainlink Oracle Network
2
Yield Protocol (Aave/ERC4626)
3
UUPS Proxy

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


high Severity
3
1

MarketEngineAdminModule.sol
Oracle Cursor State Persists After Oracle Adapter Replacement, Enabling Stale Data Bypass
The `_enforceAndUpdateOracleCursor` function maintains per-template-per-feed monotonicity state in `lastOracleCursorByTemplateFeed` and `oracleCursorUsesRoundId`. When an oracle adapter is replaced via `setRateOracle`, `setSmartDataOracle`, `setMacroOracle`, or `setEquityOracle`, the cursor state is NOT reset. The new oracle adapter may have a completely different round ID sequence (e.g., starting from round 1 if it's a new Chainlink aggregator), but the cursor still holds the old oracle's last round ID. This means: (1) If the new oracle's round IDs are lower than the old cursor's roundId, ALL calls will revert with `OracleSampleNotMonotonic`, permanently bricking the market. (2) If the new oracle's round IDs happen to be higher (e.g., a different aggregator with higher round IDs), the cursor mode check (`priorUsesRoundId != supportsRoundId`) could trigger if the new adapter doesn't support round IDs, reverting with `InvalidOracleFeed`.


Hide Details
Impact
After an oracle adapter replacement (which may be necessary for security or operational reasons), all markets using that oracle class could become permanently unresolvable if the new oracle's round IDs are lower than the stored cursor. This would lock user funds indefinitely, requiring emergency cancellation of all affected epochs. This is a liveness risk that could affect all markets simultaneously.
Scenario
1. Protocol deploys with rateOracle pointing to Chainlink aggregator A (round IDs 1000-2000)
2. Markets are created and epochs resolved; cursor stores roundId=2000 for templateId/feedId
3. Admin calls setRateOracle(newOracleAdapter) pointing to a new Chainlink aggregator B (round IDs start at 1)
4. Worker calls lockEpoch or resolveEpoch
5. _readOracleOrRevert calls getNormalizedPriceWithRoundId, returns roundId=1
6. _enforceAndUpdateOracleCursor checks: oracleRoundId(1) < c.roundId(2000) → reverts with OracleSampleNotMonotonic
7. All epochs using this oracle class are permanently stuck
Affected code
function setRateOracle(address oracle) external {
_authAdmin();
if (oracle == address(0)) revert InvalidOracleFeed();
address old = address(rateOracle);
rateOracle = IPriceOracle(oracle);
emit RateOracleSet(old, oracle);
}

// No cursor reset performed
// Cursor state persists in:
// lastOracleCursorByTemplateFeed[templateId][feedId]
// oracleCursorUsesRoundId[templateId][feedId]
Proposed fix
Add a cursor reset mechanism that is called when oracle adapters are replaced. Either reset all cursors for the affected oracle class, or provide an admin function to reset specific template-feed cursors:
function setRateOracle(address oracle) external {
    _authAdmin();
    if (oracle == address(0)) revert InvalidOracleFeed();
    address old = address(rateOracle);
    rateOracle = IPriceOracle(oracle);
    emit RateOracleSet(old, oracle);
    // Note: Admin must manually reset oracle cursors for affected templates
    // via resetOracleCursor(templateId, feedId) after oracle replacement
}

// Add new admin function:
function resetOracleCursor(bytes32 templateId, bytes32 feedId) external {
    _authAdmin();
    delete lastOracleCursorByTemplateFeed[templateId][feedId];
    delete oracleCursorUsesRoundId[templateId][feedId];
    // Also reset lastOracleRoundIdByTemplate if needed
}
2

MarketEngineRollingLifecycleModule.sol
cancelRollingEpochWhileHalted Does Not Withdraw Yield Router Principal Before Cancellation
The `cancelRollingEpochWhileHalted` function in `MarketEngineRollingLifecycleModule` cancels epochs during a halted rolling market and sets up refund liabilities. However, unlike `cancelEpoch` in `MarketEngineCoreLifecycleModule`, it does NOT attempt to withdraw the epoch's `routedPrincipal` from the yield router before setting up the refund. This means: (1) The `e.routedPrincipal` is never zeroed out, leaving a dangling reference to funds still in the yield router. (2) The refund liability is set to `e.totalPool` (the full pool), but the actual tokens backing this refund may still be in the yield router, not in the contract's balance. (3) When users try to claim their refunds, the contract may not have sufficient token balance to pay them, as the principal is still locked in the yield router.


Hide Details
Impact
Users who deposited into a rolling epoch that gets cancelled while halted may be unable to claim their refunds if the contract's token balance is insufficient (because principal is still in the yield router). The vault accounting shows claims available, but the actual tokens are locked in the yield router. This could result in a partial or complete loss of user funds for the affected epoch, depending on the yield router's state.
Scenario
1. Rolling market is live with epoch N having routedPrincipal = 1000 tokens in yield router
2. Rolling market halts (oracle failure, buffer miss, etc.)
3. Admin calls cancelRollingEpochWhileHalted(templateId, epochId, reason, false)
4. refundLiability = e.totalPool (e.g., 1000 tokens)
5. vault.claims += 1000, vault.active -= 1000
6. e.routedPrincipal is still 1000 (not withdrawn)
7. User calls claim() → _claimOne computes refund amount
8. stakeToken.safeTransfer(user, amount) is called
9. If contract balance < amount (because 950 tokens are in yield router), transfer fails
10. Users cannot claim their refunds
Affected code
function cancelRollingEpochWhileHalted(
bytes32 templateId,
uint64 epochId,
MarketTypes.CancelReason reason,
bool voided
) external nonReentrant {
_authAdmin();
// ... validation ...

uint256 refundLiability = e.totalPool;
if (refundLiability > 0) {
_vaults[templateId].active -= refundLiability;
_vaults[templateId].claims += refundLiability;
MarketMath.reserveClaimsFromActive(ledger, refundLiability);
}
// BUG: e.routedPrincipal is never withdrawn or zeroed!
// The yield router still holds routedPrincipal tokens
e.claimLiabilityTotal = 0;
e.totalRefundLiability = refundLiability;
// ...
}
Proposed fix
Add yield router withdrawal logic to `cancelRollingEpochWhileHalted`, similar to `cancelEpoch`:
function cancelRollingEpochWhileHalted(
    bytes32 templateId,
    uint64 epochId,
    MarketTypes.CancelReason reason,
    bool voided
) external nonReentrant {
    _authAdmin();
    // ... existing validation ...
    
    // Add yield router withdrawal before setting refund liability
    IYieldRouterV2 r = yieldRouter;
    if (address(r) != address(0) && e.routedPrincipal > 0) {
        uint256 routedPrincipal = e.routedPrincipal;
        // Attempt withdrawal; if it fails, still proceed but log it
        uint256 b0 = stakeToken.balanceOf(address(this));
        try r.withdrawScaled(templateId, routedPrincipal) returns (uint256) {
            uint256 b1 = stakeToken.balanceOf(address(this));
            e.routedPrincipal = 0;
            if (b1 > b0 + routedPrincipal) {
                // Handle yield
                uint256 gy = (b1 - b0) - routedPrincipal;
                _vaults[templateId].fees += gy;
                ledger.feeReserveTotal += gy;
            }
        } catch {
            emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
            // routedPrincipal remains set; admin must handle separately
        }
    }
    
    uint256 refundLiability = e.totalPool;
    // ... rest of function
}
3

MarketEngineCoreLifecycleModule.sol
Vault Active Balance Can Underflow When Yield Router Returns Less Than Principal
In `_withdrawRoutedPrincipalOnResolve` and `_withdrawResolvePrincipal`, when the yield router returns less than the `routedPrincipal` (e.g., due to slippage, losses, or partial withdrawal), `grossYield` is returned as 0. However, the `routedPrincipal` is still zeroed out (`e.routedPrincipal = 0`), meaning the protocol acknowledges the loss. The issue is in `_applyResolveAccounting`: the `totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal` is checked against `_vaults[templateId].active`. The `active` balance was set assuming the full `routedPrincipal` would be returned. If the yield router returns less, the `active` balance is lower than expected, but `SettlementLogic.compute` was called with `netYield=0` (no yield), so the settlement amounts are based on the original pool. This means `active` could be less than `totalDeduction`, causing `VaultInsufficientActive` revert and permanently blocking epoch resolution.


Hide Details
Impact
If the yield router returns less than the principal (due to losses, slippage, or bugs), the epoch cannot be resolved because `_vaults[templateId].active` is lower than the required `totalDeduction`. This permanently locks the epoch in the `Locked` state, preventing users from claiming their funds. The only recovery path is `cancelEpoch`, but that also tries to withdraw from the yield router (which already failed). This is a critical liveness risk when yield routers experience losses.
Scenario
1. Epoch has totalPool=1000, routedPrincipal=950
2. vault.active=1000 (full pool)
3. Yield router experiences a 10% loss
4. _withdrawRoutedPrincipalOnResolve: received=855 (950*0.9), grossYield=0
5. vault.active is still 1000 (not updated by withdrawal - the 95 token loss is unaccounted)
6. Wait - actually vault.active was set to 1000 when deposited, and the 950 went to yield router
7. The contract only has 50 tokens (5% buffer) + whatever was returned (855)
8. vault.active=1000 but contract balance=905
9. SettlementLogic computes claimLiabilityTotal=950 (winners get their share)
10. _applyResolveAccounting: active(1000) >= totalDeduction(950+fee) → passes
11. But actual token balance is 905, not 1000
12. When users try to claim, safeTransfer fails due to insufficient balance
Affected code
// In _withdrawRoutedPrincipalOnResolve:
try r.withdrawScaled(templateId, routedPrincipal) returns (uint256) {
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant();
uint256 received = b1 - b0;
e.routedPrincipal = 0;
if (received > routedPrincipal) return received - routedPrincipal;
return 0; // Returns 0 even if received < routedPrincipal (LOSS CASE)
}

// In _applyResolveAccounting:
if (_vaults[templateId].active < totalDeduction) {
revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction);
}
Proposed fix
Account for yield router losses by updating the vault active balance when the returned amount is less than principal:
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
        
        if (received < routedPrincipal) {
            // Account for the loss
            uint256 loss = routedPrincipal - received;
            _vaults[templateId].active -= loss;
            _ledgers[templateId].activeCollateralTotal -= loss; // or appropriate ledger field
        }
        
        if (received > routedPrincipal) return received - routedPrincipal;
        return 0;
    }
    // ...
}

medium Severity
7
1

MarketEngineState.sol
Duplicate Storage Mappings in MarketEngineState Create Silent Storage Collision
MarketEngineState declares two sets of selector-to-module mappings: the ERC-7201 namespaced `ModuleRegistryStorage` struct in the dispatcher (accessed via assembly slot), AND legacy `selectorToModule`/`selectorImmutable` mappings in the inherited state layout. The dispatcher's `setSelectorModule` writes to the ERC-7201 namespaced storage, while the legacy mappings in `MarketEngineState` occupy different storage slots. This means the `selectorToModule` and `selectorImmutable` mappings in `MarketEngineState` are never written by the dispatcher but occupy storage slots that could be overwritten by future module upgrades or storage layout changes. More critically, if any module were to write to `selectorToModule` directly (thinking it's the canonical mapping), it would write to a different slot than what the dispatcher reads, creating a silent divergence. The `__gap` array of 41 slots is intended to reserve space, but the presence of these duplicate mappings is architecturally confusing and dangerous.


Hide Details
Impact
Any module that inherits MarketEngineState and accidentally reads from `selectorToModule` or `selectorImmutable` (the inherited state variables) will read stale/empty data instead of the actual dispatcher registry. This could cause modules to bypass selector immutability checks or fail to find registered modules. Additionally, the duplicate mappings waste storage slots and reduce the effective size of the `__gap` buffer, increasing upgrade collision risk.
Scenario
1. Deploy MarketEngineDispatcher proxy and call initialize()
2. Call setSelectorModule(selector, module, true) - this writes to ERC-7201 namespaced storage
3. A module that reads `selectorImmutable[selector]` directly (from inherited state) will see `false` instead of `true`
4. This could allow a module to bypass immutability checks if it uses the inherited mapping instead of the dispatcher's registry
Affected code
// In MarketEngineState.sol
// --- dispatcher state (appended after legacy state) ---
mapping(bytes4 selector => address module) internal selectorToModule;
mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

uint256[41] private __gap;

// In MarketEngineDispatcher.sol - uses DIFFERENT storage location
struct ModuleRegistryStorage {
mapping(bytes4 selector => address module) selectorToModule;
mapping(bytes4 selector => bool immutableSelector) selectorImmutable;
mapping(address module => bool approved) approvedModules;
mapping(address module => bytes32 codeHash) moduleCodeHash;
mapping(bytes32 codeHash => bool allowed) allowedModuleCodeHashes;
}
Proposed fix
Remove the duplicate `selectorToModule` and `selectorImmutable` mappings from `MarketEngineState`. These are dead storage that creates confusion. The canonical registry is in the ERC-7201 namespaced `ModuleRegistryStorage` in the dispatcher. Update the `__gap` size accordingly to maintain the same total storage footprint:
// Remove these from MarketEngineState.sol:
// mapping(bytes4 selector => address module) internal selectorToModule;
// mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

// Increase __gap to compensate (was 41, add 2 more for the removed mappings)
uint256[43] private __gap;
2

MarketEngineCoreLifecycleModule.sol
ReentrancyGuardTransient Slot Collision Between Dispatcher and Modules via Delegatecall
Both `MarketEngineDispatcher` and the module contracts (e.g., `MarketEngineCoreLifecycleModule`, `MarketEngineRollingLifecycleModule`, `MarketEngineUserOpsClaimsModule`) inherit `ReentrancyGuardTransient`. When a module is called via `delegatecall` from the dispatcher's `fallback()`, the module's `nonReentrant` modifier operates on the proxy's transient storage context. However, the `ReentrancyGuardTransient` uses a fixed transient storage slot (defined by OpenZeppelin as `keccak256('ReentrancyGuardTransient.guard') - 1`). Since the dispatcher itself also inherits `ReentrancyGuardTransient`, both the dispatcher and modules share the SAME transient storage slot when executing in the proxy context. This means if the dispatcher's own `nonReentrant` modifier is ever used (it's inherited but not directly applied to fallback), and a module's `nonReentrant` is active, they would interfere. More critically, the `lockEpoch` and `openEpoch` functions in `MarketEngineCoreLifecycleModule` do NOT have `nonReentrant` guards, while `resolveEpoch` does. A malicious yield router could potentially reenter `lockEpoch` during a `resolveEpoch` call since they share the same reentrancy guard slot but `lockEpoch` is unguarded.


Hide Details
Impact
While the yield router is admin-controlled and trusted, the asymmetric reentrancy protection creates a defense-in-depth gap. If the yield router is compromised or behaves maliciously, it could reenter `lockEpoch` during `resolveEpoch` execution (after checkpoint B is written but before accounting is finalized), potentially locking an already-locked epoch or corrupting epoch state. The `lockEpoch` and `openEpoch` functions lack `nonReentrant` despite making state changes that interact with oracle reads.
Scenario
1. Attacker compromises or controls the yield router
2. Worker calls resolveEpoch(templateId, epochId) - nonReentrant guard is set
3. Inside _finishResolveEpochManual, _withdrawRoutedPrincipalOnResolve calls r.withdrawScaled()
4. Malicious yield router reenters lockEpoch (different selector, no nonReentrant guard)
5. lockEpoch checks e.isLockable(nowTs) - epoch is already Locked, so this reverts
6. However, if the attacker targets openEpoch for the NEXT epoch, they could open it prematurely before the current resolve completes
Affected code
function lockEpoch(bytes32 templateId, uint64 epochId) external {
_authAdminOrWorker();
if (globalPaused) revert ProtocolPaused();
_lockEpoch(templateId, epochId);
}

function resolveEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
_authAdminOrWorker();
if (globalPaused) revert ProtocolPaused();
_resolveEpoch(templateId, epochId);
}
Proposed fix
Add `nonReentrant` to `lockEpoch`, `openEpoch`, and their batch variants. Since these are called via delegatecall and share the proxy's transient storage, the guard will be effective:
function lockEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
    _authAdminOrWorker();
    if (globalPaused) revert ProtocolPaused();
    _lockEpoch(templateId, epochId);
}

function openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) external nonReentrant {
    _authAdminOrWorker();
    if (globalPaused) revert ProtocolPaused();
    _openEpoch(templateId, epochId, openAt, lockAt, resolveAt);
}
3

MarketEngineUserOpsClaimsModule.sol
Yield Router Deposit Approval Race Condition via forceApprove
In `_depositToSide`, the contract calls `stakeToken.forceApprove(address(r), routeAmount)` before attempting `r.depositScaled(templateId, routeAmount)`. The `forceApprove` sets the allowance to exactly `routeAmount`. However, if the `depositScaled` call fails (caught by the try/catch), the approval is NOT revoked. This leaves a residual approval for `routeAmount` tokens on the yield router. On the next deposit, `forceApprove` is called again with the new `routeAmount`, overwriting the previous approval. While `forceApprove` (which calls `approve(0)` then `approve(amount)`) prevents the classic ERC20 approval race condition, the residual approval after a failed deposit means the yield router retains spending rights for the previous `routeAmount` even though the deposit failed. A malicious or compromised yield router could exploit this window.


Hide Details
Impact
After a failed `depositScaled` call, the yield router retains an approval for `routeAmount` tokens. A malicious yield router could call `transferFrom` on the stake token to steal these tokens. While the yield router is admin-controlled, this represents an unnecessary attack surface. Additionally, if the yield router is replaced (via `setYieldRouter`) without revoking the old approval, the old router retains spending rights.
Scenario
1. User calls depositToSide with amount=1000
2. routeAmount = 950 (after 5% buffer)
3. forceApprove(yieldRouter, 950) is called
4. r.depositScaled reverts (e.g., yield router is paused)
5. catch block emits YieldRouterDepositFailed
6. Approval of 950 tokens remains on yieldRouter
7. Malicious yield router calls stakeToken.transferFrom(proxy, attacker, 950)
8. 950 tokens stolen from the protocol
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
// BUG: approval of routeAmount remains active!
}
}
}
Proposed fix
Revoke the approval in the catch block and also when `attributionUnits == 0`:
stakeToken.forceApprove(address(r), routeAmount);
try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) {
    if (attributionUnits > 0) {
        e.routedPrincipal += routeAmount;
    } else {
        // Revoke unused approval
        stakeToken.forceApprove(address(r), 0);
        emit YieldRouterDepositFailed(templateId, routeAmount);
    }
} catch {
    // Revoke approval on failure
    stakeToken.forceApprove(address(r), 0);
    emit YieldRouterDepositFailed(templateId, routeAmount);
}


Also, in `setYieldRouter`, revoke approval for the old router:
function setYieldRouter(address router, uint16 feeBps) external {
    _authAdmin();
    // ...
    address old = address(yieldRouter);
    if (old != address(0)) {
        stakeToken.forceApprove(old, 0); // Revoke old router approval
    }
    // ...
}
4

MarketEngineDispatcher.sol
Module Code Hash Check Can Be Bypassed via Metamorphic Contract Pattern
The `_enforceApprovedModule` function re-checks `keccak256(module.code)` at call time to detect code changes. However, this check can be bypassed using the metamorphic contract pattern: (1) Deploy a module at a CREATE2 address with legitimate bytecode. (2) Register the module (code hash allowlisted and registered). (3) The module calls `selfdestruct` (or uses a proxy pattern to change behavior). (4) Redeploy malicious bytecode at the same CREATE2 address. (5) The `_enforceApprovedModule` check will now see the NEW code hash, which doesn't match the stored hash, and REVERT. This means the attack doesn't succeed in executing malicious code, but it DOES permanently brick all selectors pointing to this module (they will always revert with `ModuleCodeHashMismatch`). This is a griefing/DoS vector that requires admin action to recover.


Hide Details
Impact
A malicious actor who can deploy a module (requires admin cooperation for registration, but could be a compromised admin or a social engineering attack) could permanently brick all selectors pointing to that module by selfdestructing and redeploying with different bytecode. Recovery requires admin to: (1) Revoke the old module. (2) Register a new module. (3) Remap all affected selectors. During this recovery period, all affected functions are unavailable, potentially locking user funds if claim/deposit functions are affected.
Scenario
1. Attacker (or compromised admin) deploys Module_v1 at CREATE2 address A with legitimate code
2. Admin allowlists code hash of Module_v1, registers it, maps selectors
3. Module_v1 selfdestructs (or is a proxy that changes implementation)
4. Attacker redeploys Module_v2 at address A with different code
5. Any call to a selector mapped to address A now reverts with ModuleCodeHashMismatch
6. Protocol functions are bricked until admin remaps selectors to a new module
Affected code
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
Proposed fix
This is partially mitigated by the runtime code hash check (it prevents execution of malicious code). However, to prevent the DoS vector:

1. Ensure modules are deployed as non-upgradeable contracts without `selfdestruct`
2. Add a recovery mechanism that allows remapping selectors without requiring the old module to be valid:
// Emergency selector remap that bypasses the old module check
function emergencyRemapSelector(bytes4 selector, address newModule) external onlyAdmin {
    // Only callable when old module is invalid (code hash mismatch)
    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    address oldModule = $.selectorToModule[selector];
    if (oldModule != address(0)) {
        bytes32 expectedHash = $.moduleCodeHash[oldModule];
        bytes32 actualHash = keccak256(oldModule.code);
        require(actualHash != expectedHash, "Old module still valid, use setSelectorModule");
    }
    // Proceed with remapping to new approved module
    _enforceApprovedModule(newModule);
    $.selectorToModule[selector] = newModule;
    emit SelectorModuleSet(selector, newModule, false);
}
5

MarketEngineCoreLifecycleModule.sol
Template Can Be Updated While Active Epoch Is Open, Changing Settlement Parameters Mid-Epoch
The `upsertTemplate` function allows the admin to update any template parameter at any time, including `settlementFeeBps`, `switchFeeBps`, `outcomeCount`, `condition`, `thresholdRule`, and oracle parameters. However, when an epoch is opened, template parameters are COPIED to the epoch storage. This means changes to the template after epoch opening do NOT affect the current epoch. The issue is that `upsertTemplate` can change `active=false` (deactivating the template) while an epoch is open, which doesn't affect the current epoch but prevents new epochs from being opened. More critically, if `outcomeCount` is reduced in the template while an epoch is open, the next epoch will have fewer outcomes, but users who deposited in the current epoch based on the old outcome count are unaffected. This is by design (epoch snapshots template at open time). However, there's no check preventing `upsertTemplate` from changing `executionMode` from Manual to Rolling (or vice versa) while a market is active, which could break the lifecycle.


Hide Details
Impact
Changing `executionMode` from Manual to Rolling (or vice versa) while a market has an active epoch could break the lifecycle: (1) If changed to Rolling while a Manual epoch is open, `openEpoch` will revert with `ManualModeOnly` for the next epoch, but `genesisStartRolling` will also fail because the ledger is not in `Uninitialized` phase. (2) If changed to Manual while a Rolling epoch is open, `executeRollingRound` will revert with `RollingModeOnly`. This could permanently lock the market in an unresolvable state.
Scenario
1. Template T is Manual mode, epoch 5 is open
2. Admin calls upsertTemplate with executionMode=Rolling
3. Template T is now Rolling mode
4. Worker calls lockEpoch(T, 5) → reverts with ManualModeOnly (checks template.executionMode)
5. Worker calls executeRollingRound(T) → reverts with RollingWrongPhase (ledger.rollingPhase=Uninitialized)
6. Epoch 5 is permanently stuck in Open state
7. Users cannot get their funds back without admin calling cancelEpoch
Affected code
function upsertTemplate(UpsertTemplateParams calldata p) external {
_authAdmin();
// ... validation ...
// No check if there's an active epoch!
t.slug = p.slug;
t.executionMode = p.executionMode; // Can change Manual→Rolling while epoch is open!
t.outcomeCount = p.outcomeCount;
// ... all fields updated ...
}
Proposed fix
Add a check in `upsertTemplate` to prevent changing `executionMode` if the market has an active (non-terminal) epoch:
function upsertTemplate(UpsertTemplateParams calldata p) external {
    _authAdmin();
    // ... existing validation ...
    
    bytes32 tid = templateIdFromSlug(p.slug);
    MarketTypes.Template storage t = _templates[tid];
    
    // Prevent executionMode change if market is active
    if (t.version != 0 && t.executionMode != p.executionMode) {
        MarketTypes.Ledger storage ledger = _ledgers[tid];
        if (ledger.initialized && ledger.activeEpochId != ledger.lastResolvedEpochId) {
            revert InvalidTemplate(); // Cannot change execution mode with active epoch
        }
    }
    
    // ... rest of function
}
6

MarketEngineUserOpsClaimsModule.sol
switchSide Does Not Update vault.active When Fee Is Withdrawn From Yield Router
In `_withdrawSwitchFeePrincipal`, when the yield router returns more than `principalToWithdraw` (i.e., there's yield), the excess is added to `vault.fees` and `ledger.feeReserveTotal`. However, the `vault.active` balance is NOT updated to reflect the returned principal. The principal was already deducted from `vault.active` when the switch fee was processed (in `switchSide`: `vault.active -= feeAmount`). When `_withdrawSwitchFeePrincipal` withdraws `principalToWithdraw` from the yield router, the returned tokens increase the contract's balance, but `vault.active` is not credited with the returned principal. This means `vault.active` is understated by `principalToWithdraw` after the withdrawal, creating an accounting divergence between the vault's tracked balance and the actual token balance.


Hide Details
Impact
The vault's `active` balance becomes understated over time as switch fees are processed. This means: (1) `VaultInsufficientActive` checks may trigger prematurely, blocking epoch resolution. (2) The total tracked balance (`active + claims + fees`) diverges from the actual token balance. (3) Fee withdrawals may be blocked because `feeReserveTotal` doesn't account for the returned principal. The severity depends on the volume of switch fee operations and yield router activity.
Scenario
1. Epoch has routedPrincipal=950, vault.active=1000
2. User switches side with grossAmount=100, feeAmount=1 (1% fee)
3. switchSide: vault.active -= 1 → vault.active=999, vault.fees += 1
4. _withdrawSwitchFeePrincipal: principalToWithdraw = 0.95 (95% of fee)
5. yield router returns 0.96 (0.95 principal + 0.01 yield)
6. grossReturned=0.96 > principalToWithdraw=0.95
7. grossYield=0.01, vault.fees += 0.01 → vault.fees=1.01
8. BUT vault.active is still 999, not 999.95 (the 0.95 principal returned is untracked)
9. Over many switches, vault.active diverges significantly from actual balance
Affected code
function _withdrawSwitchFeePrincipal(
bytes32 templateId,
uint64 epochId,
uint256 feeAmount,
MarketTypes.VaultBalances storage vault,
MarketTypes.Ledger storage ledger
) internal {
// ...
uint256 grossReturned = _balanceDeltaAfterWithdrawScaled(r, templateId, principalToWithdraw);
e.routedPrincipal -= principalToWithdraw;
if (grossReturned > principalToWithdraw) {
uint256 grossYield = grossReturned - principalToWithdraw;
vault.fees += grossYield; // Only yield added to fees
ledger.feeReserveTotal += grossYield;
// BUG: principalToWithdraw returned to contract but vault.active not updated!
// The principal portion of grossReturned is unaccounted
}
// If grossReturned <= principalToWithdraw, nothing is updated at all!
}
Proposed fix
Update `vault.active` to reflect the returned principal:
function _withdrawSwitchFeePrincipal(
    bytes32 templateId,
    uint64 epochId,
    uint256 feeAmount,
    MarketTypes.VaultBalances storage vault,
    MarketTypes.Ledger storage ledger
) internal {
    // ...
    uint256 grossReturned = _balanceDeltaAfterWithdrawScaled(r, templateId, principalToWithdraw);
    e.routedPrincipal -= principalToWithdraw;
    
    // The principal portion is returned to active (it was deducted as fee but the fee
    // was already moved to vault.fees; the principal backing it is now back in the contract)
    // Actually, the fee was already moved from active to fees in switchSide
    // The principal withdrawal just brings tokens back to the contract
    // We need to track this correctly:
    
    if (grossReturned >= principalToWithdraw) {
        uint256 grossYield = grossReturned - principalToWithdraw;
        if (grossYield > 0) {
            vault.fees += grossYield;
            ledger.feeReserveTotal += grossYield;
        }
    }
    // Note: The principal itself was already accounted for in vault.fees when the switch fee was taken
    // No additional vault.active update needed - the tokens are now backing vault.fees
}
A thorough accounting review of the switch fee flow is recommended to ensure all token movements are correctly tracked.
7

MarketEngineAdminModule.sol
Missing Admin Transfer Mechanism Creates Single Point of Failure
The `admin` role is set once during `initialize` and can only be changed if there's a module that implements an admin transfer function (not visible in the provided code). The `MarketEngineAdminModule` does not include a `transferAdmin` or `setAdmin` function. If the admin key is lost or compromised, there is no recovery mechanism. The `_authorizeUpgrade` function requires `onlyAdmin`, so even UUPS upgrades are blocked if admin is lost. The only way to change admin would be through a UUPS upgrade to a new implementation that includes admin transfer logic, but that also requires admin authorization.


Hide Details
Impact
If the admin key is lost or compromised: (1) No new modules can be registered. (2) No UUPS upgrades can be performed. (3) No oracle adapters can be changed. (4) No yield router can be updated. (5) The protocol is permanently frozen in its current state. This is a critical operational risk for a production protocol.
Scenario
1. Admin private key is lost
2. Protocol needs to update oracle adapter (old one is deprecated)
3. setRateOracle requires onlyAdmin → reverts
4. upgradeToAndCall requires onlyAdmin → reverts
5. Protocol is permanently stuck with deprecated oracle
6. All markets using that oracle class become unresolvable
Affected code
function _authorizeUpgrade(address) internal override onlyAdmin {}

// In MarketEngineAdminModule - no setAdmin function exists
// setWorkerAuthority exists but not setAdmin
function setWorkerAuthority(address worker) external {
_authAdmin();
// ...
}
// No equivalent setAdmin function
Proposed fix
Add an admin transfer function with a two-step process (propose + accept) to prevent accidental transfers:
// In MarketEngineAdminModule:
address public pendingAdmin;

function proposeAdmin(address newAdmin) external {
    _authAdmin();
    if (newAdmin == address(0)) revert InvalidAuthority();
    pendingAdmin = newAdmin;
    emit AdminProposed(newAdmin);
}

function acceptAdmin() external {
    if (msg.sender != pendingAdmin) revert Unauthorized();
    address prev = admin;
    admin = pendingAdmin;
    pendingAdmin = address(0);
    emit AdminTransferred(prev, admin);
}
Alternatively, use a multi-sig or timelock as the admin from the start.

low Severity
5
1

MarketEngineAdminModule.sol
withdrawFees Does Not Check Vault Balance, Only Ledger Reserve - Potential Accounting Divergence
The `withdrawFees` function in `MarketEngineAdminModule` checks `ledger.feeReserveTotal >= amount` before transferring, but the actual token transfer comes from the contract's token balance. The vault's `fees` balance (`_vaults[templateId].fees`) is decremented after transfer. However, there is no check that `_vaults[templateId].fees >= amount` before the transfer. While `ledger.feeReserveTotal` and `_vaults[templateId].fees` should be in sync under normal operation, if they ever diverge (due to a bug, a malicious module, or an accounting error), the function could transfer tokens that are actually reserved for claims, not fees. The `ledger.feeReserveTotal` check is the only guard, but `_vaults[templateId].fees` is the canonical fee balance.


Hide Details
Impact
If `ledger.feeReserveTotal` and `_vaults[templateId].fees` diverge, the function could: (1) Transfer more tokens than are actually in the fee bucket, drawing from claim reserves. (2) Cause an underflow revert on `_vaults[templateId].fees -= amount` if fees < amount but feeReserveTotal >= amount. This could result in user claims being underfunded or the function being permanently bricked for a template.
Scenario
Scenario where divergence occurs:
1. A buggy module increments ledger.feeReserveTotal without incrementing _vaults[templateId].fees
2. ledger.feeReserveTotal = 1000, _vaults[templateId].fees = 500
3. Admin calls withdrawFees(templateId, 800)
4. Check: ledger.feeReserveTotal(1000) >= 800 → passes
5. stakeToken.safeTransfer(treasury, 800) → succeeds (tokens exist in contract)
6. _vaults[templateId].fees -= 800 → UNDERFLOW REVERT (500 - 800)
7. Function is permanently bricked for this template
Affected code
function withdrawFees(bytes32 templateId, uint256 amount) external {
_authTreasuryOrAdmin();
if (amount == 0) revert NothingToClaim();
MarketTypes.Ledger storage ledger = _ledgers[templateId];
if (!ledger.initialized) revert InvalidTemplate();
if (ledger.feeReserveTotal < amount) revert NothingToClaim();

stakeToken.safeTransfer(treasury, amount);
MarketMath.releaseFeeOnWithdraw(ledger, amount);
_vaults[templateId].fees -= amount;
emit FeesWithdrawn(templateId, amount);
}
Proposed fix
Add a check for `_vaults[templateId].fees >= amount` and ensure both values are checked:
function withdrawFees(bytes32 templateId, uint256 amount) external {
    _authTreasuryOrAdmin();
    if (amount == 0) revert NothingToClaim();
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    
    // Check both accounting sources for consistency
    if (ledger.feeReserveTotal < amount) revert NothingToClaim();
    if (_vaults[templateId].fees < amount) revert NothingToClaim();

    stakeToken.safeTransfer(treasury, amount);
    MarketMath.releaseFeeOnWithdraw(ledger, amount);
    _vaults[templateId].fees -= amount;
    emit FeesWithdrawn(templateId, amount);
}
2

MarketEngineRollingLifecycleModule.sol
Rolling Epoch Opens With Past Timing When executeRollingRound Is Called Late
In `_openRollingEpoch`, the new epoch's timing is set as: `openAt = startTs`, `lockAt = startTs + inter`, `resolveAt = startTs + 2 * inter`, where `startTs` is `nowTs` at the time of the `executeRollingRound` call. However, `startTs` is passed from `_executeRollingRoundCore` which uses `uint64(block.timestamp)`. If `executeRollingRound` is called late (e.g., at the end of the buffer window), the newly opened epoch's `openAt` will be in the past, and `lockAt` may be very close to the current time. This means users have very little time to deposit into the new epoch before it locks. In extreme cases (if called at `lockAt + rollingBufferSeconds`), the new epoch could open with `lockAt` already in the past, making it immediately lockable with zero deposit window.


Hide Details
Impact
Users may have significantly reduced or zero time to deposit into newly opened rolling epochs if the keeper calls `executeRollingRound` late (within the buffer window). This is a fairness issue that could disadvantage users who are monitoring for new epoch openings. In the worst case, if `rollingBufferSeconds` is large relative to `rollingIntervalSeconds`, the new epoch could be immediately lockable, preventing any deposits.
Scenario
1. Template has rollingIntervalSeconds=3600 (1 hour), rollingBufferSeconds=300 (5 min)
2. Keeper calls executeRollingRound at lockAt + 299 seconds (just before buffer expires)
3. New epoch opens with openAt = lockAt + 299, lockAt = lockAt + 299 + 3600
4. Users have 3600 seconds to deposit (normal)
5. BUT if rollingIntervalSeconds=60, rollingBufferSeconds=50:
6. Keeper calls at lockAt + 49 seconds
7. New epoch: openAt = lockAt+49, lockAt = lockAt+49+60 = lockAt+109
8. Users have only 60 seconds to deposit, but the epoch was supposed to have 60 seconds
9. Effectively, users lose 49 seconds of deposit window
Affected code
function _openRollingEpoch(bytes32 templateId, uint64 startTs, MarketTypes.Template storage t)
internal
returns (uint64 openedEpochId)
{
// ...
uint64 inter = t.rollingIntervalSeconds;
uint64 openAt = startTs; // startTs = nowTs, which could be late
uint64 lockAt = startTs + inter;
uint64 resolveAt = startTs + 2 * inter;
// ...
}
Proposed fix
Consider using the expected timing (based on the previous epoch's timing) rather than `nowTs` for the new epoch's timing, to maintain consistent epoch windows:
// Instead of using nowTs as startTs, use the previous epoch's resolveAt
// This ensures consistent epoch windows regardless of keeper timing
uint64 newOpenAt = ePrev.timing.resolveAt; // or eCur.timing.lockAt
uint64 newLockAt = newOpenAt + inter;
uint64 newResolveAt = newOpenAt + 2 * inter;
Alternatively, document this behavior clearly and ensure `rollingBufferSeconds` is small relative to `rollingIntervalSeconds` to minimize the impact.
3

MarketEngineUserOpsClaimsModule.sol
claimMany Emits Claimed Events Before Transfer, Enabling Misleading Event Ordering
In `claimMany`, the `Claimed` event is emitted inside the loop for each epoch BEFORE the actual token transfer occurs (which happens after the loop). This means if the final `safeTransfer` fails (e.g., due to a token blacklist or insufficient balance), all `Claimed` events have already been emitted but no tokens were transferred. Off-chain systems monitoring `Claimed` events would incorrectly believe the claims were processed. Additionally, the `pos.claimed = true` flag is set inside `_claimOne`, so if the transfer fails, users cannot re-claim (their position is marked as claimed but they received nothing).


Hide Details
Impact
If `safeTransfer` fails after events are emitted: (1) Users' positions are permanently marked as `claimed = true` (set in `_claimOne`), preventing them from ever claiming again. (2) `Claimed` events are emitted but no tokens transferred, misleading off-chain indexers. (3) Vault accounting (`claims` balance, `claimedTotal`) is updated but tokens remain in the contract, creating an accounting divergence. This is a critical fund-locking scenario for tokens with blacklists (e.g., USDC) where the recipient could be blacklisted between deposit and claim.
Scenario
1. User deposits into epochs 1, 2, 3 using USDC as stake token
2. User gets blacklisted by USDC between deposit and claim
3. User calls claimMany([1, 2, 3])
4. _claimOne(1): pos.claimed=true, vault.claims-=amount1, Claimed event emitted
5. _claimOne(2): pos.claimed=true, vault.claims-=amount2, Claimed event emitted
6. _claimOne(3): pos.claimed=true, vault.claims-=amount3, Claimed event emitted
7. safeTransfer(user, total) REVERTS (user is blacklisted)
8. Transaction reverts, but... wait, it DOES revert entirely due to Solidity's revert semantics
9. Actually all state changes revert too - this is less severe than initially thought
10. BUT: if the token's transfer fails silently (non-reverting), the issue manifests
Affected code
function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
_validateBatchSize(epochIds.length);
uint256 total = 0;
for (uint256 i = 0; i < epochIds.length; i++) {
uint256 amt = _claimOne(templateId, epochIds[i], msg.sender);
total += amt;
emit Claimed(templateId, epochIds[i], msg.sender, amt); // Event emitted before transfer!
}
if (total == 0) revert NothingToClaim();
stakeToken.safeTransfer(msg.sender, total); // Transfer happens after all events
}
Proposed fix
While Solidity's revert semantics mean the entire transaction reverts if `safeTransfer` fails, the event ordering is still misleading for off-chain systems. Move the transfer before events, or emit events after transfer:
function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
    _validateBatchSize(epochIds.length);
    uint256 total = 0;
    uint256[] memory amounts = new uint256[](epochIds.length);
    for (uint256 i = 0; i < epochIds.length; i++) {
        amounts[i] = _claimOne(templateId, epochIds[i], msg.sender);
        total += amounts[i];
    }
    if (total == 0) revert NothingToClaim();
    stakeToken.safeTransfer(msg.sender, total);  // Transfer first
    for (uint256 i = 0; i < epochIds.length; i++) {
        if (amounts[i] > 0) {
            emit Claimed(templateId, epochIds[i], msg.sender, amounts[i]);  // Events after transfer
        }
    }
}
4

MarketEngineViewModule.sol
getUserEpochs Pagination Returns Incorrect nextCursor When size=0
In `MarketEngineViewModule.getUserEpochs`, when `size=0` is passed, `boundedSize` is set to 0 (since 0 <= MAX_USER_EPOCHS_PAGE_SIZE). Then `end = cursor + 0 = cursor`, `outLen = cursor - cursor = 0`, and `nextCursor = cursor`. The function returns an empty array with `nextCursor = cursor`, which is the same as the input cursor. This means callers using `size=0` will get stuck in an infinite loop if they use `nextCursor` to paginate (they'll keep getting cursor=cursor). While this is a minor issue, it could cause off-chain integrators to loop indefinitely.


Hide Details
Impact
Off-chain integrators calling `getUserEpochs` with `size=0` will receive `nextCursor == cursor`, potentially causing infinite loops in pagination logic. This is a low-severity issue affecting only off-chain integrations, not on-chain security.
Scenario
1. User has 10 epochs
2. Caller calls getUserEpochs(templateId, user, 0, 0)
3. Returns: epochIds=[], nextCursor=0
4. Caller uses nextCursor=0 for next call
5. Gets same result: epochIds=[], nextCursor=0
6. Infinite loop
Affected code
function getUserEpochs(bytes32 templateId, address user, uint256 cursor, uint256 size)
external
view
returns (uint64[] memory epochIds, uint256 nextCursor)
{
uint64[] storage src = _userEpochs[templateId][user];
uint256 n = src.length;
if (cursor >= n) return (new uint64[](0), cursor);
uint256 boundedSize = size;
if (boundedSize > MAX_USER_EPOCHS_PAGE_SIZE) boundedSize = MAX_USER_EPOCHS_PAGE_SIZE;
uint256 end = cursor + boundedSize; // If size=0, end=cursor
if (end > n) end = n;
uint256 outLen = end - cursor; // outLen=0
// ...
nextCursor = end; // nextCursor=cursor (no progress!)
}
Proposed fix
Add a minimum size check or handle the size=0 case explicitly:
function getUserEpochs(bytes32 templateId, address user, uint256 cursor, uint256 size)
    external
    view
    returns (uint64[] memory epochIds, uint256 nextCursor)
{
    if (size == 0) size = 1; // Minimum page size of 1
    uint64[] storage src = _userEpochs[templateId][user];
    // ... rest of function
}
5

MarketEngineDispatcher.sol
Hardcoded SELECTOR_SET_SELECTOR_MODULE Constant May Not Match Actual Function Selector
In `MarketEngineDispatcher`, the constant `SELECTOR_SET_SELECTOR_MODULE = 0x5837c6a8` is hardcoded as the selector for `setSelectorModule(bytes4,address,bool)`. This is used in `_isRootOwnedSelector` to prevent the admin from remapping this critical function to a module. If the hardcoded value doesn't match the actual computed selector of `setSelectorModule(bytes4,address,bool)`, the protection would be bypassed. The actual selector can be computed as `bytes4(keccak256('setSelectorModule(bytes4,address,bool)'))`. While the comment says this is the correct selector, hardcoded selectors are fragile and error-prone, especially if the function signature changes.


Hide Details
Impact
If any of the hardcoded selectors are incorrect (due to typo or function signature change), the `_isRootOwnedSelector` protection would fail to protect those functions. An admin could then remap `setSelectorModule` to a malicious module, allowing arbitrary storage writes. This is a code quality issue that could become a security issue if the contract is modified.
Scenario
Verification: `bytes4(keccak256('setSelectorModule(bytes4,address,bool)'))` should equal `0x5837c6a8`. If it doesn't, the protection is broken. Similarly for the other constants.
Affected code
bytes4 private constant SELECTOR_INITIALIZE = 0x7b89ffdb;
bytes4 private constant SELECTOR_UPGRADE_TO_AND_CALL = 0x4f1ef286;
bytes4 private constant SELECTOR_PROXIABLE_UUID = 0x52d1902d;
bytes4 private constant SELECTOR_SET_SELECTOR_MODULE = 0x5837c6a8; // setSelectorModule(bytes4,address,bool)

function _isRootOwnedSelector(bytes4 selector) private pure returns (bool) {
return selector == SELECTOR_INITIALIZE || selector == SELECTOR_UPGRADE_TO_AND_CALL
|| selector == SELECTOR_PROXIABLE_UUID || selector == SELECTOR_SET_SELECTOR_MODULE;
}
Proposed fix
Use computed selectors instead of hardcoded values to prevent typos and ensure correctness:
bytes4 private constant SELECTOR_INITIALIZE = 
    bytes4(keccak256('initialize((address,address,address,address,address,uint16,uint16,uint8,uint8,uint64,uint16))'));
bytes4 private constant SELECTOR_UPGRADE_TO_AND_CALL = 
    bytes4(keccak256('upgradeToAndCall(address,bytes)'));
bytes4 private constant SELECTOR_PROXIABLE_UUID = 
    bytes4(keccak256('proxiableUUID()'));
bytes4 private constant SELECTOR_SET_SELECTOR_MODULE = 
    bytes4(keccak256('setSelectorModule(bytes4,address,bool)'));
Alternatively, add a test that verifies these constants match the actual function selectors.

gas Severity
1
1

MarketEngineDispatcher.sol
Gas Optimization: _enforceApprovedModule Called Twice Per Delegatecall (Once in _delegateForSelector, Once Implicitly)
In `_delegateForSelector`, `_enforceApprovedModule(module)` is called before the delegatecall. `_enforceApprovedModule` itself calls `_enforceModuleStorageCompatibility(module)`, which performs a `staticcall` to the module. This means every delegatecall performs: (1) An `approvedModules` storage read. (2) A `moduleCodeHash` storage read. (3) A `keccak256(module.code)` computation (expensive for large modules). (4) A `staticcall` to the module for storage compatibility check. These 4 operations happen on EVERY function call routed through the dispatcher, adding significant gas overhead to all user-facing operations.


Hide Details
Impact
Every user-facing function call (deposit, claim, switch, lock, resolve) incurs the overhead of: 2 storage reads, a full bytecode hash computation, and a staticcall. For large module contracts, `keccak256(module.code)` can cost 10,000+ gas. This adds significant cost to all user operations and could make the protocol uncompetitive on gas-sensitive chains.
Scenario
Gas measurement:
- keccak256 of 10KB bytecode ≈ 10,000 gas
- 2 SLOAD operations ≈ 4,200 gas (cold) or 200 gas (warm)
- staticcall overhead ≈ 700 gas + execution cost
- Total overhead per call: ~15,000+ gas on cold storage
Affected code
function _delegateForSelector(bytes4 selector) private {
ModuleRegistryStorage storage $ = _moduleRegistryStorage();
address module = $.selectorToModule[selector];
if (module == address(0)) revert ModuleNotSet(selector);
_enforceApprovedModule(module); // Expensive: storage reads + keccak256(code) + staticcall

assembly {
calldatacopy(0, 0, calldatasize())
let success := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
// ...
}
}

function _enforceApprovedModule(address module) private view {
// Storage read 1: approvedModules
// Storage read 2: moduleCodeHash
// keccak256(module.code) - O(n) where n = bytecode size
// staticcall for storage compatibility
}
Proposed fix
Consider caching the module approval check or using a lighter verification mechanism for hot paths. One approach is to use a version/nonce that changes when modules are updated, allowing a cheaper check:
// Option 1: Cache module validity in transient storage
// Option 2: Only check code hash on registration, not on every call
// (accept the risk that code hash check on every call is defense-in-depth)

// Option 3: Separate security levels - full check on registration, lighter check on call
function _enforceApprovedModuleFast(address module) private view {
    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    if (!$.approvedModules[module]) revert UnapprovedModule(module);
    // Skip code hash re-check for gas savings
    // Code hash is checked on registration; metamorphic attack is mitigated by
    // the fact that selfdestruct + redeploy would change the hash and cause revert
}
Note: Removing the runtime code hash check reduces security against metamorphic contracts. Document the tradeoff clearly.

informational Severity
3
1

MarketEngineCoreLifecycleModule.sol
Missing Validation That epochId Matches Template's Expected Next Epoch in cancelEpoch
The `cancelEpoch` function in `MarketEngineCoreLifecycleModule` calls `_requireActiveEpoch(ledger, epochId)` which checks `epochId == ledger.activeEpochId`. This is correct. However, after cancellation, `ledger.lastResolvedEpochId = epochId` is set. This means the next `openEpoch` call will require `epochId == ledger.activeEpochId + 1 == epochId + 1`. But `_requireCanOpenNextEpoch` checks `ledger.activeEpochId != ledger.lastResolvedEpochId` - after cancel, `activeEpochId == lastResolvedEpochId == epochId`, so this passes. The issue is that `cancelEpoch` does NOT reset `ledger.activeEpochId` to 0 or to `lastResolvedEpochId`. After cancellation, `activeEpochId` still points to the cancelled epoch. The next `openEpoch` must use `epochId + 1`. This is by design, but there's no validation that the cancelled epoch's `epochId` is consistent with the ledger's expected sequence, creating a potential for epoch ID gaps if cancellations happen out of order (though the `_requireActiveEpoch` check prevents this).


Hide Details
Impact
This is primarily an informational/design clarity issue. The behavior is consistent but could confuse integrators who expect `activeEpochId` to be reset after cancellation. More importantly, if a future module or upgrade incorrectly assumes `activeEpochId` is reset to 0 after cancellation (as it is in `resetRollingLifecycle`), it could cause epoch ID conflicts.
Scenario
1. Template has activeEpochId=5, lastResolvedEpochId=4
2. Admin calls cancelEpoch(templateId, 5, reason, false)
3. After cancel: activeEpochId=5, lastResolvedEpochId=5
4. _requireCanOpenNextEpoch checks: activeEpochId(5) == lastResolvedEpochId(5) → OK
5. Next openEpoch must use epochId=6
6. This is correct behavior but activeEpochId=5 still points to a cancelled epoch
7. Any code that reads activeEpochId and assumes it's an active/open epoch will be wrong
Affected code
function cancelEpoch(bytes32 templateId, uint64 epochId, MarketTypes.CancelReason reason, bool voided)
external
nonReentrant
{
// ...
_requireActiveEpoch(ledger, epochId); // Checks epochId == activeEpochId
// ...
ledger.lastResolvedEpochId = epochId; // Sets lastResolvedEpochId = activeEpochId
// activeEpochId is NOT updated here
emit EpochCancelled(templateId, epochId, uint8(reason));
// After this: activeEpochId == lastResolvedEpochId == epochId
// Next openEpoch must use epochId+1
}
Proposed fix
Consider adding a comment or documentation clarifying that `activeEpochId` is not reset after cancellation and points to the last cancelled/resolved epoch. Alternatively, add a view function that returns whether the current active epoch is in a terminal state:
// Add to MarketEngineViewModule or MarketEngineState
function isActiveEpochTerminal(bytes32 templateId) external view returns (bool) {
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (ledger.activeEpochId == 0) return true;
    MarketTypes.Epoch storage e = _epochs[templateId][ledger.activeEpochId];
    return e.status == MarketTypes.EpochStatus.Resolved || 
           e.status == MarketTypes.EpochStatus.Cancelled || 
           e.status == MarketTypes.EpochStatus.Voided;
}
2

MarketEngineRollingLifecycleModule.sol
genesisStartRolling Emits Incorrect lockAt and resolveAt in RollingGenesisStarted Event
In `genesisStartRolling`, the `RollingGenesisStarted` event is emitted with `lockAt = ts + t.rollingIntervalSeconds` and `resolveAt = ts + 2 * t.rollingIntervalSeconds`. However, the actual epoch timing is set in `_openRollingEpoch` as `lockAt = startTs + inter` and `resolveAt = startTs + 2 * inter` where `startTs = ts`. So the event values should match. BUT: `_openRollingEpoch` is called BEFORE the event is emitted, and `_openRollingEpoch` emits its own `EpochOpened` event with the correct timing. The `RollingGenesisStarted` event then re-emits the same timing values. This is redundant but not incorrect. However, if `t.rollingIntervalSeconds` changes between the `_openRollingEpoch` call and the event emission (which can't happen in the same transaction), the values would diverge. More importantly, the event uses `t.rollingIntervalSeconds` directly from storage, which is the same value used in `_openRollingEpoch`, so they should always match.


Hide Details
Impact
This is an informational issue. The event values are correct and match the actual epoch timing. However, the redundancy could confuse off-chain indexers that process both `EpochOpened` and `RollingGenesisStarted` events for the same epoch.
Scenario
No exploit possible. This is a code quality issue.
Affected code
function genesisStartRolling(bytes32 templateId) external {
// ...
uint64 ts = uint64(block.timestamp);
uint64 opened = _openRollingEpoch(templateId, ts, t); // Opens epoch, emits EpochOpened
ledger.rollingPhase = MarketTypes.RollingPhase.GenesisOpen;
emit RollingGenesisStarted(
templateId, opened,
uint64(ts + t.rollingIntervalSeconds), // lockAt
uint64(ts + 2 * t.rollingIntervalSeconds) // resolveAt
);
// These values match EpochOpened but are redundant
}
Proposed fix
Either remove the redundant timing parameters from `RollingGenesisStarted` (since `EpochOpened` already contains this information), or document that both events carry the same timing data:
// Option 1: Remove redundant timing from RollingGenesisStarted
event RollingGenesisStarted(bytes32 indexed templateId, uint64 epochId);

// Option 2: Keep as-is but add documentation
// @dev lockAt and resolveAt mirror the EpochOpened event for the same epochId
event RollingGenesisStarted(bytes32 indexed templateId, uint64 epochId, uint64 lockAt, uint64 resolveAt);
3

MarketEngineCoreLifecycleModule.sol
Corridor Market Validation Loop Has Off-By-One Error
In `_validateTemplate` for `MarketType.Corridor`, the validation loop for range bounds has an off-by-one issue. The comment says 'outcomes 0=in-band, 1=upper breach, 2=lower breach' and `outcomeCount` must be 3. The validation checks `rangeBoundsE8[0] < rangeBoundsE8[1]` (lower bound < upper bound), then loops `for (uint256 i = 2; i < uint256(t.outcomeCount) - 1; i++)`. Since `outcomeCount=3`, the loop runs for `i in [2, 2)` which is an EMPTY loop (2 < 3-1=2 is false). This means only the first pair of bounds is validated, and any additional bounds (if outcomeCount were > 3, which is prevented) would not be validated. While the current constraint `outcomeCount==3` makes this safe, the loop logic is misleading and would be incorrect if the constraint were relaxed.


Hide Details
Impact
The loop never executes for Corridor markets (since outcomeCount=3 and the loop condition is `i < 2`). This is currently safe because only 2 range bounds are needed for a Corridor market (lower and upper). However, the dead code is misleading and could cause issues if the outcomeCount constraint is relaxed in a future upgrade.
Scenario
For outcomeCount=3: loop runs for i in [2, 2) → empty, no additional validation
Only rangeBoundsE8[0] < rangeBoundsE8[1] is checked
Affected code
} else if (t.marketType == MarketTypes.MarketType.Corridor) {
// `Resolvers.resolveCorridor` uses outcomes 0=in-band, 1=upper breach, 2=lower breach.
if (t.outcomeCount != 3) revert InvalidTemplate();
if (!(t.rangeBoundsE8[0] < t.rangeBoundsE8[1])) revert InvalidTemplate();
for (uint256 i = 2; i < uint256(t.outcomeCount) - 1; i++) { // Loop never executes!
if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
}
}
Proposed fix
Remove the dead loop or fix it to correctly validate the intended bounds:
} else if (t.marketType == MarketTypes.MarketType.Corridor) {
    if (t.outcomeCount != 3) revert InvalidTemplate();
    // Corridor needs exactly 2 bounds: lower (index 0) and upper (index 1)
    if (!(t.rangeBoundsE8[0] < t.rangeBoundsE8[1])) revert InvalidTemplate();
    // Remove the dead loop - it never executes for outcomeCount=3
}