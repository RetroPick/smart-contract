DeFi Prediction Market / Modular Dispatcher Proxy

A modular, upgradeable prediction market engine built on UUPS proxy pattern. The system allows creation of market templates with various types (Direction, Threshold, Range, Velocity, Ladder, Convergence, Composite, Corridor, Cascade), manages epoch-based betting rounds, handles oracle price feeds for settlement, and supports yield routing for idle capital. Users deposit stake tokens to take positions on market outcomes, and winners claim proportional payouts after epoch resolution.

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

External Calls
1
IERC20 (stakeToken)
2
IPriceOracle (priceOracle/rateOracle/smartDataOracle/macroOracle/equityOracle)
3
IYieldRouterV2
4
Module Contracts (via delegatecall)

External Systems
1
Oracle (Chainlink)
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


critical Severity
1
1

MarketEngineDispatcher.sol
No Timelock on Critical Admin Operations — Single-Step Module Registration and Upgrade
All critical administrative operations — including UUPS upgrades, module registration, selector mapping, and oracle changes — can be executed in a single transaction by the admin with no delay: ```solidity function _authorizeUpgrade(address) internal override onlyAdmin {} function registerModule(address module, bytes32 expectedCodeHash) external onlyAdmin { ... } function setSelectorModule(bytes4 selector, address module, bool makeImmutable) external onlyAdmin { ... } ``` A compromised admin key (or a malicious admin) can immediately: 1. Register a malicious module 2. Map all critical selectors to it 3. Execute arbitrary code in the proxy's storage context 4. Drain all user funds This is a single-transaction attack with no opportunity for users to exit before the attack completes.


Hide Details
Impact
A compromised admin key leads to immediate, irreversible loss of all user funds. There is no window for users to withdraw funds or for the community to detect and respond to a malicious upgrade/module registration. This is a critical centralization risk.
Scenario
1. Attacker compromises admin private key.
2. Attacker calls `allowModuleCodeHash(hash(DrainModule))`.
3. Attacker calls `registerModule(drainModuleAddr, hash(DrainModule))`.
4. Attacker calls `setSelectorModule(depositSelector, drainModuleAddr, false)` and `setSelectorModule(claimSelector, drainModuleAddr, false)`.
5. All subsequent deposits go to the drain module, and all claims are redirected.
6. Alternatively, attacker calls `upgradeToAndCall(maliciousImpl, "")` to replace the entire implementation.
Affected code
function _authorizeUpgrade(address) internal override onlyAdmin {}

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
Proposed fix
1. Use a multi-sig wallet (e.g., Gnosis Safe with 3-of-5 or higher threshold) for the admin role.
2. Implement a timelock contract (e.g., OpenZeppelin TimelockController) with a minimum delay of 24-48 hours for:
- Module registration and selector changes
- UUPS upgrades
- Oracle address changes
3. Consider a two-step admin transfer pattern.
4. Emit events with sufficient lead time for monitoring systems to detect suspicious admin actions.
// Example: Add timelock check
uint256 public constant UPGRADE_TIMELOCK = 48 hours;
mapping(bytes32 => uint256) public pendingOperations;

function scheduleUpgrade(address newImpl) external onlyAdmin {
    bytes32 opId = keccak256(abi.encode("upgrade", newImpl));
    pendingOperations[opId] = block.timestamp + UPGRADE_TIMELOCK;
    emit UpgradeScheduled(newImpl, pendingOperations[opId]);
}

high Severity
4
1

MarketEngineState.sol
Storage Layout Collision: Duplicate Selector Mappings in Both ERC-7201 Namespace and Linear Storage
In `MarketEngineState`, there are two storage variables declared at the end of the linear storage layout: ```solidity mapping(bytes4 selector => address module) internal selectorToModule; mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable; ``` However, `MarketEngineDispatcher` also stores the same data in its ERC-7201 namespaced `ModuleRegistryStorage` struct: ```solidity struct ModuleRegistryStorage { mapping(bytes4 selector => address module) selectorToModule; mapping(bytes4 selector => bool immutableSelector) selectorImmutable; mapping(address module => bool approved) approvedModules; mapping(address module => bytes32 codeHash) moduleCodeHash; mapping(bytes32 codeHash => bool allowed) allowedModuleCodeHashes; } ``` The dispatcher reads/writes selector mappings exclusively through `_moduleRegistryStorage()` (the ERC-7201 slot), while the linear storage variables in `MarketEngineState` are never used by the dispatcher. However, any delegatecall module that inherits `MarketEngineState` and directly accesses `selectorToModule` or `selectorImmutable` will read/write the linear storage slots, NOT the ERC-7201 namespace. This creates a silent divergence: the dispatcher's routing table (ERC-7201) and the module's view of the routing table (linear storage) are completely different storage locations. A module that attempts to read or enforce selector immutability via the inherited state variables will operate on stale/empty data, potentially bypassing immutability protections or reading incorrect module addresses.


Hide Details
Impact
If any module inherits `MarketEngineState` and reads `selectorToModule` or `selectorImmutable` directly (e.g., to enforce access control or check routing), it will read from empty/stale linear storage rather than the actual ERC-7201 registry. This could allow a module to bypass immutability checks or make incorrect routing decisions. Additionally, the dead storage variables in `MarketEngineState` consume slots in the linear layout, reducing the effective size of `__gap[41]` for future upgrades.
Scenario
1. Admin registers a module and maps selector S to it via `setSelectorModule(S, moduleA, true)` — this writes to ERC-7201 storage.
2. A module contract inherits `MarketEngineState` and contains logic like:
require(!selectorImmutable[selector], "immutable");
3. When this module is delegatecalled, `selectorImmutable[selector]` reads from the linear storage slot (always false/zero), not the ERC-7201 slot where the immutability flag was actually set.
4. The immutability check is silently bypassed.
Affected code
// In MarketEngineState.sol
mapping(bytes4 selector => address module) internal selectorToModule;
mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

// In MarketEngineDispatcher.sol - uses DIFFERENT storage location
function _moduleRegistryStorage() private pure returns (ModuleRegistryStorage storage $) {
assembly {
$.slot := MODULE_REGISTRY_STORAGE_LOCATION;
}
}
Proposed fix
Remove the duplicate `selectorToModule` and `selectorImmutable` mappings from `MarketEngineState` since they are never used by the dispatcher (which uses ERC-7201 namespaced storage). If modules need to access registry data, they should use the same `_moduleRegistryStorage()` accessor. Alternatively, document clearly that these linear storage variables are intentionally unused and should never be accessed by modules. Also update `__gap` size accordingly to maintain the intended storage reservation.
2

MarketEngineDispatcher.sol
ReentrancyGuardTransient Not Applied to Fallback — Module Delegatecalls Bypass Reentrancy Protection
The `MarketEngineDispatcher` inherits `ReentrancyGuardTransient` but the `fallback()` function that routes all module calls does NOT apply the `nonReentrant` modifier: ```solidity fallback() external payable { _delegateForSelector(msg.sig); } ``` The `nonReentrant` modifier from `ReentrancyGuardTransient` must be explicitly applied to functions that need protection. Since all user-facing operations (depositToSide, switchSide, claim, etc.) are routed through this unprotected fallback, the reentrancy guard provides no protection for any of these operations unless the individual module functions also apply the guard. Furthermore, `ReentrancyGuardTransient` uses transient storage (EIP-1153), which is reset at the end of each transaction. This means the guard state is NOT preserved across delegatecalls within the same transaction if the module itself doesn't use the same guard. A reentrant call through the fallback would find the transient storage in its initial (unlocked) state if the module's nonReentrant check was the one that set it, since transient storage is shared across the call context but the guard's slot must be the same.


Hide Details
Impact
All module-implemented functions (depositToSide, switchSide, claim, resolveEpoch, etc.) that involve token transfers or state changes are potentially vulnerable to reentrancy attacks if the module implementations do not independently apply reentrancy guards. An attacker could reenter through the fallback during a token transfer callback (e.g., ERC777 hooks, yield router callbacks) to manipulate accounting state.
Scenario
1. User calls `claim(templateId, epochId)` which routes through fallback → module's claim function.
2. Module's claim function transfers tokens to user via `stakeToken.transfer(user, amount)`.
3. If stakeToken is ERC777 or has a transfer hook, the hook calls back into the dispatcher's fallback.
4. Since fallback has no `nonReentrant` modifier, the call proceeds to the module again.
5. If the module's claim function doesn't have its own reentrancy guard, the user can claim twice.
Affected code
fallback() external payable {
_delegateForSelector(msg.sig);
}
Proposed fix
Apply the `nonReentrant` modifier to the fallback function:
fallback() external payable nonReentrant {
    _delegateForSelector(msg.sig);
}
This ensures all module calls are protected by the transient reentrancy guard at the dispatcher level, regardless of whether individual module functions implement their own guards. Additionally, ensure all module functions that perform external calls also apply `nonReentrant` as defense-in-depth.
3

MarketEngineDispatcher.sol
CREATE2 Redeployment Attack: Module Code Hash Check Can Be Bypassed
The `_enforceApprovedModule` function verifies that a module's current bytecode matches the stored code hash at every delegatecall: ```solidity bytes32 expectedCodeHash = $.moduleCodeHash[module]; bytes32 actualCodeHash = keccak256(module.code); if (actualCodeHash != expectedCodeHash) { revert ModuleCodeHashMismatch(module, expectedCodeHash, actualCodeHash); } ``` However, this protection can be bypassed using a CREATE2 redeployment attack: 1. A malicious admin deploys a legitimate module at address A using CREATE2 with a specific salt. 2. The module passes all checks and is registered with its code hash. 3. The admin calls `revokeModule(A)` which only deletes `approvedModules[A]` and `moduleCodeHash[A]` — but does NOT remove the selector mapping. 4. The contract at address A self-destructs (if it has a selfdestruct opcode). 5. A malicious contract is deployed at the same address A using CREATE2 with the same salt. 6. The new malicious contract at A has different bytecode, so `_enforceApprovedModule` would catch it. However, a more subtle attack: if the admin registers a module, maps selectors to it, then the module is revoked but selectors are NOT updated (no function to atomically revoke + clear selectors), the selector still points to the revoked module address. When `_delegateForSelector` is called, it calls `_enforceApprovedModule` which checks `approvedModules[module]` — this would revert since the module was revoked. But if the admin then re-registers a NEW module at the same address (after CREATE2 redeploy with malicious code), the selector still points to it and the new malicious code would be executed.


Hide Details
Impact
A compromised or malicious admin could register a malicious module at a previously-used address via CREATE2 redeployment, bypassing the code hash protection. This would allow arbitrary code execution in the proxy's storage context, enabling complete fund theft. The attack requires admin compromise AND a module contract with selfdestruct capability.
Scenario
1. Admin deploys `LegitModule` at address A via CREATE2 (salt=X, initcode=Y).
2. Admin calls `allowModuleCodeHash(hash(LegitModule))`, `registerModule(A, hash)`, `setSelectorModule(depositSelector, A, false)`.
3. Admin calls `revokeModule(A)` — selectors still point to A.
4. `LegitModule` at A calls `selfdestruct` (if it has one).
5. Admin deploys `MaliciousModule` at address A via CREATE2 (same salt X, different initcode Z).
6. Admin calls `allowModuleCodeHash(hash(MaliciousModule))`, `registerModule(A, hash(MaliciousModule))`.
7. Selector still points to A, which now contains malicious code.
8. Next call to `depositToSide` routes to malicious module via delegatecall.
Affected code
function revokeModule(address module) external onlyAdmin {
ModuleRegistryStorage storage $ = _moduleRegistryStorage();
delete $.approvedModules[module];
delete $.moduleCodeHash[module];
emit ModuleRevoked(module);
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
Proposed fix
1. Add a function to atomically revoke a module AND clear all its selector mappings.
2. Track which selectors are mapped to each module to enable bulk clearing.
3. Consider prohibiting modules that contain `selfdestruct` opcodes (verify via bytecode analysis off-chain).
4. Implement a timelock on module registration and selector changes to allow community review.
function revokeModuleAndClearSelectors(address module, bytes4[] calldata selectors) external onlyAdmin {
    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    delete $.approvedModules[module];
    delete $.moduleCodeHash[module];
    for (uint256 i = 0; i < selectors.length; i++) {
        if ($.selectorToModule[selectors[i]] == module) {
            delete $.selectorToModule[selectors[i]];
        }
    }
    emit ModuleRevoked(module);
}
4

MarketEngineDispatcher.sol
Storage Compatibility Marker Is Insufficient — Modules Can Have Incompatible Storage Layouts
The `_enforceModuleStorageCompatibility` function only verifies that a module returns a specific constant value from `marketEngineStorageCompatibility()`: ```solidity function _enforceModuleStorageCompatibility(address module) private view { (bool ok, bytes memory out) = module.staticcall(abi.encodeWithSelector(SELECTOR_STORAGE_COMPATIBILITY)); if (!ok || out.length != 32) revert IncompatibleModuleStorage(module); bytes32 marker = abi.decode(out, (bytes32)); if (marker != MODULE_STORAGE_COMPATIBILITY_ID) revert IncompatibleModuleStorage(module); } ``` This check only proves the module was compiled with the `MODULE_STORAGE_COMPATIBILITY_ID` constant, NOT that the module's storage layout actually matches `MarketEngineState`. A module could: 1. Inherit `MarketEngineState` but add new storage variables BEFORE the `__gap` (breaking layout) 2. Inherit `MarketEngineState` but use a different version with reordered fields 3. Simply implement `marketEngineStorageCompatibility()` returning the correct constant without inheriting `MarketEngineState` at all The comment in the code explicitly acknowledges this: "it only proves the module implements this selector with the expected constant, not that bytecode matches `MarketEngineState` storage." However, this is a critical security property that cannot be enforced on-chain.


Hide Details
Impact
A module with an incompatible storage layout (even if unintentionally) would silently corrupt the proxy's storage when delegatecalled. This could lead to: incorrect accounting (wrong balances, wrong epoch states), unauthorized access (admin address overwritten), or complete protocol compromise. The risk is amplified because storage corruption is often not immediately detectable.
Scenario
// Malicious or accidentally broken module
contract BrokenModule is MarketEngineState {
    // Adding a new variable BEFORE __gap breaks layout for future modules
    // but this module still passes the compatibility check
    address public newVariable; // This shifts __gap and any future appended variables
    
    function marketEngineStorageCompatibility() external pure returns (bytes32) {
        return MODULE_STORAGE_COMPATIBILITY_ID; // Passes the check!
    }
    
    // All functions operate on wrong storage slots
}
Affected code
function _enforceModuleStorageCompatibility(address module) private view {
(bool ok, bytes memory out) = module.staticcall(abi.encodeWithSelector(SELECTOR_STORAGE_COMPATIBILITY));
if (!ok || out.length != 32) revert IncompatibleModuleStorage(module);
bytes32 marker = abi.decode(out, (bytes32));
if (marker != MODULE_STORAGE_COMPATIBILITY_ID) revert IncompatibleModuleStorage(module);
}
Proposed fix
1. Implement a storage layout hash that covers all variable names, types, and positions:
bytes32 internal constant STORAGE_LAYOUT_HASH = keccak256(abi.encode(
    "stakeToken", "address",
    "priceOracle", "address",
    // ... all variables in order
    "__gap", "uint256[41]"
));

function marketEngineStorageLayoutHash() external pure returns (bytes32) {
    return STORAGE_LAYOUT_HASH;
}
2. Use a CI/CD pipeline with `forge inspect` storage layout diffs to catch layout changes before deployment.
3. Consider using ERC-7201 namespaced storage for ALL module state to eliminate layout collision risk entirely.
4. Add a version number to the compatibility ID that must be bumped when layout changes.

medium Severity
2
1

MarketEngineDispatcher.sol
Selector Collision Risk: Root-Owned Selectors Hardcoded as Constants May Not Match Actual Function Selectors
The dispatcher hardcodes function selectors as constants and uses them to prevent remapping of root-owned functions: ```solidity bytes4 private constant SELECTOR_INITIALIZE = 0x7b89ffdb; bytes4 private constant SELECTOR_UPGRADE_TO_AND_CALL = 0x4f1ef286; bytes4 private constant SELECTOR_PROXIABLE_UUID = 0x52d1902d; bytes4 private constant SELECTOR_SET_SELECTOR_MODULE = 0x5837c6a8; // setSelectorModule(bytes4,address,bool) ``` If any of these hardcoded values are incorrect (due to typo, ABI encoding difference, or function signature change), the `_isRootOwnedSelector` check would fail to protect the corresponding function, allowing an admin to remap it to a malicious module. For example, `SELECTOR_INITIALIZE = 0x7b89ffdb` — the actual selector for `initialize(InitConfig)` where `InitConfig` is a struct should be computed as `bytes4(keccak256("initialize((address,address,address,address,address,uint16,uint16,uint8,uint8,uint64,uint16))"))`. If the struct encoding differs, the constant would be wrong. Additionally, there's no compile-time verification that these constants match the actual function selectors.


Hide Details
Impact
If any hardcoded selector constant is incorrect, the corresponding root-owned function could be remapped to a malicious module via `setSelectorModule`. For example, if `SELECTOR_UPGRADE_TO_AND_CALL` is wrong, an admin could remap the upgrade function to a module that performs a malicious upgrade, bypassing the `_authorizeUpgrade` check.
Scenario
1. Verify that `bytes4(keccak256("setSelectorModule(bytes4,address,bool)")) == 0x5837c6a8`.
2. If any constant is wrong, an admin could call `setSelectorModule(wrongSelector, maliciousModule, false)` where `wrongSelector` is the actual selector of a root-owned function.
3. The `_isRootOwnedSelector` check would not catch it (since it checks the wrong constant).
4. The root-owned function is now routed to the malicious module.
Affected code
bytes4 private constant SELECTOR_INITIALIZE = 0x7b89ffdb;
bytes4 private constant SELECTOR_UPGRADE_TO_AND_CALL = 0x4f1ef286;
bytes4 private constant SELECTOR_PROXIABLE_UUID = 0x52d1902d;
bytes4 private constant SELECTOR_SET_SELECTOR_MODULE = 0x5837c6a8;

function _isRootOwnedSelector(bytes4 selector) private pure returns (bool) {
return selector == SELECTOR_INITIALIZE || selector == SELECTOR_UPGRADE_TO_AND_CALL
|| selector == SELECTOR_PROXIABLE_UUID || selector == SELECTOR_SET_SELECTOR_MODULE;
}
Proposed fix
Replace hardcoded constants with computed selectors to ensure correctness:
bytes4 private constant SELECTOR_INITIALIZE = 
    bytes4(keccak256("initialize((address,address,address,address,address,uint16,uint16,uint8,uint8,uint64,uint16))"));
bytes4 private constant SELECTOR_UPGRADE_TO_AND_CALL = 
    bytes4(keccak256("upgradeToAndCall(address,bytes)"));
bytes4 private constant SELECTOR_PROXIABLE_UUID = 
    bytes4(keccak256("proxiableUUID()"));
bytes4 private constant SELECTOR_SET_SELECTOR_MODULE = 
    bytes4(keccak256("setSelectorModule(bytes4,address,bool)"));

Alternatively, add a test that verifies each constant matches the actual function selector:
function test_selectorConstants() public {
    assertEq(MarketEngineDispatcher.SELECTOR_INITIALIZE, 
        IMarketEngine.initialize.selector);
    assertEq(MarketEngineDispatcher.SELECTOR_SET_SELECTOR_MODULE,
        bytes4(keccak256("setSelectorModule(bytes4,address,bool)")));
}
2

MarketEngineDispatcher.sol
Gas Griefing in `_enforceApprovedModule`: Expensive Staticcall on Every Delegatecall
The `_enforceApprovedModule` function is called on every fallback invocation (every module call) and performs: 1. Two storage reads (approvedModules, moduleCodeHash) 2. `keccak256(module.code)` — hashing the entire module bytecode 3. A `staticcall` to the module for storage compatibility check ```solidity function _enforceApprovedModule(address module) private view { ModuleRegistryStorage storage $ = _moduleRegistryStorage(); if (!$.approvedModules[module]) revert UnapprovedModule(module); bytes32 expectedCodeHash = $.moduleCodeHash[module]; bytes32 actualCodeHash = keccak256(module.code); // Hashes entire bytecode! if (actualCodeHash != expectedCodeHash) { revert ModuleCodeHashMismatch(module, expectedCodeHash, actualCodeHash); } _enforceModuleStorageCompatibility(module); // Additional staticcall! } ``` For a typical module with ~10KB of bytecode, `keccak256(module.code)` costs approximately 3 gas per byte = ~30,000 gas just for the hash. The additional staticcall adds another ~2,100+ gas. This means every single user interaction (deposit, claim, switch) costs an extra ~35,000+ gas overhead beyond the actual operation cost.


Hide Details
Impact
Every user-facing operation costs an additional ~35,000-50,000 gas due to bytecode hashing and staticcall overhead. On L1 at 30 gwei gas price, this is ~$1-3 per transaction in wasted gas. On high-frequency operations like deposits and claims, this significantly degrades user experience and protocol competitiveness. Additionally, this creates a DoS vector: if a module's bytecode is very large, the gas cost could approach block gas limits for complex operations.
Scenario
1. Deploy a module with 24KB of bytecode (near the contract size limit).
2. Register it and map a selector to it.
3. Call any function routed to this module.
4. `keccak256(module.code)` for 24KB costs: 24,000 * 3 = 72,000 gas just for the hash.
5. Plus staticcall overhead: ~5,000 gas.
6. Total overhead per call: ~77,000 gas beyond the actual operation.
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
Cache the code hash verification result or use a lighter-weight check:

**Option 1**: Only verify code hash during registration, not on every call (accept the risk that code cannot change for non-self-destructable contracts):
function _enforceApprovedModule(address module) private view {
    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    if (!$.approvedModules[module]) revert UnapprovedModule(module);
    // Remove runtime code hash check - rely on registration-time verification
    // and the fact that deployed bytecode is immutable (no selfdestruct)
}


**Option 2**: Add a flag to skip runtime hash check for modules verified as non-self-destructable:
mapping(address module => bool skipRuntimeHashCheck) internal trustedModules;
**Option 3**: Cache the hash check result in transient storage to avoid re-hashing within the same transaction.

low Severity
6
1

MarketEngineState.sol
Missing Zero-Address Validation for Oracle Updates — Admin Can Set Null Oracles
The `setRateOracle`, `setSmartDataOracle`, `setMacroOracle`, and `setEquityOracle` functions (declared in the interface but implemented in modules) allow setting oracle addresses. The `_resolveOracleByClass` function checks for zero address at call time: ```solidity if (oracleClass == MarketTypes.OracleClass.CHAINLINK_RATE) { if (address(rateOracle) == address(0)) revert OracleAdapterNotConfigured(); return rateOracle; } ``` However, if an admin accidentally sets an oracle to `address(0)` (e.g., via `setRateOracle(address(0))`), all markets using that oracle class would fail to lock or resolve until the oracle is reset. This is a liveness risk. Additionally, the `priceOracle` (the default oracle) is set in `initialize` with a zero-address check, but there is no function to update it after initialization. If the primary price oracle needs to be replaced (e.g., due to deprecation), there is no upgrade path without a full UUPS upgrade.


Hide Details
Impact
If an admin accidentally sets a secondary oracle to `address(0)`, all markets using that oracle class will fail to lock/resolve, causing a DoS for those markets. Users' funds would be locked until the oracle is reset. Additionally, the inability to update `priceOracle` (the primary oracle) without a full upgrade is an operational limitation.
Scenario
1. Admin calls `setRateOracle(address(0))` (accidentally or maliciously).
2. All markets with `oracleClass = CHAINLINK_RATE` fail to lock or resolve.
3. `_resolveOracleByClass` reverts with `OracleAdapterNotConfigured`.
4. Users' funds are locked in active epochs until admin resets the oracle.
Affected code
// In IMarketEngine.sol interface:
function setRateOracle(address oracle) external;
function setSmartDataOracle(address oracle) external;
function setMacroOracle(address oracle) external;
function setEquityOracle(address oracle) external;

// In MarketEngineState.sol:
function _resolveOracleByClass(MarketTypes.OracleClass oracleClass) internal view returns (IPriceOracle) {
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_RATE) {
if (address(rateOracle) == address(0)) revert OracleAdapterNotConfigured();
return rateOracle;
}
// ...
}
Proposed fix
Add zero-address validation in oracle setter functions:
function setRateOracle(address oracle) external {
    _authAdmin();
    require(oracle != address(0), "Zero oracle address");
    address prev = address(rateOracle);
    rateOracle = IPriceOracle(oracle);
    emit RateOracleSet(prev, oracle);
}
Also consider adding a `setPriceOracle` function for the primary oracle to allow updates without full upgrades.
2

MarketEngineDispatcher.sol
Missing Access Control on `receive()` — Contract Accepts Arbitrary ETH
The `MarketEngineDispatcher` contract has an unrestricted `receive()` function: ```solidity receive() external payable {} ``` This allows anyone to send ETH to the contract. Since the contract is a prediction market engine that operates exclusively with ERC20 stake tokens, there is no legitimate reason to accept ETH. Any ETH sent to the contract would be permanently locked since there is no withdrawal mechanism for ETH in the contract.


Hide Details
Impact
ETH sent to the contract is permanently locked with no recovery mechanism. While this doesn't directly compromise security, it creates a fund-locking risk. Additionally, the payable fallback combined with the receive function means the contract can accumulate ETH that cannot be recovered.
Scenario
1. Any user calls `address(dispatcher).call{value: 1 ether}("")` or simply sends ETH.
2. The `receive()` function accepts it silently.
3. The ETH is permanently locked in the contract with no withdrawal function.
Affected code
receive() external payable {}
Proposed fix
Either remove the `receive()` function entirely if ETH is not needed, or add a recovery mechanism:
// Option 1: Reject ETH
receive() external payable {
    revert("ETH not accepted");
}

// Option 2: Add recovery function (admin only)
function recoverETH(address payable to) external onlyAdmin {
    (bool success,) = to.call{value: address(this).balance}("");
    require(success, "ETH recovery failed");
}
Also consider removing `payable` from the `fallback()` function if modules don't need to receive ETH.
3

MarketTypes.sol
Precision Loss in `_mulBps` for Small Values
The `_mulBps` function in `MarketTypes` uses a manual division approach to avoid overflow: ```solidity function _mulBps(uint256 value, uint16 bps) private pure returns (uint256) { uint256 q = value / BPS_DENOMINATOR; uint256 r = value % BPS_DENOMINATOR; return (q * uint256(bps)) + ((r * uint256(bps)) / BPS_DENOMINATOR); } ``` For small values where `value < BPS_DENOMINATOR` (i.e., `value < 10,000`), `q = 0` and the result is `(r * bps) / BPS_DENOMINATOR`. This rounds down, which is expected. However, for the confidence limit calculation in `confidenceLimitE8`, this precision loss can cause the confidence limit to be computed as 0 even when `bps > 0` and `value > 0`. For example: `value = 5` (price of 5e-8), `bps = 100` (1%): - `q = 0`, `r = 5` - Result = `(5 * 100) / 10000 = 500 / 10000 = 0` The `MIN_ABSOLUTE_CONFIDENCE_E8 = 10` floor partially mitigates this, but only if `relativeLimit < minAbsoluteConfidenceE8`. If `relativeLimit = 0` and `minAbsoluteConfidenceE8 = 10`, the function returns 10, which may still be too permissive for very small prices.


Hide Details
Impact
For assets with very small prices (e.g., micro-cap tokens priced at fractions of a cent), the confidence limit calculation may be less accurate than intended. This could allow oracle data with wider-than-intended confidence intervals to pass validation, potentially enabling settlement with less reliable price data. The `MIN_ABSOLUTE_CONFIDENCE_E8 = 10` floor provides some protection but may not be sufficient for all cases.
Scenario
// Price = 5 (5e-8 in 8-decimal representation, i.e., $0.0000000050)
// maxConfidenceBps = 500 (5%)
// Expected limit: 5 * 5% = 0.25 → rounds to 0
// Actual result: max(0, 10) = 10 (the floor)
// But 10/5 = 200% confidence is allowed, far exceeding the 5% intent
int256 price = 5;
uint16 bps = 500;
uint256 limit = MarketTypes.confidenceLimitE8(price, bps, 10);
// limit = 10, but 10/5 = 200% relative confidence is accepted
Affected code
function confidenceLimitE8(int256 priceE8, uint16 maxConfidenceBps, uint256 minAbsoluteConfidenceE8)
internal
pure
returns (uint256)
{
if (priceE8 == type(int256).min) return type(uint256).max;
if (maxConfidenceBps == 0) return 0;

uint256 absPriceE8 = priceE8 < 0 ? uint256(-priceE8) : uint256(priceE8);
uint256 relativeLimit = _mulBps(absPriceE8, maxConfidenceBps);
return relativeLimit > minAbsoluteConfidenceE8 ? relativeLimit : minAbsoluteConfidenceE8;
}

function _mulBps(uint256 value, uint16 bps) private pure returns (uint256) {
uint256 q = value / BPS_DENOMINATOR;
uint256 r = value % BPS_DENOMINATOR;
return (q * uint256(bps)) + ((r * uint256(bps)) / BPS_DENOMINATOR);
}
Proposed fix
Use higher precision arithmetic to avoid precision loss:
function _mulBps(uint256 value, uint16 bps) private pure returns (uint256) {
    // Use full precision: value * bps / BPS_DENOMINATOR
    // Safe from overflow since value <= type(uint256).max and bps <= 10000
    // value * 10000 could overflow for very large values, so check:
    if (value <= type(uint256).max / uint256(bps)) {
        return (value * uint256(bps)) / BPS_DENOMINATOR;
    }
    // Fallback to split method for very large values
    uint256 q = value / BPS_DENOMINATOR;
    uint256 r = value % BPS_DENOMINATOR;
    return (q * uint256(bps)) + ((r * uint256(bps)) / BPS_DENOMINATOR);
}
Alternatively, use `mulDiv` from a math library for full precision.
4

MarketEngineDispatcher.sol
Missing Validation: `maxOutcomes = 0` Allowed in Initialize
The `initialize` function validates that `maxOutcomes` does not exceed `MAX_OUTCOMES` but does not check that it is greater than zero: ```solidity if (config.maxOutcomes > MarketTypes.MAX_OUTCOMES) revert TooManyOutcomes(); ``` If `maxOutcomes = 0` is set, any subsequent call to `upsertTemplate` that checks `outcomeCount <= maxOutcomes` would fail for any valid market (which requires at least 2 outcomes). This would effectively brick the protocol after initialization, requiring a UUPS upgrade to fix.


Hide Details
Impact
If initialized with `maxOutcomes = 0`, no market templates can be created (since all markets require at least 2 outcomes). The protocol would be non-functional from deployment, requiring an upgrade to fix. While this is an operational risk rather than a security exploit, it could lead to deployment failures.
Scenario
1. Deploy proxy and call `initialize` with `config.maxOutcomes = 0`.
2. Call `upsertTemplate` with any valid template (outcomeCount >= 2).
3. The template creation fails because `outcomeCount > maxOutcomes` (2 > 0).
4. Protocol is non-functional.
Affected code
function initialize(IMarketEngine.InitConfig calldata config) external initializer onlyProxy {
// ...
if (config.maxOutcomes > MarketTypes.MAX_OUTCOMES) revert TooManyOutcomes();
// Missing: if (config.maxOutcomes == 0) revert TooManyOutcomes();
// ...
maxOutcomes = config.maxOutcomes;
}
Proposed fix
Add a minimum value check:
if (config.maxOutcomes == 0 || config.maxOutcomes > MarketTypes.MAX_OUTCOMES) revert TooManyOutcomes();

Or more explicitly:
uint8 constant MIN_OUTCOMES = 2;
if (config.maxOutcomes < MIN_OUTCOMES || config.maxOutcomes > MarketTypes.MAX_OUTCOMES) revert TooManyOutcomes();
5

MarketEngineState.sol
Epoch `claimLiabilityTotal` Set to Zero in Refund Mode But `totalRefundLiability` Used for Claims — Potential Accounting Confusion
In `_applyResolveAccounting`, when `refundMode = true`, the epoch's `claimLiabilityTotal` is set to 0 while `totalRefundLiability` is set to the actual liability: ```solidity e.claimLiabilityTotal = outputs.refundMode ? 0 : outputs.claimLiabilityTotal; e.totalRefundLiability = outputs.refundMode ? outputs.claimLiabilityTotal : 0; ``` However, the vault accounting still moves the full `outputs.claimLiabilityTotal` to the claims reserve: ```solidity if (outputs.claimLiabilityTotal > 0) { _vaults[templateId].active -= outputs.claimLiabilityTotal; _vaults[templateId].claims += outputs.claimLiabilityTotal; MarketMath.reserveClaimsFromActive(ledger, outputs.claimLiabilityTotal); } ``` This means the vault correctly reserves funds for refunds, but the epoch's `claimLiabilityTotal` field is 0 in refund mode. If any off-chain system or module reads `epoch.claimLiabilityTotal` to determine total claims liability, it would see 0 instead of the actual refund amount, potentially causing accounting discrepancies in reporting or secondary calculations.


Hide Details
Impact
Off-chain systems reading `epoch.claimLiabilityTotal` in refund mode would see 0 instead of the actual refund amount. This could cause incorrect reporting, incorrect fee calculations in secondary systems, or confusion in monitoring tools. The on-chain accounting is correct (vault reserves are properly set), but the epoch state is misleading.
Scenario
1. An epoch enters refund mode (e.g., oracle unavailable).
2. `_applyResolveAccounting` is called with `outputs.refundMode = true` and `outputs.claimLiabilityTotal = 1000`.
3. Vault correctly reserves 1000 tokens for claims.
4. But `epoch.claimLiabilityTotal = 0` and `epoch.totalRefundLiability = 1000`.
5. An off-chain system queries `getEpoch()` and reads `claimLiabilityTotal = 0`, incorrectly concluding no claims are pending.
Affected code
function _applyResolveAccounting(
bytes32 templateId,
uint64 epochId,
MarketTypes.Ledger storage ledger,
MarketTypes.Epoch storage e,
SettlementLogic.Outputs memory outputs,
uint64 nowTs
) internal {
// ...
e.claimLiabilityTotal = outputs.refundMode ? 0 : outputs.claimLiabilityTotal;
e.totalRefundLiability = outputs.refundMode ? outputs.claimLiabilityTotal : 0;
// ...
}
Proposed fix
Consider using a unified field for total claim liability regardless of mode, or add a helper function:
// Add to MarketTypes.Epoch or as a helper
function totalClaimableAmount(Epoch storage e) internal view returns (uint256) {
    return e.refundMode ? e.totalRefundLiability : e.claimLiabilityTotal;
}
Alternatively, document clearly in the `Epoch` struct that `claimLiabilityTotal` is 0 in refund mode and `totalRefundLiability` should be used instead. Ensure all module claim logic uses the correct field based on `refundMode`.
6

MarketEngineState.sol
Unbounded `_userEpochs` Array Growth — Potential DoS in `claimMany`
The `_userEpochs` mapping stores an array of epoch IDs for each user per template: ```solidity mapping(bytes32 templateId => mapping(address user => uint64[] epochIds)) internal _userEpochs; ``` This array grows unboundedly as users participate in more epochs. The `claimMany` function (implemented in modules, not shown here but declared in the interface) iterates over `epochIds` provided by the caller. However, the `getUserEpochs` function paginates with `MAX_USER_EPOCHS_PAGE_SIZE = 256`. If a user participates in thousands of epochs, the `_userEpochs` array becomes very large. While `claimMany` takes explicit epoch IDs (bounded by caller), the internal indexing and any function that iterates `_userEpochs[templateId][user]` without pagination could hit gas limits. Additionally, the array is never pruned (claimed epochs remain in the array), causing it to grow indefinitely.


Hide Details
Impact
For highly active users participating in many epochs, the `_userEpochs` array could grow to thousands of entries. Any function that iterates this array without pagination (e.g., in module implementations) could hit block gas limits, effectively DoS-ing that user's ability to interact with the protocol. The array also wastes storage gas as claimed epochs are never removed.
Scenario
1. User participates in 10,000 epochs over time.
2. `_userEpochs[templateId][user]` array has 10,000 entries.
3. Any module function that iterates this array without pagination reverts with out-of-gas.
4. User cannot claim remaining winnings.
Affected code
mapping(bytes32 templateId => mapping(address user => uint64[] epochIds)) internal _userEpochs;

uint256 internal constant MAX_USER_EPOCHS_PAGE_SIZE = 256;
Proposed fix
1. Consider using a bitmap or sparse representation for user epoch tracking.
2. Remove claimed epoch IDs from the array (or mark them as claimed) to prevent unbounded growth:
// In claim logic, after successful claim:
// Remove epochId from _userEpochs[templateId][user] array
// (swap with last element and pop)
3. Ensure all module functions that access `_userEpochs` use pagination.
4. Add a maximum epochs-per-user limit if the array must remain unbounded.

gas Severity
2
1

MarketEngineDispatcher.sol
Gas Optimization: Redundant `_enforceModuleStorageCompatibility` Call in `_enforceApprovedModule`
The `_enforceModuleStorageCompatibility` function is called in two places: 1. Inside `registerModule` (at registration time) 2. Inside `_enforceApprovedModule` (at every delegatecall) And `_enforceApprovedModule` itself is called in two places: 1. Inside `setSelectorModule` (at selector mapping time) 2. Inside `_delegateForSelector` (at every delegatecall) This means `_enforceModuleStorageCompatibility` is called: - Once during `registerModule` - Once during `setSelectorModule` (via `_enforceApprovedModule`) - Once during every delegatecall (via `_enforceApprovedModule` → `_enforceModuleStorageCompatibility`) The staticcall in `_enforceModuleStorageCompatibility` costs ~2,100+ gas per invocation. Since the storage compatibility marker is a pure function returning a constant, it will never change for a given module address. Calling it on every delegatecall is wasteful.


Hide Details
Impact
Gas inefficiency: every user-facing operation wastes ~2,100+ gas on a redundant staticcall that always returns the same value. For high-frequency operations, this adds up significantly.
Scenario
N/A - Gas optimization
Affected code
function _enforceApprovedModule(address module) private view {
ModuleRegistryStorage storage $ = _moduleRegistryStorage();
if (!$.approvedModules[module]) revert UnapprovedModule(module);
bytes32 expectedCodeHash = $.moduleCodeHash[module];
bytes32 actualCodeHash = keccak256(module.code);
if (actualCodeHash != expectedCodeHash) {
revert ModuleCodeHashMismatch(module, expectedCodeHash, actualCodeHash);
}
_enforceModuleStorageCompatibility(module); // Redundant staticcall on every delegatecall
}
Proposed fix
Remove the `_enforceModuleStorageCompatibility` call from `_enforceApprovedModule` since it's already verified during `registerModule`. The code hash check is sufficient for runtime integrity:
function _enforceApprovedModule(address module) private view {
    ModuleRegistryStorage storage $ = _moduleRegistryStorage();
    if (!$.approvedModules[module]) revert UnapprovedModule(module);
    bytes32 expectedCodeHash = $.moduleCodeHash[module];
    bytes32 actualCodeHash = keccak256(module.code);
    if (actualCodeHash != expectedCodeHash) {
        revert ModuleCodeHashMismatch(module, expectedCodeHash, actualCodeHash);
    }
    // Storage compatibility already verified at registerModule time
    // No need to re-verify on every delegatecall
}
2

MarketEngineState.sol
Gas Optimization: `_setRemainingWinningStake` Iterates Full `MAX_OUTCOMES` Array Unnecessarily
The `_setRemainingWinningStake` function iterates up to `e.outcomeCount` outcomes to sum winning pools: ```solidity function _setRemainingWinningStake(bytes32 templateId, uint64 epochId, bool refundMode) internal { MarketTypes.Epoch storage e = _epochs[templateId][epochId]; if (refundMode) { e.remainingWinningStake = 0; return; } uint256 sum = 0; uint8 n = e.outcomeCount; for (uint256 i = 0; i < uint256(n); i++) { if (((e.winningOutcomeMask >> i) & 1) != 0) sum += e.outcomePools[i]; } e.remainingWinningStake = sum; } ``` This is called after `_applyResolveAccounting` which already has access to `outputs.claimLiabilityTotal`. In non-refund mode, `remainingWinningStake` should equal `outputs.claimLiabilityTotal` (the total amount reserved for winners). The loop re-reads storage slots that were just written, wasting gas.


Hide Details
Impact
Gas inefficiency: the loop reads up to 8 storage slots that were recently written, adding unnecessary gas cost to every epoch resolution.
Scenario
N/A - Gas optimization
Affected code
function _setRemainingWinningStake(bytes32 templateId, uint64 epochId, bool refundMode) internal {
MarketTypes.Epoch storage e = _epochs[templateId][epochId];
if (refundMode) {
e.remainingWinningStake = 0;
return;
}
uint256 sum = 0;
uint8 n = e.outcomeCount;
for (uint256 i = 0; i < uint256(n); i++) {
if (((e.winningOutcomeMask >> i) & 1) != 0) sum += e.outcomePools[i];
}
e.remainingWinningStake = sum;
}
Proposed fix
Pass the pre-computed winning pool total from `_applyResolveAccounting` instead of re-computing it:
function _applyResolveAccounting(...) internal {
    // ...
    e.remainingWinningStake = outputs.refundMode ? 0 : outputs.claimLiabilityTotal;
    // Remove call to _setRemainingWinningStake
}
Note: Verify that `outputs.claimLiabilityTotal` equals the sum of winning outcome pools before making this change, as the settlement logic may compute them differently.

informational Severity
2
1

MarketEngineState.sol
Informational: `__gap` Size May Be Insufficient After Adding Dispatcher State Variables
The `MarketEngineState` contract appends dispatcher-specific state variables after the legacy state: ```solidity // --- dispatcher state (appended after legacy state) --- mapping(bytes4 selector => address module) internal selectorToModule; mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable; uint256[41] private __gap; ``` The `__gap[41]` was presumably sized to reserve 41 slots for future additions. However, the two dispatcher mappings (`selectorToModule` and `selectorImmutable`) were added AFTER the gap was sized, consuming 2 of the reserved slots. If the original intent was to have 41 free slots for future additions, the effective free slots are now 41 (since mappings don't consume sequential slots in the same way — they use keccak256-based storage). However, if future state variables are added between the mappings and the gap, the gap size should be recalculated. Additionally, since these mappings are never used by the dispatcher (which uses ERC-7201 storage), they represent wasted storage declarations that could confuse future developers.


Hide Details
Impact
Informational: The gap size accounting may be confusing for future developers. The unused mappings waste 2 storage slot declarations (though mappings themselves don't occupy sequential slots). Future upgrades that add state variables need to carefully account for the gap size.
Scenario
N/A - Informational finding
Affected code
// --- dispatcher state (appended after legacy state) ---
mapping(bytes4 selector => address module) internal selectorToModule;
mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

uint256[41] private __gap;
Proposed fix
1. Remove the unused `selectorToModule` and `selectorImmutable` mappings from `MarketEngineState` (they are only used in the ERC-7201 namespace in the dispatcher).
2. Document the gap size calculation explicitly:
// Gap accounts for N future state variable slots
// Current usage: [list of variables and their slot counts]
// Remaining: 41 slots
uint256[41] private __gap;
3. Consider using a storage layout tracking tool (e.g., `forge inspect`) in CI to automatically verify gap sizes.
2

MarketTypes.sol
Informational: `validateCheckpointBPublishTime` Only Checks Monotonicity Against `checkpointA`, Not `checkpointA_B`
For market types that use a secondary oracle feed (e.g., Composite, Corridor markets with `oracleFeedIdB`), the `Epoch` struct contains both `checkpointA`/`checkpointB` (primary feed) and `checkpointA_B`/`checkpointB_B` (secondary feed). The `validateCheckpointBPublishTime` function only checks monotonicity against `checkpointA`: ```solidity function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds) internal view returns (bool) { if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false; if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false; return true; } ``` For secondary feed checkpoints (`checkpointB_B`), if the module uses this same validation function, it would check monotonicity against `checkpointA` (primary feed) rather than `checkpointA_B` (secondary feed). This could allow a secondary feed checkpoint B to have an earlier publish time than the secondary feed checkpoint A, violating the intended monotonicity guarantee for the secondary feed.


Hide Details
Impact
If module implementations use `validateCheckpointBPublishTime` for secondary feed validation without accounting for the secondary checkpoint A, the monotonicity guarantee for secondary feeds could be violated. This could allow settlement with temporally inconsistent oracle data for dual-feed markets.
Scenario
N/A - Informational/design concern requiring module implementation review
Affected code
function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
internal
view
returns (bool)
{
if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
return true;
}
Proposed fix
Add an overloaded version or parameter for secondary feed validation:
function validateCheckpointBPublishTimeForFeed(
    uint64 checkpointAPublishTime,
    bool checkpointAWritten,
    uint64 publishTime,
    uint64 nowTs,
    uint64 maxDelaySeconds
) internal pure returns (bool) {
    if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
    if (checkpointAWritten && publishTime < checkpointAPublishTime) return false;
    return true;
}
Ensure module implementations use the correct checkpoint A reference for each feed's checkpoint B validation.