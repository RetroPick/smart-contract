DeFi Protocol - Prediction Market / Structured Outcome Betting Engine (UUPS Upgradeable Storage Anchor)

MarketEngineState is an abstract UUPS-upgradeable storage anchor contract for a prediction market / structured outcome betting protocol called 'RetroPick'. It defines the canonical storage layout, data structures, error types, events, and shared utility functions used by a dispatcher/module architecture. The contract supports multiple market types (Direction, Threshold, RangeClose, Velocity, Ladder, Convergence, Composite, Corridor, Cascade), oracle integrations (Chainlink price/rate/smartdata/macro/equity feeds), yield routing (Aave/ERC-4626), and both manual and rolling epoch lifecycles.

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
module (via selectorToModule)

External Calls
1
IERC20 (stakeToken)
2
IPriceOracle (priceOracle, rateOracle, smartDataOracle, macroOracle, equityOracle)
3
IYieldRouterV2 (yieldRouter)
4
SettlementLogic (library)
5
MarketMath (library)
6
Resolvers (library, via SettlementLogic)

External Systems
1
Chainlink Oracle Network
2
Aave / ERC-4626 Yield Protocol
3
UUPS Proxy / Module Dispatcher

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


critical Severity
1
1

MarketEngineState.sol
MODULE_STORAGE_COMPATIBILITY_ID Check is Trivially Bypassable - Malicious Module Can Corrupt All Storage
The `marketEngineStorageCompatibility()` function is a `pure` function that simply returns a hardcoded constant (`keccak256('retropick.marketengine.state.v1')`). Any malicious module can implement this function to return the same constant without actually sharing the correct storage layout. The dispatcher uses this as the sole compatibility check before registering modules and executing delegatecalls. Since the check is purely based on a return value from the module itself (not an independent verification), a malicious or incorrectly-laid-out module can pass this check trivially. When such a module is delegatecalled, it executes in the proxy's storage context and can corrupt any storage slot — including `admin`, `stakeToken`, vault balances, epoch data, and the `selectorToModule` mapping itself.


Hide Details
Impact
A malicious or incorrectly-laid-out module registered by a compromised admin (or via a governance attack) can corrupt all protocol storage. This includes overwriting the `admin` address, draining vault balances, manipulating epoch outcomes, or taking full control of the proxy. Even without malicious intent, a module with a subtly different storage layout will silently corrupt state on every delegatecall.
Scenario
// Malicious module that passes the compatibility check but has wrong storage layout
contract MaliciousModule {
    // Returns the expected compatibility ID without actually sharing the layout
    function marketEngineStorageCompatibility() external pure returns (bytes32) {
        return keccak256('retropick.marketengine.state.v1');
    }
    
    // This function, when delegatecalled, writes to slot 0 (which is `stakeToken` in the proxy)
    // but the module thinks it's writing to its own variable
    address public myVar; // slot 0 in module = stakeToken slot in proxy
    
    function pwn(address attacker) external {
        myVar = attacker; // overwrites stakeToken in proxy storage
    }
}
// Steps:
// 1. Admin registers MaliciousModule (passes compatibility check)
// 2. Admin sets selector for pwn() to MaliciousModule
// 3. Anyone calls pwn(attacker) via proxy
// 4. stakeToken is now set to attacker's address
// 5. All subsequent balance checks use attacker-controlled token
Affected code
function marketEngineStorageCompatibility() external pure returns (bytes32) {
return MODULE_STORAGE_COMPATIBILITY_ID;
}
Proposed fix
The compatibility check should be strengthened significantly:
1. Use code hash verification (`ModuleCodeHashMismatch` error already exists) as the primary guard — verify the module's bytecode hash against a pre-approved registry.
2. Implement a two-step module registration with a timelock (e.g., 48-hour delay) so the community can review new modules.
3. Consider using EIP-7201 namespaced storage for modules to prevent layout collisions.
4. Mark all critical selectors as immutable immediately after deployment.
5. The `pure` compatibility marker should be supplemented with off-chain storage layout diff tooling as a mandatory deployment gate.
// Add to dispatcher registration logic:
mapping(address => bytes32) public approvedModuleCodeHashes;

function registerModule(address module) external onlyAdmin {
    bytes32 expectedHash = approvedModuleCodeHashes[module];
    require(expectedHash != bytes32(0), 'UnapprovedModule');
    bytes32 actualHash;
    assembly { actualHash := extcodehash(module) }
    if (actualHash != expectedHash) revert ModuleCodeHashMismatch(module, expectedHash, actualHash);
    // ... rest of registration
}

high Severity
6
1

MarketEngineState.sol
Reentrancy in _balanceDeltaAfterWithdrawScaled via Malicious/Compromised Yield Router
The `_balanceDeltaAfterWithdrawScaled` function makes an external call to `r.withdrawScaled(templateId, principalAmount)` and then reads `stakeToken.balanceOf(address(this))` to compute the received amount. There is no reentrancy guard on this function or its callers. If the yield router is malicious or compromised, it can reenter the engine during the `withdrawScaled` call — before `b1` is measured — to manipulate the balance delta. For example, a reentrant call could deposit additional tokens into the engine (inflating `b1`) or trigger another withdrawal (deflating `b1`), causing incorrect yield accounting. More critically, if the yield router reenters a claim or deposit function, it could exploit the state inconsistency between the pre-withdrawal and post-withdrawal states.


Hide Details
Impact
A compromised yield router can manipulate the balance delta measurement, causing the engine to record incorrect yield amounts. This can lead to: (1) inflated yield credited to an epoch, allowing winners to claim more than the actual pool; (2) deflated yield causing loss of legitimate yield for users; (3) cross-function reentrancy attacks if the router reenters deposit/claim functions during the withdrawal callback, potentially draining vault funds.
Scenario
// Malicious yield router that reenters during withdrawScaled
contract MaliciousYieldRouter is IYieldRouterV2 {
    IMarketEngine engine;
    IERC20 stakeToken;
    
    function withdrawScaled(bytes32 templateId, uint256 principalAmount) external returns (uint256) {
        // Reenter engine to deposit tokens, inflating b1
        stakeToken.transfer(address(engine), 1000e18);
        // OR: reenter a claim function to exploit state inconsistency
        // engine.claim(templateId, epochId); // cross-function reentrancy
        return principalAmount;
    }
}
// Result: b1 - b0 = principalAmount + 1000e18 (inflated)
// Engine records 1000e18 extra yield that doesn't exist
// Winners can claim more than the actual pool
Affected code
function _balanceDeltaAfterWithdrawScaled(IYieldRouterV2 r, bytes32 templateId, uint256 principalAmount)
internal
returns (uint256 received)
{
uint256 b0 = stakeToken.balanceOf(address(this));
r.withdrawScaled(templateId, principalAmount); // <-- external call, no reentrancy guard
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant();
unchecked {
return b1 - b0;
}
}
Proposed fix
Add a reentrancy guard to all functions that call external contracts and then read state. Use OpenZeppelin's `ReentrancyGuard` or implement a custom mutex:
// Add ReentrancyGuard to MarketEngineState or the calling module
bool private _locked;

modifier nonReentrant() {
    require(!_locked, 'ReentrancyGuard: reentrant call');
    _locked = true;
    _;
    _locked = false;
}

// Apply to all epoch lifecycle functions that call external contracts
function resolveEpoch(...) external nonReentrant {
    // ...
    uint256 received = _balanceDeltaAfterWithdrawScaled(yieldRouter, templateId, principal);
    // ...
}
Also follow the checks-effects-interactions pattern: update all internal state before making external calls.
2

MarketEngineState.sol
Vault Active Balance Can Underflow if claimLiabilityTotal + settlementFeeTotal Exceeds Active Balance
In `_applyResolveAccounting`, the vault's `active` balance is decremented twice: first by `claimLiabilityTotal` and then by `settlementFeeTotal`. While Solidity 0.8.24 provides built-in overflow/underflow protection (causing a revert), there is no explicit pre-check that `_vaults[templateId].active >= claimLiabilityTotal + settlementFeeTotal`. If the settlement computation (via `SettlementLogic.compute`) produces values that exceed the active balance — due to yield accounting discrepancies, rounding errors, or a bug in `MarketMath.computeClaimLiabilityComponents` — the transaction will revert with an arithmetic underflow, permanently bricking epoch resolution. This is a liveness/DoS risk rather than a fund-loss risk, but it can permanently lock user funds in an unresolvable epoch.


Hide Details
Impact
If the computed settlement amounts exceed the active vault balance (due to yield accounting drift, rounding, or a bug), the epoch resolution transaction will revert with an arithmetic underflow. This permanently prevents epoch resolution, locking all user funds in the epoch indefinitely. Users cannot claim winnings or refunds. The only recovery would be an admin upgrade to fix the accounting, which requires a UUPS upgrade.
Scenario
Scenario:
1. Epoch has `totalPool = 1000 tokens` deposited into active vault.
2. Yield router is configured; `routedPrincipal = 1000 tokens` sent to router.
3. Due to a yield router bug, `_balanceDeltaAfterWithdrawScaled` returns `1001 tokens` (1 token extra due to donation/rounding).
4. `netYield = 1` token is added to `effectiveTotalPool = 1001`.
5. `SettlementLogic.compute` computes `claimLiabilityTotal = 950` and `settlementFeeTotal = 51` (total = 1001).
6. But `_vaults[templateId].active` was only incremented by the original 1000 deposit (yield was not added to active).
7. `active (1000) - claimLiabilityTotal (950) = 50`, then `50 - settlementFeeTotal (51)` → UNDERFLOW REVERT.
8. Epoch is permanently unresolvable.
Affected code
function _applyResolveAccounting(
bytes32 templateId,
uint64 epochId,
MarketTypes.Ledger storage ledger,
MarketTypes.Epoch storage e,
SettlementLogic.Outputs memory outputs,
uint64 nowTs
) internal {
if (outputs.claimLiabilityTotal > 0) {
_vaults[templateId].active -= outputs.claimLiabilityTotal; // <-- can underflow
_vaults[templateId].claims += outputs.claimLiabilityTotal;
MarketMath.reserveClaimsFromActive(ledger, outputs.claimLiabilityTotal);
}
if (outputs.settlementFeeTotal > 0) {
_vaults[templateId].active -= outputs.settlementFeeTotal; // <-- can underflow
_vaults[templateId].fees += outputs.settlementFeeTotal;
MarketMath.reserveFeesFromActive(ledger, outputs.settlementFeeTotal);
}
// ...
}
Proposed fix
Add an explicit invariant check before the deductions:
function _applyResolveAccounting(...) internal {
    uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
    // Explicit invariant: active must cover all deductions
    if (_vaults[templateId].active < totalDeduction) {
        // Emit warning event and cap deductions to available active balance
        // OR revert with a descriptive error
        revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction);
    }
    // ... rest of accounting
}
Also ensure that when yield is added to `effectiveTotalPool` in `SettlementLogic.compute`, the corresponding amount is also added to `_vaults[templateId].active` before settlement computation.
3

SettlementLogic.sol
Single-Threshold Used for All Composite Feeds - Incorrect Settlement for Multi-Feed Markets
In `SettlementLogic.compute`, for `MarketType.Composite` markets, the code initializes a `thresholds[4]` array and sets ALL thresholds to `e.absoluteThresholdValueE8` — the same single threshold value for every composite feed. This means all composite feeds are evaluated against the same threshold, regardless of whether each feed has its own threshold. For a composite market comparing, say, BTC price vs ETH price with different thresholds, all feeds would be incorrectly evaluated against the same threshold value, leading to wrong outcome determination and incorrect fund distribution.


Hide Details
Impact
Composite markets with multiple feeds that require different thresholds will be incorrectly resolved. All feeds are evaluated against the same `absoluteThresholdValueE8`, which may be correct for one feed but wrong for others. This leads to incorrect winning outcome determination, causing winners to lose their rightful claims and losers to incorrectly receive payouts. This is a direct financial loss for users.
Scenario
Scenario:
1. Admin creates a Composite market: 'BTC > $50,000 AND ETH > $3,000'
2. `absoluteThresholdValueE8 = 5000000000000` (BTC threshold: $50,000 in e8)
3. At resolution: BTC = $55,000 (above threshold ✓), ETH = $3,500 (above $3,000 ✓)
4. But the code sets `thresholds[0] = thresholds[1] = 5000000000000` ($50,000)
5. ETH checkpoint B = $3,500 = 350000000000 in e8
6. `resolveComposite` evaluates ETH against $50,000 threshold → ETH FAILS
7. Composite AND logic → market resolves as LOSS even though both conditions were met
8. Users who bet on the correct outcome (both above) lose their funds incorrectly
Affected code
} else if (e.marketType == MarketTypes.MarketType.Composite) {
int256[4] memory thresholds = [int256(0), int256(0), int256(0), int256(0)];
for (uint256 i = 0; i < e.compositeFeedCount; i++) {
thresholds[i] = e.absoluteThresholdValueE8; // <-- ALL feeds get the SAME threshold
}
outputs.refundMode = false;
outputs.winningMask = Resolvers.resolveComposite(
e.compositeLogic, e.compositeFeedCount, e.compositeConditions, thresholds, e.compositeCheckpointsB
);
e.winningOutcomeMask = outputs.winningMask;
}
Proposed fix
The `Epoch` struct should store per-feed thresholds for composite markets. Add a `int256[4] compositeThresholdsE8` field to the `Epoch` struct and populate it at epoch open time:
// In MarketTypes.Epoch struct, add:
int256[4] compositeThresholdsE8;

// In SettlementLogic.compute, replace:
} else if (e.marketType == MarketTypes.MarketType.Composite) {
    outputs.refundMode = false;
    outputs.winningMask = Resolvers.resolveComposite(
        e.compositeLogic, 
        e.compositeFeedCount, 
        e.compositeConditions, 
        e.compositeThresholdsE8,  // use per-feed thresholds
        e.compositeCheckpointsB
    );
    e.winningOutcomeMask = outputs.winningMask;
}
If per-feed thresholds are intentionally not supported (all feeds use the same threshold), this should be clearly documented and enforced at template creation time.
4

IPriceOracle.sol
nowTs Parameter in IPriceOracle Can Be Spoofed by Callers to Bypass Staleness Checks
The `IPriceOracle.getNormalizedPrice` interface accepts a `nowTs` parameter that is explicitly documented as 'ABI-compat; production adapters MUST ignore it for freshness.' However, this is a documentation-only constraint with no on-chain enforcement. If any production oracle adapter implementation uses the caller-supplied `nowTs` for staleness checks (instead of `block.timestamp`), an attacker can pass an arbitrary `nowTs` value to make stale oracle prices appear fresh. This would allow epoch lock/resolve operations to proceed with outdated price data, manipulating market outcomes. The risk is amplified because the interface explicitly passes `nowTs` from the engine to the oracle, creating a tempting implementation pattern for adapter developers.


Hide Details
Impact
If any oracle adapter uses caller-supplied `nowTs` for staleness validation, an attacker (or the worker authority) can pass a future `nowTs` to make a stale price appear fresh. This allows: (1) locking an epoch with a stale price that doesn't reflect current market conditions; (2) resolving an epoch with an outdated price that determines the wrong winner; (3) systematic manipulation of market outcomes by always using favorable stale prices.
Scenario
// Vulnerable oracle adapter (violates the interface spec but is a realistic implementation mistake)
contract VulnerableChainlinkAdapter is IPriceOracle {
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external view returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8)
    {
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(feed).latestRoundData();
        // BUG: uses caller-supplied nowTs instead of block.timestamp
        require(nowTs - updatedAt <= maxAgeSeconds, 'Stale');
        return (int256(answer), uint64(updatedAt), 0);
    }
}

// Attacker calls lockEpoch with nowTs = block.timestamp + 1 days
// This makes a 23-hour-old price appear fresh (within maxAgeSeconds)
// The stale price is used as checkpoint A, manipulating the Direction market outcome
Affected code
// From IPriceOracle.sol
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
external
view
returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);

// The nowTs parameter is passed from engine callers and could be spoofed
// if any adapter implementation uses it for freshness validation
Proposed fix
Remove the `nowTs` parameter from the `IPriceOracle` interface entirely, or make it clearly non-functional:
// Option 1: Remove nowTs from interface
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds)
    external view
    returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);

// Option 2: Add on-chain enforcement in the engine before using oracle data
function _getOraclePrice(bytes32 feedId, uint64 maxAgeSeconds) internal view 
    returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8) 
{
    (priceE8, publishTime, confidenceE8) = oracle.getNormalizedPrice(feedId, maxAgeSeconds, 0);
    // Engine-side staleness check using block.timestamp (cannot be spoofed)
    require(block.timestamp - publishTime <= maxAgeSeconds, 'OracleStale');
}
Also add a mandatory audit requirement that all oracle adapter implementations use `block.timestamp` for freshness checks.
5

SettlementLogic.sol
Corridor Market Type Has No Refund/Void Mode - Zero-Winning-Pool Scenario Causes Stuck Funds
In `SettlementLogic.compute`, the `Corridor` market type (and `Cascade`) does not have a refund/void mode. If `Resolvers.resolveCorridor` returns a `winningMask` of 0 (no winning outcome), the code proceeds to compute `claimLiabilityTotal` and `settlementFeeTotal` with `winningPool = 0`. When `winningPool = 0`, `MarketMath.computeClaimLiabilityComponents` is called with a zero winning pool, which may produce unexpected results (e.g., zero claims, full fees, or a revert). Unlike `Direction` and `Convergence` markets which explicitly check for void conditions and set `refundMode = true`, `Corridor` and `Cascade` markets have no such protection. If the price stays within the corridor (or outside all cascade levels), users' funds may be incorrectly handled.


Hide Details
Impact
If a Corridor or Cascade market resolves with no winning outcome (winningMask = 0), the settlement computation proceeds with `winningPool = 0`. Depending on `MarketMath.computeClaimLiabilityComponents` behavior with zero winning pool: (1) it may assign all funds as fees (treasury captures all user funds); (2) it may revert, permanently bricking epoch resolution; (3) it may produce zero claims, leaving all funds stuck in the active vault with no way to claim them. In any case, users lose their funds.
Scenario
Scenario for Corridor market:
1. Corridor market: price must breach either upper OR lower bound to determine winner
2. Outcome 0 = price breaches upper bound, Outcome 1 = price breaches lower bound
3. During the epoch, price stays perfectly within the corridor (neither bound breached)
4. `epochHighE8 < upperBound` AND `epochLowE8 > lowerBound`
5. `resolveCorridor` returns `winningMask = 0` (no breach)
6. `winningPool = 0`
7. `computeClaimLiabilityComponents(totalPool, 0, feeBps, feeOnLosingPool)` is called
8. Behavior depends on MarketMath implementation - likely assigns 0 to claimLiabilityTotal
9. All funds remain in active vault with no claimable flag set correctly
10. Users cannot claim refunds because `refundMode = false`
Affected code
} else if (e.marketType == MarketTypes.MarketType.Corridor) {
outputs.refundMode = false; // <-- No void/refund mode for Corridor
int256 lowerBound = e.rangeBoundsE8[0];
int256 upperBound = e.rangeBoundsE8[1];
outputs.winningMask = Resolvers.resolveCorridor(e.epochHighE8, e.epochLowE8, upperBound, lowerBound);
e.winningOutcomeMask = outputs.winningMask;
} else {
outputs.refundMode = false; // <-- No void/refund mode for Cascade either
outputs.winningMask = Resolvers.resolveCascade(
e.epochHighE8, e.epochLowE8, e.outcomeCount, e.rangeBoundsE8, e.cascadeDownward
);
e.winningOutcomeMask = outputs.winningMask;
}
// If winningMask == 0, winningPool == 0, and computeClaimLiabilityComponents is called with winningPool=0
Proposed fix
Add explicit void/refund handling for Corridor and Cascade markets when `winningMask == 0`:
} else if (e.marketType == MarketTypes.MarketType.Corridor) {
    outputs.winningMask = Resolvers.resolveCorridor(e.epochHighE8, e.epochLowE8, upperBound, lowerBound);
    if (outputs.winningMask == 0) {
        // No breach occurred - refund all participants
        outputs.refundMode = true;
        outputs.claimLiabilityTotal = e.totalPool;
        outputs.settlementFeeTotal = 0;
        return outputs;
    }
    outputs.refundMode = false;
    e.winningOutcomeMask = outputs.winningMask;
}

Also add a general safety check after all market type resolutions:
// Safety net: if no winner and not already in refund mode, trigger refund
if (outputs.winningMask == 0 && !outputs.refundMode) {
    outputs.refundMode = true;
    outputs.claimLiabilityTotal = e.totalPool + netYield;
    outputs.settlementFeeTotal = 0;
    return outputs;
}
6

MarketEngineState.sol
Uninitialized UUPS Proxy Attack Vector - Admin Address Defaults to address(0)
The `MarketEngineState` contract is an abstract UUPS-upgradeable storage anchor. The `admin` state variable is set in `MarketEngineDispatcher.initialize()`. If the `initialize()` function is not called (or is called with `address(0)` as admin), the `onlyAdmin` modifier checks `msg.sender != admin` where `admin = address(0)`. This means `address(0)` would be the admin, and since no real account can have `address(0)` as their address, no admin functions can be called. However, more critically, if the proxy implementation is deployed without initialization, an attacker can call `initialize()` themselves (if it lacks an `initializer` modifier or if the modifier is bypassable) and set themselves as admin. The contract comment acknowledges this: 'A proxy that skips initialize is broken by design—operational risk, not an on-chain uninitialized read.' This is a known risk that should be mitigated.


Hide Details
Impact
If the proxy is deployed without calling `initialize()`: (1) `admin = address(0)`, making all `onlyAdmin` functions permanently inaccessible; (2) An attacker who can call `initialize()` before the legitimate deployer can take full admin control; (3) All vault balances, oracle configurations, and module registrations would be under attacker control. This is a deployment-time risk but has catastrophic consequences if triggered.
Scenario
// Attack scenario:
// 1. Deployer deploys proxy pointing to MarketEngineDispatcher implementation
// 2. Deployer forgets to call initialize() (or tx fails)
// 3. Attacker monitors mempool and sees the uninitialized proxy
// 4. Attacker calls initialize(attacker, attacker, attacker) on the proxy
// 5. Attacker is now admin, treasury, and workerAuthority
// 6. Attacker registers malicious modules, drains any deposited funds
// 7. Attacker sets stakeToken to a malicious ERC20
Affected code
// admin is declared but not initialized in this contract
address public admin;

// onlyAdmin modifier
modifier onlyAdmin() {
if (msg.sender != admin) revert Unauthorized();
_;
}

// configInitialized flag exists but is not checked in onlyAdmin
bool public configInitialized;
Proposed fix
1. Use OpenZeppelin's `Initializable` with the `initializer` modifier to prevent double-initialization.
2. Add a `_disableInitializers()` call in the implementation constructor to prevent direct initialization of the implementation contract.
3. Add a check in `onlyAdmin` for the initialized state:
modifier onlyAdmin() {
    if (!configInitialized) revert NotInitialized();
    if (msg.sender != admin) revert Unauthorized();
    _;
}
4. Consider using OpenZeppelin's `UUPSUpgradeable` with `_authorizeUpgrade` protected by `onlyAdmin`.
5. Deploy and initialize in the same transaction using a factory contract.

medium Severity
4
1

MarketTypes.sol
Checkpoint B Monotonicity Only Checks Against Checkpoint A - Allows Replay of Old Prices at Resolution
In `MarketTypes.validateCheckpointBPublishTime`, the monotonicity check only verifies that checkpoint B's `publishTime >= checkpoint A's publishTime`. It does NOT check that checkpoint B's `publishTime` is strictly greater than the previous checkpoint B (if any). This means that if an epoch is somehow re-resolved (or if the resolution function can be called multiple times before the epoch status is updated), the same checkpoint B price could be replayed. More importantly, for markets where checkpoint A is not required (Threshold, RangeClose, Ladder, Corridor, Cascade), there is NO monotonicity check at all — only freshness. This means any fresh price within `maxDelaySeconds` can be used as checkpoint B, even if it's older than a previously submitted price.


Hide Details
Impact
For markets without checkpoint A (Threshold, RangeClose, Ladder, Corridor, Cascade), a worker/keeper can use any fresh price within the staleness window as checkpoint B. If the staleness window is large (e.g., 1 hour), the keeper can cherry-pick the most favorable price from the last hour to manipulate the outcome. This is a form of oracle price manipulation that benefits the keeper or colluding parties.
Scenario
Scenario for Threshold market with 1-hour maxDelaySeconds:
1. Threshold market: BTC must be >= $50,000 to win
2. At resolveAt, BTC price is $49,500 (below threshold)
3. But 45 minutes ago, BTC was $50,500 (above threshold)
4. Worker calls resolveEpoch with the 45-minute-old price (publishTime = now - 45min)
5. `validateCheckpointBPublishTime` passes: fresh (within 1 hour), no checkpoint A to check against
6. Market resolves as WIN using the cherry-picked favorable price
7. Users who bet on BELOW lose their funds incorrectly
Affected code
function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
internal
view
returns (bool)
{
if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
// No check: publishTime > previous checkpoint B publishTime
// No check for markets without checkpoint A
return true;
}
Proposed fix
For markets without checkpoint A, implement a stricter price selection policy:
function validateCheckpointBPublishTime(
    Epoch storage e, 
    uint64 publishTime, 
    uint64 nowTs, 
    uint64 maxDelaySeconds
) internal view returns (bool) {
    if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
    if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
    // Add: for markets without checkpoint A, require price is close to resolveAt
    // This prevents cherry-picking old prices within the staleness window
    if (!e.checkpointA.written) {
        // Require publishTime is within a tighter window of resolveAt
        uint64 tightWindow = maxDelaySeconds / 4; // e.g., 15 min if maxDelay is 1 hour
        if (nowTs - publishTime > tightWindow) return false;
    }
    return true;
}
Alternatively, use the `lastOracleCursorByTemplateFeed` mechanism to enforce monotonic round IDs for all market types.
2

SettlementLogic.sol
Composite Market Uses Single absoluteThresholdValueE8 for All Feeds - Missing Per-Feed Threshold Storage
The `Epoch` struct stores only a single `absoluteThresholdValueE8` value, but `Composite` markets can have up to 4 feeds (`compositeFeedCount`), each potentially requiring a different threshold. The `Template` struct also only has a single `absoluteThresholdValueE8`. This architectural limitation means composite markets cannot have different thresholds per feed. The `SettlementLogic.compute` function explicitly copies the same threshold to all feeds: `thresholds[i] = e.absoluteThresholdValueE8`. This is a design flaw that limits the expressiveness of composite markets and can lead to incorrect settlement if different feeds require different thresholds.


Hide Details
Impact
Composite markets are limited to using the same threshold for all feeds. This prevents the creation of meaningful multi-asset composite markets (e.g., 'BTC > $50K AND ETH > $3K'). If operators try to work around this by using relative thresholds or normalized prices, the settlement logic will still apply the same absolute threshold to all feeds, potentially causing incorrect outcome determination and financial losses for users.
Scenario
This is a design limitation rather than an exploitable vulnerability in isolation, but combined with the previous finding about composite markets, it confirms that composite market settlement is fundamentally broken for multi-threshold use cases.
Affected code
// In MarketTypes.Template and Epoch - only ONE threshold:
int256 absoluteThresholdValueE8;

// In SettlementLogic.compute:
int256[4] memory thresholds = [int256(0), int256(0), int256(0), int256(0)];
for (uint256 i = 0; i < e.compositeFeedCount; i++) {
thresholds[i] = e.absoluteThresholdValueE8; // Same threshold for ALL feeds
}
Proposed fix
Add per-feed threshold storage to both `Template` and `Epoch` structs:
// In MarketTypes.Template and Epoch, add:
int256[4] compositeThresholdsE8;  // Per-feed thresholds for Composite markets

// In SettlementLogic.compute, use per-feed thresholds:
} else if (e.marketType == MarketTypes.MarketType.Composite) {
    outputs.refundMode = false;
    outputs.winningMask = Resolvers.resolveComposite(
        e.compositeLogic, 
        e.compositeFeedCount, 
        e.compositeConditions, 
        e.compositeThresholdsE8,  // Per-feed thresholds
        e.compositeCheckpointsB
    );
    e.winningOutcomeMask = outputs.winningMask;
}
Note: This requires a storage layout change, which must be done carefully in the UUPS upgrade to avoid slot collisions.
3

MarketEngineState.sol
YieldRouterBalanceInvariant Revert Can Permanently Brick Epoch Resolution
In `_balanceDeltaAfterWithdrawScaled`, if `b1 < b0` (the contract's stakeToken balance decreases after `withdrawScaled`), the function reverts with `YieldRouterBalanceInvariant`. This can happen if: (1) the yield router sends tokens to a different address; (2) the stakeToken has a fee-on-transfer mechanism that deducts tokens during the router's internal transfer; (3) a reentrancy attack drains tokens between `b0` and `b1` measurements. If this revert occurs during epoch resolution, the epoch cannot be resolved, permanently locking all user funds. The `yieldRouterFailureCount` mechanism (max 3 failures) only applies to specific failure paths, not this revert.


Hide Details
Impact
If the yield router fails in a way that causes `b1 < b0`, epoch resolution is permanently bricked. All user funds (both winning and losing stakes) are locked in the active vault with no way to claim them. The only recovery is an admin UUPS upgrade to fix the accounting, which requires governance action and may not be possible if the admin key is compromised.
Scenario
Scenario:
1. Epoch has 1000 tokens routed to yield router
2. Yield router has a bug: it sends tokens to treasury instead of engine
3. `withdrawScaled` is called: router sends 1000 tokens to treasury (not engine)
4. `b1 = b0` (no change in engine balance) → `b1 - b0 = 0` (this case is OK)
5. OR: router sends 999 tokens to engine but deducts 1 token as fee
6. `b1 = b0 - 1` → `b1 < b0` → `YieldRouterBalanceInvariant` revert
7. Epoch resolution permanently fails
8. All user funds locked
Affected code
function _balanceDeltaAfterWithdrawScaled(IYieldRouterV2 r, bytes32 templateId, uint256 principalAmount)
internal
returns (uint256 received)
{
uint256 b0 = stakeToken.balanceOf(address(this));
r.withdrawScaled(templateId, principalAmount);
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant(); // <-- Can permanently brick resolution
unchecked {
return b1 - b0;
}
}
Proposed fix
Add a fallback resolution path that can be triggered by admin when the yield router fails:
// Add emergency resolution without yield router
function emergencyResolveEpoch(
    bytes32 templateId, 
    uint64 epochId,
    bool skipYieldWithdrawal
) external onlyAdmin {
    // Allow resolution with zero yield if router is broken
    // This prevents permanent fund lockup
    uint256 netYield = 0;
    if (!skipYieldWithdrawal) {
        netYield = _balanceDeltaAfterWithdrawScaled(yieldRouter, templateId, routedPrincipal);
    }
    // Proceed with settlement using netYield = 0
    SettlementLogic.Outputs memory outputs = SettlementLogic.compute(e, netYield);
    _applyResolveAccounting(templateId, epochId, ledger, e, outputs, uint64(block.timestamp));
}
Also consider wrapping the yield withdrawal in a try-catch and recording the failure rather than reverting.
4

SettlementLogic.sol
Ladder Market Winner Index Selection Uses First Winning Bit - Incorrect for Multi-Winner Scenarios
In `SettlementLogic.compute` for `Ladder` markets, the winner index is determined by finding the first set bit in `outputs.winningMask`. The code iterates through outcomes and breaks on the first winning outcome found (`winnerIdx = i; break;`). If `Resolvers.resolveLadder` can return a mask with multiple winning bits set, only the first winner's payout weight (`ladderPayoutWeightsBps[winnerIdx]`) is used for the entire settlement computation. This means all winning participants share the payout weight of the lowest-indexed winner, which may not be the intended behavior for ladder markets with multiple winning rungs.


Hide Details
Impact
If a Ladder market can have multiple winning outcomes (e.g., a ladder where multiple rungs are hit), the settlement uses only the first winner's payout weight. This could result in: (1) incorrect payout amounts for all winners; (2) treasury receiving incorrect fee amounts; (3) users who bet on higher-indexed winning rungs receiving payouts calculated with the wrong weight. The financial impact depends on how different the payout weights are across rungs.
Scenario
Scenario:
1. Ladder market with 3 outcomes: weights [3000, 5000, 8000] bps
2. `resolveLadder` returns `winningMask = 0b110` (outcomes 1 and 2 both win)
3. Code finds first winner: `winnerIdx = 1` (outcome 1, weight 5000 bps)
4. Settlement uses weight 5000 bps for the entire pool
5. But outcome 2 winners expected weight 8000 bps
6. Outcome 2 winners receive less than expected
7. Treasury receives more fees than intended
Affected code
if (e.marketType == MarketTypes.MarketType.Ladder) {
uint8 winnerIdx = 0;
for (uint8 i = 0; i < e.outcomeCount; i++) {
if (((outputs.winningMask >> i) & 1) != 0) {
winnerIdx = i;
break; // <-- Only uses FIRST winning outcome's weight
}
}
uint16 winnerWeight = e.ladderPayoutWeightsBps[winnerIdx];
(outputs.claimLiabilityTotal, outputs.settlementFeeTotal,) = MarketMath.computeLadderLiabilityComponents(
effectiveTotalPool, winningPool, e.settlementFeeBps, e.feeOnLosingPool, winnerWeight
);
}
Proposed fix
Clarify the intended behavior for Ladder markets with multiple winners. If only one winner is intended:
// Add assertion that Ladder markets always have exactly one winner
if (e.marketType == MarketTypes.MarketType.Ladder) {
    // Count winning bits
    uint256 winnerCount = 0;
    uint8 winnerIdx = 0;
    for (uint8 i = 0; i < e.outcomeCount; i++) {
        if (((outputs.winningMask >> i) & 1) != 0) {
            winnerCount++;
            if (winnerCount == 1) winnerIdx = i;
        }
    }
    require(winnerCount == 1, 'LadderMultipleWinners'); // Enforce single winner
    // ... rest of computation
}
If multiple winners are intended, implement proper per-winner weight computation.

low Severity
4
1

MarketEngineState.sol
MIN_MANUAL_DEPOSIT_WINDOW and MIN_MANUAL_LOCK_WINDOW Are Only 10 Seconds - Susceptible to Timestamp Manipulation
The constants `MIN_MANUAL_DEPOSIT_WINDOW` and `MIN_MANUAL_LOCK_WINDOW` are set to only 10 seconds. On Ethereum PoS, validators can manipulate `block.timestamp` by up to ~12 seconds. This means a validator could potentially manipulate the timestamp to skip the deposit window entirely (making `openAt` appear to be in the past and `lockAt` appear to have passed), preventing users from depositing. Similarly, a 10-second lock window could be bypassed by timestamp manipulation, allowing an epoch to be locked before users have a chance to deposit. While these are minimum values and operators can set larger windows, the existence of such small minimums creates a footgun.


Hide Details
Impact
With 10-second minimum windows, a malicious validator can manipulate `block.timestamp` to: (1) skip the deposit window, preventing users from participating in an epoch; (2) lock an epoch before users can deposit, resulting in an epoch with zero or minimal deposits; (3) create race conditions where the epoch transitions between states faster than users can react. This is a griefing attack that doesn't directly steal funds but prevents fair market participation.
Scenario
Scenario:
1. Admin creates epoch with `openAt = T`, `lockAt = T + 10` (minimum window)
2. User submits deposit transaction at time T+5
3. Malicious validator includes the transaction in a block with `block.timestamp = T + 11`
4. `isEpochOpen` check: `nowTs (T+11) < lockAt (T+10)` → FALSE
5. User's deposit reverts with `BettingClosed`
6. Epoch locks with zero deposits, or only deposits from colluding parties
Affected code
uint64 internal constant MIN_MANUAL_DEPOSIT_WINDOW = 10;
uint64 internal constant MIN_MANUAL_LOCK_WINDOW = 10;
Proposed fix
Increase the minimum window constants to values well above the block timestamp manipulation bound:
// Increase minimums to be safely above validator timestamp manipulation (~12 seconds)
uint64 internal constant MIN_MANUAL_DEPOSIT_WINDOW = 60;  // 1 minute minimum
uint64 internal constant MIN_MANUAL_LOCK_WINDOW = 60;     // 1 minute minimum

// For production use, recommend much larger windows (hours/days)
// Document that 10-second windows are only for testing
Also add a warning in the documentation that minimum windows should be set to at least 5-10 minutes for production deployments.
2

MarketEngineState.sol
templateIdFromSlug Collision Risk - Two Different Slugs Can Produce the Same templateId
The `templateIdFromSlug` function computes `keccak256(bytes(slug))` to derive a `templateId`. While keccak256 collisions are computationally infeasible in practice, the function does not enforce slug uniqueness at the contract level. If two different slugs happen to produce the same `templateId` (or if an admin accidentally creates two templates with the same slug), the second template creation would overwrite the first template's data in `_templates[templateId]`. This could corrupt an existing active market's configuration, affecting all open epochs for that template.


Hide Details
Impact
If a template is created with a slug that produces the same `templateId` as an existing template (either by collision or by reusing the same slug), the existing template's configuration is overwritten. This affects all active epochs for the original template: oracle feeds, fee parameters, market type, and outcome counts could all change mid-epoch, leading to incorrect settlement and financial losses for users.
Scenario
Scenario (admin error, not cryptographic collision):
1. Admin creates template with slug 'btc-direction-daily' → templateId = H1
2. Users deposit into epochs for H1
3. Admin accidentally creates another template with slug 'btc-direction-daily' (same slug)
4. `_templates[H1]` is overwritten with new configuration
5. Existing open epochs for H1 now use the new template's oracle feed and fee parameters
6. Settlement uses wrong oracle, wrong fees, potentially wrong market type
Affected code
function templateIdFromSlug(string memory slug) public pure returns (bytes32) {
return keccak256(bytes(slug));
}

// Used as key for all template-related mappings:
mapping(bytes32 templateId => MarketTypes.Template) internal _templates;
mapping(bytes32 templateId => MarketTypes.Ledger) internal _ledgers;
mapping(bytes32 templateId => MarketTypes.VaultBalances) internal _vaults;
Proposed fix
Add a uniqueness check in the template creation function (in the module that handles template upserts):
function upsertTemplate(string memory slug, ...) external onlyAdmin {
    bytes32 templateId = templateIdFromSlug(slug);
    // Check if template already exists with a DIFFERENT slug
    // (slug collision detection)
    if (_templates[templateId].active) {
        // Verify the existing template has the same slug
        require(
            keccak256(bytes(_templates[templateId].slug)) == keccak256(bytes(slug)),
            'TemplateSlugCollision'
        );
    }
    // ... rest of upsert logic
}
Also enforce `SLUG_MAX_LEN = 32` at the contract level and emit events with the full slug for off-chain monitoring.
3

MarketEngineState.sol
Storage Gap __gap[41] May Be Insufficient for Future Upgrades Given Large State Variable Count
The `MarketEngineState` contract uses a `uint256[41] private __gap` storage gap for upgrade safety. However, the contract already has a very large number of state variables (stakeToken, 5 oracle addresses, admin, treasury, workerAuthority, globalPaused, defaultSettlementFeeBps, maxSwitchFeeBps, maxOutcomes, oracleConfig, 7 mappings, yieldRouter, yieldFeeBps, lmRewardsEnabled, yieldRouterDisabled, yieldRouterFailureCount, 2 dispatcher mappings). The comment says 'Keep this layout append-only for upgrade safety.' With only 41 slots of gap, and given the protocol's complexity and likely need for future features, the gap may be exhausted in future upgrades, forcing dangerous storage layout changes.


Hide Details
Impact
If future upgrades require more than 41 new state variables, the gap will be exhausted. Developers may be tempted to: (1) reduce the gap size (breaking upgrade safety); (2) add variables after the gap (colliding with module-appended storage); (3) use a different storage pattern that breaks the existing layout. Any of these could corrupt existing state, leading to incorrect vault balances, wrong admin addresses, or broken oracle configurations.
Scenario
This is a long-term operational risk rather than an immediately exploitable vulnerability. The risk materializes when the protocol needs to add more than 41 new state variables in future upgrades.
Affected code
uint256[41] private __gap;

// Already has many state variables:
IERC20 public stakeToken; // slot N
IPriceOracle public priceOracle; // slot N+1
IPriceOracle public rateOracle; // slot N+2
IPriceOracle public smartDataOracle; // slot N+3
IPriceOracle public macroOracle; // slot N+4
IPriceOracle public equityOracle; // slot N+5
// ... many more
uint256[41] private __gap; // Only 41 slots remaining
Proposed fix
Increase the storage gap to a larger value (e.g., 100 or 200 slots) to provide more headroom for future upgrades:
// Increase gap to provide more upgrade headroom
uint256[100] private __gap;  // Increased from 41

Alternatively, adopt EIP-7201 namespaced storage to completely avoid storage collision issues:
// EIP-7201 namespaced storage
bytes32 private constant STORAGE_LOCATION = 
    keccak256(abi.encode(uint256(keccak256('retropick.marketengine.state.v1')) - 1)) & ~bytes32(uint256(0xff));

struct MarketEngineStorage {
    IERC20 stakeToken;
    // ... all state variables
}

function _getStorage() internal pure returns (MarketEngineStorage storage $) {
    assembly { $.slot := STORAGE_LOCATION }
}
4

MarketEngineState.sol
configInitialized Flag Not Checked in onlyAdmin Modifier - Admin Functions Callable Before Initialization
The `configInitialized` boolean flag exists in the contract state but is never checked in the `onlyAdmin` modifier. If the proxy is initialized with `admin = address(0)` (accidentally or maliciously), the `onlyAdmin` modifier would always revert (since no real address equals `address(0)`). Conversely, if `configInitialized` is `false` but `admin` is set to a non-zero address (partial initialization), admin functions can be called even though the protocol is not fully configured. This could allow admin functions to be called in an inconsistent state where `stakeToken`, `oracleConfig`, or other critical parameters are not yet set.


Hide Details
Impact
Admin functions can be called before the protocol is fully initialized. For example, a module could be registered before `stakeToken` is set, or an epoch could be opened before `oracleConfig` is configured. This could lead to epochs with zero-address oracle feeds, incorrect fee parameters, or other inconsistent states that cause user fund losses.
Scenario
Scenario:
1. Proxy is deployed and `initialize()` is called with admin set but stakeToken = address(0)
2. `configInitialized = true` is set
3. Admin calls `upsertTemplate()` to create a template
4. Admin calls `openEpoch()` to open an epoch
5. Users deposit into the epoch
6. At lock time, oracle call fails because oracle is not configured
7. Epoch cannot be locked, user funds are stuck
Affected code
bool public configInitialized;
address public admin;

modifier onlyAdmin() {
if (msg.sender != admin) revert Unauthorized();
// Missing: if (!configInitialized) revert NotInitialized();
_;
}
Proposed fix
Add `configInitialized` check to the `onlyAdmin` modifier and add a separate `whenInitialized` modifier for user-facing functions:
modifier onlyAdmin() {
    if (!configInitialized) revert NotInitialized();
    if (msg.sender != admin) revert Unauthorized();
    _;
}

modifier whenInitialized() {
    if (!configInitialized) revert NotInitialized();
    _;
}

// Apply whenInitialized to all user-facing functions (deposit, claim, etc.)
function deposit(...) external whenInitialized {
    // ...
}

gas Severity
2
1

MarketEngineState.sol
Gas Optimization: _setRemainingWinningStake Iterates Full outcomeCount Even for Single-Winner Markets
The `_setRemainingWinningStake` function iterates through all `outcomeCount` outcomes to sum winning pools. For markets with a single winner (Direction, Threshold, most Ladder markets), this loop always iterates through all outcomes even though only one will match. With `MAX_OUTCOMES = 8`, this is a bounded loop, but it still performs unnecessary iterations and storage reads for non-winning outcomes.


Hide Details
Impact
Minor gas inefficiency. For single-winner markets, the loop performs unnecessary iterations. With MAX_OUTCOMES = 8, the maximum overhead is 7 extra iterations per resolution. This is a gas optimization opportunity, not a security issue.
Affected code
function _setRemainingWinningStake(bytes32 templateId, uint64 epochId, bool refundMode) internal {
MarketTypes.Epoch storage e = _epochs[templateId][epochId];
if (refundMode) {
e.remainingWinningStake = 0;
return;
}
uint256 sum = 0;
uint8 n = e.outcomeCount;
for (uint256 i = 0; i < uint256(n); i++) { // Iterates ALL outcomes
if (((e.winningOutcomeMask >> i) & 1) != 0) sum += e.outcomePools[i];
}
e.remainingWinningStake = sum;
}
Proposed fix
Early exit optimization for single-winner markets:
function _setRemainingWinningStake(bytes32 templateId, uint64 epochId, bool refundMode) internal {
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    if (refundMode) {
        e.remainingWinningStake = 0;
        return;
    }
    uint256 sum = 0;
    uint8 n = e.outcomeCount;
    uint256 mask = e.winningOutcomeMask;
    for (uint256 i = 0; i < uint256(n); i++) {
        if ((mask >> i) & 1 != 0) {
            sum += e.outcomePools[i];
            // Early exit if only one winner expected (optimization for common case)
            // Note: only safe if winningMask is guaranteed to have at most 1 bit set
            // for single-winner market types
        }
    }
    e.remainingWinningStake = sum;
}
Alternatively, use bit manipulation to count set bits and exit early when all winners are found.
2

SettlementLogic.sol
Gas Optimization: Redundant winningOutcomeMask Assignment in SettlementLogic.compute
In `SettlementLogic.compute`, `e.winningOutcomeMask` is assigned inside each market type branch AND then `outputs.winningMask` is also set. The `_applyResolveAccounting` function then assigns `e.winningOutcomeMask = outputs.winningMask` again. This results in double storage writes for `winningOutcomeMask` in most market type branches.


Hide Details
Impact
Each unnecessary SSTORE costs 2900 gas (warm slot) or 20000 gas (cold slot). For every epoch resolution, this wastes approximately 2900-20000 gas on a redundant storage write.
Affected code
// In SettlementLogic.compute - double assignment:
outputs.winningMask = mask;
e.winningOutcomeMask = mask; // <-- First write to storage

// In _applyResolveAccounting:
e.winningOutcomeMask = outputs.winningMask; // <-- Second write to storage (same value)
Proposed fix
Remove the `e.winningOutcomeMask = mask` assignments from within `SettlementLogic.compute` and rely solely on the assignment in `_applyResolveAccounting`:
// In SettlementLogic.compute - remove e.winningOutcomeMask assignments:
if (e.marketType == MarketTypes.MarketType.Direction) {
    (bool voided, uint256 mask) = Resolvers.resolveDirection(...);
    // ...
    outputs.winningMask = mask;
    // Remove: e.winningOutcomeMask = mask;
}
// ... same for all other market types

// _applyResolveAccounting already handles the storage write:
e.winningOutcomeMask = outputs.winningMask;  // Single authoritative write

informational Severity
2
1

MarketEngineState.sol
Informational: positionKey Uses abi.encodePacked with Fixed-Width Types - Correctly Documented but Worth Noting
The `positionKey` function uses `keccak256(abi.encodePacked(templateId, epochId))` where `templateId` is `bytes32` and `epochId` is `uint64`. The code comment correctly notes that 'Fixed-width bytes32 + uint64 packing is injective on pairs (no classic encodePacked ambiguity with dynamic types).' This is correct — since both types are fixed-width, there is no hash collision risk from `abi.encodePacked`. However, it's worth noting that this function is also used as the `marketId` for trusted-reporter oracles, creating a coupling between the position key and the oracle market ID.


Hide Details
Impact
No direct security impact. The use of `abi.encodePacked` with fixed-width types is safe. The dual use as both position key and oracle market ID is a design coupling that could cause issues if the oracle market ID scheme needs to change independently of the position key scheme.
Affected code
function positionKey(bytes32 templateId, uint64 epochId) public pure returns (bytes32) {
return keccak256(abi.encodePacked(templateId, epochId));
}
Proposed fix
Consider using `abi.encode` instead of `abi.encodePacked` for consistency and future-proofing, even though both are safe for fixed-width types:
function positionKey(bytes32 templateId, uint64 epochId) public pure returns (bytes32) {
    // abi.encode is slightly more gas-expensive but more explicit about type boundaries
    return keccak256(abi.encode(templateId, epochId));
}
Also consider separating the oracle market ID derivation from the position key if they may need to diverge in future versions.
2

IYieldRouterV2.sol
Informational: IYieldRouterV2 Interface Allows Implementations to Silently Return 0 from withdrawScaled
The `IYieldRouterV2.withdrawScaled` function's return value (`grossAmount`) is explicitly documented as 'SHOULD equal underlying actually sent to the engine; callers SHOULD verify stakeToken balance deltas instead of trusting a malicious return value alone.' The engine correctly uses balance delta instead of the return value. However, the interface does not enforce that implementations MUST revert on failure — they could silently return 0. If a router implementation returns 0 without reverting (e.g., due to a bug), `_balanceDeltaAfterWithdrawScaled` would return 0 (if no tokens were actually transferred), causing the epoch to resolve with zero yield and potentially incorrect accounting.


Hide Details
Impact
If a yield router silently fails (returns 0 without reverting), the epoch resolves with zero yield. Users lose their yield earnings but can still claim their principal. This is a financial loss for users but not a critical vulnerability since the principal is preserved.
Affected code
// IYieldRouterV2.sol
function withdrawScaled(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);
// No requirement to revert on failure - can silently return 0

// MarketEngineState.sol - correctly uses balance delta:
function _balanceDeltaAfterWithdrawScaled(...) internal returns (uint256 received) {
uint256 b0 = stakeToken.balanceOf(address(this));
r.withdrawScaled(templateId, principalAmount); // return value ignored
uint256 b1 = stakeToken.balanceOf(address(this));
// ...
}
Proposed fix
Add a minimum received amount check in `_balanceDeltaAfterWithdrawScaled`:
function _balanceDeltaAfterWithdrawScaled(
    IYieldRouterV2 r, 
    bytes32 templateId, 
    uint256 principalAmount
) internal returns (uint256 received) {
    uint256 b0 = stakeToken.balanceOf(address(this));
    r.withdrawScaled(templateId, principalAmount);
    uint256 b1 = stakeToken.balanceOf(address(this));
    if (b1 < b0) revert YieldRouterBalanceInvariant();
    unchecked { received = b1 - b0; }
    // Add: warn if received is significantly less than principalAmount
    // (allows for yield loss but catches silent failures)
    if (received < principalAmount / 2) {
        emit YieldRouterWithdrawFailed(templateId, 0, principalAmount);
    }
    return received;
}
Also update the `IYieldRouterV2` interface documentation to require that implementations MUST revert on failure.