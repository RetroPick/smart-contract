DeFi Protocol - Prediction Market Engine

MarketEngine is a modular prediction market protocol that manages binary and multi-outcome markets with support for both manual and rolling execution modes. The system uses a dispatcher pattern to route function calls to specialized modules via delegatecall, managing user deposits, position switching, epoch lifecycle (open/lock/resolve), oracle integration, yield routing, and claims settlement. The protocol supports multiple oracle types (Chainlink, TrustedReporter) and market types (Direction, Threshold, Convergence, Composite, Range, Corridor, Cascade).

Show less
Access Control
role_based


Privileged Roles
1
admin - full protocol control including template management, oracle configuration, pause/resume, fee withdrawal
2
workerAuthority - can open/lock/resolve epochs and execute rolling rounds
3
treasury - can withdraw accumulated fees
4
depositExecutor - whitelisted addresses that can deposit on behalf of other users
5
yieldRouter - trusted external contract for yield farming integration

External Calls
1
IERC20 (stakeToken)
2
IPriceOracle / IPriceOracleWithRoundId
3
IYieldRouterV2
4
IEventOracle

External Systems
1
Chainlink Oracle Network
2
Yield Router (Aave/4626)
3
Event Oracle (Trusted Reporter)

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


critical Severity
1
1

MarketEngineDispatcher.sol
Delegatecall to Untrusted Module Contracts via setSelectorModule
The MarketEngineDispatcher uses delegatecall to route function calls to module contracts based on function selectors. The setSelectorModule function allows the admin to point any selector at an arbitrary module contract address with minimal validation. The only checks are that the module address is non-zero and has code. There is no validation of the module's bytecode, no whitelist of approved modules, and no verification that the module correctly implements the expected interface or storage layout. A malicious or compromised admin could point selectors at malicious contracts that execute arbitrary code with full access to the dispatcher's storage, including all user funds, oracle configurations, and state variables. This is equivalent to a complete protocol compromise.


Hide Details
Impact
A malicious or compromised admin can deploy a malicious module contract and point any function selector at it via setSelectorModule. When users call that function, the malicious module executes arbitrary code with full access to the dispatcher's storage. This allows the attacker to: (1) steal all user deposits and fees from the vault, (2) modify oracle configurations to manipulate settlement, (3) change admin/treasury/worker addresses, (4) drain yield router integrations, (5) completely compromise the protocol. This is a critical vulnerability that gives the admin unlimited power to steal funds.
Scenario
// Malicious module contract
contract MaliciousModule {
    function stealFunds() external {
        // This executes in dispatcher's context via delegatecall
        // Can access all storage variables
        // Example: transfer all vault funds to attacker
        // Since delegatecall preserves storage, attacker can:
        // 1. Read _vaults[templateId].active
        // 2. Call stakeToken.transfer(attacker, amount)
        // 3. Modify state to cover tracks
    }
}

// Attack sequence:
// 1. Attacker compromises admin account (or is the admin)
// 2. Calls setSelectorModule(0x12345678, maliciousModuleAddress, false)
// 3. When any user calls a function with selector 0x12345678, malicious code executes
// 4. Malicious code steals funds from vault
Affected code
function setSelectorModule(bytes4 selector, address module, bool makeImmutable) external onlyAdmin {
    if (module == address(0) || module.code.length == 0) revert InvalidModule();
    if (selectorImmutable[selector]) revert SelectorImmutable(selector);
    if (_isRootOwnedSelector(selector)) revert SelectorImmutable(selector);
    selectorToModule[selector] = module;
    if (makeImmutable) selectorImmutable[selector] = true;
    emit SelectorModuleSet(selector, module, makeImmutable);
}

function _delegateForSelector(bytes4 selector) private {
    address module = selectorToModule[selector];
    if (module == address(0)) revert ModuleNotSet(selector);

    assembly {
        calldatacopy(0, 0, calldatasize())
        let success := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
        returndatacopy(0, 0, returndatasize())
        switch success
        case 0 { revert(0, returndatasize()) }
        default { return(0, returndatasize()) }
    }
}
Proposed fix
Implement a module whitelist and bytecode verification system:
// Add module registry with verification
mapping(address => bool) public approvedModules;
mapping(bytes4 => address) public selectorToModule;

// Store module bytecode hashes for verification
mapping(address => bytes32) public moduleCodeHash;

function registerModule(address module, bytes32 expectedCodeHash) external onlyAdmin {
    require(module != address(0) && module.code.length > 0, "Invalid module");
    require(keccak256(module.code) == expectedCodeHash, "Code hash mismatch");
    approvedModules[module] = true;
    moduleCodeHash[module] = expectedCodeHash;
}

function setSelectorModule(bytes4 selector, address module, bool makeImmutable) external onlyAdmin {
    require(approvedModules[module], "Module not approved");
    require(keccak256(module.code) == moduleCodeHash[module], "Module code changed");
    require(!selectorImmutable[selector], "Selector immutable");
    require(!_isRootOwnedSelector(selector), "Root selector protected");
    
    selectorToModule[selector] = module;
    if (makeImmutable) selectorImmutable[selector] = true;
    emit SelectorModuleSet(selector, module, makeImmutable);
}

function _delegateForSelector(bytes4 selector) private {
    address module = selectorToModule[selector];
    require(module != address(0), "Module not set");
    require(approvedModules[module], "Module not approved");
    require(keccak256(module.code) == moduleCodeHash[module], "Module code changed");
    
    assembly {
        calldatacopy(0, 0, calldatasize())
        let success := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
        returndatacopy(0, 0, returndatasize())
        switch success
        case 0 { revert(0, returndatasize()) }
        default { return(0, returndatasize()) }
    }
}
Alternatively, use a multi-sig or governance mechanism for module registration, and implement ERC-7201 namespaced storage to prevent storage collisions.

high Severity
4
1

MarketEngineCoreLifecycleModule.sol
Oracle Confidence Validation Insufficient for Small Prices
The _confidenceWithinBand function validates oracle confidence by checking if confidence <= (abs(price) * maxConfidenceBps) / 10_000. This creates a relative confidence band based on the price magnitude. For very small prices (e.g., 1 wei or 1 satoshi equivalent), the confidence band becomes extremely small. For example, if price is 100 (0.000001 in 8 decimals) and maxConfidenceBps is 500 (5%), the allowed confidence is only 5 wei. This is problematic because: (1) Oracle confidence intervals are typically absolute values, not relative percentages, (2) Very small prices may have confidence intervals larger than the allowed band, causing valid oracle data to be rejected, (3) Markets with small prices could become unresolvable if oracle confidence exceeds the calculated band. Additionally, the function uses assembly to compute absolute value and has a special case for type(int256).min which reverts, but this edge case handling is incomplete.


Hide Details
Impact
Markets with small prices may become unresolvable if oracle confidence exceeds the relative band. This causes: (1) Epoch lock/resolve operations to revert with OracleConfidenceTooWide, (2) Rolling markets to halt when encountering small-price markets, (3) Users unable to claim winnings from unresolvable epochs, (4) Potential for market manipulation by forcing oracle confidence to exceed the band. The impact is especially severe for markets denominated in small units (e.g., satoshis, wei) or for markets with very small price movements.
Scenario
// Example: Market with small price
int256 priceE8 = 100; // 0.000001 in 8 decimals (very small price)
uint256 confidenceE8 = 10; // Oracle confidence of 10 wei
uint16 maxConfidenceBps = 500; // 5% confidence band

// Calculate allowed confidence band
uint256 limit = (uint256(100) * uint256(500)) / 10_000;
// limit = 50000 / 10_000 = 5

// Validation fails because confidenceE8 (10) > limit (5)
// Even though 10 wei is a tiny confidence interval, it exceeds the 5% band
// This causes epoch resolution to fail

// For type(int256).min edge case:
int256 minPrice = type(int256).min;
// abs calculation in assembly: abs = minPrice (no negation possible)
// if (abs == (1 << 255)) revert InvalidOraclePrice();
// This reverts, preventing resolution even if oracle data is valid
Affected code
function _confidenceWithinBand(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps)
    internal
    pure
    returns (bool)
{
    uint256 abs;
    assembly {
        abs := priceE8
        if slt(priceE8, 0) { abs := sub(0, priceE8) }
    }
    // slither-disable-next-line incorrect-equality -- detects `type(int256).min` (no positive absolute value in int256).
    if (abs == (1 << 255)) revert InvalidOraclePrice();
    uint256 limit = (abs * uint256(maxConfidenceBps)) / 10_000;
    return confidenceE8 <= limit;
}
Proposed fix
Implement a hybrid confidence validation that uses both relative and absolute bounds:
function _confidenceWithinBand(
    int256 priceE8,
    uint256 confidenceE8,
    uint16 maxConfidenceBps,
    uint256 minAbsoluteConfidenceE8 // New parameter
) internal pure returns (bool) {
    uint256 abs;
    assembly {
        abs := priceE8
        if slt(priceE8, 0) { abs := sub(0, priceE8) }
    }
    
    // Handle type(int256).min edge case
    if (abs == (1 << 255)) {
        // For extreme prices, use absolute confidence check only
        return confidenceE8 <= minAbsoluteConfidenceE8;
    }
    
    // Calculate relative band
    uint256 relativeBand = (abs * uint256(maxConfidenceBps)) / 10_000;
    
    // Use maximum of relative band and minimum absolute confidence
    uint256 limit = relativeBand > minAbsoluteConfidenceE8 ? relativeBand : minAbsoluteConfidenceE8;
    
    return confidenceE8 <= limit;
}

// Update _enforceConfidence to pass minimum confidence
function _enforceConfidence(
    int256 priceE8,
    uint256 confidenceE8,
    uint16 maxConfidenceBps,
    uint256 minAbsoluteConfidenceE8
) internal pure {
    if (!_confidenceWithinBand(priceE8, confidenceE8, maxConfidenceBps, minAbsoluteConfidenceE8)) {
        revert OracleConfidenceTooWide();
    }
}

// Store minimum confidence as template parameter
struct Template {
    // ... existing fields ...
    uint256 minAbsoluteConfidenceE8; // Minimum absolute confidence in 8 decimals
}
2

MarketEngineCoreLifecycleModule.sol
Inconsistent Yield Router Failure Handling Between Manual and Rolling Modes
The protocol handles yield router failures inconsistently between manual and rolling epoch resolution modes. In manual mode (_finishResolveEpochManual), if the yield router's withdrawScaled call fails, the function reverts with YieldWithdrawFailed, blocking epoch resolution entirely. In rolling mode (_finishResolveEpoch with rollingLink=true), the same failure causes the market to halt instead of reverting. This inconsistency creates several problems: (1) Manual markets become permanently stuck if yield router fails, with no recovery mechanism, (2) Rolling markets halt but can be recovered via resetRollingLifecycle, (3) Users cannot claim winnings from stuck manual epochs, (4) The protocol's behavior is unpredictable depending on execution mode. Additionally, the yield router is trusted but failures are not properly handled - there's no circuit breaker, no fallback mechanism, and no way to recover from yield router insolvency.


Hide Details
Impact
Manual markets can become permanently stuck if the yield router fails or becomes insolvent. Users cannot claim winnings, and the protocol cannot recover without admin intervention (which may not be possible if the yield router is permanently broken). This results in: (1) Permanent loss of user funds in stuck epochs, (2) Inability to resolve markets, (3) Accumulated fees and yield locked in vault, (4) Protocol reputation damage. Rolling markets have better recovery (via halt and reset), but the inconsistency is confusing and error-prone.
Scenario
// Scenario 1: Yield router becomes insolvent
// 1. Admin sets yieldRouter to a contract that will fail
// 2. Users deposit to manual market, funds are routed to yield router
// 3. Yield router becomes insolvent (e.g., Aave hack, smart contract bug)
// 4. Admin tries to resolve epoch
// 5. _withdrawRoutedPrincipalOnResolve calls r.withdrawScaled()
// 6. Yield router reverts (insufficient funds)
// 7. _withdrawRoutedPrincipalOnResolve catches error and reverts YieldWithdrawFailed
// 8. resolveEpoch reverts, epoch cannot be resolved
// 9. Users cannot claim winnings
// 10. Funds are locked in yield router and vault

// Scenario 2: Rolling market with same yield router failure
// 1-6. Same as above
// 7. _withdrawResolvePrincipal catches error
// 8. Since rollingLink=true, calls _haltRolling instead of reverting
// 9. Market halts but can be recovered via resetRollingLifecycle
// 10. Admin can reset and open new epochs
Affected code
// Manual mode - reverts on yield router failure
function _withdrawRoutedPrincipalOnResolve(bytes32 templateId, uint64 epochId, uint256 totalPool)
    internal
    returns (uint256 grossYield)
{
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0) || totalPool < 1) return 0;

    uint256 routedPrincipal = (totalPool * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
    if (routedPrincipal < 1) return 0;

    try r.withdrawScaled(templateId, routedPrincipal) returns (uint256 grossReturned) {
        if (grossReturned > routedPrincipal) return grossReturned - routedPrincipal;
        return 0;
    } catch {
        emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
        revert YieldWithdrawFailed(); // REVERTS - blocks resolution
    }
}

// Rolling mode - halts market on yield router failure
function _withdrawResolvePrincipal(bytes32 templateId, uint64 epochId, uint256 totalPool, bool rollingLink)
    internal
    returns (uint256 grossYield)
{
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0) || totalPool < 1) return 0;

    uint256 routedPrincipal = (totalPool * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
    if (routedPrincipal < 1) return 0;

    try r.withdrawScaled(templateId, routedPrincipal) returns (uint256 grossReturned) {
        if (grossReturned > routedPrincipal) return grossReturned - routedPrincipal;
        return 0;
    } catch {
        emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
        if (rollingLink) {
            _haltRolling(
                templateId,
                _ledgers[templateId],
                MarketTypes.RollingHaltReason.OracleFailure,
                _ledgers[templateId].activeEpochId
            );
            return 0; // HALTS - allows recovery
        }
        revert YieldWithdrawFailed();
    }
}
Proposed fix
Implement consistent failure handling with recovery mechanisms:
// Add yield router circuit breaker
bool public yieldRouterDisabled;
uint256 public yieldRouterFailureCount;
uint256 public constant MAX_YIELD_ROUTER_FAILURES = 3;

function _withdrawRoutedPrincipalOnResolve(
    bytes32 templateId,
    uint64 epochId,
    uint256 totalPool
) internal returns (uint256 grossYield) {
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0) || totalPool < 1 || yieldRouterDisabled) return 0;

    uint256 routedPrincipal = (totalPool * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
    if (routedPrincipal < 1) return 0;

    try r.withdrawScaled(templateId, routedPrincipal) returns (uint256 grossReturned) {
        if (grossReturned > routedPrincipal) return grossReturned - routedPrincipal;
        return 0;
    } catch {
        emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
        
        // Increment failure counter
        yieldRouterFailureCount++;
        
        // Disable yield router after too many failures
        if (yieldRouterFailureCount >= MAX_YIELD_ROUTER_FAILURES) {
            yieldRouterDisabled = true;
            emit YieldRouterDisabled();
        }
        
        // Return 0 yield instead of reverting
        // This allows epoch resolution to continue
        // Funds remain in yield router (can be recovered separately)
        return 0;
    }
}

// Add emergency yield withdrawal function
function emergencyYieldWithdraw(bytes32 templateId) external onlyAdmin {
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0)) revert Unauthorized();
    r.emergencyWithdraw(templateId);
}

// Add yield router reset function
function resetYieldRouterFailures() external onlyAdmin {
    yieldRouterFailureCount = 0;
    yieldRouterDisabled = false;
}
3

MarketEngineUserOpsClaimsModule.sol
Unchecked Return Value from Yield Router depositScaled
In the _depositToSide function, when routing deposits to the yield router, the return value from yieldRouter.depositScaled is intentionally ignored with a comment stating 'return (attribution units) intentionally unused'. However, this creates a problem: if the yield router's depositScaled call fails silently (returns false or reverts), the failure is caught and logged but the deposit continues as if it succeeded. This means: (1) User deposits are recorded in the vault as if they were routed to yield router, (2) But the actual funds may not be routed (if the call failed), (3) The vault accounting becomes inconsistent - it thinks funds are earning yield when they're not, (4) On resolution, the protocol tries to withdraw from yield router but the funds were never deposited, causing withdrawal failures. The try-catch block catches all exceptions but doesn't validate that the deposit actually succeeded.


Hide Details
Impact
Vault accounting becomes inconsistent when yield router deposits fail. The protocol records deposits as routed but they're not actually in the yield router. This causes: (1) Epoch resolution to fail when trying to withdraw non-existent routed funds, (2) Yield calculations to be incorrect (no yield earned on unrouted funds), (3) Potential for vault insolvency if many deposits fail to route, (4) Users unable to claim winnings if resolution fails. The impact is especially severe if the yield router becomes temporarily unavailable - all deposits during that period would fail to route but be recorded as routed.
Scenario
// Scenario: Yield router becomes temporarily unavailable
// 1. User calls depositToSide with 1000 tokens
// 2. Tokens are transferred to contract
// 3. Contract tries to route 950 tokens to yield router
// 4. Yield router is down (reverts or returns false)
// 5. try-catch catches the error
// 6. YieldRouterDepositFailed event is emitted
// 7. Function continues - deposit is recorded in vault
// 8. Vault thinks 950 tokens are earning yield in router
// 9. But tokens are actually sitting in contract
// 10. On epoch resolution, protocol tries to withdraw 950 tokens
// 11. Withdrawal fails because tokens were never deposited
// 12. Resolution fails, users cannot claim

// Vault accounting mismatch:
// _vaults[templateId].active = 1000 (recorded)
// Actual tokens in contract = 1000 (not routed)
// Actual tokens in yield router = 0 (deposit failed)
// Protocol expects 950 in router, 50 in contract
// But actually has 1000 in contract, 0 in router
Affected code
function _depositToSide(
    address payer,
    address beneficiary,
    bytes32 templateId,
    uint64 epochId,
    uint8 outcomeIndex,
    uint256 amount
) internal {
    // ... validation code ...
    
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
            stakeToken.forceApprove(address(r), routeAmount);
            // slither-disable-next-line unused-return -- `depositScaled` return (attribution units) intentionally unused; failures are isolated in `catch`.
            try r.depositScaled(templateId, routeAmount) {}
            catch {
                emit YieldRouterDepositFailed(templateId, routeAmount);
                // Continues without reverting - deposit is recorded but not routed
            }
        }
    }
    emit PositionDeposited(templateId, epochId, beneficiary, outcomeIndex, amount);
}
Proposed fix
Implement proper validation of yield router deposits:
function _depositToSide(
    address payer,
    address beneficiary,
    bytes32 templateId,
    uint64 epochId,
    uint8 outcomeIndex,
    uint256 amount
) internal {
    // ... validation code ...
    
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
            stakeToken.forceApprove(address(r), routeAmount);
            
            bool depositSucceeded = false;
            try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) {
                // Validate that deposit was successful
                if (attributionUnits > 0) {
                    depositSucceeded = true;
                }
            } catch {
                // Deposit failed
                depositSucceeded = false;
            }
            
            if (!depositSucceeded) {
                // If deposit fails, reduce the recorded active amount
                // This keeps vault accounting consistent
                _vaults[templateId].active -= routeAmount;
                ledger.decreaseActiveCollateral(routeAmount);
                emit YieldRouterDepositFailed(templateId, routeAmount);
                // Funds remain in contract (not routed)
            }
        }
    }
    emit PositionDeposited(templateId, epochId, beneficiary, outcomeIndex, amount);
}

// Alternative: Track routed vs unrouted amounts separately
struct VaultBalances {
    uint256 active;           // Total active funds
    uint256 routed;           // Amount successfully routed to yield router
    uint256 unrouted;         // Amount not routed (in contract)
    uint256 claims;           // Amount reserved for claims
    uint256 fees;             // Amount reserved for fees
}

// Then in withdrawal logic, only withdraw from routed amount
function _withdrawRoutedPrincipalOnResolve(
    bytes32 templateId,
    uint64 epochId,
    uint256 totalPool
) internal returns (uint256 grossYield) {
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0)) return 0;
    
    // Only withdraw the amount that was actually routed
    uint256 routedAmount = _vaults[templateId].routed;
    if (routedAmount < 1) return 0;
    
    try r.withdrawScaled(templateId, routedAmount) returns (uint256 grossReturned) {
        if (grossReturned > routedAmount) return grossReturned - routedAmount;
        return 0;
    } catch {
        emit YieldRouterWithdrawFailed(templateId, epochId, routedAmount);
        return 0;
    }
}
4

MarketEngineDispatcher.sol
Potential Storage Collision in Delegatecall Modules
The MarketEngineDispatcher uses delegatecall to route calls to module contracts. All modules inherit from MarketEngineState which defines the storage layout. However, there is no enforcement that modules maintain the exact same storage layout as MarketEngineState. If a module adds new state variables or reorders existing ones, it could cause storage collisions where module state overwrites dispatcher state. The gap array (uint256[41] private __gap) provides some buffer but is not foolproof. Additionally, if a module is upgraded or replaced with a different implementation, the new module might have a different storage layout, causing collisions. The contract includes a comment acknowledging this risk ('Keep this layout append-only for upgrade safety') but provides no mechanism to enforce it.


Hide Details
Impact
Storage collisions could cause: (1) Module state to overwrite critical dispatcher state (admin, treasury, oracle addresses), (2) Dispatcher state to be corrupted by module operations, (3) Incorrect settlement calculations if ledger or epoch state is corrupted, (4) Unauthorized access to funds if vault balances are corrupted, (5) Complete protocol compromise if admin address is overwritten. The impact is especially severe because delegatecall gives modules full access to dispatcher storage, and there's no validation that storage layouts match.
Scenario
// Malicious or buggy module with storage collision
contract MaliciousModule is MarketEngineState {
    // Intentionally add new state variables
    // These will collide with __gap array
    uint256 public maliciousVar1; // Overwrites __gap[0]
    uint256 public maliciousVar2; // Overwrites __gap[1]
    address public newAdmin;      // Overwrites __gap[2]
    
    function stealAdmin() external {
        // When this function is called via delegatecall:
        // 1. newAdmin is stored at storage slot for __gap[2]
        // 2. But __gap[2] is actually the storage slot for something else
        // 3. This overwrites critical state
        newAdmin = msg.sender;
    }
}

// Attack sequence:
// 1. Admin calls setSelectorModule(0x12345678, maliciousModuleAddress, false)
// 2. User calls function with selector 0x12345678
// 3. Dispatcher routes to malicious module via delegatecall
// 4. Malicious module's stealAdmin() executes in dispatcher context
// 5. newAdmin = msg.sender overwrites storage at __gap[2]
// 6. This corrupts dispatcher state
// 7. Subsequent operations fail or behave unexpectedly
Affected code
// MarketEngineState - defines storage layout
abstract contract MarketEngineState {
    IERC20 public stakeToken;
    IPriceOracle public priceOracle;
    // ... many more state variables ...
    
    // --- dispatcher state (appended after legacy state) ---
    mapping(bytes4 selector => address module) internal selectorToModule;
    mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

    uint256[41] private __gap; // Gap for future upgrades
}

// Module inherits from MarketEngineState
contract MarketEngineCoreLifecycleModule is MarketEngineState, ReentrancyGuardTransient {
    // If this module adds new state variables, they will collide with dispatcher storage
    // Example of problematic code:
    // uint256 public newVariable; // This would overwrite __gap[0]
    
    // No mechanism to prevent this
}

// Dispatcher routes calls via delegatecall
function _delegateForSelector(bytes4 selector) private {
    address module = selectorToModule[selector];
    if (module == address(0)) revert ModuleNotSet(selector);

    assembly {
        calldatacopy(0, 0, calldatasize())
        let success := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
        returndatacopy(0, 0, returndatasize())
        switch success
        case 0 { revert(0, returndatasize()) }
        default { return(0, returndatasize()) }
    }
}
Proposed fix
Implement storage layout verification and use ERC-7201 namespaced storage:
// Option 1: Use ERC-7201 namespaced storage
// This prevents collisions by using unique storage slots

abstract contract MarketEngineState {
    // Use ERC-7201 namespaced storage
    bytes32 private constant MARKET_ENGINE_STORAGE_LOCATION = 
        keccak256(abi.encode(uint256(keccak256("market.engine.storage")) - 1)) & ~bytes32(uint256(0xff));
    
    struct MarketEngineStorage {
        IERC20 stakeToken;
        IPriceOracle priceOracle;
        // ... all state variables ...
        mapping(bytes4 selector => address module) selectorToModule;
        mapping(bytes4 selector => bool immutableSelector) selectorImmutable;
    }
    
    function _getMarketEngineStorage() internal pure returns (MarketEngineStorage storage $) {
        assembly {
            $.slot := MARKET_ENGINE_STORAGE_LOCATION
        }
    }
}

// Option 2: Implement storage layout verification
contract MarketEngineDispatcher is Initializable, ReentrancyGuardTransient, UUPSUpgradeable, MarketEngineState {
    // Store expected storage layout hash
    bytes32 public expectedStorageHash;
    
    function setSelectorModule(bytes4 selector, address module, bool makeImmutable) external onlyAdmin {
        if (module == address(0) || module.code.length == 0) revert InvalidModule();
        
        // Verify module storage layout matches expected layout
        bytes32 moduleStorageHash = keccak256(module.code);
        // This is a simplified check - in practice, you'd need more sophisticated verification
        
        if (selectorImmutable[selector]) revert SelectorImmutable(selector);
        if (_isRootOwnedSelector(selector)) revert SelectorImmutable(selector);
        selectorToModule[selector] = module;
        if (makeImmutable) selectorImmutable[selector] = true;
        emit SelectorModuleSet(selector, module, makeImmutable);
    }
    
    // Add function to verify storage layout
    function verifyStorageLayout() external view returns (bool) {
        // Check that critical state variables are at expected slots
        // This is a runtime check that can detect collisions
        // Implementation would depend on specific storage layout
        return true;
    }
}

// Option 3: Use proxy pattern with separate storage contracts
// Instead of delegatecall, use separate storage contracts
// This eliminates storage collision risk entirely

medium Severity
4
1

MarketEngineUserOpsClaimsModule.sol
Missing Validation of Array Lengths in Batch Operations
The batch operation functions (openEpochsBatch, lockEpochsBatch, resolveEpochsBatch, executeRollingRoundBatch) accept arrays of function parameters without enforcing maximum batch sizes. While openEpochsBatch validates that all input arrays have the same length, there is no check for the total number of operations. An attacker could submit a batch with thousands of epochs, causing: (1) Out-of-gas errors that consume user gas without completing any operations, (2) Denial of service by blocking the worker authority from processing legitimate batches, (3) Potential for griefing attacks where an attacker submits large batches to waste gas. Additionally, claimMany has no batch size limit, allowing users to claim from thousands of epochs in a single transaction, which could exceed gas limits.


Hide Details
Impact
Attackers can cause denial of service by submitting large batch operations that consume excessive gas. This prevents legitimate operations from being processed. For claimMany, users could accidentally submit claims for thousands of epochs, causing their transaction to fail and lose gas. The impact is especially severe for rolling markets where the worker authority needs to execute rounds frequently - a large batch could block the worker from processing legitimate rounds.
Scenario
// Attack 1: DOS via openEpochsBatch
// Attacker calls openEpochsBatch with 10,000 epochs
// Each _openEpoch call costs ~50,000 gas
// Total: 500,000,000 gas (exceeds block limit)
// Transaction fails, but attacker can retry with smaller batches
// Worker authority cannot process legitimate batches

// Attack 2: DOS via claimMany
// User accidentally calls claimMany with 5,000 epoch IDs
// Each _claimOne call costs ~30,000 gas
// Total: 150,000,000 gas (exceeds block limit)
// User's transaction fails, loses gas

// Attack 3: Griefing rolling markets
// Attacker calls executeRollingRoundBatch with 1,000 template IDs
// Each round execution costs ~200,000 gas
// Total: 200,000,000 gas
// Worker authority's round execution fails
// Rolling markets halt due to missed buffer windows
Affected code
function openEpochsBatch(
    bytes32[] calldata templateIds,
    uint64[] calldata epochIds,
    uint64[] calldata openAt,
    uint64[] calldata lockAt,
    uint64[] calldata resolveAt
) external {
    if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
    if (globalPaused) revert ProtocolPaused();
    uint256 n = templateIds.length;
    if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
        revert InvalidTemplate();
    }
    // No check for maximum batch size
    for (uint256 i = 0; i < n; i++) {
        _openEpoch(templateIds[i], epochIds[i], openAt[i], lockAt[i], resolveAt[i]);
    }
}

function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
    uint256 total = 0;
    // No batch size limit
    for (uint256 i = 0; i < epochIds.length; i++) {
        uint256 amt = _claimOne(templateId, epochIds[i], msg.sender);
        total += amt;
        emit Claimed(templateId, epochIds[i], msg.sender, amt);
    }
    if (total == 0) revert NothingToClaim();
    stakeToken.safeTransfer(msg.sender, total);
}
Proposed fix
Add batch size limits to all batch operations:
// Add constant for maximum batch size
uint256 public constant MAX_BATCH_SIZE = 100;

function openEpochsBatch(
    bytes32[] calldata templateIds,
    uint64[] calldata epochIds,
    uint64[] calldata openAt,
    uint64[] calldata lockAt,
    uint64[] calldata resolveAt
) external {
    if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
    if (globalPaused) revert ProtocolPaused();
    uint256 n = templateIds.length;
    
    // Add batch size validation
    if (n == 0 || n > MAX_BATCH_SIZE) revert InvalidTemplate();
    
    if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
        revert InvalidTemplate();
    }
    for (uint256 i = 0; i < n; i++) {
        _openEpoch(templateIds[i], epochIds[i], openAt[i], lockAt[i], resolveAt[i]);
    }
}

function lockEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external {
    if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
    if (globalPaused) revert ProtocolPaused();
    uint256 n = templateIds.length;
    
    if (n == 0 || n > MAX_BATCH_SIZE) revert InvalidTemplate();
    if (n != epochIds.length) revert InvalidTemplate();
    
    for (uint256 i = 0; i < n; i++) {
        _lockEpoch(templateIds[i], epochIds[i]);
    }
}

function resolveEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external nonReentrant {
    if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
    if (globalPaused) revert ProtocolPaused();
    uint256 n = templateIds.length;
    
    if (n == 0 || n > MAX_BATCH_SIZE) revert InvalidTemplate();
    if (n != epochIds.length) revert InvalidTemplate();
    
    for (uint256 i = 0; i < n; i++) {
        _resolveEpoch(templateIds[i], epochIds[i]);
    }
}

function executeRollingRoundBatch(bytes32[] calldata templateIds) external nonReentrant {
    if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
    if (globalPaused) revert ProtocolPaused();
    
    uint256 n = templateIds.length;
    if (n == 0 || n > MAX_BATCH_SIZE) revert InvalidTemplate();
    
    for (uint256 i = 0; i < n; i++) {
        _executeRollingRoundCore(templateIds[i]);
    }
}

function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
    uint256 n = epochIds.length;
    if (n == 0 || n > MAX_BATCH_SIZE) revert InvalidTemplate();
    
    uint256 total = 0;
    for (uint256 i = 0; i < n; i++) {
        uint256 amt = _claimOne(templateId, epochIds[i], msg.sender);
        total += amt;
        emit Claimed(templateId, epochIds[i], msg.sender, amt);
    }
    if (total == 0) revert NothingToClaim();
    stakeToken.safeTransfer(msg.sender, total);
}
2

MarketEngineCoreLifecycleModule.sol
Insufficient Validation of Oracle Monotonicity for Round ID Zero
The _enforceAndUpdateOracleCursor function enforces that oracle round IDs must be monotonically increasing. However, it treats round ID 0 as a valid value (returned when the oracle doesn't support round IDs). This creates a problem: if an oracle falls back to the non-round-ID interface (returning 0), the monotonicity check allows any subsequent round ID to be accepted, even if it's lower than a previous valid round ID. The check 'if (oracleRoundId < c.roundId)' will pass if c.roundId is 0 and the new oracleRoundId is any value. Additionally, if an oracle switches from supporting round IDs to not supporting them (or vice versa), the monotonicity enforcement breaks down.


Hide Details
Impact
Oracle monotonicity enforcement can be bypassed by switching between round ID and non-round-ID interfaces. This allows: (1) Stale oracle data to be accepted if the oracle falls back to non-round-ID interface, (2) Backwards movement in oracle data if round ID support is lost, (3) Potential for oracle manipulation by exploiting the fallback mechanism. The impact is especially severe for rolling markets where oracle data is critical for continuous operation.
Scenario
// Scenario: Oracle switches from round ID support to fallback
// 1. First read: oracle returns roundId=100, publishTime=1000
// 2. Cursor is updated: c.roundId=100, c.publishTime=1000
// 3. Second read: oracle fails to return round ID (falls back)
// 4. Fallback returns roundId=0, publishTime=900 (stale data)
// 5. Monotonicity check: if (0 < 100) revert - PASSES (0 is not < 100)
// 6. Cursor is updated: c.roundId=0, c.publishTime=900
// 7. Third read: oracle returns roundId=50, publishTime=950
// 8. Monotonicity check: if (50 < 0) revert - FAILS (50 is not < 0)
// 9. Cursor is updated: c.roundId=50, c.publishTime=950
// 10. Stale data (publishTime=950) is accepted

// The monotonicity enforcement is broken because:
// - Round ID 0 is treated as valid
// - Switching between round ID and non-round-ID breaks monotonicity
// - Stale data can be accepted
Affected code
function _enforceAndUpdateOracleCursor(bytes32 templateId, bytes32 feedId, uint80 oracleRoundId, uint64 publishTime)
    internal
{
    OracleCursor storage c = lastOracleCursorByTemplateFeed[templateId][feedId];
    if (oracleRoundId < c.roundId) {
        revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
    }
    // slither-disable-next-line incorrect-equality -- same round id must not move publish time backwards.
    if (oracleRoundId == c.roundId && publishTime < c.publishTime) {
        revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
    }
    c.roundId = oracleRoundId;
    c.publishTime = publishTime;
    if (oracleRoundId > lastOracleRoundIdByTemplate[templateId]) {
        lastOracleRoundIdByTemplate[templateId] = oracleRoundId;
    }
}

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
        _enforceAndUpdateOracleCursor(templateId, feedId, rid, pt);
        return (p, pt, c, rid);
    } catch {
        (priceE8, publishTime, confidenceE8) =
            _resolveOracleByClass(oracleClass).getNormalizedPrice(feedId, maxDelay, nowTs);
        _enforceAndUpdateOracleCursor(templateId, feedId, 0, publishTime); // Returns 0 for round ID
        return (priceE8, publishTime, confidenceE8, 0);
    }
}
Proposed fix
Implement proper handling of round ID zero and oracle interface switching:
// Track oracle interface type per feed
mapping(bytes32 templateId => mapping(bytes32 feedId => bool)) internal oracleSupportsRoundId;

function _enforceAndUpdateOracleCursor(
    bytes32 templateId,
    bytes32 feedId,
    uint80 oracleRoundId,
    uint64 publishTime,
    bool supportsRoundId
) internal {
    OracleCursor storage c = lastOracleCursorByTemplateFeed[templateId][feedId];
    
    // Check for oracle interface switching
    bool wasRoundIdSupported = oracleSupportsRoundId[templateId][feedId];
    if (wasRoundIdSupported != supportsRoundId) {
        // Oracle interface changed - reset cursor to prevent monotonicity issues
        c.roundId = 0;
        c.publishTime = 0;
    }
    
    // Only enforce round ID monotonicity if oracle supports round IDs
    if (supportsRoundId) {
        if (oracleRoundId == 0) revert InvalidOracleFeed(); // Round ID 0 is invalid
        if (oracleRoundId < c.roundId) {
            revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
        }
    }
    
    // Always enforce publish time monotonicity
    if (publishTime < c.publishTime) {
        revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
    }
    
    c.roundId = oracleRoundId;
    c.publishTime = publishTime;
    oracleSupportsRoundId[templateId][feedId] = supportsRoundId;
    
    if (supportsRoundId && oracleRoundId > lastOracleRoundIdByTemplate[templateId]) {
        lastOracleRoundIdByTemplate[templateId] = oracleRoundId;
    }
}

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
        _enforceAndUpdateOracleCursor(templateId, feedId, rid, pt, true); // Supports round ID
        return (p, pt, c, rid);
    } catch {
        (priceE8, publishTime, confidenceE8) =
            _resolveOracleByClass(oracleClass).getNormalizedPrice(feedId, maxDelay, nowTs);
        _enforceAndUpdateOracleCursor(templateId, feedId, 0, publishTime, false); // No round ID
        return (priceE8, publishTime, confidenceE8, 0);
    }
}
3

MarketEngineCoreLifecycleModule.sol
Missing Validation of Epoch Timing Constraints
The _openEpoch function validates that openAt < lockAt < resolveAt, but does not validate that these times are in the future or that they are reasonable. An admin could open an epoch with timing in the past, causing: (1) Epochs that are immediately locked (if lockAt is in the past), (2) Epochs that are immediately resolvable (if resolveAt is in the past), (3) Users unable to deposit because the epoch is already closed. Additionally, there's no validation that the timing windows are reasonable (e.g., lockAt should be at least some minimum time after openAt to allow users to deposit). An admin could create epochs with 1-second windows, making it impossible for users to participate.


Hide Details
Impact
Admin can create epochs with invalid timing that prevent user participation. This causes: (1) Users unable to deposit to epochs that are already closed, (2) Epochs that lock/resolve immediately, (3) Potential for griefing where admin creates unusable epochs, (4) Confusion and loss of user trust. The impact is especially severe for rolling markets where timing is critical.
Scenario
// Attack: Create epoch with past timing
// 1. Admin calls openEpoch with:
//    - openAt = block.timestamp - 1000 (1000 seconds ago)
//    - lockAt = block.timestamp - 500 (500 seconds ago)
//    - resolveAt = block.timestamp - 100 (100 seconds ago)
// 2. Validation passes: openAt < lockAt < resolveAt
// 3. Epoch is created with Open status
// 4. User tries to deposit
// 5. _depositToSide checks if epoch is open: e.isEpochOpen(nowTs)
// 6. isEpochOpen checks: nowTs >= openAt && nowTs < lockAt
// 7. nowTs >= openAt (true) && nowTs < lockAt (false - lockAt is in past)
// 8. Deposit fails with BettingClosed
// 9. Users cannot participate in epoch

// Attack: Create epoch with 1-second window
// 1. Admin calls openEpoch with:
//    - openAt = block.timestamp
//    - lockAt = block.timestamp + 1
//    - resolveAt = block.timestamp + 2
// 2. Validation passes
// 3. Epoch is created
// 4. In next block (1+ seconds later), epoch is already locked
// 5. Users have no time to deposit
Affected code
function _openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) internal {
    if (_templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
    if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();
    // No validation that times are in the future
    // No validation that windows are reasonable
    
    MarketTypes.Template storage t = _templates[templateId];
    if (t.version == 0) revert InvalidTemplate();
    if (!t.active) revert TemplateInactive();
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    _requireCanOpenNextEpoch(ledger, epochId);
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    if (e.exists) revert EpochAlreadyExists();

    uint64 nowTs = uint64(block.timestamp);
    e.version = MarketTypes.VERSION;
    e.status = MarketTypes.EpochStatus.Open;
    // ... rest of initialization ...
}
Proposed fix
Add validation for epoch timing constraints:
// Add constants for minimum timing windows
uint64 public constant MIN_DEPOSIT_WINDOW = 300; // 5 minutes minimum
uint64 public constant MIN_LOCK_WINDOW = 300;    // 5 minutes minimum
uint64 public constant MAX_EPOCH_DURATION = 30 days;

function _openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) internal {
    if (_templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
    
    // Validate timing order
    if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();
    
    uint64 nowTs = uint64(block.timestamp);
    
    // Validate times are in the future
    if (openAt <= nowTs) revert InvalidTiming(); // openAt must be in future
    
    // Validate minimum windows
    if (lockAt - openAt < MIN_DEPOSIT_WINDOW) revert InvalidTiming();
    if (resolveAt - lockAt < MIN_LOCK_WINDOW) revert InvalidTiming();
    
    // Validate maximum duration
    if (resolveAt - openAt > MAX_EPOCH_DURATION) revert InvalidTiming();
    
    MarketTypes.Template storage t = _templates[templateId];
    if (t.version == 0) revert InvalidTemplate();
    if (!t.active) revert TemplateInactive();
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    _requireCanOpenNextEpoch(ledger, epochId);
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    if (e.exists) revert EpochAlreadyExists();

    e.version = MarketTypes.VERSION;
    e.status = MarketTypes.EpochStatus.Open;
    // ... rest of initialization ...
}

// Also add validation for rolling epoch timing
function _openRollingEpoch(bytes32 templateId, uint64 startTs, MarketTypes.Template storage t)
    internal
    returns (uint64 openedEpochId)
{
    if (t.version == 0) revert InvalidTemplate();
    if (!t.active) revert TemplateInactive();
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    uint64 epochId = ledger.rollingNextEpochId;
    if (epochId == 0) revert InvalidEpochState();

    uint64 inter = t.rollingIntervalSeconds;
    // Validate rolling interval is reasonable
    if (inter < 60) revert RollingInvalidParams(); // Minimum 1 minute
    if (inter > 7 days) revert RollingInvalidParams(); // Maximum 7 days
    
    uint64 openAt = startTs;
    uint64 lockAt = startTs + inter;
    uint64 resolveAt = startTs + 2 * inter;
    if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();
    
    // ... rest of implementation ...
}
4

MarketEngineCoreLifecycleModule.sol
Missing Validation of Template Configuration Parameters
The upsertTemplate function accepts many configuration parameters but has limited validation of their relationships and constraints. For example: (1) rangeBoundsE8 array is not validated to ensure bounds are strictly increasing, (2) ladderPayoutWeightsBps array is not validated to ensure weights sum to 10,000 or are reasonable, (3) compositeFeedIds array is not validated to ensure all feeds are non-zero, (4) velocityBoundsE4 array is not validated. While some validation exists in _validateTemplate, it's incomplete. Invalid template configurations could cause: (1) Incorrect settlement calculations, (2) Markets that cannot be resolved, (3) Unexpected payout distributions.


Hide Details
Impact
Invalid template configurations could cause: (1) Incorrect settlement calculations if payout weights don't sum correctly, (2) Markets that cannot be resolved if oracle feeds are not properly configured, (3) Unexpected payout distributions if ladder bounds are not ordered correctly. The impact depends on the specific invalid configuration.
Scenario
// Example 1: Invalid ladder payout weights
// Admin creates template with ladderPayoutWeightsBps = [2000, 2000, 2000, 2000, 0, 0, 0, 0]
// Weights sum to 8000, not 10000
// Settlement logic expects weights to sum to 10000
// Payouts are calculated incorrectly

// Example 2: Invalid range bounds
// Admin creates Range market with rangeBoundsE8 = [100, 50, 200, 150]
// Bounds are not strictly increasing
// Settlement logic expects increasing bounds
// Market cannot be resolved correctly

// Example 3: Invalid composite feeds
// Admin creates Composite market with compositeFeedCount = 3
// But compositeFeedIds = [0x123, 0x456, 0x000, 0x000]
// Third feed is zero
// Oracle reads fail
Affected code
function upsertTemplate(UpsertTemplateParams calldata p) external {
    if (msg.sender != admin) revert Unauthorized();
    if (bytes(p.slug).length == 0 || bytes(p.slug).length > MarketTypes.SLUG_MAX_LEN) revert InvalidTemplate();
    if (bytes(p.assetSymbol).length == 0 || bytes(p.assetSymbol).length > MarketTypes.ASSET_SYMBOL_MAX_LEN) {
        revert InvalidTemplate();
    }
    if (p.switchFeeBps > maxSwitchFeeBps) revert InvalidFeeBps();
    if (p.outcomeCount == 0 || p.outcomeCount > maxOutcomes) revert TooManyOutcomes();
    _validateOracleParams(p);

    bytes32 tid = templateIdFromSlug(p.slug);
    MarketTypes.Template storage t = _templates[tid];
    // ... template assignment ...
    
    _validateTemplate(t);
    emit TemplateUpserted(...);
}

function _validateTemplate(MarketTypes.Template storage t) internal view {
    if (t.outcomeCount > maxOutcomes) revert TooManyOutcomes();
    if (t.switchFeeBps > 10_000 || t.settlementFeeBps > 10_000) revert InvalidFeeBps();
    if (t.marketType == MarketTypes.MarketType.Direction) {
        if (t.outcomeCount != 2) revert InvalidTemplate();
        if (t.thresholdRule != MarketTypes.ThresholdRule.None) revert InvalidTemplate();
        if (!t.equalPriceVoids) revert InvalidTemplate();
    } else if (t.marketType == MarketTypes.MarketType.Threshold) {
        if (t.outcomeCount != 2) revert InvalidTemplate();
        if (t.thresholdRule != MarketTypes.ThresholdRule.Absolute) revert InvalidTemplate();
    } else if (t.marketType == MarketTypes.MarketType.Convergence || t.marketType == MarketTypes.MarketType.Composite) {
        if (t.outcomeCount != 2) revert InvalidTemplate();
        if (t.thresholdRule != MarketTypes.ThresholdRule.Absolute) revert InvalidTemplate();
        if (t.marketType == MarketTypes.MarketType.Convergence && t.oracleFeedIdB == bytes32(0)) revert InvalidTemplate();
        if (
            t.marketType == MarketTypes.MarketType.Composite
                && (t.compositeFeedCount < 2 || t.compositeFeedCount > 4 || t.compositeFeedIds[0] == bytes32(0))
        ) revert InvalidTemplate();
    } else {
        if (t.outcomeCount < 2) revert InvalidTemplate();
        // Missing validation of rangeBoundsE8 ordering
        for (uint256 i = 1; i < uint256(t.outcomeCount) - 1; i++) {
            if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
        }
    }
    // Missing validation of ladderPayoutWeightsBps
    // Missing validation of velocityBoundsE4
    // Missing validation of compositeFeedIds completeness
    if (
        t.executionMode == MarketTypes.ExecutionMode.Rolling
            && (
                t.marketType == MarketTypes.MarketType.Convergence || t.marketType == MarketTypes.MarketType.Composite
                    || t.marketType == MarketTypes.MarketType.Corridor || t.marketType == MarketTypes.MarketType.Cascade
            )
    ) revert RollingInvalidParams();
    if (t.oracleMaxConfidenceBps > 0 && t.oracleMaxConfidenceBps > 10_000) revert InvalidFeeBps();
}
Proposed fix
Add comprehensive validation of template parameters:
function _validateTemplate(MarketTypes.Template storage t) internal view {
    if (t.outcomeCount > maxOutcomes) revert TooManyOutcomes();
    if (t.switchFeeBps > 10_000 || t.settlementFeeBps > 10_000) revert InvalidFeeBps();
    
    // Validate market type specific constraints
    if (t.marketType == MarketTypes.MarketType.Direction) {
        if (t.outcomeCount != 2) revert InvalidTemplate();
        if (t.thresholdRule != MarketTypes.ThresholdRule.None) revert InvalidTemplate();
        if (!t.equalPriceVoids) revert InvalidTemplate();
    } else if (t.marketType == MarketTypes.MarketType.Threshold) {
        if (t.outcomeCount != 2) revert InvalidTemplate();
        if (t.thresholdRule != MarketTypes.ThresholdRule.Absolute) revert InvalidTemplate();
    } else if (t.marketType == MarketTypes.MarketType.Convergence) {
        if (t.outcomeCount != 2) revert InvalidTemplate();
        if (t.thresholdRule != MarketTypes.ThresholdRule.Absolute) revert InvalidTemplate();
        if (t.oracleFeedIdB == bytes32(0)) revert InvalidTemplate();
    } else if (t.marketType == MarketTypes.MarketType.Composite) {
        if (t.outcomeCount != 2) revert InvalidTemplate();
        if (t.thresholdRule != MarketTypes.ThresholdRule.Absolute) revert InvalidTemplate();
        if (t.compositeFeedCount < 2 || t.compositeFeedCount > 4) revert InvalidTemplate();
        
        // Validate all composite feeds are non-zero
        for (uint256 i = 0; i < t.compositeFeedCount; i++) {
            if (t.compositeFeedIds[i] == bytes32(0)) revert InvalidTemplate();
        }
    } else if (t.marketType == MarketTypes.MarketType.Range) {
        if (t.outcomeCount < 2) revert InvalidTemplate();
        
        // Validate range bounds are strictly increasing
        for (uint256 i = 1; i < uint256(t.outcomeCount) - 1; i++) {
            if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
        }
    } else if (t.marketType == MarketTypes.MarketType.Ladder) {
        if (t.outcomeCount < 2) revert InvalidTemplate();
        
        // Validate ladder bounds are strictly increasing
        for (uint256 i = 1; i < uint256(t.outcomeCount) - 1; i++) {
            if (!(t.ladderBoundsE8[i - 1] < t.ladderBoundsE8[i])) revert InvalidTemplate();
        }
        
        // Validate ladder payout weights sum to 10000
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < uint256(t.outcomeCount); i++) {
            totalWeight += t.ladderPayoutWeightsBps[i];
        }
        if (totalWeight != 10_000) revert InvalidTemplate();
    }
    
    // Validate velocity bounds if present
    if (t.marketType == MarketTypes.MarketType.Velocity) {
        for (uint256 i = 1; i < uint256(t.outcomeCount) - 1; i++) {
            if (!(t.velocityBoundsE4[i - 1] < t.velocityBoundsE4[i])) revert InvalidTemplate();
        }
    }
    
    // Validate rolling market constraints
    if (t.executionMode == MarketTypes.ExecutionMode.Rolling) {
        if (
            t.marketType == MarketTypes.MarketType.Convergence
                || t.marketType == MarketTypes.MarketType.Composite
                || t.marketType == MarketTypes.MarketType.Corridor
                || t.marketType == MarketTypes.MarketType.Cascade
        ) revert RollingInvalidParams();
    }
    
    // Validate oracle configuration
    if (t.oracleMaxConfidenceBps > 0 && t.oracleMaxConfidenceBps > 10_000) revert InvalidFeeBps();
}

low Severity
3
1

MarketEngineCoreLifecycleModule.sol
Potential Integer Overflow in Yield Fee Calculation
The _applyGrossYield function calculates yield fees using: yieldFee = (grossYield * uint256(yieldFeeBps)) / 10_000. While Solidity 0.8+ has checked arithmetic, this calculation could theoretically overflow if grossYield is very large (close to type(uint256).max) and yieldFeeBps is large. More importantly, the calculation uses integer division which rounds down, potentially losing precision. For example, if grossYield is 999 and yieldFeeBps is 1, the fee would be (999 * 1) / 10_000 = 0, losing 999 wei of yield. This is a precision loss issue rather than an overflow, but it could accumulate across many epochs.


Hide Details
Impact
Precision loss in yield fee calculations could cause: (1) Small amounts of yield to be lost due to rounding down, (2) Accumulated losses across many epochs, (3) Vault accounting discrepancies where total yield doesn't match fees + net yield. The impact is relatively small per epoch but could accumulate to significant amounts over time.
Scenario
// Example: Precision loss in yield fee calculation
// Scenario: Small yield amounts with low fee percentage

// Case 1: grossYield = 999, yieldFeeBps = 1 (0.01%)
// yieldFee = (999 * 1) / 10_000 = 0 (rounds down)
// netYield = 999 - 0 = 999
// Lost: 0.999 wei (should be 0.0999 wei fee)

// Case 2: grossYield = 100, yieldFeeBps = 50 (0.5%)
// yieldFee = (100 * 50) / 10_000 = 5000 / 10_000 = 0 (rounds down)
// netYield = 100 - 0 = 100
// Lost: 0.5 wei (should be 0.5 wei fee)

// Case 3: Over 1000 epochs with grossYield = 100 each
// Total grossYield = 100,000
// If each epoch loses 0.5 wei due to rounding
// Total loss = 500 wei
// This accumulates to significant amounts
Affected code
function _applyGrossYield(bytes32 templateId, MarketTypes.Ledger storage ledger, uint256 grossYield)
    internal
    returns (uint256 yieldFee, uint256 netYield)
{
    if (grossYield < 1) return (0, 0);

    _vaults[templateId].active += grossYield;
    ledger.increaseActiveCollateral(grossYield);

    yieldFee = (grossYield * uint256(yieldFeeBps)) / 10_000;
    netYield = grossYield - yieldFee;
    if (yieldFee > 0) {
        _vaults[templateId].active -= yieldFee;
        _vaults[templateId].fees += yieldFee;
        MarketMath.reserveFeesFromActive(ledger, yieldFee);
    }
}
Proposed fix
Implement proper rounding and precision handling:
function _applyGrossYield(bytes32 templateId, MarketTypes.Ledger storage ledger, uint256 grossYield)
    internal
    returns (uint256 yieldFee, uint256 netYield)
{
    if (grossYield < 1) return (0, 0);

    _vaults[templateId].active += grossYield;
    ledger.increaseActiveCollateral(grossYield);

    // Use proper rounding: round up for fees to ensure protocol doesn't lose money
    // yieldFee = ceil((grossYield * yieldFeeBps) / 10_000)
    yieldFee = (grossYield * uint256(yieldFeeBps) + 9_999) / 10_000;
    
    // Ensure yieldFee doesn't exceed grossYield
    if (yieldFee > grossYield) {
        yieldFee = grossYield;
    }
    
    netYield = grossYield - yieldFee;
    
    if (yieldFee > 0) {
        _vaults[templateId].active -= yieldFee;
        _vaults[templateId].fees += yieldFee;
        MarketMath.reserveFeesFromActive(ledger, yieldFee);
    }
}

// Alternative: Use fixed-point arithmetic for better precision
function _applyGrossYieldWithPrecision(
    bytes32 templateId,
    MarketTypes.Ledger storage ledger,
    uint256 grossYield
) internal returns (uint256 yieldFee, uint256 netYield) {
    if (grossYield < 1) return (0, 0);

    _vaults[templateId].active += grossYield;
    ledger.increaseActiveCollateral(grossYield);

    // Use 1e18 precision for intermediate calculations
    uint256 feePercentage = (uint256(yieldFeeBps) * 1e18) / 10_000;
    yieldFee = (grossYield * feePercentage) / 1e18;
    
    // Ensure yieldFee doesn't exceed grossYield
    if (yieldFee > grossYield) {
        yieldFee = grossYield;
    }
    
    netYield = grossYield - yieldFee;
    
    if (yieldFee > 0) {
        _vaults[templateId].active -= yieldFee;
        _vaults[templateId].fees += yieldFee;
        MarketMath.reserveFeesFromActive(ledger, yieldFee);
    }
}
2

MarketEngineUserOpsClaimsModule.sol
Missing Validation of Outcome Index in Position Operations
The switchSide function validates that fromOutcome and toOutcome are less than e.outcomeCount, but this validation happens after the position is already accessed. Additionally, the validation uses uint256 casting which could mask issues if outcomeIndex is very large. More importantly, there's no validation that the outcome indices are valid when accessing the pos.stakes array. Since pos.stakes is a fixed-size array (uint256[8]), accessing an index >= 8 would cause an out-of-bounds access. While Solidity prevents actual out-of-bounds access, the validation should happen earlier and more explicitly.


Hide Details
Impact
While Solidity prevents actual out-of-bounds access, the late validation could cause: (1) Confusing error messages if validation fails after state is accessed, (2) Potential for logic errors if validation is skipped in some code paths, (3) Inconsistent behavior between different outcome operations. The impact is relatively low since Solidity prevents actual memory corruption, but it's a code quality issue.
Scenario
// Example: Invalid outcome index
// 1. User calls switchSide with fromOutcome=10, toOutcome=5
// 2. Epoch has outcomeCount=2 (binary market)
// 3. Validation: if (!(10 < 2 && 5 < 2)) revert InvalidOutcome()
// 4. Revert happens
// 5. But if validation was missing, accessing pos.stakes[10] would be out of bounds
// 6. Solidity would prevent actual access, but it's still a logic error
Affected code
function switchSide(bytes32 templateId, uint64 epochId, uint8 fromOutcome, uint8 toOutcome, uint256 grossAmount)
    external
    nonReentrant
{
    if (globalPaused) revert ProtocolPaused();
    if (!configInitialized) revert Unauthorized();
    if (grossAmount == 0) revert ZeroStake();
    if (fromOutcome == toOutcome) revert InvalidOutcome();

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
    // Validation happens here, but after accessing e
    if (!(uint256(fromOutcome) < uint256(e.outcomeCount) && uint256(toOutcome) < uint256(e.outcomeCount))) {
        revert InvalidOutcome();
    }
    // ... rest of function ...
}
Proposed fix
Add early validation of outcome indices:
function switchSide(bytes32 templateId, uint64 epochId, uint8 fromOutcome, uint8 toOutcome, uint256 grossAmount)
    external
    nonReentrant
{
    if (globalPaused) revert ProtocolPaused();
    if (!configInitialized) revert Unauthorized();
    if (grossAmount == 0) revert ZeroStake();
    if (fromOutcome == toOutcome) revert InvalidOutcome();

    // Early validation of outcome indices
    if (fromOutcome >= MarketTypes.MAX_OUTCOMES || toOutcome >= MarketTypes.MAX_OUTCOMES) {
        revert InvalidOutcome();
    }

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
    // Validate against actual epoch outcome count
    if (fromOutcome >= e.outcomeCount || toOutcome >= e.outcomeCount) {
        revert InvalidOutcome();
    }
    
    // ... rest of function ...
}

// Apply same pattern to depositToSide
function _depositToSide(
    address payer,
    address beneficiary,
    bytes32 templateId,
    uint64 epochId,
    uint8 outcomeIndex,
    uint256 amount
) internal {
    if (!configInitialized) revert Unauthorized();
    if (amount == 0) revert ZeroStake();
    
    // Early validation of outcome index
    if (outcomeIndex >= MarketTypes.MAX_OUTCOMES) {
        revert InvalidOutcome();
    }
    
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
    // Validate against actual epoch outcome count
    if (outcomeIndex >= e.outcomeCount) {
        revert InvalidOutcome();
    }
    
    // ... rest of function ...
}
3

MarketEngineUserOpsClaimsModule.sol
Potential DoS via Large User Epoch Array Growth
The _userEpochs mapping stores an array of epoch IDs for each user in each market. Every time a user deposits to a new epoch, the epoch ID is appended to this array. There is no limit on the array size, so a user could accumulate thousands of epoch entries. The getUserEpochs function iterates through this array with pagination, but if the array becomes very large, even pagination could be expensive. More importantly, if a user participates in many epochs (e.g., 10,000 epochs), the _userEpochs[templateId][user] array would have 10,000 entries. Iterating through this array in getUserEpochs would be expensive. Additionally, there's no deduplication - if a user deposits to the same epoch multiple times, the epoch ID is added multiple times to the array.


Hide Details
Impact
Large user epoch arrays could cause: (1) getUserEpochs to be expensive if the array is very large, (2) Potential for DoS if a user accumulates many epochs and then calls getUserEpochs with large size parameter, (3) Storage bloat if users participate in many epochs. The impact is relatively low since pagination limits the per-call cost, but it could accumulate over time.
Scenario
// Scenario: User participates in 10,000 epochs
// 1. User calls depositToSide for epoch 1
// 2. _userEpochs[templateId][user].push(1)
// 3. User calls depositToSide for epoch 2
// 4. _userEpochs[templateId][user].push(2)
// ... repeat 10,000 times ...
// 5. _userEpochs[templateId][user] now has 10,000 entries
// 6. User calls getUserEpochs with size=1000
// 7. Function iterates through 1000 entries
// 8. Gas cost is proportional to array size
// 9. If array is very large, even pagination could be expensive

// Potential DoS:
// 1. Attacker creates many epochs
// 2. Attacker deposits to all epochs
// 3. Attacker calls getUserEpochs with large size
// 4. Function iterates through many entries
// 5. Gas cost exceeds block limit
// 6. Call fails
Affected code
function _depositToSide(
    address payer,
    address beneficiary,
    bytes32 templateId,
    uint64 epochId,
    uint8 outcomeIndex,
    uint256 amount
) internal {
    // ... validation code ...
    
    bytes32 pk = positionKey(templateId, epochId);
    MarketTypes.Position storage pos = _positions[pk][beneficiary];
    if (!pos.initialized) {
        pos.version = MarketTypes.VERSION;
        pos.initialized = true;
        e.totalPositions += 1;
        _userEpochs[templateId][beneficiary].push(epochId); // Appends to array without limit
        emit UserEpochIndexed(templateId, epochId, beneficiary);
    }
    // ... rest of function ...
}

function getUserEpochs(bytes32 templateId, address user, uint256 cursor, uint256 size)
    external
    view
    returns (uint64[] memory epochIds, uint256 nextCursor)
{
    uint64[] storage src = _userEpochs[templateId][user];
    uint256 n = src.length;
    if (cursor >= n) return (new uint64[](0), cursor);
    uint256 end = cursor + size;
    if (end > n) end = n;
    uint256 outLen = end - cursor;
    epochIds = new uint64[](outLen);
    for (uint256 i = 0; i < outLen; i++) {
        epochIds[i] = src[cursor + i]; // Iterates through array
    }
    nextCursor = end;
}
Proposed fix
Implement limits on user epoch array size:
// Add constant for maximum epochs per user
uint256 public constant MAX_EPOCHS_PER_USER = 1000;

function _depositToSide(
    address payer,
    address beneficiary,
    bytes32 templateId,
    uint64 epochId,
    uint8 outcomeIndex,
    uint256 amount
) internal {
    // ... validation code ...
    
    bytes32 pk = positionKey(templateId, epochId);
    MarketTypes.Position storage pos = _positions[pk][beneficiary];
    if (!pos.initialized) {
        pos.version = MarketTypes.VERSION;
        pos.initialized = true;
        e.totalPositions += 1;
        
        // Check array size limit
        uint64[] storage userEpochs = _userEpochs[templateId][beneficiary];
        if (userEpochs.length >= MAX_EPOCHS_PER_USER) {
            revert TooManyEpochs();
        }
        
        // Check for duplicates before adding
        bool alreadyExists = false;
        for (uint256 i = 0; i < userEpochs.length; i++) {
            if (userEpochs[i] == epochId) {
                alreadyExists = true;
                break;
            }
        }
        
        if (!alreadyExists) {
            userEpochs.push(epochId);
        }
        
        emit UserEpochIndexed(templateId, epochId, beneficiary);
    }
    // ... rest of function ...
}

// Alternative: Use a mapping to track user epochs instead of array
mapping(bytes32 templateId => mapping(address user => mapping(uint64 epochId => bool))) internal userEpochExists;
mapping(bytes32 templateId => mapping(address user => uint64[])) internal _userEpochs;

function _depositToSide(
    address payer,
    address beneficiary,
    bytes32 templateId,
    uint64 epochId,
    uint8 outcomeIndex,
    uint256 amount
) internal {
    // ... validation code ...
    
    bytes32 pk = positionKey(templateId, epochId);
    MarketTypes.Position storage pos = _positions[pk][beneficiary];
    if (!pos.initialized) {
        pos.version = MarketTypes.VERSION;
        pos.initialized = true;
        e.totalPositions += 1;
        
        // Only add if not already in array
        if (!userEpochExists[templateId][beneficiary][epochId]) {
            _userEpochs[templateId][beneficiary].push(epochId);
            userEpochExists[templateId][beneficiary][epochId] = true;
        }
        
        emit UserEpochIndexed(templateId, epochId, beneficiary);
    }
    // ... rest of function ...
}

informational Severity
1
1

IMarketEngine.sol
Floating Pragma Version Allows Inconsistent Compiler Behavior
All contract files use pragma solidity ^0.8.24, which allows compilation with any Solidity version from 0.8.24 to 0.9.0 (exclusive). Different compiler versions may have different optimization behaviors, bug fixes, or language semantics. This could lead to: (1) Inconsistent bytecode across deployments if different compiler versions are used, (2) Potential for compiler-specific bugs or optimizations to affect contract behavior, (3) Difficulty in reproducing issues if different versions are used in different environments. While Solidity 0.8.x is generally stable, pinning to a specific version ensures consistency.


Hide Details
Impact
Inconsistent compiler versions could cause: (1) Different bytecode deployed in different environments, (2) Potential for compiler bugs to affect some deployments but not others, (3) Difficulty in auditing and verifying contract behavior. The impact is relatively low since Solidity 0.8.x is stable, but it's a best practice to pin versions.
Scenario
// Example: Different compiler versions could produce different bytecode
// Deployment 1: Compiled with solc 0.8.24
// Deployment 2: Compiled with solc 0.8.25
// Both are valid under pragma ^0.8.24
// But bytecode could differ due to:
// - Different optimization levels
// - Different bug fixes
// - Different language semantics
// This makes it difficult to verify that the deployed code matches the source
Affected code
All contract files have: `pragma solidity ^0.8.24;`
Proposed fix
Pin pragma to specific version:
// Change from:
pragma solidity ^0.8.24;
s
// To:
pragma solidity 0.8.24;

// Or if you want to allow patch versions:
pragma solidity 0.8.24;