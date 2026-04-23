DeFi Prediction Market / Structured Outcome Protocol with Yield Integration

This is a comprehensive prediction market / structured outcome betting protocol called 'RetroPick'. It supports multiple market types (Direction, Threshold, RangeClose, Velocity, Ladder, Convergence, Composite, Corridor, Cascade) where users stake tokens on outcomes. The protocol integrates with Aave v3 for yield generation on staked collateral, uses Chainlink and TrustedReporter oracles for price/event data, and implements a sophisticated settlement engine with fee mechanics, claim payouts, and rolling/manual epoch lifecycles.

Show less
Access Control
role_based


Privileged Roles
1
Owner (Ownable2Step)
2
ENGINE (immutable address)
3
trustedReporter (TrustedReporterAdapter)
4
Admin/Keeper (implied by MarketEngine)

External Calls
1
IPoolAaveV3
2
IScaledBalanceToken (aToken)
3
IRewardsController
4
IERC4626 (StataToken)
5
IERC20 (stakeToken)
6
ChainlinkAdapter
7
IEventOracle (TrustedReporterAdapter)

External Systems
1
Aave V3 Protocol
2
Chainlink Oracle Network
3
EIP-712 Signature Scheme

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


high Severity
2
1

SettlementLogic.sol
Composite Market Uses Single Threshold for All Feeds - Critical Logic Error
In SettlementLogic.compute(), when resolving a Composite market type, all composite feeds are assigned the same threshold value (e.absoluteThresholdValueE8). The thresholds array is initialized as [int256(0), int256(0), int256(0), int256(0)] and then all entries are set to the same e.absoluteThresholdValueE8 value. This means a Composite market with multiple feeds requiring different threshold conditions (e.g., BTC > $50,000 AND ETH > $3,000) will incorrectly evaluate all feeds against the same threshold, leading to wrong outcome determination.


Hide Details
Impact
All composite markets with multiple feeds will resolve incorrectly unless all feeds happen to share the same threshold. This can cause winners to be incorrectly determined, leading to wrong payouts. Users who correctly predicted multi-condition outcomes may lose funds, while users who predicted incorrectly may receive payouts. This is a fundamental logic error that breaks the core functionality of Composite market types.
Scenario
1. Create a Composite market with 2 feeds: Feed A (BTC, threshold $50,000) and Feed B (ETH, threshold $3,000)
2. At resolve time, BTC = $55,000 (above $50,000) and ETH = $2,500 (below $3,000)
3. Expected: With AND logic, outcome should be NO (condition not fully met)
4. Actual: Both feeds are evaluated against e.absoluteThresholdValueE8 (which is one single value, say $50,000)
5. ETH at $2,500 < $50,000 threshold → condition NOT met for feed B
6. BTC at $55,000 >= $50,000 → condition met for feed A
7. Result depends on which single threshold was stored, not the intended per-feed thresholds
8. The market resolves based on wrong threshold comparisons, producing incorrect outcomes
Affected code
} else if (e.marketType == MarketTypes.MarketType.Composite) {
int256[4] memory thresholds = [int256(0), int256(0), int256(0), int256(0)];
for (uint256 i = 0; i < e.compositeFeedCount; i++) {
thresholds[i] = e.absoluteThresholdValueE8;
}
outputs.refundMode = false;
outputs.winningMask = Resolvers.resolveComposite(
e.compositeLogic, e.compositeFeedCount, e.compositeConditions, thresholds, e.compositeCheckpointsB
);
e.winningOutcomeMask = outputs.winningMask;
Proposed fix
Store per-feed thresholds in the Epoch struct. Add a `int256[4] compositeThresholdsE8` field to the Epoch struct and populate it from the Template at epoch open time. Then use these individual thresholds in settlement:
// In Epoch struct (MarketTypes.sol), add:
int256[4] compositeThresholdsE8;

// In SettlementLogic.compute() Composite branch:
} else if (e.marketType == MarketTypes.MarketType.Composite) {
    outputs.refundMode = false;
    outputs.winningMask = Resolvers.resolveComposite(
        e.compositeLogic, e.compositeFeedCount, e.compositeConditions, 
        e.compositeThresholdsE8,  // Use per-feed thresholds
        e.compositeCheckpointsB
    );
    e.winningOutcomeMask = outputs.winningMask;
}
2

TrustedReporterAdapter.sol
Signature Replay Attack via clearLockSample/clearResolveResult - Oracle Data Manipulation
The TrustedReporterAdapter allows the owner to clear lock samples and resolve results via clearLockSample() and clearResolveResult(). After clearing, the same EIP-712 signature can be replayed to re-post the same data (since the written flag is reset to false). More critically, if the trustedReporter key signs a message with a specific observedAt timestamp, and the owner clears the sample, the same signature can be resubmitted as long as it's still within the maxSignatureAgeSeconds window. This enables the owner to selectively clear and re-accept oracle data, potentially manipulating market outcomes by choosing which data gets accepted.


Hide Details
Impact
The owner can manipulate market outcomes by: (1) Clearing a legitimate oracle sample that would produce an unfavorable outcome, (2) Waiting for a different price observation that produces a favorable outcome, (3) Having the reporter sign and submit the new data. This effectively gives the owner the ability to cherry-pick oracle data within the maxSignatureAgeSeconds window, enabling market manipulation and theft of user funds.
Scenario
1. Market is open, trustedReporter posts lock sample with price = $50,000 (observedAt = T)
2. Owner sees that this price would cause them to lose on their position
3. Owner calls clearLockSample(marketId) to delete the sample
4. Within maxSignatureAgeSeconds (up to 48 hours), owner has reporter sign a new sample with price = $45,000 (observedAt = T+1)
5. Anyone calls postLockSample() with the new signature
6. Market now locks with the manipulated price
7. Owner profits from the manipulated outcome
Affected code
function clearLockSample(bytes32 marketId) external onlyOwner {
delete _lockSamples[marketId];
}

function clearResolveResult(bytes32 marketId) external onlyOwner {
delete _resolveSamples[marketId];
}
Proposed fix
Add a nonce to the EIP-712 struct hash to prevent replay of cleared signatures. Also consider adding a time-lock or multi-sig requirement for clearing samples:
// Add nonce tracking
mapping(bytes32 marketId => uint256) public lockSampleNonce;
mapping(bytes32 marketId => uint256) public resolveSampleNonce;

// Update LOCK_CLAIM_TYPEHASH to include nonce
bytes32 private constant LOCK_CLAIM_TYPEHASH = keccak256(
    "LockClaim(bytes32 marketId,int256 valueE8,uint64 observedAt,bytes32 dataSourceHash,uint256 nonce)"
);

// In clearLockSample, increment nonce
function clearLockSample(bytes32 marketId) external onlyOwner {
    lockSampleNonce[marketId]++;
    delete _lockSamples[marketId];
}

// In _verifyAndStoreSample, include nonce in hash
bytes32 structHash = keccak256(abi.encode(
    typeHash, marketId, valueE8, observedAt, dataSourceHash, nonce
));

medium Severity
6
1

SettlementLogic.sol
Corridor Market Outcome Index Confusion - Incorrect Bound Assignment
In SettlementLogic.compute() for Corridor market type, the bounds are passed as resolveCorridor(e.epochHighE8, e.epochLowE8, e.rangeBoundsE8[1], e.rangeBoundsE8[0]). The upper bound is taken from index [1] and lower bound from index [0]. This is counter-intuitive and error-prone. If a template creator sets rangeBoundsE8[0] as the upper bound and rangeBoundsE8[1] as the lower bound (which is the natural ordering), the corridor logic will be inverted, causing incorrect outcome determination. Furthermore, in resolveCorridor(), outcome 1 is returned when highE8 >= upperBoundE8 (price broke above) and outcome 2 when lowE8 <= lowerBoundE8 (price broke below), but there's no validation that upperBoundE8 > lowerBoundE8.


Hide Details
Impact
If template creators use the natural ordering (rangeBoundsE8[0] = lower, rangeBoundsE8[1] = upper), the corridor market will resolve with swapped bounds, causing incorrect outcome determination. Winners and losers will be incorrectly identified, leading to wrong payouts. Users who correctly predicted the price staying within the corridor may lose their stake, while users who predicted a breakout may incorrectly receive payouts.
Scenario
1. Create a Corridor market with rangeBoundsE8[0] = 45000e8 (lower bound) and rangeBoundsE8[1] = 55000e8 (upper bound)
2. Price stays within [45000, 55000] during the epoch
3. Expected: outcome 0 wins (stayed in corridor)
4. Actual: resolveCorridor is called with upperBoundE8=55000e8, lowerBoundE8=45000e8 - this happens to be correct in this case
5. BUT if creator sets rangeBoundsE8[0] = 55000e8 (upper) and rangeBoundsE8[1] = 45000e8 (lower) following natural index ordering:
6. resolveCorridor is called with upperBoundE8=45000e8, lowerBoundE8=55000e8
7. Since upperBound < lowerBound, any price will trigger either the upper or lower breach condition incorrectly
Affected code
} else if (e.marketType == MarketTypes.MarketType.Corridor) {
outputs.refundMode = false;
outputs.winningMask =
Resolvers.resolveCorridor(e.epochHighE8, e.epochLowE8, e.rangeBoundsE8[1], e.rangeBoundsE8[0]);
e.winningOutcomeMask = outputs.winningMask;
}
Proposed fix
Add explicit validation that rangeBoundsE8[1] > rangeBoundsE8[0] for Corridor markets, and add clear documentation about the index semantics. Consider using named constants or a dedicated struct:
// Add validation in template creation/epoch open:
if (e.marketType == MarketTypes.MarketType.Corridor) {
    require(e.rangeBoundsE8[1] > e.rangeBoundsE8[0], "Corridor: upper bound must exceed lower bound");
}

// Add NatSpec to clarify:
// rangeBoundsE8[0] = lowerBound (floor of corridor)
// rangeBoundsE8[1] = upperBound (ceiling of corridor)
2

Resolvers.sol
Potential Overflow in resolveConvergence Band Calculation
In Resolvers.resolveConvergence(), the band calculation `(openSpread * uint256(toleranceBps)) / 10_000` can overflow if openSpread is very large. The openSpread is computed as the absolute difference between two int256 oracle values cast to uint256. If both oracle values are near the int256 extremes (e.g., one is very large positive and one is very large negative), the difference could be close to uint256 max. Multiplying by toleranceBps (up to 10,000) would then overflow. Additionally, the check `closeSpread + band < openSpread` can overflow if closeSpread and band are both large values.


Hide Details
Impact
If oracle prices are extreme values (which is possible for certain asset types), the overflow in band calculation would cause incorrect convergence determination. The market could resolve with the wrong outcome, causing incorrect payouts. In Solidity 0.8.x, the overflow would cause a revert, potentially causing a DoS on market resolution.
Scenario
1. Create a Convergence market with two assets where prices can diverge significantly
2. Set a1.valueE8 = type(int256).max / 2 and a2.valueE8 = -(type(int256).max / 2)
3. openSpread = uint256(type(int256).max) ≈ 2^255
4. band = (2^255 * toleranceBps) / 10_000 → overflows uint256
5. In Solidity 0.8.x, this causes a revert, making the market unresolvable
6. Alternatively, closeSpread + band could overflow in the comparison check
Affected code
function resolveConvergence(
MarketTypes.OracleCheckpoint memory a1,
MarketTypes.OracleCheckpoint memory a2,
MarketTypes.OracleCheckpoint memory b1,
MarketTypes.OracleCheckpoint memory b2,
uint16 toleranceBps
) internal pure returns (bool voided, uint256 mask) {
if (!a1.written || !a2.written || !b1.written || !b2.written) revert InvalidEpochState();
uint256 openSpread = uint256((a1.valueE8 - a2.valueE8) < 0 ? (a2.valueE8 - a1.valueE8) : (a1.valueE8 - a2.valueE8));
uint256 closeSpread =
uint256((b1.valueE8 - b2.valueE8) < 0 ? (b2.valueE8 - b1.valueE8) : (b1.valueE8 - b2.valueE8));
uint256 band = (openSpread * uint256(toleranceBps)) / 10_000;
if (closeSpread + band < openSpread) return (false, uint256(1) << 0);
if (closeSpread > openSpread + band) return (false, uint256(1) << 1);
return (true, 0);
}
Proposed fix
Use OpenZeppelin's Math.mulDiv for the band calculation to prevent overflow, and use checked addition for the comparison:
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

function resolveConvergence(...) internal pure returns (bool voided, uint256 mask) {
    // ... existing checks ...
    uint256 band = Math.mulDiv(openSpread, uint256(toleranceBps), 10_000);
    
    // Use checked addition to prevent overflow in comparisons
    uint256 openSpreadPlusBand;
    unchecked {
        openSpreadPlusBand = openSpread + band;
        if (openSpreadPlusBand < openSpread) openSpreadPlusBand = type(uint256).max; // overflow cap
    }
    
    uint256 closeSpreadPlusBand;
    unchecked {
        closeSpreadPlusBand = closeSpread + band;
        if (closeSpreadPlusBand < closeSpread) closeSpreadPlusBand = type(uint256).max;
    }
    
    if (closeSpreadPlusBand < openSpread) return (false, uint256(1) << 0);
    if (closeSpread > openSpreadPlusBand) return (false, uint256(1) << 1);
    return (true, 0);
}
3

YieldRouterAaveV3.sol
YieldRouterAaveV3 Uses aToken Balance Delta Instead of Scaled Balance - Incorrect Share Accounting
In YieldRouterAaveV3._deposit(), the shares minted are calculated as the difference in aToken.balanceOf() before and after the Aave supply call. However, aToken.balanceOf() returns the rebasing balance (principal + accrued interest), not the scaled balance. This means the 'minted' shares tracked in sharesByTemplate include the interest accrued between the two balanceOf() calls. Over time, as interest accrues, the sharesByTemplate values will diverge from the actual scaled balance, leading to incorrect proportional withdrawal calculations.


Hide Details
Impact
The sharesByTemplate tracking becomes inaccurate over time as aToken balances rebase. When withdrawing proportionally, the calculation `Math.mulDiv(totalShares, principalAmount, principal)` uses inflated share values, potentially causing over-withdrawal or under-withdrawal. In a multi-template scenario, one template could effectively steal yield from another template's shares. The YieldRouterV2 correctly uses scaledBalanceOf() to avoid this issue, but YieldRouterAaveV3 does not.
Scenario
1. Template A deposits 1000 USDC at time T0, sharesByTemplate[A] = 1000 aUSDC
2. Template B deposits 1000 USDC at time T1 (after some interest accrual)
3. At T1, aToken.balanceOf() before supply = 1010 (1000 + 10 interest for A)
4. After supply, aToken.balanceOf() = 2010
5. minted = 2010 - 1010 = 1000, sharesByTemplate[B] = 1000
6. But actual scaled balance for B is slightly less than 1000 due to index > 1
7. Over time, proportional withdrawals become inaccurate
8. Template with more shares can withdraw more than its fair share of yield
Affected code
function _deposit(bytes32 templateId, uint256 amount) internal {
if (amount == 0) revert ZeroAmount();

STAKE_TOKEN.safeTransferFrom(ENGINE, address(this), amount);

uint256 beforeBal = A_TOKEN.balanceOf(address(this));
AAVE_POOL.supply(address(STAKE_TOKEN), amount, address(this), 0);
uint256 afterBal = A_TOKEN.balanceOf(address(this));
uint256 minted = afterBal - beforeBal;

principalByTemplate[templateId] += amount;
sharesByTemplate[templateId] += minted;

emit YieldDeposited(templateId, amount, minted);
}
Proposed fix
Use scaledBalanceOf() instead of balanceOf() for share tracking, consistent with YieldRouterV2:
function _deposit(bytes32 templateId, uint256 amount) internal {
    if (amount == 0) revert ZeroAmount();
    STAKE_TOKEN.safeTransferFrom(ENGINE, address(this), amount);
    
    // Use scaled balance for accurate share tracking
    uint256 scaledBefore = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
    AAVE_POOL.supply(address(STAKE_TOKEN), amount, address(this), 0);
    uint256 scaledAfter = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
    uint256 minted = scaledAfter - scaledBefore;
    
    principalByTemplate[templateId] += amount;
    sharesByTemplate[templateId] += minted;
    
    emit YieldDeposited(templateId, amount, minted);
}
4

Resolvers.sol
resolveCascade Does Not Validate Bounds Array is Monotonically Increasing
In Resolvers.resolveCascade(), the function iterates through boundsE8 to count how many levels have been reached. For upward cascade (downward=false), it checks `highE8 >= boundsE8[i]` for each level. For downward cascade, it checks `lowE8 <= boundsE8[i]`. The function assumes bounds are monotonically ordered (increasing for upward, decreasing for downward), but there is no validation of this. If bounds are not properly ordered, the level counting will be incorrect, potentially assigning the wrong outcome.


Hide Details
Impact
If bounds are not monotonically ordered, the cascade level counting will be incorrect. For example, if bounds are [100, 50, 150] for an upward cascade, a price of 120 would match bounds[0]=100 and bounds[2]=150 but not bounds[1]=50, giving levelsReached=2 instead of the intended 1. This leads to incorrect outcome assignment and wrong payouts.
Scenario
1. Create an upward Cascade market with 4 outcomes and boundsE8 = [100e8, 50e8, 200e8, 0, 0, 0, 0] (non-monotonic)
2. Price high = 120e8
3. Level 0: 120 >= 100 → levelsReached = 1
4. Level 1: 120 >= 50 → levelsReached = 2
5. Level 2: 120 >= 200 → false
6. Result: outcome 2 wins (levelsReached=2)
7. Expected with correct bounds [50, 100, 200]: outcome 2 would also win, but with bounds [100, 50, 200] the semantics are wrong
8. The market resolves based on incorrectly ordered bounds
Affected code
function resolveCascade(int256 highE8, int256 lowE8, uint8 outcomeCount, int256[7] memory boundsE8, bool downward)
internal
pure
returns (uint256 mask)
{
if (outcomeCount < 2) revert InvalidTemplate();
uint256 levelsReached = 0;
uint256 maxLevels = uint256(outcomeCount) - 1;
for (uint256 i = 0; i < maxLevels; i++) {
if (downward) {
if (lowE8 <= boundsE8[i]) levelsReached++;
} else {
if (highE8 >= boundsE8[i]) levelsReached++;
}
}
if (levelsReached >= outcomeCount) levelsReached = outcomeCount - 1;
return uint256(1) << levelsReached;
}
Proposed fix
Add validation in the template/epoch creation to ensure bounds are monotonically ordered for Cascade markets:
// In template validation (MarketEngine):
if (template.marketType == MarketTypes.MarketType.Cascade) {
    for (uint256 i = 1; i < template.outcomeCount - 1; i++) {
        if (template.cascadeDownward) {
            require(template.rangeBoundsE8[i] < template.rangeBoundsE8[i-1], 
                "Cascade: downward bounds must be decreasing");
        } else {
            require(template.rangeBoundsE8[i] > template.rangeBoundsE8[i-1], 
                "Cascade: upward bounds must be increasing");
        }
    }
}
5

TrustedReporterAdapter.sol
TrustedReporterAdapter: OHLC Sample Can Override Resolve Sample Priority
In TrustedReporterAdapter.getResult(), the function first checks if an OHLC sample exists and returns its closeE8 value. If no OHLC sample exists, it falls back to the resolve sample. This means if both an OHLC sample and a resolve sample are posted for the same marketId, the OHLC sample always takes precedence. However, there is no mechanism to prevent posting both types of samples for the same market. An attacker (or even the trusted reporter) could post a resolve sample first, then post an OHLC sample with a different closeE8 value to override the resolution data.


Hide Details
Impact
The trusted reporter (or anyone with a valid reporter signature) can override a previously posted resolve sample by posting an OHLC sample with a different close price. This allows manipulation of market resolution after the resolve sample has been posted. If the market engine reads getResult() after both samples are posted, it will use the OHLC close price instead of the resolve sample value, potentially changing the market outcome.
Scenario
1. Market resolves, trustedReporter posts resolve sample: valueE8 = 50000e8 (price went up)
2. This would cause outcome 0 to win (price up)
3. Attacker (with reporter key) posts OHLC sample: closeE8 = 45000e8 (price went down)
4. getResult() now returns (45000e8, true) instead of (50000e8, true)
5. Market engine reads the OHLC close price and resolves with outcome 1 (price down)
6. Market outcome is manipulated
Affected code
function getResult(bytes32 marketId) external view override returns (int256 result, bool resolved) {
OhlcSample storage ohlc = _ohlcSamples[marketId];
if (ohlc.written) return (ohlc.closeE8, true);
Sample storage s = _resolveSamples[marketId];
return (s.valueE8, s.written);
}
Proposed fix
Add mutual exclusivity between OHLC and resolve samples, or add a check to prevent OHLC posting if a resolve sample already exists:
function postOhlcResult(
    bytes32 marketId,
    int256 highE8,
    int256 lowE8,
    int256 closeE8,
    uint64 observedAt,
    bytes32 dataSourceHash,
    bytes calldata signature
) external {
    OhlcSample storage s = _ohlcSamples[marketId];
    if (s.written) revert AlreadyResolved();
    
    // Prevent OHLC from overriding an existing resolve sample
    if (_resolveSamples[marketId].written) revert AlreadyResolved();
    
    // ... rest of function
}
Alternatively, document clearly that OHLC takes precedence and ensure the engine only uses one type per market.
6

YieldRouterV2.sol
YieldRouterV2 emergencyWithdraw Does Not Emit Event Before Potential Revert
In YieldRouterV2.emergencyWithdraw(), the EmergencyWithdrawV2 event is emitted after the _withdrawScaled() call completes. If _withdrawScaled() reverts (e.g., due to Aave reserve being paused), no event is emitted. This is actually correct behavior. However, the function calls _withdrawScaled() which internally calls _requireReserveWithdrawable(), meaning emergency withdrawals are blocked when the Aave reserve is paused. This defeats the purpose of an emergency withdrawal function - in a true emergency (e.g., Aave is being exploited), the owner cannot withdraw funds.


Hide Details
Impact
In a genuine emergency where the Aave reserve is paused (e.g., due to a security incident), the emergencyWithdraw function will revert with ReservePaused error. This means the protocol cannot recover funds during the exact scenario where emergency withdrawal is most needed. Funds could be permanently locked if Aave's pause is indefinite.
Scenario
1. Aave reserve is paused due to a security incident
2. Protocol admin calls emergencyWithdraw(templateId) to recover funds
3. _withdrawScaled() is called, which calls _requireReserveWithdrawable()
4. _requireReserveWithdrawable() reads isPaused = true
5. Function reverts with ReservePaused
6. Funds remain locked in the paused Aave reserve
7. Protocol cannot recover user funds during the emergency
Affected code
function emergencyWithdraw(bytes32 templateId) external override returns (uint256 grossAmount) {
if (msg.sender != ENGINE && msg.sender != owner()) revert Unauthorized();
TemplateYield storage t = _templates[templateId];
uint256 p = t.principal;
if (p == 0) return 0;
// Full template unwind (per-template accounting); never use pool max-withdraw for multi-template safety.
grossAmount = _withdrawScaled(templateId, p);
emit EmergencyWithdrawV2(templateId, grossAmount);
}
Proposed fix
Add a bypass for the reserve health check in emergency withdrawal:
function emergencyWithdraw(bytes32 templateId) external override returns (uint256 grossAmount) {
    if (msg.sender != ENGINE && msg.sender != owner()) revert Unauthorized();
    TemplateYield storage t = _templates[templateId];
    uint256 p = t.principal;
    if (p == 0) return 0;
    
    // Emergency withdrawal bypasses reserve health checks
    // This is intentional - in emergencies, we need to withdraw regardless of reserve state
    TemplateYield storage template = _templates[templateId];
    uint256 s = template.scaledPrincipal;
    if (s > 0) {
        uint256 idx = AAVE_POOL.getReserveNormalizedIncome(address(STAKE_TOKEN));
        uint256 underlyingToWithdraw = s.scaledToReal(idx);
        try AAVE_POOL.withdraw(address(STAKE_TOKEN), underlyingToWithdraw, ENGINE) returns (uint256 withdrawn) {
            grossAmount = withdrawn;
        } catch {
            // If Aave withdrawal fails, at least reset accounting
            grossAmount = 0;
        }
    }
    template.principal = 0;
    template.scaledPrincipal = 0;
    emit EmergencyWithdrawV2(templateId, grossAmount);
}

low Severity
9
1

YieldRouterAaveV3.sol
YieldRouterAaveV3.emergencyWithdraw Passes aToken Shares as Underlying Amount to Aave withdraw()
In YieldRouterAaveV3.emergencyWithdraw(), the code calls `AAVE_POOL.withdraw(address(STAKE_TOKEN), shares, ENGINE)` where `shares` is the aToken balance (from sharesByTemplate). However, the Aave v3 pool's withdraw() function expects the `amount` parameter to be the underlying asset amount, not the aToken share amount. While aTokens are 1:1 with underlying at the time of minting, they rebase over time, so the aToken balance will be greater than the original underlying amount deposited. Passing the aToken balance as the underlying amount will withdraw more than intended, potentially draining other templates' funds.


Hide Details
Impact
The emergencyWithdraw function will attempt to withdraw more underlying than the template's actual share, potentially: (1) Withdrawing yield that belongs to other templates, (2) Causing the Aave withdrawal to fail if the requested amount exceeds available liquidity, (3) Leaving accounting inconsistencies between the router and the engine. Note: Aave v3's withdraw() with a specific amount will withdraw that exact underlying amount, so if shares > actual underlying value, it could over-withdraw from the shared aToken pool.
Scenario
1. Template A deposits 1000 USDC, sharesByTemplate[A] = 1000 aUSDC
2. Time passes, interest accrues: aToken balance for A is now 1050 (1000 principal + 50 yield)
3. Owner calls emergencyWithdraw(templateIdA)
4. shares = 1050 (the current aToken balance tracked)
5. AAVE_POOL.withdraw(USDC, 1050, ENGINE) is called
6. Aave withdraws 1050 USDC (more than the 1000 principal)
7. This is actually correct behavior for emergency withdrawal (getting principal + yield)
8. BUT: if multiple templates share the router and template B has 1000 aUSDC, withdrawing 1050 for A could consume some of B's yield
Affected code
function emergencyWithdraw(bytes32 templateId) external override returns (uint256 grossAmount) {
if (msg.sender != ENGINE && msg.sender != owner()) revert Unauthorized();

uint256 shares = sharesByTemplate[templateId];
if (shares == 0) return 0;

grossAmount = AAVE_POOL.withdraw(address(STAKE_TOKEN), shares, ENGINE);

principalByTemplate[templateId] = 0;
sharesByTemplate[templateId] = 0;

emit EmergencyWithdraw(templateId, shares, grossAmount);
}
Proposed fix
For emergency withdrawal, use type(uint256).max to withdraw the full aToken position for the template, or use the actual aToken balance. However, since multiple templates share one router, use the tracked shares directly with Aave's share-based withdrawal:
function emergencyWithdraw(bytes32 templateId) external override returns (uint256 grossAmount) {
    if (msg.sender != ENGINE && msg.sender != owner()) revert Unauthorized();

    uint256 shares = sharesByTemplate[templateId];
    if (shares == 0) return 0;

    // Use the actual aToken balance as the amount to withdraw
    // aToken is 1:1 with underlying in terms of Aave's withdraw() parameter
    // Pass shares as the aToken amount to redeem
    grossAmount = AAVE_POOL.withdraw(address(STAKE_TOKEN), shares, ENGINE);

    principalByTemplate[templateId] = 0;
    sharesByTemplate[templateId] = 0;

    emit EmergencyWithdraw(templateId, shares, grossAmount);
}
Note: The actual fix depends on whether sharesByTemplate tracks aToken units or scaled units. If it tracks aToken units (rebasing), the current code is actually correct for Aave v3 since aToken.balanceOf() == underlying amount. The real issue is the inconsistency in the _deposit() function using balanceOf() vs scaledBalanceOf().
2

YieldRouterV2.sol
globalScaledBalance State Variable Becomes Stale in Multi-Template Scenarios
In YieldRouterV2, the globalScaledBalance state variable is updated to `scaledAfter` (the total scaled balance of the router) after each deposit or withdrawal. However, this value represents the total scaled balance across ALL templates, not just the one being operated on. If multiple templates are active simultaneously, the globalScaledBalance will be overwritten with the current total after each operation, which is correct. However, if a deposit for template A is followed by a deposit for template B, the globalScaledBalance after B's deposit correctly reflects both A and B. But if template A then withdraws, globalScaledBalance is updated to reflect only the remaining balance, which is correct. The issue is that globalScaledBalance is a public state variable that external contracts/users may rely on for accounting, but it only reflects the state after the last operation, not a real-time view.


Hide Details
Impact
The globalScaledBalance variable can become stale between transactions. If external contracts or the engine use this value for accounting decisions, they may operate on outdated data. More critically, the StataToken path does NOT update globalScaledBalance, meaning after a StataToken deposit, globalScaledBalance will not reflect the actual total scaled balance. This creates an inconsistency between AToken-path and StataToken-path templates.
Scenario
1. Template A uses AToken path, deposits 1000 USDC → globalScaledBalance = 1000 scaled units
2. Template B uses StataToken path, deposits 1000 USDC → globalScaledBalance still = 1000 (not updated)
3. External contract reads globalScaledBalance = 1000, but actual total value is ~2000
4. Accounting decisions based on globalScaledBalance are incorrect
Affected code
uint256 scaledBefore = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
AAAVE_POOL.supply(address(STAKE_TOKEN), amount, address(this), 0);
uint256 scaledAfter = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
attributionUnits = scaledAfter - scaledBefore;
globalScaledBalance = scaledAfter;
Proposed fix
Either remove globalScaledBalance as a public state variable and replace it with a view function that reads the actual current value, or update it consistently for all paths:
// Option 1: Replace with view function
function globalScaledBalance() external view returns (uint256) {
    return IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
}

// Option 2: Update for StataToken path too
// In _depositScaled StataToken branch:
uint256 scaledAfterStata = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
globalScaledBalance = scaledAfterStata;
3

Resolvers.sol
resolveRangeClose Off-By-One: Boundary Value at rangeBoundsE8[0] Assigned to Wrong Bucket
In Resolvers.resolveRangeClose(), the bucket assignment logic has a subtle boundary condition issue. When `value == rangeBoundsE8[0]`, the first condition `value < rangeBoundsE8[0]` is false, so the code falls into the else branch and starts with `idx = outcomeCount - 1`. The inner loop then checks `value < rangeBoundsE8[i]` for i starting at 1. Since `value == rangeBoundsE8[0]`, it will check if `value < rangeBoundsE8[1]`. If true, idx = 1. This means a value exactly equal to rangeBoundsE8[0] is assigned to bucket 1, not bucket 0. The documentation says 'idx = 0 if value < bounds[0]' and 'idx = i if bounds[i-1] <= value < bounds[i]', so value == bounds[0] should be in bucket 1 (since bounds[0] <= value < bounds[1]). This is actually correct per the spec, but the spec itself may be confusing - the first bucket (idx=0) only captures values strictly below bounds[0].


Hide Details
Impact
The boundary semantics may not match user expectations. Users who bet on 'bucket 0' (below the first bound) will lose if the price lands exactly on the first bound, as it will be assigned to bucket 1. This could lead to unexpected losses for users who correctly predicted the price range but lost due to boundary semantics. The impact depends on how the market is documented to users.
Scenario
1. Create a RangeClose market with 3 outcomes and rangeBoundsE8 = [50000e8, 60000e8, 0, 0, 0, 0, 0]
2. Bucket 0: price < 50000 (below)
3. Bucket 1: 50000 <= price < 60000 (middle)
4. Bucket 2: price >= 60000 (above)
5. Price resolves at exactly 50000e8
6. value < rangeBoundsE8[0] → false (50000 is not < 50000)
7. idx starts at 2 (outcomeCount-1)
8. Loop: i=1, value < rangeBoundsE8[1] → 50000 < 60000 → true, idx = 1
9. Result: bucket 1 wins
10. Users who bet on bucket 0 (below 50000) lose, even though price is at the boundary
Affected code
function resolveRangeClose(
MarketTypes.OracleCheckpoint memory b,
uint8 outcomeCount,
int256[7] memory rangeBoundsE8
) internal pure returns (uint256 mask) {
if (!b.written) revert InvalidEpochState();
if (outcomeCount < 2) revert InvalidTemplate();
int256 value = b.valueE8;
uint256 idx;
if (value < rangeBoundsE8[0]) {
idx = 0;
} else {
idx = uint256(outcomeCount) - 1;
for (uint256 i = 1; i < uint256(outcomeCount) - 1; i++) {
if (value < rangeBoundsE8[i]) {
idx = i;
break;
}
}
}
return uint256(1) << idx;
}
Proposed fix
The current behavior is consistent with the documented spec (idx=0 only for strictly below bounds[0]). However, add explicit documentation and consider whether the boundary semantics are user-friendly:
/// @dev Bucket assignment semantics:
/// - Bucket 0: value STRICTLY BELOW bounds[0] (i.e., value < bounds[0])
/// - Bucket i (1 <= i <= outcomeCount-2): bounds[i-1] <= value < bounds[i]
/// - Bucket outcomeCount-1: value >= bounds[outcomeCount-2]
/// Note: A value exactly equal to bounds[0] falls into Bucket 1, not Bucket 0.
If the intended behavior is that bucket 0 includes the lower boundary, change the condition to `value <= rangeBoundsE8[0]`.
4

YieldRouterV2.sol
YieldRouterV2 StataToken Partial Withdrawal May Leave Dust Due to Share Rounding
In YieldRouterV2._withdrawScaled() for the StataToken path, when doing a partial withdrawal, the code computes `underlyingRequest` using mulDiv floor rounding, then converts to shares using `STATA_TOKEN.convertToShares(underlyingRequest)`. The convertToShares() function in ERC-4626 typically uses floor rounding, which means the actual shares redeemed may be slightly less than needed to cover the requested underlying amount. This creates a systematic underpayment where the engine receives slightly less than the requested principalAmount worth of underlying.


Hide Details
Impact
The engine may receive slightly less underlying than expected for partial withdrawals. Over many partial withdrawals, this dust accumulates in the StataToken position. The principal accounting (t.principal) is decremented by the full principalAmount, but the actual underlying received is slightly less. This creates a growing discrepancy between tracked principal and actual value, potentially causing the last withdrawal to fail or return less than expected.
Scenario
1. Template deposits 1000 USDC into StataToken path
2. Partial withdrawal requested: 500 USDC
3. totalAssets = 1050 (with yield), underlyingRequest = 525 (floor)
4. sharesToRedeem = convertToShares(525) → may round down to shares worth 524.99
5. grossAmount = 524.99 USDC returned to engine
6. t.principal = 500 (decremented by full 500)
7. Remaining: t.principal = 500, but actual value = 525.01 (slightly more than expected)
8. This is actually favorable for the remaining position, but the engine received less than expected
Affected code
uint256 totalAssets = STATA_TOKEN.convertToAssets(sharesTotal);
uint256 underlyingRequest = principalAmount == p
? totalAssets
: Math.mulDiv(totalAssets, principalAmount, p, Math.Rounding.Floor);
uint256 sharesToRedeem = principalAmount == p ? sharesTotal : STATA_TOKEN.convertToShares(underlyingRequest);
if (sharesToRedeem > sharesTotal) sharesToRedeem = sharesTotal;
grossAmount = STATA_TOKEN.redeem(sharesToRedeem, ENGINE, address(this));
t.stataShares = sharesTotal - sharesToRedeem;
t.principal = p - principalAmount;
Proposed fix
Use ceiling rounding for share conversion to ensure the engine receives at least the requested amount:
// Use ceiling rounding for shares to ensure sufficient underlying is redeemed
uint256 sharesToRedeem = principalAmount == p 
    ? sharesTotal 
    : STATA_TOKEN.convertToShares(underlyingRequest + 1); // Add 1 wei to ensure ceiling
if (sharesToRedeem > sharesTotal) sharesToRedeem = sharesTotal;

Or use ERC-4626's previewWithdraw() which uses ceiling rounding by convention:
uint256 sharesToRedeem = principalAmount == p 
    ? sharesTotal 
    : STATA_TOKEN.previewWithdraw(underlyingRequest);
5

YieldRouterV2.sol
Aave Reserve Configuration Bit Positions May Be Incorrect
In YieldRouterV2._requireReserveHealthy(), the reserve configuration bits are read at positions 56, 57, and 60. These positions are hardcoded based on the Aave v3 ReserveConfigurationMap layout. However, if Aave v3 updates its configuration layout in a future version, or if the bit positions are incorrect for the specific Aave v3 deployment being used, the health checks could silently pass or fail incorrectly. The Aave v3 documentation specifies: isActive at bit 56, isFrozen at bit 57, isPaused at bit 60, which matches the implementation. However, this is a fragile dependency on internal Aave storage layout.


Hide Details
Impact
If the bit positions are wrong (e.g., due to a different Aave v3 fork or version), the reserve health check could: (1) Allow deposits into a paused/frozen reserve, leading to failed transactions or locked funds, (2) Incorrectly reject deposits into a healthy reserve, causing DoS. The impact is moderate since Aave v3 is well-documented, but the hardcoded bit positions create a maintenance risk.
Scenario
1. Deploy YieldRouterV2 against an Aave v3 fork that uses different bit positions
2. Reserve is paused (bit 60 in standard Aave = 1)
3. But in the fork, paused is at bit 61
4. _requireReserveHealthy() reads bit 60 = 0 (not paused in fork's layout)
5. Deposit proceeds into a paused reserve
6. Aave supply() call fails or behaves unexpectedly
Affected code
function _requireReserveHealthy() internal view {
ReserveConfigurationMap memory cfg = AAVE_POOL.getConfiguration(address(STAKE_TOKEN));
uint256 data = cfg.data;
bool isActive = (data >> 56) & 1 == 1;
bool isFrozen = (data >> 57) & 1 == 1;
bool isPaused = (data >> 60) & 1 == 1;
if (!isActive || isFrozen || isPaused) revert ReserveNotHealthy();
}
Proposed fix
Use Aave's official DataTypes library or interface to read reserve configuration rather than hardcoded bit positions:
// Option 1: Use Aave's IPool.getReserveData() which returns structured data
// Option 2: Import Aave's ReserveConfiguration library
// Option 3: Add a comment with the Aave v3 spec reference and version

/// @dev Bit positions per Aave v3 ReserveConfigurationMap (v3.0.0):
/// Bit 56: isActive
/// Bit 57: isFrozen  
/// Bit 60: isPaused
/// Reference: https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/configuration/ReserveConfiguration.sol
function _requireReserveHealthy() internal view {
    // ... existing implementation with added reference comment
}
6

Resolvers.sol
Missing Validation: resolveVelocity Allows Zero Base Price Division
In Resolvers.resolveVelocity(), the function correctly reverts if `absBase == 0` (when checkpoint A price is exactly zero). However, it does not handle the case where checkpoint A price is very small (e.g., 1 wei in E8 precision = 0.00000001). In this case, even a tiny absolute price movement would result in an astronomically large `moveBpsE4` value, potentially causing the outcome to always land in the highest bucket regardless of actual price movement. This could be exploited by market creators who set up markets with near-zero base prices.


Hide Details
Impact
For markets with very small base prices, the velocity calculation becomes meaningless. A market creator could set up a velocity market on an asset with a near-zero price, where any price movement (even 1 wei) would result in the maximum velocity bucket winning. This could be used to create markets where the outcome is predictable regardless of actual price movement, enabling market manipulation.
Scenario
1. Create a Velocity market on an asset with price = 1 (1e-8 in E8 precision)
2. absBase = 1
3. Any price movement of 1 unit: absDelta = 1
4. moveBpsE4 = (1 * 10_000) / 1 = 10_000 (100% move in BPS)
5. This exceeds any reasonable velocityBoundsE4 value
6. Outcome always lands in the highest bucket
7. Market creator who knows this can bet on the highest bucket with certainty
Affected code
function resolveVelocity(
MarketTypes.OracleCheckpoint memory a,
MarketTypes.OracleCheckpoint memory b,
uint8 outcomeCount,
uint32[7] memory velocityBoundsE4
) internal pure returns (uint256 mask) {
if (!a.written || !b.written) revert InvalidEpochState();
if (outcomeCount < 2) revert InvalidTemplate();
int256 delta = b.valueE8 - a.valueE8;
uint256 absDelta = uint256(delta < 0 ? -delta : delta);
uint256 absBase = uint256(a.valueE8 < 0 ? -a.valueE8 : a.valueE8);
if (absBase == 0) revert InvalidEpochState();
uint256 moveBpsE4 = (absDelta * 10_000) / absBase;
// ...
}
Proposed fix
Add a minimum base price validation:
function resolveVelocity(...) internal pure returns (uint256 mask) {
    // ...
    uint256 absBase = uint256(a.valueE8 < 0 ? -a.valueE8 : a.valueE8);
    if (absBase == 0) revert InvalidEpochState();
    
    // Add minimum base price check to prevent manipulation with near-zero prices
    // Minimum meaningful price: 1000 in E8 = 0.00001
    if (absBase < 1000) revert InvalidEpochState();
    
    uint256 moveBpsE4 = (absDelta * 10_000) / absBase;
    // ...
}
Alternatively, validate the base price at template creation time.
7

YieldRouterV2.sol
YieldRouterV2 rescueToken Does Not Prevent Rescuing STAKE_TOKEN
In YieldRouterV2.rescueToken(), the function prevents rescuing the aToken (A_TOKEN) but does not prevent rescuing the STAKE_TOKEN (the underlying collateral). If STAKE_TOKEN accidentally ends up in the router (e.g., due to a failed deposit where tokens were transferred but supply() failed), the owner could rescue them. However, this also means the owner can rescue any STAKE_TOKEN that legitimately belongs to the protocol's accounting, potentially draining user funds.


Hide Details
Impact
The owner can rescue STAKE_TOKEN from the router, which could include tokens that are part of the protocol's accounting. While the router is designed to not hold STAKE_TOKEN (it immediately supplies to Aave), there are edge cases where STAKE_TOKEN could be present (e.g., failed Aave supply, direct transfers). If the owner is malicious or compromised, they could drain STAKE_TOKEN from the router.
Scenario
1. Due to a bug or direct transfer, 1000 USDC (STAKE_TOKEN) ends up in YieldRouterV2
2. Owner calls rescueToken(USDC_ADDRESS, attacker, 1000e6)
3. 1000 USDC is transferred to attacker
4. If this USDC was part of a pending deposit, the engine's accounting is now inconsistent
Affected code
function rescueToken(address token, address to, uint256 amount) external onlyOwner {
if (token == address(A_TOKEN)) revert InvalidAddress();
IERC20(token).safeTransfer(to, amount);
}
Proposed fix
Add STAKE_TOKEN to the rescue blacklist, or implement a more sophisticated rescue mechanism that only allows rescuing tokens that are not part of the protocol's accounting:
function rescueToken(address token, address to, uint256 amount) external onlyOwner {
    if (token == address(A_TOKEN)) revert InvalidAddress();
    if (token == address(STAKE_TOKEN)) revert InvalidAddress(); // Also protect stake token
    IERC20(token).safeTransfer(to, amount);
}
Note: If STAKE_TOKEN rescue is needed for emergency recovery, add a time-lock or multi-sig requirement.
8

Resolvers.sol
Majority Logic in resolveComposite Uses Integer Division - Incorrect for Even Feed Counts
In Resolvers.resolveComposite(), the Majority logic uses `trueCount > feedCount / 2` to determine if a majority of conditions are met. Due to integer division, for feedCount=2, feedCount/2=1, so the condition requires trueCount > 1, meaning BOTH feeds must be true for a majority. This is equivalent to AND logic for 2 feeds, not majority (which should be >50%, i.e., at least 1 out of 2). For feedCount=4, feedCount/2=2, requiring trueCount > 2, meaning at least 3 out of 4 must be true. This is a supermajority (75%), not a simple majority (>50% = at least 3 out of 4 is actually correct for 4 feeds). The issue is specifically with feedCount=2 where majority should mean 1 out of 2 but the code requires 2 out of 2.


Hide Details
Impact
For Composite markets with 2 feeds using Majority logic, the market behaves identically to AND logic. Users who expect a majority (1 out of 2) to win will be surprised when both conditions must be met. This could cause incorrect market outcomes and user losses when exactly 1 out of 2 conditions is met.
Scenario
1. Create a Composite market with feedCount=2, logic=Majority
2. Feed A condition: BTC >= $50,000 → met (BTC = $55,000)
3. Feed B condition: ETH >= $3,000 → not met (ETH = $2,500)
4. trueCount = 1
5. feedCount / 2 = 1 (integer division)
6. result = trueCount > 1 → 1 > 1 → false
7. Outcome 1 (NO) wins
8. Expected with true majority: 1 out of 2 = 50% → should be YES (majority met)
9. Users who bet YES lose despite a majority of conditions being met
Affected code
bool result;
if (logic == MarketTypes.CompositeLogic.And) {
result = trueCount == feedCount;
} else if (logic == MarketTypes.CompositeLogic.Or) {
result = trueCount > 0;
} else {
result = trueCount > feedCount / 2;
}
Proposed fix
Fix the majority calculation to use ceiling division for proper majority semantics:
} else { // Majority
    // Majority means strictly more than half
    // For feedCount=2: need > 1 (i.e., 2) - this is AND behavior
    // For feedCount=3: need > 1 (i.e., 2+)
    // For feedCount=4: need > 2 (i.e., 3+)
    // If intended as simple majority (>= ceil(feedCount/2)):
    result = trueCount * 2 > feedCount; // Equivalent to trueCount > feedCount/2 with proper rounding
}
Note: `trueCount * 2 > feedCount` correctly handles all cases:
- feedCount=2: need trueCount*2 > 2, i.e., trueCount > 1, i.e., trueCount >= 2 (AND behavior - may be intentional)
- feedCount=3: need trueCount*2 > 3, i.e., trueCount >= 2 (majority)
- feedCount=4: need trueCount*2 > 4, i.e., trueCount >= 3 (majority)
Document clearly what 'Majority' means for each feed count.
9

TrustedReporterAdapter.sol
Lack of Input Validation for OHLC Data: highE8 < lowE8 Not Checked
In TrustedReporterAdapter.postOhlcResult(), there is no validation that highE8 >= lowE8 or that closeE8 is within [lowE8, highE8]. A malicious or erroneous reporter could post OHLC data where high < low, or where close is outside the high-low range. This invalid OHLC data would be stored and used for market resolution (e.g., Corridor and Cascade markets use epochHighE8 and epochLowE8). Invalid OHLC data could cause incorrect market resolution.


Hide Details
Impact
Invalid OHLC data (e.g., high < low) could cause incorrect resolution of Corridor and Cascade markets. For example, if highE8 < lowE8, the Corridor resolution logic `if (highE8 >= upperBoundE8)` and `if (lowE8 <= lowerBoundE8)` could produce unexpected results. This could lead to incorrect payouts and user fund losses.
Scenario
1. Trusted reporter (or compromised key) signs OHLC data with highE8 = 40000e8, lowE8 = 60000e8 (inverted)
2. postOhlcResult() accepts this data (no validation)
3. Corridor market uses epochHighE8 = 40000 and epochLowE8 = 60000
4. resolveCorridor(40000, 60000, upperBound, lowerBound) is called
5. Since lowE8 (60000) > upperBound (say 55000), the condition `lowE8 <= lowerBoundE8` may not trigger
6. But `highE8 >= upperBoundE8` → 40000 >= 55000 → false
7. Result: outcome 0 (stayed in corridor) wins, even though the data is invalid
Affected code
function postOhlcResult(
bytes32 marketId,
int256 highE8,
int256 lowE8,
int256 closeE8,
uint64 observedAt,
bytes32 dataSourceHash,
bytes calldata signature
) external {
OhlcSample storage s = _ohlcSamples[marketId];
if (s.written) revert AlreadyResolved();
if (observedAt > block.timestamp) revert ObservedAtInFuture();
unchecked {
if (block.timestamp - uint256(observedAt) > maxSignatureAgeSeconds) revert SignatureTooOld();
}
// ... no validation of highE8 >= lowE8 or closeE8 in range
s.highE8 = highE8;
s.lowE8 = lowE8;
s.closeE8 = closeE8;
Proposed fix
Add validation for OHLC data integrity:
function postOhlcResult(
    bytes32 marketId,
    int256 highE8,
    int256 lowE8,
    int256 closeE8,
    uint64 observedAt,
    bytes32 dataSourceHash,
    bytes calldata signature
) external {
    // Validate OHLC data integrity
    if (highE8 < lowE8) revert InvalidOhlcData();
    if (closeE8 < lowE8 || closeE8 > highE8) revert InvalidOhlcData();
    
    // ... rest of function
}

error InvalidOhlcData();

gas Severity
2
1

MarketMath.sol
Gas Optimization: Redundant Storage Reads in computeClaimPayoutStorage
In MarketMath.computeClaimPayoutStorage(), the function reads epoch.outcomeCount and epoch.winningOutcomeMask multiple times from storage - once in totalWinningStake() and again in the winningPool calculation loop. Each storage read costs 2100 gas (cold) or 100 gas (warm). The function could cache these values in memory variables to reduce gas costs.


Hide Details
Impact
Higher gas costs for claim operations. In a high-volume prediction market, this could significantly increase user costs for claiming payouts.
Scenario
N/A - Gas optimization issue
Affected code
function computeClaimPayoutStorage(
MarketTypes.Epoch storage epoch,
uint256[8] memory stakes,
uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
userWinningStake_ = totalWinningStake(epoch.winningOutcomeMask, epoch.outcomeCount, stakes);
if (userWinningStake_ == 0) return (0, 0);

uint256 winningPool = 0;
for (uint256 i = 0; i < epoch.outcomeCount; i++) {
if ((epoch.winningOutcomeMask >> i) & 1 == 1) {
winningPool += epoch.outcomePools[i];
}
}
Proposed fix
Cache storage values in memory variables:
function computeClaimPayoutStorage(
    MarketTypes.Epoch storage epoch,
    uint256[8] memory stakes,
    uint256 remainingClaimsForEpoch
) internal view returns (uint256 payout, uint256 userWinningStake_) {
    // Cache storage reads
    uint256 winningMask = epoch.winningOutcomeMask;
    uint8 outcomeCount = epoch.outcomeCount;
    
    userWinningStake_ = totalWinningStake(winningMask, outcomeCount, stakes);
    if (userWinningStake_ == 0) return (0, 0);

    uint256 winningPool = 0;
    for (uint256 i = 0; i < outcomeCount; i++) {
        if ((winningMask >> i) & 1 == 1) {
            winningPool += epoch.outcomePools[i];
        }
    }
    // ...
}
2

Resolvers.sol
Gas Optimization: Loop in resolveRangeClose Starts at i=1 But Could Start at i=0 with Bounds Check
In Resolvers.resolveRangeClose(), when value >= rangeBoundsE8[0], the loop starts at i=1 and checks `value < rangeBoundsE8[i]`. The loop could be simplified by starting at i=0 and checking all bounds uniformly, eliminating the special case for the first bound. This would reduce code complexity and potentially save gas by removing the branch.


Hide Details
Impact
Minor gas inefficiency and code complexity. No security impact.
Scenario
N/A - Gas optimization
Affected code
if (value < rangeBoundsE8[0]) {
idx = 0;
} else {
idx = uint256(outcomeCount) - 1;
for (uint256 i = 1; i < uint256(outcomeCount) - 1; i++) {
if (value < rangeBoundsE8[i]) {
idx = i;
break;
}
}
}
Proposed fix
Simplify the loop structure:
uint256 idx = uint256(outcomeCount) - 1; // Default to last bucket
for (uint256 i = 0; i < uint256(outcomeCount) - 1; i++) {
    if (value < rangeBoundsE8[i]) {
        idx = i;
        break;
    }
}
return uint256(1) << idx;
This is equivalent but simpler and avoids the special case for the first bound.

informational Severity
1
1

TrustedReporterAdapter.sol
Informational: TrustedReporterAdapter Single Point of Failure - Centralization Risk
The TrustedReporterAdapter relies on a single `trustedReporter` address for all oracle data submissions. This creates a single point of failure: if the reporter key is compromised, lost, or the reporter becomes unavailable, all markets using TrustedReporter oracle kind will be unable to resolve. The owner can update the reporter address, but this requires the owner to be available and responsive. There is no multi-sig, threshold signature, or fallback mechanism.


Hide Details
Impact
If the trustedReporter key is compromised: attacker can post arbitrary oracle data, manipulating all TrustedReporter markets. If the key is lost: all TrustedReporter markets become permanently unresolvable, locking user funds. This is a significant centralization risk for a financial protocol.
Scenario
N/A - Centralization/design risk
Affected code
address public trustedReporter;

function setTrustedReporter(address newReporter) external onlyOwner {
if (newReporter == address(0)) revert ZeroAddress();
emit TrustedReporterUpdated(trustedReporter, newReporter);
trustedReporter = newReporter;
}
Proposed fix
Consider implementing a multi-reporter scheme with threshold signatures, or use a time-locked reporter rotation mechanism:
// Option 1: Multiple reporters with threshold
address[] public trustedReporters;
uint256 public requiredSignatures;

// Option 2: Time-locked reporter updates
uint256 public reporterUpdateDelay = 24 hours;
address public pendingReporter;
uint256 public reporterUpdateTime;

function proposeReporter(address newReporter) external onlyOwner {
    pendingReporter = newReporter;
    reporterUpdateTime = block.timestamp + reporterUpdateDelay;
}

function acceptReporter() external onlyOwner {
    require(block.timestamp >= reporterUpdateTime, "Too early");
    trustedReporter = pendingReporter;
}