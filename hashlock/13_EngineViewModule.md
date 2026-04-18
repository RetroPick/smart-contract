DeFi Prediction Market Protocol / UUPS Upgradeable Dispatcher

A UUPS-upgradeable, dispatcher-based prediction market engine that manages the full lifecycle of prediction market epochs (open → lock → resolve → claim). The system uses a modular architecture where a central dispatcher delegates calls to registered modules via delegatecall. MarketEngineState serves as the canonical storage anchor shared by all modules. Markets are organized by 'templates' (market definitions) and 'epochs' (individual rounds), supporting multiple market types (Direction, Threshold, Range, Velocity, Ladder, Convergence, Composite, Corridor, Cascade) with Chainlink oracle integration and optional yield routing.

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
dispatcher (module allowlist)

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

External Systems
1
Chainlink Oracle Network
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


critical Severity
2
1

MarketEngineState.sol
Storage Layout Compatibility Marker is Insufficient - Delegatecall Module Can Corrupt Proxy Storage
The `marketEngineStorageCompatibility()` marker only proves a module implements one specific selector returning a constant hash. It does NOT verify that the module's actual storage layout matches `MarketEngineState`. Any module that inherits `MarketEngineState` but adds additional state variables before the `__gap`, uses a different inheritance order, or has a different compiler version/optimization setting could silently corrupt the proxy's storage slots. The comment in the code explicitly acknowledges this: 'only discipline, review, and the dispatcher bytecode allowlist mitigate storage clashes.' The code hash allowlist helps but only prevents unregistered modules - a registered module with a subtle storage layout difference (e.g., an extra inherited contract) would pass all checks and corrupt storage on delegatecall.


Hide Details
Impact
A module with a misaligned storage layout (even accidentally) could overwrite critical state variables like `admin`, `stakeToken`, `configInitialized`, or vault balances during delegatecall execution. This could lead to complete protocol compromise, fund drainage, or permanent DoS. Even a well-intentioned module upgrade with a subtle layout difference could corrupt all protocol state.
Scenario
// Scenario: Module developer accidentally adds a state variable before inheriting MarketEngineState
contract MalignedModule is SomeOtherContract, MarketEngineState {
// SomeOtherContract adds a uint256 at slot 0
// This shifts ALL MarketEngineState variables by 1 slot
// stakeToken now reads from slot 1 (was slot 0)
// admin now reads from slot 7 (was slot 6)
// When this module executes via delegatecall, it reads/writes wrong slots
// The compatibility marker check passes because the function exists
// The code hash check passes if admin pre-approved this hash

function marketEngineStorageCompatibility() external pure returns (bytes32) {
return MODULE_STORAGE_COMPATIBILITY_ID; // passes check
}

function maliciousFunction() external {
// Writes to what it thinks is 'admin' slot but actually corrupts 'stakeToken'
admin = msg.sender; // corrupts wrong storage slot in proxy
}
}
Affected code
function marketEngineStorageCompatibility() external pure returns (bytes32) {
return MODULE_STORAGE_COMPATIBILITY_ID;
}
Proposed fix
1. Adopt EIP-7201 namespaced storage pattern for all modules to eliminate layout collision risk entirely.
2. Add automated storage layout snapshot tests in CI that compare module storage layouts against the canonical `MarketEngineState` layout using `forge inspect`.
3. Consider using a storage layout hash (computed from the ABI-encoded slot assignments) as the compatibility marker instead of a simple constant.
4. Require modules to be deployed from a verified factory that enforces correct inheritance.
// EIP-7201 approach - each module uses isolated storage namespace
bytes32 private constant MARKET_ENGINE_STORAGE_SLOT = 
    keccak256(abi.encode(uint256(keccak256('retropick.marketengine.state.v1')) - 1)) & ~bytes32(uint256(0xff));

function _getMarketEngineStorage() internal pure returns (MarketEngineStorage storage $) {
    assembly { $.slot := MARKET_ENGINE_STORAGE_SLOT }
}
2

MarketEngineState.sol
Single Admin Key Controls All Critical Protocol Operations Without Timelock
The entire protocol is controlled by a single `admin` address with no timelock, multi-sig requirement, or governance delay. The admin can: register arbitrary modules (which execute via delegatecall in the proxy's storage context), change oracle addresses, set the yield router, modify fee parameters, pause the protocol, and change the treasury. The `_authAdmin()` function only checks `msg.sender == admin` with no additional safeguards. If the admin private key is compromised, an attacker gains complete control over all user funds.


Hide Details
Impact
Complete protocol compromise if admin key is stolen or phished. Attacker can: (1) register a malicious module that drains all vault funds via delegatecall, (2) replace oracle addresses with manipulated oracles to resolve epochs incorrectly, (3) redirect treasury to attacker address, (4) disable yield router to strand funds, (5) permanently pause the protocol. All user funds at risk.
Scenario
// Attack scenario after admin key compromise:
// Step 1: Deploy malicious module
contract DrainModule is MarketEngineState {
function marketEngineStorageCompatibility() external pure returns (bytes32) {
return MODULE_STORAGE_COMPATIBILITY_ID;
}
function drain(address attacker) external {
// In delegatecall context, this drains the proxy's stakeToken balance
stakeToken.transfer(attacker, stakeToken.balanceOf(address(this)));
}
}
// Step 2: Admin allows code hash, registers module, maps selector
// Step 3: Call drain() through dispatcher -> all funds stolen
Affected code
function _authAdmin() internal view {
if (!configInitialized) revert NotInitialized();
if (msg.sender != admin) revert Unauthorized();
}

modifier onlyAdmin() {
if (!configInitialized) revert NotInitialized();
if (msg.sender != admin) revert Unauthorized();
_;
}
Proposed fix
1. Use a multi-sig wallet (e.g., Gnosis Safe with 3-of-5 signers) as the admin address.
2. Implement a timelock (minimum 48-72 hours) for critical operations like module registration, oracle changes, and yield router updates.
3. Separate operational roles: worker for epoch management, treasury for fee withdrawal, governance for protocol changes.
4. Consider implementing an emergency guardian role with limited powers (pause only) that can act quickly.
// Add timelock for critical admin operations
mapping(bytes32 => uint256) public pendingOperations;
uint256 public constant TIMELOCK_DELAY = 48 hours;

function scheduleModuleRegistration(address module) external onlyAdmin {
    bytes32 opId = keccak256(abi.encode('registerModule', module, block.timestamp));
    pendingOperations[opId] = block.timestamp + TIMELOCK_DELAY;
    emit OperationScheduled(opId, block.timestamp + TIMELOCK_DELAY);
}

high Severity
3
1

MarketEngineState.sol
Reentrancy Risk in _balanceDeltaAfterWithdrawScaled via Untrusted Yield Router
The `_balanceDeltaAfterWithdrawScaled` function calls `r.withdrawScaled(templateId, principalAmount)` on an external `IYieldRouterV2` contract before reading `stakeToken.balanceOf(address(this))`. If the yield router is a malicious or compromised contract, it can reenter the protocol during the `withdrawScaled` call. Since vault state (e.g., `_vaults[templateId].active`) may not have been updated before this call in the calling context, a reentrant call could exploit inconsistent state. Additionally, if `stakeToken` is an ERC777 or has transfer hooks, the `balanceOf` call after `withdrawScaled` could be manipulated if the router triggers token callbacks that modify the contract's balance.


Hide Details
Impact
A compromised yield router could reenter the protocol during `withdrawScaled`, exploiting state inconsistencies to double-count withdrawals, manipulate vault balances, or drain funds. If the stakeToken has transfer hooks, the balance delta could be manipulated to report incorrect received amounts, leading to accounting errors that accumulate over time.
Scenario
// Malicious yield router that reenters during withdrawScaled
contract MaliciousYieldRouter is IYieldRouterV2 {
IMarketEngine engine;
bytes32 targetTemplate;

function withdrawScaled(bytes32 templateId, uint256 amount) external {
// Reenter the engine before balance is read
// If vault state hasn't been updated yet, can exploit inconsistency
engine.claimFees(targetTemplate); // or any state-modifying call
// Then transfer tokens to make balance delta look correct
IERC20(stakeToken).transfer(address(engine), amount);
}
}
Affected code
function _balanceDeltaAfterWithdrawScaled(IYieldRouterV2 r, bytes32 templateId, uint256 principalAmount)
internal
returns (uint256 received)
{
uint256 b0 = stakeToken.balanceOf(address(this));
r.withdrawScaled(templateId, principalAmount); // external call to untrusted contract
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant();
unchecked {
return b1 - b0;
}
}
Proposed fix
1. Apply a `nonReentrant` modifier to all functions that call `_balanceDeltaAfterWithdrawScaled`.
2. Follow checks-effects-interactions: update all vault state BEFORE calling the yield router.
3. Validate that the yield router address is a trusted, audited contract and consider adding a whitelist check.
// Add reentrancy guard to calling functions
function _balanceDeltaAfterWithdrawScaled(IYieldRouterV2 r, bytes32 templateId, uint256 principalAmount)
    internal
    returns (uint256 received)
{
    // Ensure vault state is updated BEFORE this call in the calling context
    uint256 b0 = stakeToken.balanceOf(address(this));
    r.withdrawScaled(templateId, principalAmount);
    uint256 b1 = stakeToken.balanceOf(address(this));
    if (b1 < b0) revert YieldRouterBalanceInvariant();
    unchecked {
        return b1 - b0;
    }
}
// Calling functions should have nonReentrant modifier applied
2

MarketEngineState.sol
Uninitialized Proxy Vulnerability - configInitialized Can Be Bypassed via Module Storage Collision
The `configInitialized` flag is the sole guard against operating on an uninitialized proxy. All auth functions check this flag first. However, since modules execute via delegatecall in the proxy's storage context, a module with a storage layout collision could write `true` to the `configInitialized` slot (slot 6, after the 6 oracle addresses) without going through the proper `initialize` function. Additionally, if the UUPS proxy implementation is deployed without calling `initialize`, the `_disableInitializers()` pattern from OpenZeppelin is not visible in the provided code, leaving the implementation contract itself potentially initializable by anyone.


Hide Details
Impact
If the implementation contract (not the proxy) is initialized by an attacker, they become admin of the implementation. While this doesn't directly affect the proxy's storage, it could be used to register malicious modules or manipulate the implementation in ways that affect future upgrades. If `configInitialized` can be set via storage collision, an attacker could set `admin` to their address and take control.
Scenario
// If implementation contract is not protected with _disableInitializers():
// Attacker calls initialize() directly on the implementation contract
// Sets themselves as admin of the implementation
// Can then register malicious modules that affect future proxy upgrades
// Or use the implementation as a vector for other attacks

// Storage collision scenario:
// A module that writes to slot 6 (configInitialized) and slot 7 (admin)
// could bypass the initialization check
Affected code
bool public configInitialized;
address public admin;

modifier onlyAdmin() {
if (!configInitialized) revert NotInitialized();
if (msg.sender != admin) revert Unauthorized();
_;
}
Proposed fix
1. Ensure the implementation contract calls `_disableInitializers()` in its constructor to prevent direct initialization.
2. Add an explicit check that `admin != address(0)` in addition to `configInitialized`.
3. Consider using OpenZeppelin's `Initializable` with `initializer` modifier for the initialize function.
// In the implementation contract constructor:
constructor() {
    _disableInitializers(); // Prevents initialization of implementation directly
}

// Strengthen the auth check:
function _authAdmin() internal view {
    if (!configInitialized || admin == address(0)) revert NotInitialized();
    if (msg.sender != admin) revert Unauthorized();
}
3

MarketEngineState.sol
Vault Balance Invariant Can Be Violated by Rebasing/Fee-on-Transfer Stake Tokens
The `_balanceDeltaAfterWithdrawScaled` function uses a balance delta pattern to handle non-standard ERC20 tokens. However, the broader vault accounting in `_applyResolveAccounting` directly manipulates `_vaults[templateId].active` by subtracting `claimLiabilityTotal + settlementFeeTotal`. If `stakeToken` is a rebasing token (like stETH or aToken), the actual balance held by the contract can change between transactions without any deposits or withdrawals, causing `_vaults[templateId].active` to diverge from the actual token balance. This creates an accounting discrepancy that could allow over-claiming or cause legitimate claims to fail.


Hide Details
Impact
With a rebasing stake token: (1) If token balance increases (positive rebase), the excess yield is not captured in vault accounting, effectively locking funds. (2) If token balance decreases (negative rebase, e.g., slashing), `_vaults[templateId].active` overstates actual holdings, causing `VaultInsufficientActive` reverts that prevent epoch resolution and claim processing, permanently locking user funds.
Scenario
// Scenario with negative rebasing token (e.g., slashed stETH):
// 1. Users deposit 1000 stETH, _vaults[template].active = 1000e18
// 2. Slashing event: actual balance drops to 900e18
// 3. Epoch resolves: claimLiabilityTotal = 950e18 (based on original deposits)
// 4. Check: _vaults[template].active (1000e18) >= 950e18 -> passes
// 5. _vaults[template].active -= 950e18 -> active = 50e18
// 6. Claims bucket = 950e18 but actual token balance only has 900e18
// 7. When users try to claim, contract has insufficient tokens -> claims fail
Affected code
function _applyResolveAccounting(
bytes32 templateId,
uint64 epochId,
MarketTypes.Ledger storage ledger,
MarketTypes.Epoch storage e,
SettlementLogic.Outputs memory outputs,
uint64 nowTs
) internal {
uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
if (_vaults[templateId].active < totalDeduction) {
revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction);
}
if (outputs.claimLiabilityTotal > 0) {
_vaults[templateId].active -= outputs.claimLiabilityTotal;
_vaults[templateId].claims += outputs.claimLiabilityTotal;
...
}
...
}
Proposed fix
1. Document clearly that rebasing tokens are NOT supported as stake tokens.
2. Add a validation in the initialize function to check that the stake token is not a rebasing token.
3. Consider adding a reconciliation function that syncs vault accounting with actual token balance.
4. If rebasing tokens must be supported, use share-based accounting instead of absolute amounts.
// Add explicit documentation and validation
function _validateStakeToken(address token) internal view {
    // Ensure token is not rebasing by checking balance stability
    // This is a best-effort check - document unsupported token types
    require(token != address(0), 'Invalid stake token');
    // Consider adding a registry of approved stake tokens
}

medium Severity
6
1

MarketTypes.sol
Oracle Checkpoint A Allows Stale Price Data - publishTime Can Be Far Before lockAt
The `validateCheckpointAPublishTime` function explicitly does NOT require `publishTime >= lockAt`. The comment states: 'Do NOT require publishTime >= lockAt; Chainlink updatedAt may be earlier than lockAt while still fresh.' This means an oracle price from `maxDelaySeconds` before the lock time can be used as checkpoint A. For Direction/Velocity markets, this means the 'starting price' for comparison could be significantly older than the lock time, allowing informed actors who know the oracle's update schedule to predict outcomes or exploit the timing gap.


Hide Details
Impact
For Direction markets (comparing checkpoint B vs checkpoint A), if checkpoint A uses a price from `maxDelaySeconds` before lockAt, and checkpoint B uses a price from `maxDelaySeconds` before resolveAt, the actual comparison window is `(resolveAt - lockAt) + 2*maxDelaySeconds` instead of just `resolveAt - lockAt`. This significantly widens the oracle manipulation window and allows front-running based on known oracle update schedules.
Scenario
// Scenario for Direction market with maxDelaySeconds = 3600 (1 hour):
// lockAt = T, resolveAt = T + 1 hour
// Checkpoint A: publishTime = T - 3599 (just within staleness window)
// Checkpoint B: publishTime = T + 1 hour - 3599
// Actual price comparison: price at (T-3599) vs price at (T+3601)
// Effective window: ~2 hours instead of 1 hour
// An attacker who knows the oracle update schedule can:
// 1. Observe that checkpoint A will use an old low price
// 2. Bet 'Up' knowing the current price is already higher
// 3. Collect winnings with near-certainty
Affected code
function validateCheckpointAPublishTime(Epoch storage, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
internal
pure
returns (bool)
{
return validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds);
// NOTE: Does NOT check publishTime >= lockAt
}
Proposed fix
For Direction and Velocity markets where checkpoint A is the reference price, consider requiring `publishTime >= lockAt - maxDelaySeconds` AND `publishTime <= lockAt + maxDelaySeconds` to ensure the checkpoint A price is actually from around the lock time.
function validateCheckpointAPublishTime(
    Epoch storage e, 
    uint64 publishTime, 
    uint64 nowTs, 
    uint64 maxDelaySeconds
) internal view returns (bool) {
    if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
    // For direction/velocity markets, ensure price is from near lock time
    if (e.marketType == MarketTypes.MarketType.Direction || 
        e.marketType == MarketTypes.MarketType.Velocity) {
        if (publishTime < e.timing.lockAt - maxDelaySeconds) return false;
    }
    return true;
}
2

MarketEngineState.sol
MIN_MANUAL_DEPOSIT_WINDOW and MIN_MANUAL_LOCK_WINDOW Are Dangerously Small (10 seconds)
The constants `MIN_MANUAL_DEPOSIT_WINDOW = 10` and `MIN_MANUAL_LOCK_WINDOW = 10` allow epoch windows as short as 10 seconds. Combined with `block.timestamp` manipulation tolerance of ~15 seconds on Ethereum (and even more on some L2s), a 10-second window could be entirely skipped or manipulated. A validator/miner could manipulate the timestamp to skip the deposit window entirely, or a keeper could open and immediately lock an epoch within the same block, preventing any user deposits.


Hide Details
Impact
1. Epochs can be opened and locked in the same block (or within 1-2 blocks), preventing user participation. 2. On L2 networks with faster block times, 10 seconds may be only 1-2 blocks, making the window practically unusable. 3. A malicious keeper (workerAuthority) could open epochs with minimal windows to prevent users from depositing on outcomes they don't want to win. 4. Timestamp manipulation by validators could cause users to miss deposit windows.
Scenario
// Malicious keeper scenario:
// 1. Keeper opens epoch with openAt=now, lockAt=now+10
// 2. In the same transaction or next block, keeper locks the epoch
// 3. No users had time to deposit
// 4. Epoch resolves with only keeper-controlled positions
// 5. Keeper collects all fees with no competition

// On Arbitrum (250ms blocks), 10 seconds = ~40 blocks
// On some L2s with 1-second blocks, 10 seconds = 10 blocks
// Still very short for meaningful user participation
Affected code
uint64 internal constant MIN_MANUAL_DEPOSIT_WINDOW = 10;
uint64 internal constant MIN_MANUAL_LOCK_WINDOW = 10;
Proposed fix
Increase minimum windows to values that provide meaningful participation time:
// Increase minimum windows significantly
uint64 internal constant MIN_MANUAL_DEPOSIT_WINDOW = 5 minutes; // was 10 seconds
uint64 internal constant MIN_MANUAL_LOCK_WINDOW = 1 minutes;    // was 10 seconds
uint64 internal constant MIN_ROLLING_INTERVAL_SECONDS = 1 minutes; // was 10 seconds

// Also add validation in epoch open function:
require(
    timing.lockAt - timing.openAt >= MIN_MANUAL_DEPOSIT_WINDOW,
    'Deposit window too short'
);
3

MarketEngineState.sol
YieldRouterBalanceInvariant Check Insufficient - Partial Principal Loss Not Detected
The `_balanceDeltaAfterWithdrawScaled` function only checks that `b1 >= b0` (balance didn't decrease). It does NOT verify that the received amount equals the requested `principalAmount`. If the yield router returns less than the requested principal (e.g., due to slippage, partial withdrawal, or a bug), the function silently accepts the lower amount. The calling code then uses this lower `received` value for accounting, potentially leaving the vault with less active collateral than expected while the epoch's `routedPrincipal` still records the full amount.


Hide Details
Impact
If the yield router returns less than `principalAmount`, the vault's active balance will be lower than expected. This could cause: (1) `VaultInsufficientActive` reverts during epoch resolution, preventing claims, (2) accumulated shortfalls across multiple epochs leading to insolvency, (3) the failure counter not incrementing (since the call 'succeeded'), allowing the underpayment to continue indefinitely.
Scenario
// Scenario: Yield router has a bug that returns 99% of principal
// principalAmount = 1000e18
// Yield router transfers only 990e18 to the engine
// b1 - b0 = 990e18 (>= b0, so no revert)
// received = 990e18
// But routedPrincipal was 1000e18
// Shortfall: 10e18 per withdrawal
// After 100 epochs: 1000e18 shortfall
// Eventually VaultInsufficientActive reverts block all claims
// Failure counter never increments because withdrawScaled 'succeeded'
Affected code
function _balanceDeltaAfterWithdrawScaled(IYieldRouterV2 r, bytes32 templateId, uint256 principalAmount)
internal
returns (uint256 received)
{
uint256 b0 = stakeToken.balanceOf(address(this));
r.withdrawScaled(templateId, principalAmount);
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant();
unchecked {
return b1 - b0; // Could be less than principalAmount!
}
}
Proposed fix
Add a minimum received amount check and consider incrementing the failure counter on shortfall:
function _balanceDeltaAfterWithdrawScaled(
    IYieldRouterV2 r, 
    bytes32 templateId, 
    uint256 principalAmount
) internal returns (uint256 received) {
    uint256 b0 = stakeToken.balanceOf(address(this));
    r.withdrawScaled(templateId, principalAmount);
    uint256 b1 = stakeToken.balanceOf(address(this));
    if (b1 < b0) revert YieldRouterBalanceInvariant();
    unchecked {
        received = b1 - b0;
    }
    // Check for principal shortfall (allow small rounding tolerance)
    if (received < principalAmount) {
        // Log shortfall and potentially increment failure counter
        emit YieldRouterPrincipalShortfall(templateId, principalAmount, received);
    }
    return received;
}
4

MarketTypes.sol
Epoch Struct is Extremely Large - Potential Gas Limit Issues on L2 and High Storage Costs
The `Epoch` struct in `MarketTypes` is extraordinarily large, containing: 4 `OracleCheckpoint` structs (each with int256 + uint128 + uint64 + bool = ~3 slots), 4 composite checkpoint arrays (4 * 4 = 16 more OracleCheckpoints), multiple fixed arrays (`outcomePools[8]`, `rangeBoundsE8[7]`, `velocityBoundsE4[7]`, `ladderBoundsE8[7]`, `ladderPayoutWeightsBps[8]`, `compositeFeedIds[4]`, `compositeConditions[4]`, `compositeAbsoluteThresholdsE8[4]`), plus dozens of scalar fields. Storing or reading a full `Epoch` struct could consume enormous amounts of gas, potentially hitting block gas limits on L2 networks or making epoch operations prohibitively expensive.


Hide Details
Impact
1. `getEpoch()` returning the full struct as memory copy could be extremely gas-intensive for callers. 2. Opening an epoch (writing the full struct to storage) could cost hundreds of thousands of gas. 3. On L2 networks with calldata costs, passing epoch data could be prohibitively expensive. 4. The `_setRemainingWinningStake` function iterates over `outcomePools` which requires reading multiple storage slots. 5. Epoch creation in rolling mode (which happens frequently) could hit gas limits.
Scenario
// Rough storage slot estimate for Epoch struct:
// Scalar fields: ~15 slots
// OracleCheckpoint x4 (checkpointA, checkpointB, checkpointA_B, checkpointB_B): ~12 slots
// compositeCheckpointsA[4] + compositeCheckpointsB[4]: ~24 slots
// outcomePools[8]: 8 slots
// rangeBoundsE8[7]: 7 slots
// velocityBoundsE4[7]: ~2 slots (packed)
// ladderBoundsE8[7]: 7 slots
// ladderPayoutWeightsBps[8]: ~1 slot (packed)
// compositeFeedIds[4]: 4 slots
// compositeAbsoluteThresholdsE8[4]: 4 slots
// Total: ~85+ storage slots per epoch
// At 20k gas per SSTORE: ~1.7M gas just for storage writes
Affected code
struct Epoch {
// ... 50+ fields including:
OracleCheckpoint[4] compositeCheckpointsA;
OracleCheckpoint[4] compositeCheckpointsB;
int256[RANGE_BOUNDS_LEN] rangeBoundsE8; // 7 slots
uint32[RANGE_BOUNDS_LEN] velocityBoundsE4;
int256[RANGE_BOUNDS_LEN] ladderBoundsE8; // 7 slots
uint16[MAX_OUTCOMES] ladderPayoutWeightsBps;
bytes32[4] compositeFeedIds;
int256[4] compositeAbsoluteThresholdsE8;
uint256[MAX_OUTCOMES] outcomePools; // 8 slots
// ... many more fields
}
Proposed fix
1. Split the `Epoch` struct into a core struct (always needed) and extension structs (market-type specific) using separate mappings.
2. Use lazy initialization - only write market-type-specific fields when the epoch is for that market type.
3. Consider using a separate mapping for composite oracle checkpoints.
// Split into core and extension
struct EpochCore {
    // Only the fields needed for all market types
    uint8 version;
    EpochStatus status;
    uint8 outcomeCount;
    MarketTiming timing;
    uint256 totalPool;
    uint256[MAX_OUTCOMES] outcomePools;
    // ... essential fields only
}

struct EpochCompositeExt {
    OracleCheckpoint[4] compositeCheckpointsA;
    OracleCheckpoint[4] compositeCheckpointsB;
    bytes32[4] compositeFeedIds;
    // ... composite-specific fields
}

mapping(bytes32 => mapping(uint64 => EpochCore)) internal _epochCores;
mapping(bytes32 => mapping(uint64 => EpochCompositeExt)) internal _epochCompositeExts;
5

MarketTypes.sol
validateCheckpointBPublishTime Monotonicity Check Only Against checkpointA, Not checkpointA_B
The `validateCheckpointBPublishTime` function checks monotonicity of checkpoint B's publishTime against `checkpointA.publishTime`. However, for Composite and Corridor market types that use a secondary oracle feed (tracked via `checkpointA_B` and `checkpointB_B`), there is no corresponding monotonicity check for the secondary feed's checkpoint B against its checkpoint A (`checkpointA_B`). This means the secondary oracle's checkpoint B could have a publishTime earlier than the secondary oracle's checkpoint A, creating temporal inconsistency in the oracle data used for settlement.


Hide Details
Impact
For Composite/Corridor markets using dual oracle feeds, the secondary feed's checkpoint B could use a price from before the secondary feed's checkpoint A. This creates a scenario where the 'resolve' price for the secondary feed is older than the 'lock' price, which is logically inconsistent and could lead to incorrect settlement outcomes. An informed actor who knows the oracle update schedule could exploit this to influence settlement.
Scenario
// Composite market with two feeds:
// Primary feed: checkpointA.publishTime = T, checkpointB.publishTime = T+1h (valid)
// Secondary feed: checkpointA_B.publishTime = T+30min
// Secondary feed: checkpointB_B.publishTime = T+15min (BEFORE checkpointA_B!)
// validateCheckpointBPublishTime only checks against checkpointA.publishTime (T)
// T+15min > T, so check passes
// But checkpointB_B is actually OLDER than checkpointA_B
// Settlement uses stale secondary oracle data
Affected code
function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
internal
view
returns (bool)
{
if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
// Missing: check against e.checkpointA_B.publishTime for secondary feed
return true;
}
Proposed fix
Extend the monotonicity check to cover secondary oracle checkpoints:
function validateCheckpointBPublishTime(
    Epoch storage e, 
    uint64 publishTime, 
    uint64 nowTs, 
    uint64 maxDelaySeconds
) internal view returns (bool) {
    if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
    if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
    return true;
}

// Add separate validation for secondary feed:
function validateCheckpointB_BPublishTime(
    Epoch storage e,
    uint64 publishTime,
    uint64 nowTs,
    uint64 maxDelaySeconds
) internal view returns (bool) {
    if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
    // Check monotonicity against secondary checkpoint A
    if (e.checkpointA_B.written && publishTime < e.checkpointA_B.publishTime) return false;
    return true;
}
6

MarketEngineState.sol
MAX_YIELD_ROUTER_FAILURES Counter Can Be Reset by Admin - Potential Abuse Vector
The `yieldRouterFailureCount` tracks consecutive yield router failures and auto-disables the router after `MAX_YIELD_ROUTER_FAILURES = 3`. However, the `YieldRouterFailureStateReset` event suggests there is an admin function to reset this counter. If an admin (or compromised admin) repeatedly resets the failure counter, a broken yield router could continue operating indefinitely, slowly draining principal through partial withdrawals. The failure counter is a safety mechanism that can be bypassed by the admin.


Hide Details
Impact
A compromised admin or a malicious admin could: (1) Allow a broken yield router to continue operating by resetting the failure counter after each failure, (2) Prevent the auto-disable mechanism from triggering, (3) Slowly drain user principal through a yield router that consistently returns less than deposited. The safety mechanism of auto-disabling after 3 failures is effectively nullified.
Scenario
// Attack scenario with compromised admin:
// 1. Yield router starts failing (returning less than principal)
// 2. failureCount reaches 3, router should be disabled
// 3. Admin calls resetYieldRouterFailureState() before disable triggers
// 4. failureCount reset to 0
// 5. Router continues operating, draining principal
// 6. Repeat indefinitely
Affected code
uint8 public yieldRouterFailureCount;
uint8 internal constant MAX_YIELD_ROUTER_FAILURES = 3;

// Event suggests admin can reset:
event YieldRouterFailureStateReset();
Proposed fix
1. Add a timelock on the failure state reset function.
2. Require the yield router to be replaced (not just reset) when failures occur.
3. Add a maximum number of resets before requiring governance approval.
4. Emit detailed events when the failure state is reset, including who reset it and when.
uint256 public lastFailureResetTimestamp;
uint256 public constant FAILURE_RESET_COOLDOWN = 7 days;
uint8 public totalFailureResets;
uint8 public constant MAX_FAILURE_RESETS = 3;

function resetYieldRouterFailureState() external onlyAdmin {
    require(block.timestamp >= lastFailureResetTimestamp + FAILURE_RESET_COOLDOWN, 'Reset cooldown active');
    require(totalFailureResets < MAX_FAILURE_RESETS, 'Max resets exceeded, replace router');
    yieldRouterFailureCount = 0;
    yieldRouterDisabled = false;
    lastFailureResetTimestamp = block.timestamp;
    totalFailureResets++;
    emit YieldRouterFailureStateReset();
}

low Severity
7
1

MarketEngineState.sol
Missing Zero-Address Validation for Critical Address Parameters
The `MarketEngineState` contract stores several critical address parameters (`admin`, `treasury`, `workerAuthority`, `stakeToken`, `priceOracle`, `yieldRouter`, etc.) but the auth helper functions only check `configInitialized` and `msg.sender`. There is no validation that these addresses are non-zero when set. If `treasury` is set to `address(0)`, fee withdrawals would burn fees. If `workerAuthority` is set to `address(0)`, anyone could call worker-restricted functions (since `msg.sender` can never be `address(0)` in normal execution, but this creates a logical gap). If `admin` is set to `address(0)` after initialization, the protocol becomes permanently locked.


Hide Details
Impact
1. If `workerAuthority` is set to `address(0)`, the `_authAdminOrWorker` check becomes `msg.sender != admin && msg.sender != address(0)`. Since `msg.sender` is never `address(0)`, this effectively means only admin can call worker functions - not a security issue but a functional regression. 2. If `treasury` is `address(0)`, fee transfers go to the zero address (burned). 3. If `admin` is transferred to `address(0)`, the protocol is permanently locked with no recovery path.
Scenario
// Scenario: Admin accidentally sets treasury to address(0)
// All fee withdrawals burn tokens instead of going to treasury
// No way to recover without admin intervention

// Scenario: Admin sets workerAuthority to address(0)
// Worker functions can only be called by admin
// Rolling mode operations require admin for every round
// Operational bottleneck
Affected code
function _authAdminOrWorker() internal view {
if (!configInitialized) revert NotInitialized();
if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
// No check: what if workerAuthority == address(0)?
}

function _authTreasuryOrAdmin() internal view {
if (!configInitialized) revert NotInitialized();
if (msg.sender != treasury && msg.sender != admin) revert Unauthorized();
// No check: what if treasury == address(0)?
}
Proposed fix
Add zero-address validation for all critical address assignments:
function _setAdmin(address newAdmin) internal {
    require(newAdmin != address(0), 'Admin cannot be zero address');
    admin = newAdmin;
}

function _setTreasury(address newTreasury) internal {
    require(newTreasury != address(0), 'Treasury cannot be zero address');
    treasury = newTreasury;
}

function _setWorkerAuthority(address newWorker) internal {
    // Allow address(0) to disable worker role, but document this
    workerAuthority = newWorker;
    emit WorkerAuthorityUpdated(workerAuthority, newWorker);
}
2

MarketEngineViewModule.sol
getEpoch Returns Zero-Value Struct for Non-Existent Epochs Without Indication
The `getEpoch` function in `MarketEngineViewModule` returns the full `Epoch` struct for any `(templateId, epochId)` pair, including non-existent epochs. For non-existent epochs, it returns a zero-value struct where all fields are zero/false/default. The `exists` field in the `Epoch` struct is `false` for non-existent epochs, but callers who don't check this field will receive misleading data. Off-chain systems or integrators that don't check `epoch.exists` could make incorrect decisions based on zero-value epoch data.


Hide Details
Impact
Off-chain integrators, bots, or other contracts that call `getEpoch` without checking `epoch.exists` will receive a zero-value struct that looks like a valid epoch with `status=Scheduled` (enum value 0), `outcomeCount=0`, all pools at 0, etc. This could cause: (1) incorrect UI displays showing phantom epochs, (2) bots attempting to interact with non-existent epochs, (3) downstream contracts making incorrect decisions based on false epoch data.
Scenario
// Off-chain integrator vulnerability:
// integrator.js
const epoch = await contract.getEpoch(templateId, 99999); // non-existent
console.log(epoch.status); // 0 = Scheduled (misleading!)
console.log(epoch.totalPool); // 0 (looks like empty epoch)
console.log(epoch.exists); // false (but integrator doesn't check this)
// Integrator incorrectly treats this as a scheduled epoch with no deposits
Affected code
function getEpoch(bytes32 templateId, uint64 epochId) external view returns (MarketTypes.Epoch memory) {
return _epochs[templateId][epochId];
}
Proposed fix
Add an explicit revert or return indicator for non-existent epochs:
function getEpoch(bytes32 templateId, uint64 epochId) 
    external 
    view 
    returns (MarketTypes.Epoch memory epoch, bool exists) 
{
    epoch = _epochs[templateId][epochId];
    exists = epoch.exists;
}

// Or alternatively, revert for non-existent epochs:
function getEpoch(bytes32 templateId, uint64 epochId) external view returns (MarketTypes.Epoch memory) {
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    if (!e.exists) revert EpochNotFound(templateId, epochId);
    return e;
}
3

MarketTypes.sol
Precision Loss in _mulBps for Small Values - Confidence Limit Calculation Underestimates
The `_mulBps` function in `MarketTypes` uses integer division that can lose precision for small values. The calculation `(q * bps) + ((r * bps) / BPS_DENOMINATOR)` where `q = value / 10000` and `r = value % 10000` loses the fractional part of `(r * bps) / 10000`. For the `confidenceLimitE8` function, this means the computed confidence limit can be slightly lower than the mathematically correct value. While `MIN_ABSOLUTE_CONFIDENCE_E8 = 10` provides a floor, for prices near this floor the rounding could cause valid oracle data to be rejected as having too-wide confidence intervals.


Hide Details
Impact
For small price values (e.g., a token priced at 0.0001 USD = 10000 in e8 format), the confidence limit calculation may round down, causing oracle data with valid confidence intervals to be rejected as `OracleConfidenceTooWide`. This could cause epoch lock/resolve to fail, triggering unnecessary cancellations or halts in rolling mode. The impact is limited by the `MIN_ABSOLUTE_CONFIDENCE_E8 = 10` floor but this floor is very small.
Scenario
// Example precision loss:
// price = 100 (e8), maxConfidenceBps = 50 (0.5%)
// Expected: 100 * 50 / 10000 = 0.5 -> rounds to 0
// _mulBps: q = 100/10000 = 0, r = 100
// result = 0 + (100 * 50 / 10000) = 5000/10000 = 0
// Actual confidence limit = 0, but MIN_ABSOLUTE_CONFIDENCE_E8 = 10 saves it
// However: price = 200, maxConfidenceBps = 50
// Expected: 200 * 50 / 10000 = 1
// _mulBps: q = 0, r = 200, result = (200*50)/10000 = 10000/10000 = 1 (OK)
// Edge case: price = 199, maxConfidenceBps = 50
// result = (199*50)/10000 = 9950/10000 = 0 (rounds down to 0!)
// Falls back to MIN_ABSOLUTE_CONFIDENCE_E8 = 10
Affected code
function _mulBps(uint256 value, uint16 bps) private pure returns (uint256) {
uint256 q = value / BPS_DENOMINATOR;
uint256 r = value % BPS_DENOMINATOR;
return (q * uint256(bps)) + ((r * uint256(bps)) / BPS_DENOMINATOR);
}

function confidenceLimitE8(int256 priceE8, uint16 maxConfidenceBps, uint256 minAbsoluteConfidenceE8)
internal
pure
returns (uint256)
{
...
uint256 relativeLimit = _mulBps(absPriceE8, maxConfidenceBps);
return relativeLimit > minAbsoluteConfidenceE8 ? relativeLimit : minAbsoluteConfidenceE8;
}
Proposed fix
Use a simpler and more precise multiplication approach:
function _mulBps(uint256 value, uint16 bps) private pure returns (uint256) {
    // Direct multiplication is safe for uint256 values within reasonable bounds
    // value * bps <= type(uint256).max for any realistic price (e8) and bps <= 10000
    return (value * uint256(bps)) / BPS_DENOMINATOR;
}
This is simpler, equally precise (same rounding behavior), and avoids the unnecessary split calculation. The original implementation was likely intended to prevent overflow, but `value * bps` for e8 prices and bps <= 10000 is well within uint256 range.
4

MarketEngineViewModule.sol
getUserEpochs Pagination Returns Incorrect nextCursor When size=0
In `getUserEpochs`, when `size=0` is passed, `boundedSize` is set to 0 (since 0 < MAX_USER_EPOCHS_PAGE_SIZE). Then `end = cursor + 0 = cursor`, `outLen = cursor - cursor = 0`, and `nextCursor = cursor`. The function returns an empty array with `nextCursor = cursor`, which is the same as the input cursor. This creates an infinite loop for any caller that uses `nextCursor` to paginate: they will keep calling with the same cursor and getting empty results, never advancing. While `size=0` is arguably invalid input, it should be handled gracefully.


Hide Details
Impact
Off-chain callers passing `size=0` will receive `nextCursor = cursor`, creating an infinite pagination loop. While this is a caller error, it could cause off-chain systems to hang or consume excessive resources. Additionally, the lack of input validation for `size=0` is inconsistent with the `_validateBatchSize` pattern used elsewhere in the contract.
Scenario
// Off-chain pagination loop that hangs:
let cursor = 0;
while (true) {
const [epochs, nextCursor] = await contract.getUserEpochs(templateId, user, cursor, 0);
if (epochs.length === 0) break; // Never breaks because nextCursor == cursor
cursor = nextCursor;
}
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
uint256 end = cursor + boundedSize;
if (end > n) end = n;
uint256 outLen = end - cursor;
epochIds = new uint64[](outLen);
for (uint256 i = 0; i < outLen; i++) {
epochIds[i] = src[cursor + i];
}
nextCursor = end;
}
Proposed fix
Add input validation for the `size` parameter:
function getUserEpochs(bytes32 templateId, address user, uint256 cursor, uint256 size)
    external
    view
    returns (uint64[] memory epochIds, uint256 nextCursor)
{
    require(size > 0, 'Size must be positive'); // Add this check
    uint64[] storage src = _userEpochs[templateId][user];
    uint256 n = src.length;
    if (cursor >= n) return (new uint64[](0), cursor);
    uint256 boundedSize = size > MAX_USER_EPOCHS_PAGE_SIZE ? MAX_USER_EPOCHS_PAGE_SIZE : size;
    uint256 end = cursor + boundedSize;
    if (end > n) end = n;
    uint256 outLen = end - cursor;
    epochIds = new uint64[](outLen);
    for (uint256 i = 0; i < outLen; i++) {
        epochIds[i] = src[cursor + i];
    }
    nextCursor = end;
}
5

MarketEngineState.sol
templateIdFromSlug Allows Slug Collision - Different Slugs Can Produce Same templateId
The `templateIdFromSlug` function uses `keccak256(bytes(slug))` to derive template IDs. While keccak256 is collision-resistant in practice, the function does not enforce uniqueness of slugs at the contract level. More importantly, there is no validation of slug length or content in this function. The `SLUG_MAX_LEN = 32` constant exists in `MarketTypes` but is not enforced in `templateIdFromSlug`. An admin could create two templates with different slugs that happen to produce the same `templateId` (extremely unlikely but theoretically possible), or more practically, could create a template with an empty slug (`keccak256('')`) which would be a valid but confusing template ID.


Hide Details
Impact
1. Empty slug creates a valid but confusing template ID (`keccak256('')`). 2. No enforcement of `SLUG_MAX_LEN = 32` means slugs can be arbitrarily long, wasting gas. 3. If slug validation is done off-chain but not on-chain, an admin could accidentally create templates with invalid slugs that are hard to identify. 4. The lack of a slug registry means the same slug could be 'registered' multiple times (though they'd map to the same templateId, the second upsert would overwrite the first).
Scenario
// Empty slug creates valid templateId:
bytes32 emptySlugId = templateIdFromSlug(''); // = keccak256('')
// This is a valid templateId that could be used to create a template
// But it's confusing and hard to identify

// Very long slug wastes gas:
string memory longSlug = 'a'.repeat(10000);
bytes32 id = templateIdFromSlug(longSlug); // Valid but expensive
Affected code
function templateIdFromSlug(string memory slug) public pure returns (bytes32) {
return keccak256(bytes(slug));
}
Proposed fix
Add slug validation in the template creation function (not just in `templateIdFromSlug` since it's a pure view function):
function templateIdFromSlug(string memory slug) public pure returns (bytes32) {
    return keccak256(bytes(slug));
}

// In template upsert function, add validation:
function _validateSlug(string memory slug) internal pure {
    bytes memory slugBytes = bytes(slug);
    require(slugBytes.length > 0, 'Empty slug');
    require(slugBytes.length <= MarketTypes.SLUG_MAX_LEN, 'Slug too long');
    // Optionally: validate characters are alphanumeric/hyphen only
}
6

MarketTypes.sol
Epoch totalPool Not Validated Against Sum of outcomePools - Accounting Invariant Not Enforced
The `Epoch` struct maintains both `totalPool` (total stake across all outcomes) and `outcomePools[MAX_OUTCOMES]` (per-outcome stake). These two values should always satisfy `totalPool == sum(outcomePools)`. However, there is no on-chain enforcement of this invariant. If any module incorrectly updates one without the other (e.g., updates `outcomePools[i]` but forgets to update `totalPool`), the accounting will silently diverge. The `_applyResolveAccounting` function uses `outputs.claimLiabilityTotal` from `SettlementLogic` which presumably uses `outcomePools`, but `totalPool` is used elsewhere for display and potentially for other calculations.


Hide Details
Impact
If `totalPool` diverges from `sum(outcomePools)`, it could cause: (1) Incorrect fee calculations if fees are based on `totalPool`, (2) Misleading data for off-chain systems that use `totalPool` for display, (3) Potential for exploiting the discrepancy if any settlement logic uses `totalPool` directly instead of summing `outcomePools`. The risk is amplified by the modular architecture where multiple modules can modify epoch state.
Scenario
// Hypothetical buggy module:
function buggyDeposit(bytes32 templateId, uint64 epochId, uint8 outcome, uint256 amount) external {
MarketTypes.Epoch storage e = _epochs[templateId][epochId];
e.outcomePools[outcome] += amount; // Updates outcome pool
// BUG: Forgot to update e.totalPool += amount;
// Now totalPool < sum(outcomePools)
// Settlement calculations using totalPool will be incorrect
}
Affected code
struct Epoch {
...
uint256 totalPool; // Should equal sum of outcomePools
uint256[MAX_OUTCOMES] outcomePools; // Per-outcome stakes
...
}
Proposed fix
Add an invariant check function and use it in critical paths:
function _validateEpochPoolInvariant(bytes32 templateId, uint64 epochId) internal view {
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    uint256 poolSum = 0;
    for (uint256 i = 0; i < e.outcomeCount; i++) {
        poolSum += e.outcomePools[i];
    }
    require(poolSum == e.totalPool, 'Pool invariant violated');
}

// Or use a helper that updates both atomically:
function _addToOutcomePool(
    MarketTypes.Epoch storage e, 
    uint8 outcome, 
    uint256 amount
) internal {
    e.outcomePools[outcome] += amount;
    e.totalPool += amount;  // Always update together
}
7

MarketEngineState.sol
Missing Event for Admin Transfer - Critical State Change Not Logged
The `MarketEngineState` contract defines events for `WorkerAuthorityUpdated` and `TreasuryUpdated` but there is no corresponding event for admin address changes. The `admin` address is the most privileged role in the protocol, and any change to it should be logged for transparency and monitoring. Without an event, off-chain monitoring systems cannot detect admin transfers, making it impossible to alert on potential admin key compromises or unauthorized transfers.


Hide Details
Impact
1. No on-chain audit trail for admin transfers. 2. Off-chain monitoring systems cannot detect admin key changes. 3. If admin is transferred to a malicious address, there is no event to trigger alerts. 4. Inconsistent event coverage compared to other privileged roles (worker, treasury both have events).
Affected code
address public admin;
// Events defined:
event WorkerAuthorityUpdated(address indexed previousWorker, address indexed newWorker);
event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
// Missing: event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
Proposed fix
Add an admin transfer event and emit it whenever admin changes:
event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

// In the admin transfer function (wherever it's implemented in the dispatcher):
function transferAdmin(address newAdmin) external onlyAdmin {
    require(newAdmin != address(0), 'New admin cannot be zero address');
    address previousAdmin = admin;
    admin = newAdmin;
    emit AdminTransferred(previousAdmin, newAdmin);
}

// Consider two-step transfer for extra safety:
address public pendingAdmin;

function proposeAdmin(address newAdmin) external onlyAdmin {
    pendingAdmin = newAdmin;
    emit AdminProposed(admin, newAdmin);
}

function acceptAdmin() external {
    require(msg.sender == pendingAdmin, 'Not pending admin');
    emit AdminTransferred(admin, pendingAdmin);
    admin = pendingAdmin;
    pendingAdmin = address(0);
}

gas Severity
2
1

MarketEngineState.sol
Gas Optimization: Redundant Storage Reads in _applyResolveAccounting
The `_applyResolveAccounting` function reads `_vaults[templateId].active` multiple times from storage: once for the invariant check, once for the claimLiabilityTotal deduction, and once for the settlementFeeTotal deduction. Each storage read costs 2100 gas (cold) or 100 gas (warm). Caching the vault in a local storage pointer or memory variable would reduce gas costs.


Hide Details
Impact
Unnecessary gas costs for epoch resolution transactions. Each redundant storage read costs 100 gas (warm slot). With 6 reads that could be reduced to 1 storage pointer assignment, this saves approximately 500 gas per epoch resolution.
Affected code
function _applyResolveAccounting(...) internal {
uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
if (_vaults[templateId].active < totalDeduction) { // Read 1
revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction); // Read 2
}
if (outputs.claimLiabilityTotal > 0) {
_vaults[templateId].active -= outputs.claimLiabilityTotal; // Read 3 + Write
_vaults[templateId].claims += outputs.claimLiabilityTotal; // Read 4 + Write
...
}
if (outputs.settlementFeeTotal > 0) {
_vaults[templateId].active -= outputs.settlementFeeTotal; // Read 5 + Write
_vaults[templateId].fees += outputs.settlementFeeTotal; // Read 6 + Write
...
}
}
Proposed fix
Cache the vault storage pointer:
function _applyResolveAccounting(...) internal {
    MarketTypes.VaultBalances storage vault = _vaults[templateId]; // Single storage pointer
    uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
    if (vault.active < totalDeduction) {
        revert VaultInsufficientActive(templateId, vault.active, totalDeduction);
    }
    if (outputs.claimLiabilityTotal > 0) {
        vault.active -= outputs.claimLiabilityTotal;
        vault.claims += outputs.claimLiabilityTotal;
        MarketMath.reserveClaimsFromActive(ledger, outputs.claimLiabilityTotal);
    }
    if (outputs.settlementFeeTotal > 0) {
        vault.active -= outputs.settlementFeeTotal;
        vault.fees += outputs.settlementFeeTotal;
        MarketMath.reserveFeesFromActive(ledger, outputs.settlementFeeTotal);
    }
    // ... rest of function
}
2

MarketEngineState.sol
Gas Optimization: _setRemainingWinningStake Iterates Full outcomeCount Even for Single-Winner Markets
The `_setRemainingWinningStake` function iterates over all `outcomeCount` outcomes (up to 8) to sum winning pools. For markets with a single winning outcome (Direction, Threshold), this loop always iterates the full count even though only one outcome will match. A short-circuit optimization could save gas for the common case.


Hide Details
Impact
Minor gas inefficiency. For 2-outcome markets (most common case), the loop always runs twice. For 8-outcome markets, it runs 8 times. The savings are small (each iteration is a storage read + bit operation) but accumulate over many epoch resolutions.
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
Add early exit when all winning outcomes have been found:
function _setRemainingWinningStake(bytes32 templateId, uint64 epochId, bool refundMode) internal {
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    if (refundMode) {
        e.remainingWinningStake = 0;
        return;
    }
    uint256 sum = 0;
    uint8 n = e.outcomeCount;
    uint256 mask = e.winningOutcomeMask;
    // Use popcount to know how many winners to find
    for (uint256 i = 0; i < uint256(n) && mask != 0; i++) {
        if ((mask & 1) != 0) {
            sum += e.outcomePools[i];
            mask >>= 1;
            if (mask == 0) break; // No more winners
        } else {
            mask >>= 1;
        }
    }
    e.remainingWinningStake = sum;
}

informational Severity
1
1

MarketEngineState.sol
Insufficient Gap Size May Be Inadequate for Future Upgrades
The `__gap[41]` storage gap in `MarketEngineState` is intended to reserve space for future state variables in upgrades. However, the gap size of 41 slots may be insufficient given the current storage layout already uses approximately 20+ slots for declared variables. More critically, the gap is placed AFTER the `selectorImmutable` mapping, meaning any new state variables added to `MarketEngineState` in an upgrade would consume from the gap. But if modules also inherit `MarketEngineState` and are upgraded independently, the gap calculation must account for both the proxy's and modules' storage needs. The comment says 'append-only' but doesn't specify how many slots are available.


Hide Details
Impact
If future upgrades require more than 41 additional state variables (unlikely but possible for a complex protocol), the gap will be exhausted and new variables will collide with storage slots used by other contracts or mappings. Additionally, if the gap size was calculated incorrectly (e.g., not accounting for all current variables), existing storage could already be at risk.
Scenario
// Storage slot audit:
// Slot 0: stakeToken (address, 20 bytes)
// Slot 1: priceOracle
// Slot 2: rateOracle
// Slot 3: smartDataOracle
// Slot 4: macroOracle
// Slot 5: equityOracle
// Slot 6: configInitialized(bool) + admin(address) packed
// Slot 7: treasury(address) + workerAuthority(address) - may span 2 slots
// ... etc.
// Mappings don't consume sequential slots but their slot numbers matter
// Total declared variables: ~20 slots
// Gap: 41 slots
// Total reserved: ~61 slots
// This seems adequate but should be formally verified
Affected code
// --- dispatcher state (appended after legacy state) ---
mapping(bytes4 selector => address module) internal selectorToModule;
mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

uint256[41] private __gap;
Proposed fix
1. Document the exact storage slot layout with slot numbers for each variable.
2. Add a storage layout test that verifies slot assignments don't change between versions.
3. Consider increasing the gap to 100 slots for more headroom.
4. Use `forge inspect` to generate and version-control the storage layout.
// Increase gap for safety
uint256[100] private __gap; // was 41, increased to 100

// Add storage layout documentation comment:
// Slot 0: stakeToken
// Slot 1: priceOracle
// ... (document all slots)
// Slot N: __gap[0] through __gap[99]