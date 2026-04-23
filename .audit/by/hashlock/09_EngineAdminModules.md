DeFi Prediction Market / Structured Betting Protocol

This is a sophisticated prediction market / structured betting protocol called 'RetroPick MarketEngine'. It operates as a UUPS upgradeable proxy system using a dispatcher/module pattern where logic is split across multiple delegatecall modules. The system allows users to stake tokens on outcomes of various market types (Direction, Threshold, Range, Velocity, Ladder, Convergence, Composite, Corridor, Cascade), with oracle-driven resolution. It supports both manual epoch lifecycle management and rolling (automated pipeline) mode. The protocol integrates with yield routers (Aave/ERC4626) to generate yield on staked collateral during active epochs, and uses multiple oracle adapters (Chainlink price, rate, smart data, macro, equity feeds) for settlement.

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
IPriceOracle (priceOracle, rateOracle, smartDataOracle, macroOracle, equityOracle)
3
IYieldRouterV2 (yieldRouter)
4
OpenZeppelin SafeERC20

External Systems
1
Chainlink Oracle Network
2
Aave / ERC4626 Yield Vaults
3
UUPS Proxy / Dispatcher

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


high Severity
3
1

MarketEngineState.sol
Delegatecall Module Storage Compatibility Check is Insufficient - Only Verifies Selector Not Layout
The `marketEngineStorageCompatibility()` function returns a constant `MODULE_STORAGE_COMPATIBILITY_ID` that the dispatcher uses to verify module compatibility. However, as explicitly documented in the code: 'it only proves the module implements this selector with the expected constant, not that bytecode matches `MarketEngineState` storage.' Any contract can implement this function returning the correct constant without actually having the correct storage layout. A malicious or incorrectly implemented module that adds state variables before the inherited `MarketEngineState` layout would pass the compatibility check but corrupt all storage slots when called via delegatecall. The `__gap` array of 41 slots provides some upgrade buffer but doesn't protect against modules with incorrect layouts.


Hide Details
Impact
A module with incorrect storage layout (e.g., an extra state variable declared before inheriting MarketEngineState) would pass the compatibility check but corrupt the proxy's storage when called via delegatecall. This could overwrite critical variables like `admin`, `stakeToken`, `treasury`, or `configInitialized`, leading to complete protocol compromise, fund theft, or permanent DoS. The code hash allowlisting in the dispatcher provides the primary protection, but this is an operational/governance risk rather than an on-chain guarantee.
Scenario
1. Developer creates a new module `MaliciousModule` that inherits `MarketEngineState` but adds a state variable before the inherited layout:
contract MaliciousModule is MarketEngineState {
    address private extraVar; // This shifts ALL inherited storage slots by 1!
    
    function marketEngineStorageCompatibility() external pure returns (bytes32) {
        return MODULE_STORAGE_COMPATIBILITY_ID; // Passes the check!
    }
    
    function doSomething() external {
        // Any storage write here corrupts the proxy's state
        admin = msg.sender; // Actually writes to stakeToken slot!
    }
}
2. Module passes the compatibility check.
3. If code hash is allowlisted (by mistake or malicious admin), delegatecall corrupts storage.
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
Consider implementing EIP-7201 namespaced storage to eliminate storage collision risk entirely:
// Use a unique storage slot for all state
bytes32 private constant STORAGE_SLOT = keccak256('retropick.marketengine.state.v1') - 1;

struct EngineStorage {
    IERC20 stakeToken;
    address admin;
    // ... all state variables
}

function _storage() internal pure returns (EngineStorage storage s) {
    bytes32 slot = STORAGE_SLOT;
    assembly { s.slot := slot }
}
Alternatively, add automated storage layout verification in CI/CD using tools like `hardhat-storage-layout` or OpenZeppelin's storage layout checker. Document the exact expected storage layout hash and verify it on-chain during module registration.
2

MarketEngineAdminModule.sol
Reentrancy in withdrawFees via ERC20 safeTransfer Before State Update
In `MarketEngineAdminModule.withdrawFees`, the `stakeToken.safeTransfer(treasury, amount)` call is made BEFORE the ledger and vault state updates (`MarketMath.releaseFeeOnWithdraw` and `_vaults[templateId].fees -= amount`). This violates the checks-effects-interactions pattern. If the `stakeToken` is an ERC777 token or any token with transfer hooks (e.g., a token that calls a receiver hook on the treasury address), the treasury contract could reenter `withdrawFees` before the ledger state is updated, allowing double-withdrawal of fees. Since `ledger.feeReserveTotal` is only decremented after the transfer, a reentrant call would pass the `ledger.feeReserveTotal < amount` check again with the original (un-decremented) value.


Hide Details
Impact
If the stakeToken supports transfer hooks (ERC777, ERC1363, or similar), the treasury address could reenter `withdrawFees` before the ledger state is updated, draining the entire fee reserve multiple times. This could result in complete loss of accumulated protocol fees and potentially underflow the vault/ledger accounting, corrupting protocol state.
Scenario
1. Admin sets treasury to a malicious contract `MaliciousTreasury`.
2. Protocol accumulates fees in `feeReserveTotal` for a templateId.
3. `MaliciousTreasury` calls `withdrawFees(templateId, amount)`.
4. `stakeToken.safeTransfer(treasury, amount)` triggers `MaliciousTreasury.tokensReceived()` (ERC777 hook).
5. Inside the hook, `MaliciousTreasury` calls `withdrawFees(templateId, amount)` again.
6. Since `ledger.feeReserveTotal` hasn't been decremented yet, the check passes.
7. Funds are transferred again before state is updated.
8. This repeats until the contract is drained.
contract MaliciousTreasury {
    address engine;
    bytes32 templateId;
    uint256 amount;
    bool attacking;
    
    function tokensReceived(...) external {
        if (!attacking) {
            attacking = true;
            IMarketEngine(engine).withdrawFees(templateId, amount);
        }
    }
}
Affected code
function withdrawFees(bytes32 templateId, uint256 amount) external {
_authTreasuryOrAdmin();
if (amount == 0) revert NothingToClaim();
MarketTypes.Ledger storage ledger = _ledgers[templateId];
if (!ledger.initialized) revert InvalidTemplate();
if (ledger.feeReserveTotal < amount) revert NothingToClaim();

stakeToken.safeTransfer(treasury, amount); // <-- external call BEFORE state update
MarketMath.releaseFeeOnWithdraw(ledger, amount); // <-- state update AFTER
_vaults[templateId].fees -= amount; // <-- state update AFTER
emit FeesWithdrawn(templateId, amount);
}
Proposed fix
Apply the checks-effects-interactions pattern by updating state before making external calls:
function withdrawFees(bytes32 templateId, uint256 amount) external {
    _authTreasuryOrAdmin();
    if (amount == 0) revert NothingToClaim();
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    if (ledger.feeReserveTotal < amount) revert NothingToClaim();

    // Effects before interactions
    MarketMath.releaseFeeOnWithdraw(ledger, amount);
    _vaults[templateId].fees -= amount;
    emit FeesWithdrawn(templateId, amount);
    
    // Interaction last
    stakeToken.safeTransfer(treasury, amount);
}
Additionally, consider adding a `nonReentrant` modifier to all external state-changing functions.
3

MarketEngineAdminModule.sol
Centralized Admin Can Redirect Fee Withdrawals to Arbitrary Treasury Address
The `withdrawFees` function transfers fees to the `treasury` address, which can be changed by the admin at any time via `setTreasury`. There is no timelock or delay on treasury changes. An admin (or compromised admin key) could: (1) change the treasury to an attacker-controlled address, (2) immediately call `withdrawFees` to drain all accumulated fees to the attacker's address. Since `withdrawFees` is callable by both `treasury` and `admin`, and `setTreasury` is callable by `admin`, the admin has unilateral control over where fees go. This is a centralization risk that could be exploited if the admin key is compromised.


Hide Details
Impact
A compromised admin key can redirect all accumulated protocol fees to an attacker-controlled address in a single atomic operation (setTreasury + withdrawFees). This could result in complete loss of all accumulated settlement fees across all templates. Given that fees accumulate over time and could represent significant value, this is a meaningful financial risk.
Scenario
1. Attacker compromises admin private key.
2. Attacker calls `setTreasury(attackerAddress)`.
3. Attacker calls `withdrawFees(templateId, ledger.feeReserveTotal)` for each template.
4. All accumulated fees are transferred to attacker's address.
5. Total loss: sum of all `feeReserveTotal` across all templates.
Affected code
function setTreasury(address t) external {
_authAdmin();
if (t == address(0)) revert InvalidAuthority();
address prev = treasury;
treasury = t;
emit TreasuryUpdated(prev, t);
}

function withdrawFees(bytes32 templateId, uint256 amount) external {
_authTreasuryOrAdmin();
// ...
stakeToken.safeTransfer(treasury, amount); // Transfers to current treasury
// ...
}
Proposed fix
Implement a timelock for treasury changes and/or require a two-step treasury transfer process:
address public pendingTreasury;
uint256 public treasuryChangeTimestamp;
uint256 public constant TREASURY_CHANGE_DELAY = 2 days;

function proposeTreasuryChange(address t) external {
    _authAdmin();
    if (t == address(0)) revert InvalidAuthority();
    pendingTreasury = t;
    treasuryChangeTimestamp = block.timestamp + TREASURY_CHANGE_DELAY;
    emit TreasuryChangeProposed(t, treasuryChangeTimestamp);
}

function acceptTreasuryChange() external {
    _authAdmin();
    require(block.timestamp >= treasuryChangeTimestamp, "Timelock not expired");
    address prev = treasury;
    treasury = pendingTreasury;
    pendingTreasury = address(0);
    emit TreasuryUpdated(prev, treasury);
}
Alternatively, use a multi-sig for the admin role and implement governance controls for treasury changes.

medium Severity
4
1

MarketEngineAdminModule.sol
Unchecked Return Value from emergencyWithdraw Allows Silent Fund Loss
In `yieldEmergencyWithdraw`, the return value of `r.emergencyWithdraw(templateId)` is explicitly ignored with a `slither-disable-next-line unused-return` comment. The comment states 'gross underlying is transferred to engine by router; no local use.' However, this assumption is unverified on-chain. If the yield router's `emergencyWithdraw` fails silently (returns false or a zero amount), or if the router has a bug where it doesn't actually transfer tokens back, the protocol will believe the emergency withdrawal succeeded when it didn't. Unlike `_balanceDeltaAfterWithdrawScaled` which uses balance delta verification, `yieldEmergencyWithdraw` has no such safety net. This is particularly dangerous in emergency scenarios where the yield router may be in a degraded state.


Hide Details
Impact
In an emergency scenario (e.g., yield router exploit, Aave liquidity crisis), the admin calls `yieldEmergencyWithdraw` expecting to recover user funds. If the call fails silently, the protocol believes funds are recovered but they remain stuck in the yield router. Users cannot claim their funds, leading to permanent loss of user deposits. This is especially critical because emergency withdrawals are typically triggered when something is already wrong.
Scenario
1. Yield router is deployed with a bug where `emergencyWithdraw` emits an event but doesn't transfer tokens.
2. Aave/ERC4626 vault becomes illiquid or paused.
3. Admin calls `yieldEmergencyWithdraw(templateId)` to recover funds.
4. `r.emergencyWithdraw(templateId)` executes but tokens are not transferred back.
5. Transaction succeeds (no revert).
6. Protocol believes funds are recovered.
7. Users attempt to claim but the contract has insufficient balance.
8. All claims fail, user funds are permanently lost in the yield router.
Affected code
function yieldEmergencyWithdraw(bytes32 templateId) external {
_authAdmin();
IYieldRouterV2 r = yieldRouter;
if (address(r) == address(0)) revert Unauthorized();
// slither-disable-next-line unused-return -- gross underlying is transferred to engine by router; no local use.
r.emergencyWithdraw(templateId);
}
Proposed fix
Use the balance delta pattern to verify actual funds received, similar to `_balanceDeltaAfterWithdrawScaled`:
function yieldEmergencyWithdraw(bytes32 templateId) external {
    _authAdmin();
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0)) revert Unauthorized();
    
    uint256 b0 = stakeToken.balanceOf(address(this));
    r.emergencyWithdraw(templateId);
    uint256 b1 = stakeToken.balanceOf(address(this));
    
    // Optionally: update vault accounting with recovered amount
    // uint256 recovered = b1 - b0; // safe since b1 >= b0 is expected
    // emit EmergencyWithdrawCompleted(templateId, recovered);
}
Alternatively, at minimum add an event emission with the recovered amount for off-chain monitoring.
2

MarketEngineAdminModule.sol
Vault Fees Balance Can Underflow Silently if Ledger and Vault Diverge in withdrawFees
In `withdrawFees`, the function checks `ledger.feeReserveTotal < amount` but then decrements `_vaults[templateId].fees -= amount` without checking if `_vaults[templateId].fees >= amount`. While Solidity 0.8.x has built-in overflow/underflow protection (causing a revert), the real issue is that `ledger.feeReserveTotal` and `_vaults[templateId].fees` are maintained as two separate accounting variables that should always be in sync. If any code path updates one without the other (e.g., a bug in another module, or the yield router accrual logic), these values can diverge. In that case, `withdrawFees` could pass the ledger check but revert on the vault subtraction, or vice versa, creating a permanent DoS on fee withdrawal. More critically, if `_vaults[templateId].fees` is somehow larger than `ledger.feeReserveTotal` (e.g., due to yield accrual being credited to fees vault but not ledger), excess fees could be withdrawn beyond what the ledger tracks.


Hide Details
Impact
If `ledger.feeReserveTotal` and `_vaults[templateId].fees` diverge, fee withdrawal could be permanently DoS'd (if vault.fees < ledger.feeReserveTotal) or could allow withdrawal of more tokens than properly accounted for (if vault.fees > ledger.feeReserveTotal). In the worst case, this could drain tokens that belong to user claims or active collateral.
Scenario
1. Suppose a bug in another module credits yield to `_vaults[templateId].fees` without updating `ledger.feeReserveTotal`.
2. `_vaults[templateId].fees = 1000`, `ledger.feeReserveTotal = 500`.
3. Admin calls `withdrawFees(templateId, 800)`.
4. Check `ledger.feeReserveTotal (500) < 800` → reverts with NothingToClaim.
5. But 800 tokens are actually available in vault.fees.
6. Fee withdrawal is permanently stuck at max 500 even though 1000 is available.

Alternatively:
7. `_vaults[templateId].fees = 500`, `ledger.feeReserveTotal = 1000`.
8. Admin calls `withdrawFees(templateId, 800)`.
9. Ledger check passes (1000 >= 800).
10. Transfer succeeds.
11. `_vaults[templateId].fees -= 800` → underflow revert (500 < 800).
12. Transaction reverts, but ledger was already updated if transfer happened first.
Affected code
function withdrawFees(bytes32 templateId, uint256 amount) external {
_authTreasuryOrAdmin();
if (amount == 0) revert NothingToClaim();
MarketTypes.Ledger storage ledger = _ledgers[templateId];
if (!ledger.initialized) revert InvalidTemplate();
if (ledger.feeReserveTotal < amount) revert NothingToClaim();

stakeToken.safeTransfer(treasury, amount);
MarketMath.releaseFeeOnWithdraw(ledger, amount);
_vaults[templateId].fees -= amount; // No prior check that vault.fees >= amount
emit FeesWithdrawn(templateId, amount);
}
Proposed fix
Add an explicit check that `_vaults[templateId].fees >= amount` before withdrawal, and consider adding an invariant assertion:
function withdrawFees(bytes32 templateId, uint256 amount) external {
    _authTreasuryOrAdmin();
    if (amount == 0) revert NothingToClaim();
    MarketTypes.Ledger storage ledger = _ledgers[templateId];
    if (!ledger.initialized) revert InvalidTemplate();
    if (ledger.feeReserveTotal < amount) revert NothingToClaim();
    // Dual-source check to catch accounting divergence
    if (_vaults[templateId].fees < amount) revert NothingToClaim();
    
    // Effects before interactions
    MarketMath.releaseFeeOnWithdraw(ledger, amount);
    _vaults[templateId].fees -= amount;
    emit FeesWithdrawn(templateId, amount);
    
    stakeToken.safeTransfer(treasury, amount);
}
Also consider consolidating fee tracking into a single source of truth to eliminate the dual-accounting risk.
3

MarketEngineState.sol
Missing Validation That priceOracle is Non-Zero in _resolveOracleByClass for CHAINLINK_PRICE
In `_resolveOracleByClass`, all oracle classes except `CHAINLINK_PRICE` (the default/fallback) check that the oracle address is non-zero before returning it. For `CHAINLINK_PRICE`, the function falls through to `return priceOracle` without any zero-address check. If `priceOracle` is not initialized (zero address), the function returns `address(0)` cast as `IPriceOracle`. Any subsequent call to this oracle (e.g., `priceOracle.getPrice(feedId)`) would call address(0), which in Solidity returns success with empty data (low-level call to non-existent contract succeeds). This could cause silent oracle failures or incorrect price data being used for settlement.


Hide Details
Impact
If `priceOracle` is uninitialized (zero address), markets using `CHAINLINK_PRICE` oracle class will receive a zero-address oracle. Depending on how the oracle interface is called, this could result in: (1) silent failure returning default/zero values used for settlement, (2) incorrect market resolution based on zero price data, or (3) unexpected reverts in oracle-dependent functions. This is particularly dangerous for settlement operations where incorrect oracle data leads to wrong winners being paid.
Scenario
1. Protocol is deployed but `priceOracle` is not set (zero address) due to initialization oversight.
2. A template with `oracleClass = CHAINLINK_PRICE` is created and an epoch is opened.
3. Worker calls `lockEpoch` which calls `_resolveOracle(templateId)` → `_resolveOracleByClass(CHAINLINK_PRICE)`.
4. Returns `IPriceOracle(address(0))`.
5. Subsequent call to `priceOracle.getPrice(feedId)` calls address(0).
6. EVM returns success with empty returndata.
7. ABI decoding of empty data may return zero values or revert depending on implementation.
8. If zero price is used, settlement may be incorrect.
Affected code
function _resolveOracleByClass(MarketTypes.OracleClass oracleClass) internal view returns (IPriceOracle) {
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_RATE) {
if (address(rateOracle) == address(0)) revert OracleAdapterNotConfigured();
return rateOracle;
}
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_SMARTDATA) {
if (address(smartDataOracle) == address(0)) revert OracleAdapterNotConfigured();
return smartDataOracle;
}
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_MACRO) {
if (address(macroOracle) == address(0)) revert OracleAdapterNotConfigured();
return macroOracle;
}
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_EQUITY) {
if (address(equityOracle) == address(0)) revert OracleAdapterNotConfigured();
return equityOracle;
}
return priceOracle; // No zero-address check!
}
Proposed fix
Add a zero-address check for the default `priceOracle` case:

```solidity
function _resolveOracleByClass(MarketTypes.OracleClass oracleClass) internal view returns (IPriceOracle) {
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_RATE) {
if (address(rateOracle) == address(0)) revert OracleAdapterNotConfigured();
return rateOracle;
}
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_SMARTDATA) {
if (address(smartDataOracle) == address(0)) revert OracleAdapterNotConfigured();
return smartDataOracle;
}
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_MACRO) {
if (address(macroOracle) == address(0)) revert OracleAdapterNotConfigured();
return macroOracle;
}
if (oracleClass == MarketTypes.OracleClass.CHAINLINK_EQUITY) {
if (address(equityOracle) == address(0)) revert OracleAdapterNotConfigured();
return equityOracle;
}
// Add check for default price oracle
if (address(priceOracle) == address(0)) revert OracleAdapterNotConfigured();
return priceOracle;
}
4

MarketTypes.sol
Oracle Staleness Window Allows Pre-Lock Price Data for Settlement
The `validatePublishTimeFresh` function validates oracle data freshness using `(nowTs - publishTime) <= maxDelaySeconds`. The comment in `MarketTypes` explicitly states: 'Do NOT require publishTime >= lockAt; Chainlink updatedAt may be earlier than lockAt while still fresh.' This means oracle data published significantly before the lock/resolve time can be used for settlement, as long as it's within `maxDelaySeconds`. If `maxDelaySeconds` is set to a large value (e.g., 1 hour), an oracle price from 59 minutes before the lock time could be used to settle a market. This creates a window where the oracle price used for settlement doesn't reflect the actual price at the time of lock/resolve, potentially allowing manipulation by timing transactions to use favorable old prices.


Hide Details
Impact
If `maxDelaySeconds` is configured too loosely, oracle data from well before the lock/resolve time can be used for settlement. In volatile markets, this could mean the settlement price doesn't reflect the actual market price at the intended settlement time. Workers (or admin) could potentially time their lock/resolve transactions to use oracle data from a favorable time within the staleness window, manipulating settlement outcomes.
Scenario
1. Template configured with `oracleMaxDelaySeconds = 3600` (1 hour).
2. Asset price is $100 at lockAt time.
3. Oracle last updated at lockAt - 3500 seconds (just within staleness window) when price was $90.
4. Worker calls `lockEpoch` at exactly `lockAt`.
5. Oracle returns price $90 with publishTime = lockAt - 3500.
6. `validatePublishTimeFresh`: nowTs - publishTime = 3500 <= 3600 → valid.
7. Checkpoint A is set to $90 instead of the actual $100 at lock time.
8. Settlement is based on $90, potentially changing the winning outcome.
Affected code
function validatePublishTimeFresh(uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
internal
pure
returns (bool)
{
if (publishTime == 0) return false;
if (publishTime > nowTs) return false;
unchecked {
return (nowTs - publishTime) <= maxDelaySeconds;
}
}
Proposed fix
Consider adding a minimum publishTime requirement relative to the epoch phase transition time:
function validateCheckpointAPublishTime(
    Epoch storage e, 
    uint64 publishTime, 
    uint64 nowTs, 
    uint64 maxDelaySeconds
) internal view returns (bool) {
    if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
    // Optionally: require publishTime is within a tighter window of lockAt
    // if (publishTime < e.timing.lockAt - maxDelaySeconds) return false;
    return true;
}
Alternatively, document the acceptable staleness window clearly and set conservative `maxDelaySeconds` values (e.g., 60-300 seconds for liquid markets). Consider using round ID monotonicity enforcement as the primary protection against stale data replay.

low Severity
5
1

MarketMath.sol
Division Before Multiplication Precision Loss in computeTotalUserEntitlementResolved
In `MarketMath.computeTotalUserEntitlementResolved`, the pro-rata calculation `(userWinning * distributableLosing) / winningPool` performs multiplication before division, which is correct. However, in `computeClaimPayoutStorage`, the entitlement is computed as `userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool`. The issue is that `distributableLosing` itself is computed via `_distributableLosingPoolForClaimsStorage` which calls `computeClaimLiabilityComponents` or `computeLadderLiabilityComponents`, both of which perform integer division internally. This means `distributableLosing` already has precision loss baked in before being used in the pro-rata calculation. For small pools or when `losingPool` is not evenly divisible by `BPS_DENOMINATOR`, the settlement fee calculation truncates, and this truncated value is then used in the user payout calculation, compounding the precision loss.


Hide Details
Impact
Users may receive slightly less than their mathematically correct entitlement due to compounded precision loss. While the last-claimer remainder rule prevents dust from being permanently locked, intermediate claimers may receive slightly less than their fair share, with the difference accumulating to the last claimer. For large pools with many winners, this could result in meaningful value redistribution from early claimers to the last claimer.
Scenario
Consider: totalPool=10001, winningPool=5000, losingPool=5001, feeBps=100 (1%)
- settlementFee = (5001 * 100) / 10000 = 50 (truncated from 50.01)
- distributableLosing = 5001 - 50 = 4951
- If user has 1000 winning stake out of 5000:
- entitlement = 1000 + (1000 * 4951) / 5000 = 1000 + 990 = 1990
- Correct: 1000 + (1000 * 4950.1) / 5000 ≈ 1990.02
- Loss: 0.02 tokens per user (small but compounds across many users)
Affected code
function computeClaimPayoutStorage(
MarketTypes.Epoch storage epoch,
uint256[8] memory stakes,
uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
// ...
uint256 distributableLosing = _distributableLosingPoolForClaimsStorage(epoch, winningPool);
uint256 entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool;
// ...
}
Proposed fix
The last-claimer remainder rule already handles the final dust accumulation. However, to minimize precision loss for intermediate claimers, consider using higher precision intermediate values:
// Use WAD (1e18) scaling for intermediate calculations
uint256 constant WAD = 1e18;
uint256 proRataWad = (userWinningStake_ * WAD) / winningPool;
uint256 entitlement = userWinningStake_ + (distributableLosing * proRataWad) / WAD;
Alternatively, document the precision loss as an accepted design trade-off and ensure the last-claimer remainder rule is correctly implemented to absorb all dust.
2

MarketMath.sol
computeLadderLiabilityComponents Returns Incorrect claimLiabilityTotal When winnerWeightBps >= BPS_DENOMINATOR
In `computeLadderLiabilityComponents`, when `winnerWeightBps >= BPS_DENOMINATOR` (i.e., >= 10000 bps = 100%), the function returns the base values from `computeClaimLiabilityComponents`. However, the `baseClaimLiability` returned by `computeClaimLiabilityComponents` is `winningPool + distributableLosingPool` where `distributableLosingPool = losingPool - settlementFee`. This is correct for standard markets. But for Ladder markets with `winnerWeightBps = 10000`, the intent is that winners get 100% of the distributable losing pool, which is what the base calculation already provides. The issue is subtle: when `winnerWeightBps` is exactly `BPS_DENOMINATOR`, the early return is correct. But the comment says 'Remaining losing-pool amount stays as protocol settlement fee' which implies the ladder weight should reduce the distributable amount. If `winnerWeightBps = 10000` is intended to mean 'winners get everything', the current logic is correct. However, if a template is configured with `winnerWeightBps = 0`, the distributable losing pool becomes 0 (all goes to fees), but `claimLiabilityTotal = winningPool + 0 = winningPool`, meaning winners only get their stake back with no bonus - this may be unexpected behavior.


Hide Details
Impact
If `winnerWeightBps = 0` is set for a Ladder market outcome, winners receive only their original stake back (no share of losing pool), while the entire losing pool (minus base settlement fee) is added to the protocol fee. This could be an intentional design for certain ladder tiers, but if misconfigured, it silently redirects user funds to the protocol treasury without any error or warning. Users who bet on the 'winning' outcome would receive no profit.
Scenario
1. Admin creates a Ladder market template with `ladderPayoutWeightsBps[0] = 0` for the first outcome tier.
2. Users deposit into the market, some on outcome 0 (the 'winning' outcome).
3. Epoch resolves with outcome 0 as winner.
4. `computeLadderLiabilityComponents` is called with `winnerWeightBps = 0`.
5. `distributableLosingPool = (baseDistributableLosingPool * 0) / 10000 = 0`.
6. `settlementFee = baseSettlementFee + baseDistributableLosingPool` (entire losing pool goes to fees).
7. `claimLiabilityTotal = winningPool + 0 = winningPool`.
8. Winners only get their stake back, losing pool goes entirely to treasury.
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
Add validation in template creation to prevent `ladderPayoutWeightsBps` values of 0 for active outcomes, or explicitly document and emit events when the zero-weight case occurs:
// In template validation:
for (uint8 i = 0; i < outcomeCount; i++) {
    require(template.ladderPayoutWeightsBps[i] > 0, "Ladder weight cannot be zero");
}
Alternatively, if zero-weight is intentional (refund-only tier), add explicit documentation and consider emitting a specific event when this case is triggered during settlement.
3

MarketEngineAdminModule.sol
keeperClaimLmRewards Returns Early Without Revert When lmRewardsEnabled is False
In `keeperClaimLmRewards`, when `lmRewardsEnabled` is false, the function silently returns without reverting. This means a keeper (workerAuthority) calling this function when LM rewards are disabled will receive a successful transaction with no effect. While this is not a security vulnerability per se, it creates a silent no-op that could mislead off-chain systems monitoring for LM reward claims. More importantly, the function does not emit any event when it returns early, making it impossible to distinguish between 'LM rewards claimed successfully with zero amounts' and 'LM rewards not claimed because disabled' from transaction logs alone.


Hide Details
Impact
Off-chain monitoring systems may incorrectly interpret successful transactions with no events as successful zero-reward claims rather than disabled reward claims. This could mask configuration issues where LM rewards should be enabled but aren't. Additionally, keepers waste gas on no-op transactions.
Scenario
1. Admin sets `lmRewardsEnabled = false` (or never enables it).
2. Keeper calls `keeperClaimLmRewards(templateId)` expecting to claim rewards.
3. Function returns successfully with no events emitted.
4. Off-chain system sees successful transaction, assumes rewards were claimed.
5. LM rewards accumulate unclaimed in the yield router.
Affected code
function keeperClaimLmRewards(bytes32 templateId) external {
_authAdminOrWorker();
IYieldRouterV2 r = yieldRouter;
if (address(r) == address(0)) revert Unauthorized();
if (!lmRewardsEnabled) return; // Silent early return
(address[] memory tokens, uint256[] memory amounts) = r.claimLmRewards(templateId);
uint256 n = tokens.length;
for (uint256 i; i < n; ++i) {
if (amounts[i] > 0) {
emit LMRewardReceived(templateId, tokens[i], amounts[i]);
}
}
}
Proposed fix
Either revert when LM rewards are disabled, or emit an event to indicate the early return:
function keeperClaimLmRewards(bytes32 templateId) external {
    _authAdminOrWorker();
    IYieldRouterV2 r = yieldRouter;
    if (address(r) == address(0)) revert Unauthorized();
    if (!lmRewardsEnabled) revert Unauthorized(); // Or a more specific error
    (address[] memory tokens, uint256[] memory amounts) = r.claimLmRewards(templateId);
    uint256 n = tokens.length;
    for (uint256 i; i < n; ++i) {
        if (amounts[i] > 0) {
            emit LMRewardReceived(templateId, tokens[i], amounts[i]);
        }
    }
}
4

MarketEngineAdminModule.sol
setYieldRouter Allows Setting Non-Zero feeBps When Router is Zero Address
In `setYieldRouter`, when `router == address(0)`, the function correctly sets `yieldFeeBps = 0`. However, the fee validation `if (feeBps > 10_000) revert InvalidFeeBps()` runs before the zero-address check, meaning a call with `router = address(0)` and `feeBps = 5000` would pass validation, then set `yieldFeeBps = 0` (overriding the passed feeBps). This is not a security issue per se, but it's a confusing API where the passed `feeBps` parameter is silently ignored when `router = address(0)`. More importantly, there's no validation that the router address is actually a contract (has code), meaning a non-contract address could be set as the yield router, which would cause all yield router interactions to silently succeed (EVM calls to EOAs return success).


Hide Details
Impact
If an EOA address is set as the yield router, all calls to `yieldRouter.withdrawScaled()`, `yieldRouter.emergencyWithdraw()`, and `yieldRouter.claimLmRewards()` will succeed (return empty data) without actually performing any operations. This means: (1) user collateral deposited to the 'yield router' is lost, (2) withdrawal calls succeed but return no tokens, (3) the balance delta check in `_balanceDeltaAfterWithdrawScaled` would show 0 received, potentially causing `YieldRouterBalanceInvariant` revert or incorrect accounting.
Scenario
1. Admin accidentally calls `setYieldRouter(someEOAAddress, 500)`.
2. Protocol deposits user collateral to `someEOAAddress` (tokens transferred to EOA, lost).
3. At epoch resolution, `_balanceDeltaAfterWithdrawScaled` calls `someEOAAddress.withdrawScaled()`.
4. Call to EOA succeeds with empty return data.
5. Balance delta is 0 (no tokens received).
6. If `b1 < b0` check passes (b1 == b0), returns 0 received.
7. Yield accounting shows 0 yield, but principal is also 0 (lost to EOA).
Affected code
function setYieldRouter(address router, uint16 feeBps) external {
_authAdmin();
if (feeBps > 10_000) revert InvalidFeeBps();
address old = address(yieldRouter);
yieldRouter = IYieldRouterV2(router);
yieldFeeBps = router == address(0) ? 0 : feeBps;
yieldRouterFailureCount = 0;
yieldRouterDisabled = false;
if (router == address(0)) {
lmRewardsEnabled = false;
}
emit YieldRouterSet(old, router, yieldFeeBps);
emit YieldRouterFailureStateReset();
}
Proposed fix
Add a contract existence check when setting a non-zero router address:
function setYieldRouter(address router, uint16 feeBps) external {
    _authAdmin();
    if (feeBps > 10_000) revert InvalidFeeBps();
    if (router != address(0)) {
        // Verify router is a contract
        if (router.code.length == 0) revert InvalidModule();
        // Optionally verify router implements IYieldRouterV2 interface
    }
    address old = address(yieldRouter);
    yieldRouter = IYieldRouterV2(router);
    yieldFeeBps = router == address(0) ? 0 : feeBps;
    yieldRouterFailureCount = 0;
    yieldRouterDisabled = false;
    if (router == address(0)) {
        lmRewardsEnabled = false;
    }
    emit YieldRouterSet(old, router, yieldFeeBps);
    emit YieldRouterFailureStateReset();
}
5

MarketTypes.sol
validateCheckpointBPublishTime Only Checks Monotonicity Against checkpointA, Not checkpointA_B
In `MarketTypes.validateCheckpointBPublishTime`, the monotonicity check only validates that checkpoint B's publishTime is >= checkpoint A's publishTime (`e.checkpointA.publishTime`). However, the `Epoch` struct also contains `checkpointA_B` (a second oracle feed's checkpoint A, used for Convergence/Composite markets with dual feeds). For markets that use `checkpointA_B`, the checkpoint B for the second feed (`checkpointB_B`) should also be monotonic relative to `checkpointA_B.publishTime`. The current validation only checks against the primary `checkpointA`, potentially allowing `checkpointB_B` to have a publishTime earlier than `checkpointA_B.publishTime` for dual-feed markets.


Hide Details
Impact
For Convergence or Composite markets using dual oracle feeds, the secondary feed's checkpoint B could use oracle data from before the secondary feed's checkpoint A was captured. This could allow settlement using temporally inconsistent oracle data across the two feeds, potentially leading to incorrect market resolution for dual-feed market types.
Scenario
1. Convergence market uses two oracle feeds (feedA and feedB).
2. At lock time: checkpointA.publishTime = T1, checkpointA_B.publishTime = T2 (T2 > T1).
3. At resolve time: worker provides checkpointB_B with publishTime = T1.5 (between T1 and T2).
4. `validateCheckpointBPublishTime` checks: T1.5 >= T1 (checkpointA.publishTime) → passes.
5. But T1.5 < T2 (checkpointA_B.publishTime) → should fail but doesn't.
6. Settlement uses temporally inconsistent data for the second feed.
Affected code
function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
internal
view
returns (bool)
{
if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false; // Only checks primary checkpointA
return true;
}
Proposed fix
Extend the monotonicity check to include `checkpointA_B` when it's written:
function validateCheckpointBPublishTime(
    Epoch storage e, 
    uint64 publishTime, 
    uint64 nowTs, 
    uint64 maxDelaySeconds
) internal view returns (bool) {
    if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
    if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
    // Also check against secondary feed checkpoint A
    if (e.checkpointA_B.written && publishTime < e.checkpointA_B.publishTime) return false;
    return true;
}
Note: This fix should be applied in the context of which checkpoint B is being validated (primary vs secondary feed).

gas Severity
3
1

MarketEngineState.sol
Gas Optimization: _setRemainingWinningStake Iterates Over All Outcomes Including Non-Winners
In `_setRemainingWinningStake`, the function iterates over all `outcomeCount` outcomes to sum winning pools. This is called after `_applyResolveAccounting` which already has the winning mask and pool data. The loop could be optimized by breaking early once all winning outcomes are found, or by computing the sum during the settlement logic where the winning mask is first determined. For markets with 8 outcomes where only 1 is winning, the function always iterates all 8 slots.


Hide Details
Impact
Minor gas inefficiency. For markets with many outcomes (up to 8), the loop always iterates all outcomes even when the winning mask has only 1 bit set. This wastes gas on unnecessary iterations and storage reads.
Scenario
N/A - Gas optimization only.
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
Pass the winning pool sum from `_applyResolveAccounting` where it's already computed, or add early termination for single-winner markets:
// Option 1: Pass pre-computed sum
function _setRemainingWinningStake(
    bytes32 templateId, 
    uint64 epochId, 
    bool refundMode,
    uint256 precomputedWinningPool  // Pass from caller
) internal {
    MarketTypes.Epoch storage e = _epochs[templateId][epochId];
    e.remainingWinningStake = refundMode ? 0 : precomputedWinningPool;
}

// Option 2: Count set bits and break early
for (uint256 i = 0; i < uint256(n); i++) {
    if (((e.winningOutcomeMask >> i) & 1) != 0) {
        sum += e.outcomePools[i];
        // If only one winner possible, break here
    }
}
2

MarketMath.sol
Gas Optimization: Redundant Storage Reads in computeClaimPayoutStorage
In `computeClaimPayoutStorage`, the function reads `epoch.winningOutcomeMask` and `epoch.outcomeCount` into local variables (good), but then calls `_distributableLosingPoolForClaimsStorage` which reads `epoch.marketType`, `epoch.winningOutcomeMask`, `epoch.outcomeCount`, `epoch.settlementFeeBps`, `epoch.feeOnLosingPool`, and `epoch.totalPool` from storage again. These values are already available or could be cached. The `winningPool` is also computed twice: once in the main function and once inside `_distributableLosingPoolForClaimsStorage` (via `computeClaimLiabilityComponents` or `computeLadderLiabilityComponents`).


Hide Details
Impact
Unnecessary SLOAD operations increase gas costs for claim transactions. On L2 networks, this is less critical but still represents avoidable overhead for a hot path function called by every user claiming rewards.
Scenario
N/A - Gas optimization only.
Affected code
function computeClaimPayoutStorage(
MarketTypes.Epoch storage epoch,
uint256[8] memory stakes,
uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
uint256 winningMask = epoch.winningOutcomeMask;
uint8 outcomeCount = epoch.outcomeCount;
// ...
uint256 winningPool = 0;
for (uint256 i = 0; i < outcomeCount; i++) {
if ((winningMask >> i) & 1 == 1) {
winningPool += epoch.outcomePools[i]; // Storage read
}
}
uint256 distributableLosing = _distributableLosingPoolForClaimsStorage(epoch, winningPool);
// _distributableLosingPoolForClaimsStorage reads epoch.marketType, epoch.totalPool, etc. again
}
Proposed fix
Cache frequently accessed storage values and pass them to helper functions:
function computeClaimPayoutStorage(
    MarketTypes.Epoch storage epoch,
    uint256[8] memory stakes,
    uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
    // Cache all needed values upfront
    uint256 winningMask = epoch.winningOutcomeMask;
    uint8 outcomeCount = epoch.outcomeCount;
    uint256 totalPool = epoch.totalPool;
    uint16 settlementFeeBps = epoch.settlementFeeBps;
    bool feeOnLosingPool = epoch.feeOnLosingPool;
    
    userWinningStake_ = totalWinningStake(winningMask, outcomeCount, stakes);
    if (userWinningStake_ == 0) return (0, 0);
    
    // Compute winningPool once
    uint256 winningPool = 0;
    for (uint256 i = 0; i < outcomeCount; i++) {
        if ((winningMask >> i) & 1 == 1) {
            winningPool += epoch.outcomePools[i];
        }
    }
    
    // Pass cached values to avoid re-reading storage
    // ...
}
3

MarketTypes.sol
Informational: Large Epoch Struct May Cause High Gas Costs for Storage Operations
The `MarketTypes.Epoch` struct is extremely large, containing numerous fields including multiple `OracleCheckpoint` arrays (compositeCheckpointsA[4], compositeCheckpointsB[4]), multiple fixed arrays (outcomePools[8], velocityBoundsE4[7], ladderBoundsE8[7], etc.), and many individual fields. This struct is stored in a nested mapping `_epochs[templateId][epochId]`. While individual field reads are efficient (SLOAD per slot), operations that initialize or copy the entire struct (e.g., epoch creation) will be extremely gas-intensive. The struct likely spans 50+ storage slots.


Hide Details
Impact
High gas costs for epoch creation and any operations that touch many fields. On L1 Ethereum, this could make epoch operations prohibitively expensive. On L2 networks (where this appears to be targeted based on 'L2 hot path' comments), the impact is reduced but still present.
Scenario
N/A - Gas/informational finding.
Affected code
struct Epoch {
uint8 version;
EpochStatus status;
// ... many fields ...
OracleCheckpoint[4] compositeCheckpointsA;
OracleCheckpoint[4] compositeCheckpointsB;
int256 epochHighE8;
int256 epochLowE8;
bool ohlcWritten;
}
Proposed fix
Consider splitting the Epoch struct into a 'hot' struct (frequently accessed fields) and 'cold' struct (rarely accessed fields like composite oracle data). Use separate mappings for hot and cold data:
mapping(bytes32 => mapping(uint64 => EpochCore)) internal _epochsCore;
mapping(bytes32 => mapping(uint64 => EpochOracle)) internal _epochsOracle;
mapping(bytes32 => mapping(uint64 => EpochComposite)) internal _epochsComposite;
This would reduce gas costs for common operations that only need core epoch data.

informational Severity
2
1

MarketEngineAdminModule.sol
Informational: initializeMarket Does Not Validate Template is Active Before Initialization
In `initializeMarket`, the function checks that the template exists (`t.version != 0`) but does not check that the template is active (`t.active == true`). This means a market can be initialized for an inactive template. While this may be intentional (allowing initialization before activation), it could lead to confusion where a market is initialized but cannot be used because the template is inactive. The `TemplateInactive` error exists in the codebase but is not used here.


Hide Details
Impact
Low impact. Markets can be initialized for inactive templates, which may cause confusion but doesn't directly lead to fund loss. Epoch opening functions likely check template activity separately.
Scenario
N/A - Informational finding.
Affected code
function initializeMarket(bytes32 templateId) external {
_authAdmin();
MarketTypes.Template storage t = _templates[templateId];
if (t.version == 0) revert InvalidTemplate();
MarketTypes.Ledger storage ledger = _ledgers[templateId];
if (ledger.initialized) revert EpochAlreadyExists();

ledger.version = MarketTypes.VERSION;
ledger.initialized = true;
ledger.rollingPhase = MarketTypes.RollingPhase.Uninitialized;
ledger.rollingHaltReason = MarketTypes.RollingHaltReason.NoneReason;
ledger.rollingNextEpochId = 1;

emit MarketInitialized(templateId);
}
Proposed fix
Consider adding an active template check if the intent is that only active templates should have markets initialized:
function initializeMarket(bytes32 templateId) external {
    _authAdmin();
    MarketTypes.Template storage t = _templates[templateId];
    if (t.version == 0) revert InvalidTemplate();
    // Optionally: if (!t.active) revert TemplateInactive();
    // ...
}
Or document explicitly that initialization is allowed for inactive templates (e.g., to pre-initialize before activation).
2

MarketEngineState.sol
Informational: _balanceDeltaAfterWithdrawScaled Vulnerable to Read-Only Reentrancy if stakeToken Has Callbacks
The `_balanceDeltaAfterWithdrawScaled` function measures balance delta by calling `stakeToken.balanceOf(address(this))` before and after `r.withdrawScaled(templateId)`. If the yield router's `withdrawScaled` triggers a callback in the stakeToken (e.g., ERC777 `tokensReceived` hook on the engine contract itself), the callback could modify the engine's state between `b0` and `b1` measurements. While the balance delta would still be correct (measuring actual tokens received), any state changes made during the callback could create inconsistencies with the accounting performed after this function returns. This is a read-only reentrancy variant where the balance snapshot is correct but intermediate state may be inconsistent.


Hide Details
Impact
Low risk in practice since the stakeToken is expected to be a standard ERC20. However, if a non-standard token with callbacks is used, reentrancy during the balance measurement could lead to incorrect accounting. The `YieldRouterBalanceInvariant` check provides some protection but doesn't prevent all reentrancy scenarios.
Scenario
N/A - Informational/theoretical finding for standard ERC20 tokens.
Affected code
function _balanceDeltaAfterWithdrawScaled(IYieldRouterV2 r, bytes32 templateId, uint256 principalAmount)
internal
returns (uint256 received)
{
uint256 b0 = stakeToken.balanceOf(address(this));
r.withdrawScaled(templateId, principalAmount); // External call that could trigger callbacks
uint256 b1 = stakeToken.balanceOf(address(this));
if (b1 < b0) revert YieldRouterBalanceInvariant();
unchecked {
return b1 - b0;
}
}
Proposed fix
Add a reentrancy guard to all external-facing functions that call `_balanceDeltaAfterWithdrawScaled`. Document that the stakeToken must be a standard ERC20 without transfer hooks. Consider adding a check that the stakeToken does not implement ERC777 interface during initialization.