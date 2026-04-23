DeFi Yield Router / Aave v3 Integration

YieldRouterV2 is an Aave v3 yield routing contract that manages staked token deposits into Aave's lending pool, supporting two yield paths: direct aToken (scaled balance) accounting and ERC-4626 StataToken (wrapped aToken) accounting. It tracks per-template yield positions using scaled balances to correctly account for accrued interest, supports liquidity mining reward sweeps, and provides proportional withdrawal mechanics. The contract is governed by an owner (admin) and an authorized MarketEngine that gates all mutating operations.

Show less
Access Control
custom


Privileged Roles
1
ENGINE (immutable address)
2
Owner (Ownable2Step)

External Calls
1
IPoolAaveV3
2
IScaledBalanceToken (A_TOKEN)
3
IERC4626 (STATA_TOKEN)
4
IRewardsController
5
IERC20 (STAKE_TOKEN)
6
IERC20 (A_TOKEN)

External Systems
1
Aave v3 Lending Pool
2
ERC-4626 StataToken Vault
3
Aave Rewards Controller
4
MarketEngine (ENGINE)

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


high Severity
2
1

YieldRouterV2.sol
rescueToken Allows Owner to Steal StataToken Shares from All Templates
The `rescueToken` function in `YieldRouterV2` blocks rescue of `A_TOKEN` and `STAKE_TOKEN` but does NOT block rescue of `STATA_TOKEN`. Since the StataToken path stores ERC-4626 shares in the router contract itself (tracked via `t.stataShares`), the owner can call `rescueToken(address(STATA_TOKEN), attackerAddress, amount)` to transfer all StataToken shares out of the router. This would drain all StataToken-path template positions, leaving `t.stataShares` accounting intact but the actual shares gone, making all subsequent withdrawals fail or return zero.


Hide Details
Impact
Owner can steal all StataToken shares held by the router, effectively draining all StataToken-path template positions. Users whose templates use the StataToken path would be unable to withdraw their funds. This is a high-severity rug vector for the owner.
Scenario
// Owner calls rescueToken with STATA_TOKEN address
// 1. Multiple templates have deposited via StataToken path, router holds N stata shares
// 2. Owner calls: router.rescueToken(address(STATA_TOKEN), attackerEOA, stataToken.balanceOf(address(router)))
// 3. All stata shares transferred to attacker
// 4. t.stataShares still shows non-zero values for all templates
// 5. Any subsequent withdrawScaled call for StataToken-path templates will call STATA_TOKEN.redeem() but router has no shares -> reverts or returns 0
// 6. User funds are permanently locked/stolen
Affected code
function rescueToken(address token, address to, uint256 amount) external onlyOwner {
if (token == address(A_TOKEN) || token == address(STAKE_TOKEN)) revert InvalidAddress();
IERC20(token).safeTransfer(to, amount);
}
Proposed fix
Add `STATA_TOKEN` to the blocked token list in `rescueToken`:
function rescueToken(address token, address to, uint256 amount) external onlyOwner {
    if (
        token == address(A_TOKEN) ||
        token == address(STAKE_TOKEN) ||
        token == address(STATA_TOKEN)
    ) revert InvalidAddress();
    IERC20(token).safeTransfer(to, amount);
}
2

YieldRouterV2.sol
emergencyWithdraw Callable by Owner Without Timelock Enables Rug Vector
The `emergencyWithdraw` function is callable by both `ENGINE` and `owner()`. The owner has no timelock, multi-sig requirement, or delay mechanism. A compromised or malicious owner can immediately call `emergencyWithdraw` for any templateId, withdrawing all funds to `ENGINE`. While funds go to ENGINE (not directly to the owner), if the owner also controls ENGINE or can influence ENGINE's fund distribution, this creates a complete rug vector. Furthermore, the owner can call `emergencyWithdraw` for all templates in a single block, draining the entire protocol.


Hide Details
Impact
A compromised owner key can immediately drain all template positions by calling emergencyWithdraw for each templateId. Funds are sent to ENGINE, but if the owner controls ENGINE or can front-run ENGINE's distribution logic, user funds can be stolen. This is a critical centralization risk.
Scenario
// 1. Attacker compromises owner private key
// 2. Attacker calls emergencyWithdraw(templateId1), emergencyWithdraw(templateId2), ...
// 3. All template positions are fully unwound, funds sent to ENGINE
// 4. If attacker controls ENGINE or can exploit ENGINE's fund handling, funds are stolen
// 5. All user positions are zeroed out
Affected code
function emergencyWithdraw(bytes32 templateId) external override returns (uint256 grossAmount) {
if (msg.sender != ENGINE && msg.sender != owner()) revert Unauthorized();
TemplateYield storage t = _templates[templateId];
uint256 p = t.principal;
if (p == 0) return 0;
grossAmount = _withdrawScaled(templateId, p, true);
emit EmergencyWithdrawV2(templateId, grossAmount);
}
Proposed fix
Consider restricting `emergencyWithdraw` to ENGINE only, with a separate owner-gated pause mechanism that requires ENGINE to execute the actual withdrawal:
// Option 1: Restrict to ENGINE only
function emergencyWithdraw(bytes32 templateId) external override onlyEngine returns (uint256 grossAmount) {
    // ...
}

// Option 2: Add timelock for owner-initiated emergency withdrawals
mapping(bytes32 => uint256) public emergencyWithdrawTimelocks;
uint256 public constant EMERGENCY_TIMELOCK = 2 days;

function initiateEmergencyWithdraw(bytes32 templateId) external onlyOwner {
    emergencyWithdrawTimelocks[templateId] = block.timestamp + EMERGENCY_TIMELOCK;
}

function executeEmergencyWithdraw(bytes32 templateId) external onlyOwner {
    require(block.timestamp >= emergencyWithdrawTimelocks[templateId], "Timelock active");
    // ...
}

medium Severity
6
1

YieldRouterV2.sol
Fee-on-Transfer Token Accounting Mismatch Causes Principal Inflation and Insolvency
In `_depositScaled`, the contract transfers `amount` of `STAKE_TOKEN` from `ENGINE` to the router using `safeTransferFrom`, then uses `amount` directly for accounting (`t.principal += amount`). If `STAKE_TOKEN` is a fee-on-transfer token, the actual received amount will be less than `amount`. The contract then supplies the full `amount` to Aave (which would fail if the router doesn't hold enough), or if the token deducts fees on the Aave supply call, the aToken minted will be less than `amount`. The principal tracking will be inflated relative to actual deposited value, causing `OverWithdraw` errors or insolvency when users attempt to withdraw their full principal.


Hide Details
Impact
If STAKE_TOKEN is a fee-on-transfer token, principal accounting is inflated. Users cannot withdraw their full tracked principal because the actual Aave position is smaller. This leads to OverWithdraw reverts or, in the worst case, one user's withdrawal drains another user's principal.
Scenario
// Assume STAKE_TOKEN charges 1% fee on transfer
// 1. ENGINE calls depositScaled(templateId, 1000e18)
// 2. Router receives 990e18 (after 1% fee)
// 3. Router supplies 990e18 to Aave (or fails if it tries to supply 1000e18)
// 4. t.principal = 1000e18 (inflated)
// 5. Later, ENGINE calls withdrawScaled(templateId, 1000e18)
// 6. proportionalUnderlying computes based on inflated principal
// 7. Aave position only has ~990e18 worth -> OverWithdraw or shortfall
Affected code
function _depositScaled(bytes32 templateId, uint256 amount) internal returns (uint256 attributionUnits) {
if (amount == 0) revert ZeroAmount();
TemplateYield storage t = _templates[templateId];
// ...
STAKE_TOKEN.safeTransferFrom(ENGINE, address(this), amount);
// amount used directly without checking actual received balance
// ...
t.principal += amount; // inflated if fee-on-transfer
t.scaledPrincipal += attributionUnits;
// ...
}
Proposed fix
Measure the actual received balance by checking balance before and after the transfer:
uint256 balBefore = STAKE_TOKEN.balanceOf(address(this));
STAKE_TOKEN.safeTransferFrom(ENGINE, address(this), amount);
uint256 actualReceived = STAKE_TOKEN.balanceOf(address(this)) - balBefore;
// Use actualReceived for accounting instead of amount
t.principal += actualReceived;
Alternatively, document that fee-on-transfer tokens are explicitly not supported and add a check in the constructor or deposit function.
2

YieldRouterV2.sol
Hardcoded Aave v3 ReserveConfigurationMap Bit Offsets May Silently Fail on Forks
The `_requireReserveHealthy` and `_requireReserveWithdrawable` functions hardcode bit positions 56 (active), 57 (frozen), and 60 (paused) from the Aave v3 `ReserveConfigurationMap`. These offsets are specific to Aave v3.0.x and may differ in Aave forks, upgraded versions, or alternative deployments. If the bit layout differs, the reserve health checks will silently pass or fail incorrectly. For example, if a fork uses bit 60 for a different flag, a paused reserve would not be detected, allowing deposits into an unhealthy reserve where funds could be locked.


Hide Details
Impact
On Aave forks with different bit layouts, reserve health checks could silently pass for frozen/paused/inactive reserves, allowing deposits into unhealthy reserves where funds may be locked or lost. Conversely, healthy reserves could be incorrectly flagged as unhealthy, causing DoS.
Scenario
// Scenario: Deployed on an Aave fork where 'paused' flag is at bit 58 instead of 60
// 1. Aave fork pauses the reserve (sets bit 58)
// 2. _requireReserveHealthy checks bit 60 (which is 0 = not paused)
// 3. Check passes, deposit proceeds into paused reserve
// 4. Funds may be locked in the paused reserve
// 5. Users cannot withdraw until reserve is unpaused
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
Use Aave's official DataTypes library or dedicated getter functions rather than raw bit manipulation. If raw bit manipulation must be used, add a version check or document the exact Aave version and contract address this was verified against. Consider adding an integration test that verifies the bit layout against the live Aave deployment:
// Use Aave's IPool.getReserveData() which returns structured data
// Or import Aave's DataTypes library for bit-safe access
// At minimum, add a comment with the exact Aave v3 commit hash verified
3

YieldRouterV2.sol
claimLmRewards Claims All Router Rewards Regardless of templateId, Misattributing Cross-Template Rewards
The `claimLmRewards` function accepts a `templateId` parameter but completely ignores it. It claims ALL liquidity mining rewards for the router's entire aToken position (`claimAllRewards(assets, ENGINE)`), regardless of which template is specified. Since multiple templates share one router and one aToken position, calling `claimLmRewards` for template A will also claim rewards attributable to templates B, C, D, etc. This means one template's reward claim can front-run or steal rewards from other templates, and the event emission (`LMRewardsClaimed`) incorrectly attributes all rewards to the specified templateId.


Hide Details
Impact
LM rewards are misattributed in events, making off-chain accounting incorrect. One template's reward claim drains rewards for all templates simultaneously. If the ENGINE distributes rewards based on event data, users of other templates may receive incorrect reward amounts. This could lead to unfair reward distribution or loss of rewards for some template participants.
Scenario
// 1. Template A has 10% of total router position, Template B has 90%
// 2. ENGINE calls claimLmRewards(templateA_id)
// 3. ALL rewards (100%) are claimed and sent to ENGINE, attributed to templateA in events
// 4. Template B's proportional rewards (90%) are now claimed under templateA's event
// 5. Off-chain systems tracking LMRewardsClaimed events will incorrectly attribute 100% to templateA
// 6. Template B participants receive no reward credit despite their larger position
Affected code
function claimLmRewards(bytes32 templateId)
external
override
onlyEngine
returns (address[] memory rewardsList, uint256[] memory amounts)
{
address rc = address(REWARDS_CONTROLLER);
if (rc == address(0)) {
return (new address[](0), new uint256[](0));
}
address[] memory assets = new address[](1);
assets[0] = address(A_TOKEN);
(rewardsList, amounts) = IRewardsController(rc).claimAllRewards(assets, ENGINE);
uint256 n = rewardsList.length;
for (uint256 i; i < n; ++i) {
if (amounts[i] > 0) {
emit LMRewardsClaimed(templateId, rewardsList[i], amounts[i]); // templateId is misleading
}
}
}
Proposed fix
Either: (1) Document clearly that rewards are claimed globally and rename/update the interface to reflect this, removing the misleading templateId parameter; or (2) Implement per-template reward tracking using proportional share of scaledPrincipal:
// Option 1: Remove templateId from signature or emit a global event
event LMRewardsClaimedGlobal(address indexed rewardToken, uint256 amount);

// Option 2: Track per-template reward attribution proportionally
// Emit separate events per template based on their scaledPrincipal share
4

YieldRouterV2.sol
StataToken Withdrawal May Under-Deliver Due to previewWithdraw Rounding Without Slippage Check
In `_withdrawScaled` for the StataToken path, `sharesToRedeem` is computed via `STATA_TOKEN.previewWithdraw(underlyingRequest)`. Per ERC-4626 spec, `previewWithdraw` MUST round UP (ceiling) to ensure the vault takes enough shares to deliver the requested assets. However, the actual `redeem` call uses `sharesToRedeem` shares and returns `grossAmount` which may be less than `underlyingRequest` due to rounding differences between `previewWithdraw` and `redeem`. There is no minimum output check on `grossAmount`. Additionally, the cap `if (sharesToRedeem > sharesTotal) sharesToRedeem = sharesTotal` can silently reduce the shares redeemed below what's needed to deliver `underlyingRequest`, causing under-delivery without any revert.


Hide Details
Impact
Users may receive less underlying than their proportional share entitles them to. The principal is still decremented by the full `principalAmount`, meaning the accounting shows the full withdrawal occurred but the user received less. Over time, this creates a growing discrepancy between tracked principal and actual position value, potentially causing the last withdrawer to receive significantly less than expected.
Scenario
// 1. Template has 100 stata shares worth 1000 USDC, principal = 1000 USDC
// 2. User requests partial withdrawal: principalAmount = 500 USDC
// 3. underlyingRequest = mulDiv(1000, 500, 1000) = 500 USDC
// 4. previewWithdraw(500) returns 51 shares (rounds up per ERC-4626)
// 5. redeem(51 shares) returns 499.9 USDC (actual redeem rounds down)
// 6. grossAmount = 499.9 USDC sent to ENGINE
// 7. t.principal reduced by 500 USDC (full amount)
// 8. User receives 499.9 USDC but 500 USDC was debited from their principal
Affected code
uint256 sharesToRedeem = principalAmount == p ? sharesTotal : STATA_TOKEN.previewWithdraw(underlyingRequest);
if (sharesToRedeem > sharesTotal) sharesToRedeem = sharesTotal;
grossAmount = STATA_TOKEN.redeem(sharesToRedeem, ENGINE, address(this));
t.stataShares = sharesTotal - sharesToRedeem;
t.principal = p - principalAmount;
Proposed fix
Add a minimum output check after the redeem call:
grossAmount = STATA_TOKEN.redeem(sharesToRedeem, ENGINE, address(this));
// Ensure we delivered at least the floor of what was requested
// Allow small rounding tolerance (e.g., 1 wei)
if (grossAmount + 1 < underlyingRequest && principalAmount != p) {
    // Log or handle under-delivery; consider reverting or adjusting principal
    // At minimum, adjust principal deduction to match actual delivery
}
t.stataShares = sharesTotal - sharesToRedeem;
t.principal = p - principalAmount;
Alternatively, use `convertToShares` (which rounds down) instead of `previewWithdraw` (which rounds up) for more predictable behavior, and accept that slightly fewer assets may be returned.
5

YieldRouterV2.sol
Unlimited Max Approval to External Contracts Creates Systemic Risk
The constructor grants `type(uint256).max` approval of `STAKE_TOKEN` to both `AAVE_POOL` and `STATA_TOKEN`. These are set once and never revoked. If either `AAVE_POOL` or `STATA_TOKEN` is upgraded to a malicious implementation (e.g., via a proxy upgrade), or if a vulnerability is discovered in either contract, the attacker could drain the router's entire `STAKE_TOKEN` balance (including any tokens temporarily held during deposit operations) without any additional authorization. There is no mechanism to revoke or reduce these approvals.


Hide Details
Impact
If AAVE_POOL or STATA_TOKEN is compromised or upgraded maliciously, the attacker can drain all STAKE_TOKEN held by the router. While the router typically holds STAKE_TOKEN only transiently during deposit operations, the unlimited approval persists indefinitely and represents a systemic risk.
Scenario
// Scenario: STATA_TOKEN is a proxy contract
// 1. Proxy admin upgrades STATA_TOKEN to malicious implementation
// 2. Malicious implementation calls STAKE_TOKEN.transferFrom(router, attacker, router.balance)
// 3. Since router has max approval to STATA_TOKEN, transfer succeeds
// 4. All STAKE_TOKEN in router is drained
Affected code
constructor(
// ...
) Ownable(msg.sender) {
// ...
STAKE_TOKEN.forceApprove(aavePool_, type(uint256).max);
if (stataToken_ != address(0)) {
STAKE_TOKEN.forceApprove(stataToken_, type(uint256).max);
}
}
Proposed fix
Consider using exact-amount approvals per operation, or implement an approval management function:
// Option 1: Approve exact amount before each operation
STAKE_TOKEN.forceApprove(address(AAVE_POOL), amount);
AAVE_POOL.supply(address(STAKE_TOKEN), amount, address(this), 0);
STAKE_TOKEN.forceApprove(address(AAVE_POOL), 0); // Reset after

// Option 2: Add owner-callable approval reset
function revokeApprovals() external onlyOwner {
    STAKE_TOKEN.forceApprove(address(AAVE_POOL), 0);
    if (address(STATA_TOKEN) != address(0)) {
        STAKE_TOKEN.forceApprove(address(STATA_TOKEN), 0);
    }
}
6

YieldRouterV2.sol
scaledPrincipal Can Silently Zero Out on Partial Withdrawal Due to Defensive Underflow Guard
In `_withdrawScaled` for the AToken path, after computing `scaledBurned = scaledBefore - scaledAfter`, the code has a defensive guard: `if (scaledBurned > t.scaledPrincipal) { t.scaledPrincipal = 0; }`. This guard silently zeros out `scaledPrincipal` if Aave burns more scaled balance than the template's tracked `scaledPrincipal`. This can happen legitimately due to rounding, but it can also mask a scenario where multiple templates share the router and one template's withdrawal burns scaled balance attributed to another template. The silent zeroing means subsequent operations on the affected template will see `scaledPrincipal = 0` and revert with `OverWithdraw`, effectively locking remaining funds.


Hide Details
Impact
If `scaledBurned` exceeds `t.scaledPrincipal` during a partial withdrawal (due to rounding or cross-template interference), `scaledPrincipal` is silently zeroed while `principal` still has a non-zero value. Subsequent partial withdrawals will hit `if (s == 0) revert OverWithdraw()`, locking the remaining principal. The template's funds are stuck until an emergency withdrawal is performed.
Scenario
// 1. Template A has principal=1000, scaledPrincipal=950 (after some rounding)
// 2. Partial withdrawal: principalAmount=500
// 3. proportionalUnderlying computes underlyingToWithdraw
// 4. Aave burns 951 scaled units (due to rounding in Aave's internal math)
// 5. scaledBurned = 951 > t.scaledPrincipal = 950
// 6. t.scaledPrincipal = 0 (silently zeroed)
// 7. t.principal = 500 (still non-zero)
// 8. Next withdrawal attempt: s = t.scaledPrincipal = 0 -> revert OverWithdraw
// 9. Remaining 500 principal is stuck (only emergency withdraw can recover)
Affected code
if (principalAmount == p) {
t.scaledPrincipal = 0;
} else {
if (scaledBurned > t.scaledPrincipal) {
t.scaledPrincipal = 0; // Silent zeroing - may mask accounting errors
} else {
t.scaledPrincipal -= scaledBurned;
}
}
Proposed fix
Instead of silently zeroing, emit a warning event and use the actual burned amount for accounting. Also consider using `saturatingSub` to prevent the issue:
if (principalAmount == p) {
    t.scaledPrincipal = 0;
} else {
    // Use saturating subtraction to handle rounding
    t.scaledPrincipal = scaledBurned >= t.scaledPrincipal ? 0 : t.scaledPrincipal - scaledBurned;
    if (scaledBurned > t.scaledPrincipal + scaledBurned) { // was zeroed
        emit ScaledPrincipalDriftDetected(templateId, scaledBurned, t.scaledPrincipal);
    }
}
Additionally, ensure the emergency withdrawal path can handle `scaledPrincipal = 0` with non-zero `principal` gracefully.

low Severity
5
1

YieldAccounting.sol
rayMul Overflow Risk for Large Values in YieldAccounting Library
The `rayMul` function in `YieldAccounting` computes `(a * b + HALF_RAY) / RAY`. The intermediate computation `a * b` can overflow `uint256` for large values of `a` and `b`. Specifically, if `a` and `b` are both close to `type(uint256).max / RAY` (~1.16e50), the multiplication `a * b` will overflow. While Solidity 0.8.x has built-in overflow protection that would revert, this means large positions could cause unexpected DoS on deposit/withdrawal operations. The `scaledToReal` function (which calls `rayMul`) is used in critical withdrawal paths.


Hide Details
Impact
For extremely large positions (scaled balance near uint256 max / 1e27), `rayMul` will revert due to overflow, causing DoS on withdrawal operations. While this requires astronomically large positions (>1.16e50 tokens), it's a theoretical DoS vector for high-value deployments with small-decimal tokens.
Scenario
// Theoretical overflow scenario:
// scaledBalance = 1.16e50 (near uint256.max / RAY)
// liquidityIndex = 1e27 (RAY)
// rayMul(1.16e50, 1e27) -> 1.16e50 * 1e27 overflows uint256
// Solidity 0.8 reverts -> withdrawal DoS
Affected code
function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
if (a == 0 || b == 0) return 0;
return (a * b + HALF_RAY) / RAY;
}
Proposed fix
Use OpenZeppelin's `Math.mulDiv` for overflow-safe ray multiplication:
function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0) return 0;
    // Use mulDiv to avoid overflow: (a * b + HALF_RAY) / RAY
    return Math.mulDiv(a, b, RAY, Math.Rounding.Floor) + 
           (((a % RAY) * (b % RAY) + HALF_RAY) / RAY > 0 ? 1 : 0);
    // Or simpler: use mulDiv with ceiling for the HALF_RAY rounding
    return (Math.mulDiv(a, b, RAY) + (Math.mulDiv(a % RAY, b % RAY, RAY) >= HALF_RAY / RAY ? 1 : 0));
}
// Simplest safe version:
function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0) return 0;
    return Math.mulDiv(a, b, RAY, Math.Rounding.Floor);
}
2

YieldRouterV2.sol
globalScaledBalance Stale Cache Can Mislead Integrators and Cause Accounting Drift
`globalScaledBalance` is a cached state variable updated only during mutating operations (`_depositScaled`, `_withdrawScaled`). Between operations, as Aave interest accrues, the live `scaledBalanceOf(address(this))` diverges from the cached value. Additionally, if aTokens are directly transferred to the router (donations), or if the StataToken path and AToken path are both active simultaneously, the cached value may not accurately reflect the total position. The variable is declared as `public` and named `globalScaledBalance`, which strongly implies it's a live/authoritative value, but it's actually a stale snapshot.


Hide Details
Impact
Integrators or off-chain systems reading `globalScaledBalance` may make incorrect decisions about available liquidity, yield accrual, or position sizing. In the worst case, if the ENGINE uses this value for critical calculations (e.g., determining how much yield has accrued), it could lead to incorrect fee calculations or withdrawal amounts.
Scenario
// 1. At T=0: depositScaled called, globalScaledBalance = 1000 (scaled units)
// 2. At T=1 day: Interest accrues, live scaledBalanceOf still = 1000 (scaled is constant)
// BUT underlying value has grown from 1000 USDC to 1010 USDC
// 3. globalScaledBalance still = 1000 (correct for scaled, but misleading name)
// 4. Direct aToken transfer: someone sends 100 aTokens to router
// 5. Live scaledBalanceOf = 1100, but globalScaledBalance = 1000
// 6. Integrator reads globalScaledBalance = 1000, makes decisions based on stale data
Affected code
/// @notice Cached total scaled aToken balance for this router (`scaledBalanceOf` on `A_TOKEN`) after each mutating AToken-path or Stata-path op.
/// @dev Do not treat as a live oracle across blocks — prefer `IScaledBalanceToken(A_TOKEN).scaledBalanceOf(address(this))` for authoritative reads.
uint256 public globalScaledBalance;
Proposed fix
Either remove `globalScaledBalance` as a public state variable and replace with a live view function, or clearly rename it to indicate it's a snapshot:
// Option 1: Replace with live view
function globalScaledBalance() external view returns (uint256) {
    return IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
}

// Option 2: Rename to indicate staleness
uint256 public lastSnapshotScaledBalance; // renamed from globalScaledBalance
3

YieldRouterV2.sol
pendingLmRewards Ignores templateId Parameter - Misleading Interface
The `pendingLmRewards` function accepts a `templateId` parameter but explicitly ignores it (the line `templateId;` is a no-op statement to suppress compiler warnings). The function returns pending rewards for the entire router's aToken position, not for the specific template. This is misleading to callers who expect per-template reward data. The function signature implies template-scoped rewards but delivers router-wide rewards, which could cause incorrect reward distribution calculations in the ENGINE or off-chain systems.


Hide Details
Impact
Callers expecting per-template pending rewards will receive the total router-wide pending rewards. If the ENGINE uses this to calculate per-template reward distributions, it will over-report rewards for individual templates, potentially leading to incorrect reward accounting or double-counting when multiple templates query their pending rewards.
Scenario
// 1. Template A has 10% of router position, Template B has 90%
// 2. Total pending rewards = 1000 tokens
// 3. ENGINE calls pendingLmRewards(templateA_id) -> returns 1000 tokens
// 4. ENGINE calls pendingLmRewards(templateB_id) -> returns 1000 tokens
// 5. ENGINE believes 2000 tokens are pending (double-counted)
// 6. Incorrect reward distribution calculations
Affected code
function pendingLmRewards(bytes32 templateId)
external
view
override
returns (address[] memory tokens, uint256[] memory pending)
{
templateId; // explicitly ignored - misleading
address rc = address(REWARDS_CONTROLLER);
if (rc == address(0)) {
return (new address[](0), new uint256[](0));
}
address[] memory assets = new address[](1);
assets[0] = address(A_TOKEN);
return IRewardsController(rc).getAllUserRewards(assets, address(this));
}
Proposed fix
Either update the interface to remove the `templateId` parameter (making it a global view), or implement actual per-template reward tracking:
// Option 1: Remove templateId, make it a global view
function pendingLmRewards() external view returns (address[] memory tokens, uint256[] memory pending) {
    // ...
}

// Option 2: Add NatSpec clarifying the behavior
/// @notice Returns TOTAL router pending LM rewards (not per-template).
/// @dev templateId is ignored; rewards are not tracked per-template.
function pendingLmRewards(bytes32 /* templateId */)
    external view override
    returns (address[] memory tokens, uint256[] memory pending)
{
    // ...
}
4

YieldRouterV2.sol
Missing Zero-Address Validation for rewardsController_ and stataToken_ in Constructor
The constructor validates that `stakeToken_`, `aavePool_`, `aToken_`, and `engine_` are non-zero, but does NOT validate `rewardsController_` and `stataToken_`. While zero addresses for these are handled gracefully in the code (no-op for rewards, StataNotConfigured for stata path), the `STATA_TOKEN` is set as an immutable `IERC4626` cast from `address(0)`. Calling any ERC-4626 function on a zero-address IERC4626 will revert with an EVM error rather than a clean custom error. Additionally, if `stataToken_` is accidentally set to a non-zero invalid address, the constructor will approve it without validation.


Hide Details
Impact
Low impact as zero-address cases are handled, but if an invalid non-zero address is passed for `stataToken_`, the router will grant max approval to an arbitrary address. This is a configuration risk rather than an exploitable vulnerability in normal operation.
Scenario
// Accidental misconfiguration:
// 1. Deployer passes wrong address for stataToken_ (e.g., a random EOA)
// 2. Constructor grants type(uint256).max approval to that EOA
// 3. That EOA can drain all STAKE_TOKEN from the router
// 4. No validation prevents this
Affected code
constructor(
address stakeToken_,
address aavePool_,
address aToken_,
address rewardsController_,
address stataToken_,
address engine_
) Ownable(msg.sender) {
if (stakeToken_ == address(0) || aavePool_ == address(0) || aToken_ == address(0) || engine_ == address(0)) {
revert InvalidAddress();
}
// rewardsController_ and stataToken_ not validated
STATA_TOKEN = IERC4626(stataToken_);
// ...
if (stataToken_ != address(0)) {
STAKE_TOKEN.forceApprove(stataToken_, type(uint256).max);
}
}
Proposed fix
Add validation for `stataToken_` if it's non-zero to ensure it implements the ERC-4626 interface:
if (stataToken_ != address(0)) {
    // Validate it's a contract
    require(stataToken_.code.length > 0, "stataToken not a contract");
    STAKE_TOKEN.forceApprove(stataToken_, type(uint256).max);
}
5

YieldRouterV2.sol
Aave Pool withdraw() Return Value Not Validated Against Expected Amount
In `_withdrawScaled` for the AToken path, `AAVE_POOL.withdraw()` is called with a specific `underlyingToWithdraw` amount, and the return value is used as `grossAmount`. However, there is no validation that `grossAmount` equals `underlyingToWithdraw`. Aave's `withdraw` function can return less than requested if there's insufficient liquidity (though it typically reverts in this case). More importantly, the principal deduction `t.principal = p - principalAmount` always deducts the full `principalAmount` regardless of how much was actually withdrawn. If Aave returns less than expected for any reason, the accounting will show a larger principal reduction than the actual withdrawal.


Hide Details
Impact
If Aave returns less than `underlyingToWithdraw` (due to rounding, partial liquidity, or edge cases), the principal is still fully decremented. This creates a growing discrepancy between tracked principal and actual Aave position value, potentially causing the last withdrawer to receive less than their fair share.
Scenario
// Edge case scenario:
// 1. underlyingToWithdraw = 1000 USDC
// 2. Aave returns grossAmount = 999 USDC (1 wei rounding)
// 3. t.principal -= principalAmount (full amount deducted)
// 4. Accounting shows full withdrawal but 1 USDC less was received
// 5. Over many operations, this drift accumulates
Affected code
grossAmount = AAVE_POOL.withdraw(address(STAKE_TOKEN), underlyingToWithdraw, ENGINE);
uint256 scaledAfter = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
uint256 scaledBurned = scaledBefore - scaledAfter;
// ...
t.principal = p - principalAmount; // always deducts full principalAmount
Proposed fix
Add a minimum output check or adjust principal deduction based on actual returned amount:
grossAmount = AAVE_POOL.withdraw(address(STAKE_TOKEN), underlyingToWithdraw, ENGINE);
// Validate return matches expectation (allow 1 wei tolerance for rounding)
if (grossAmount + 1 < underlyingToWithdraw) {
    revert InsufficientWithdrawal(underlyingToWithdraw, grossAmount);
}

gas Severity
2
1

YieldRouterV2.sol
Gas Optimization: Redundant scaledBalanceOf Calls in StataToken Deposit Path
In `_depositScaled` for the StataToken path, `globalScaledBalance` is updated by calling `IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this))`. However, when using the StataToken path, the router doesn't directly hold aTokens - the StataToken vault holds them. The `scaledBalanceOf` call for the router's address in the StataToken path may return 0 or an incorrect value if the router doesn't directly hold aTokens. This call is potentially wasteful and misleading.


Hide Details
Impact
Gas waste from unnecessary external call. `globalScaledBalance` may be incorrectly set to 0 or a stale value when only StataToken-path templates exist, misleading integrators about the router's total position.
Scenario
// 1. All templates use StataToken path
// 2. Router holds no aTokens directly (StataToken vault holds them)
// 3. scaledBalanceOf(router) = 0
// 4. globalScaledBalance = 0 after each StataToken deposit
// 5. Integrators reading globalScaledBalance see 0 despite significant positions
Affected code
// StataToken path in _depositScaled:
uint256 shares = STATA_TOKEN.deposit(amount, address(this));
t.principal += amount;
t.stataShares += shares;
globalScaledBalance = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this)); // potentially 0 for stata path
Proposed fix
For the StataToken path, consider not updating `globalScaledBalance` (since it's not meaningful for stata positions), or compute it differently:
// Option 1: Skip globalScaledBalance update for StataToken path
// (document that globalScaledBalance only reflects AToken-path positions)

// Option 2: Include stata-equivalent scaled balance
// uint256 stataScaled = STATA_TOKEN.convertToAssets(shares) scaled by index
// globalScaledBalance = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
// + stataEquivalentScaled;
2

YieldRouterV2.sol
Gas Optimization: Double Storage Read of _templates[templateId] in _withdrawScaled
In `_withdrawScaled`, the `TemplateYield storage t = _templates[templateId]` is read once, but `t.path`, `t.principal`, `t.scaledPrincipal`, `t.stataShares` are all accessed multiple times through the storage pointer. While Solidity storage pointers are efficient, the function could be further optimized by caching frequently accessed values in memory variables, especially `t.principal` which is read as `p` but `t.principal` is also accessed directly in some comparisons.


Hide Details
Impact
Minor gas inefficiency. No security impact.
Scenario
// No exploit - gas optimization finding
Affected code
function _withdrawScaled(bytes32 templateId, uint256 principalAmount, bool emergency) internal returns (uint256 grossAmount) {
// ...
TemplateYield storage t = _templates[templateId];
uint256 p = t.principal; // cached
// ...
uint256 s = t.scaledPrincipal; // could be cached earlier
// ...
uint256 sharesTotal = t.stataShares; // could be cached earlier
}
Proposed fix
Cache all frequently accessed storage values at the start of the function:
function _withdrawScaled(bytes32 templateId, uint256 principalAmount, bool emergency) internal returns (uint256 grossAmount) {
    if (principalAmount == 0) revert ZeroAmount();
    TemplateYield storage t = _templates[templateId];
    uint256 p = t.principal;
    uint256 s = t.scaledPrincipal;
    uint256 sharesTotal = t.stataShares;
    IYieldRouterV2.YieldPath path = t.path;
    if (principalAmount > p) revert OverWithdraw();
    // Use cached values throughout
}

informational Severity
3
1

YieldAccounting.sol
computeYield Function in YieldAccounting Library is Unused and Untested in Production
The `computeYield` function in `YieldAccounting.sol` is defined but never called anywhere in `YieldRouterV2.sol`. This function computes gross value, gross yield, net yield, and fee based on scaled balance, liquidity index, original principal, and fee BPS. Its presence suggests it was intended for fee calculation but was not integrated. Dead code in a security-critical library can be misleading and may contain bugs that go undetected since they're never exercised in tests.


Hide Details
Impact
No direct security impact as the function is unused. However, dead code increases audit surface, may indicate incomplete feature implementation (missing fee collection), and could be accidentally used in future upgrades without proper testing.
Scenario
// No exploit - informational finding
// The function exists but is never called in YieldRouterV2.sol
// grep -r 'computeYield' src/ -> only found in YieldAccounting.sol definition
Affected code
function computeYield(uint256 scaledBalance, uint256 liquidityIndex, uint256 originalPrincipal, uint256 feeBps)
internal
pure
returns (uint256 grossValue, uint256 grossYield, uint256 netYield, uint256 fee)
{
grossValue = scaledToReal(scaledBalance, liquidityIndex);
grossYield = grossValue > originalPrincipal ? grossValue - originalPrincipal : 0;
fee = (grossYield * feeBps) / BPS_DENOM;
netYield = grossYield - fee;
}
Proposed fix
Either integrate `computeYield` into the fee collection logic if fees are intended, or remove it from the library to reduce code complexity and audit surface:
// Remove if not needed:
// function computeYield(...) internal pure returns (...) { ... }

// Or integrate into withdrawal logic if fees should be collected:
// (grossValue, grossYield, netYield, fee) = YieldAccounting.computeYield(
//     t.scaledPrincipal, idx, t.principal, feeBps
// );
2

YieldAccounting.sol
realToScaled Function in YieldAccounting Library is Unused
The `realToScaled` function in `YieldAccounting.sol` (which calls `rayDiv`) is defined but never called in `YieldRouterV2.sol`. The router uses `scaledBalanceOf` deltas to track scaled principal rather than converting real amounts to scaled. This dead code adds unnecessary complexity and the `rayDiv` function it calls has a revert path (`YieldAccountingDivZero`) that is never exercised in production.


Hide Details
Impact
No direct security impact. Dead code increases audit surface and may indicate an incomplete or changed design.
Scenario
// No exploit - informational finding
// realToScaled is never called in YieldRouterV2.sol
Affected code
function realToScaled(uint256 realAmount, uint256 liquidityIndex) internal pure returns (uint256) {
return rayDiv(realAmount, liquidityIndex);
}
Proposed fix
Remove `realToScaled` and `rayDiv` from the library if they are not used, or document their intended future use:
// Remove unused functions to reduce code complexity
// function realToScaled(...) { ... }
// function rayDiv(...) { ... }
3

YieldRouterV2.sol
deposit() Return Value Discarded - IYieldRouter Compat Function Loses Attribution Units
The `deposit` function (V1 compatibility entrypoint) calls `_depositScaled` but discards its return value. The `_depositScaled` function returns `attributionUnits` (scaled balance delta for AToken path, shares minted for StataToken path), which is important for callers to track attribution. The `deposit` function signature returns `void`, so callers using the V1 interface cannot obtain attribution units. This creates an asymmetry between `deposit` (V1) and `depositScaled` (V2) where V1 callers lose important accounting information.


Hide Details
Impact
V1 interface callers cannot obtain attribution units from deposits. If the ENGINE uses the V1 `deposit` interface, it cannot track per-deposit attribution units, potentially leading to incomplete accounting. This is a design limitation rather than an exploitable vulnerability.
Scenario
// ENGINE using V1 interface:
// router.deposit(templateId, amount); // attribution units lost
// ENGINE has no way to know how many scaled units were attributed
// vs V2 interface:
// uint256 units = router.depositScaled(templateId, amount); // units captured
Affected code
function deposit(bytes32 templateId, uint256 amount) external override onlyEngine {
_depositScaled(templateId, amount); // return value discarded
}
Proposed fix
Update the V1 `deposit` function to return the attribution units, or document clearly that V1 callers should migrate to `depositScaled`:
// Option 1: Return attribution units from deposit
function deposit(bytes32 templateId, uint256 amount) external override onlyEngine returns (uint256) {
    return _depositScaled(templateId, amount);
}

// Option 2: Add NatSpec deprecation notice
/// @notice V1 compat. Use depositScaled for attribution unit tracking.
/// @dev Attribution units are discarded; use depositScaled if needed.
function deposit(bytes32 templateId, uint256 amount) external override onlyEngine {
    _depositScaled(templateId, amount);
}