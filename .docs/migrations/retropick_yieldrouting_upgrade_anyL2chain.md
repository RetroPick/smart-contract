
RetroPick Protocol
Yield Routing Upgrade
Component 1 — Aave v3 aToken Integration on Arbitrum
End-to-End Technical Design Document
Version 1.0  ·  April 2026  ·  Status: Draft for Implementation
 
0. Executive Summary
This document specifies the complete engineering plan to add yield-bearing collateral to RetroPick's MarketEngine. When a user stakes USDT into a market, that USDT is immediately deployed into Aave v3's lending pool on Arbitrum. The contract vault holds aUSDT (interest-accruing receipt tokens) instead of raw USDT. When the market resolves, the engine redeems aUSDT back to USDT and distributes both the original stakes and the accrued yield to every participant, regardless of whether they won or lost.
This is purely an infrastructure change. No market logic, resolver, or oracle layer is touched. The ChainlinkAdapter, all three market types (Direction / Threshold / RangeClose), rolling rounds, and manual epochs continue to function identically.
Dimension	Detail
Target chain	Arbitrum One (L2)
Yield protocol	Aave v3 — IPool.supply() / withdraw()
Receipt token	aUSDT (rebasing ERC-20, balance grows per-block)
Expected APY	2.5 – 4.0 % on USDT (current range, variable)
Gas overhead / market	~$0.015 per full lifecycle (supply + withdraw at 0.02 gwei)
Monthly infra cost delta	< $0.35 across all Phase 1 rolling markets
New contracts	YieldRouter.sol (1 contract, ~180 lines)
Engine changes	MarketEngine: 3 vault call-sites modified, no storage layout change
Audit scope	YieldRouter.sol + 3 diff hunks in MarketEngine


1. Motivation and Design Principles
1.1  The idle-capital problem
In the current MarketEngine, every unit of USDT deposited via depositToSide() is held raw inside the contract's ledger reserve until either a claim() is made or a withdrawFees() call is processed. For a 5-minute rolling BTC/ETH Direction market this idle window is short. For a weekly Threshold market or a monthly RangeClose, user capital can be locked for 30 – 40 days earning zero yield. This is the same structural flaw that held back Polymarket and similar platforms.
1.2  Why Aave v3 on Arbitrum
Aave v3 is the battle-hardened choice:
•	Deployed and live on Arbitrum One since March 2022 with $1 B+ TVL.
•	USDT supply APY currently 2.5 – 4.0 % (variable, reflects borrowing demand).
•	IPool interface is stable; supply() and withdraw() have not changed signature across v3 minor versions.
•	aTokens are rebasing ERC-20s — balance increases per-block automatically with no extra calls required.
•	Arbitrum gas for supply+withdraw round-trip is ~$0.015 at current prices (~440K gas at 0.021 gwei, ETH at $1,600).
•	Aave v3 V4 launched March 30 2026 on Ethereum mainnet only; Arbitrum v3 instance remains the production deployment for this integration.
1.3  Core design constraints
•	Zero-disruption to existing market logic.  No change to resolver logic, oracle reads, or epoch state machine.
•	Yield is independent of outcome.  Every participant (winner and loser) earns yield on their stake for the duration the epoch is open.
•	Redemption must never block resolution.  If Aave liquidity is temporarily unavailable, the engine must fall back gracefully without locking user funds.
•	No new storage layout in MarketEngine.  YieldRouter is a separate contract. Engine stores one address.
•	Upgrade path is UUPS-safe.  The __gap array in MarketEngine absorbs the one new address field.
•	Protocol may take a fee on yield.  A configurable yieldFeeBps (default 1000 = 10%) is deducted from gross yield before distributing to participants.

2. Architecture Overview
2.1  Component map
The upgrade introduces one new contract (YieldRouter) and modifies three call-sites inside MarketEngine. Everything else is unchanged.
Contract	Status	Role
MarketEngine	Modified	Core engine — 3 call-sites updated to route through YieldRouter
ChainlinkAdapter	Unchanged	Oracle price feed — no changes
YieldRouter	New	Wraps Aave IPool; holds aTokens on behalf of engine; exposes deposit/withdraw/balance
Aave v3 IPool	External	Arbitrum lending pool — supply()/withdraw()
aUSDT token	External	Rebasing receipt token minted by Aave on supply()

2.2  Data flow — full epoch lifecycle
The sequence below traces a single USDT from user deposit through yield accrual to final claim.
#	Phase	What happens
1	Deposit	User calls depositToSide(). Engine calls MarketMath to move USDT into active reserve, then immediately calls YieldRouter.deposit(templateId, amount). Router calls USDT.approve(aavePool) then IPool.supply(USDT, amount, address(router), 0). Aave mints aUSDT to router. Router records a Per-template aToken balance share.
2	Accrual (passive)	Every Arbitrum block (~0.25 s), Aave's LiquidityIndex increases. The router's aUSDT balance grows automatically — no keeper call required. The engine stores nothing; yield is implicit in the aToken exchange rate.
3	Resolution	Keeper calls resolveEpoch() or executeRollingRound(). After Resolvers computes the winning mask, the engine calls YieldRouter.withdraw(templateId, principalAmount). Router calls IPool.withdraw(USDT, principalAmount + yieldAmount, address(engine)). Engine receives gross USDT. Engine deducts yieldFee (sent to treasury) then adds net yield to claimLiabilityTotal. Settlement fee is deducted from net yield + principal per the normal fee logic.
4	Claim	claim() / claimMany() — unchanged. Users receive their winning payout, which now includes their pro-rata share of net yield on top of the normal winnings from the pool.
5	Fallback	If withdraw() reverts (Aave utilisation ceiling), the engine detects the revert and falls back to using raw principal already held in an emergency buffer (5% of deposits kept in engine). Market resolves normally; the 5% float covers full redemption. Aave yield for that epoch is deferred and swept in a separate keeperWithdrawYield() call.


3. Storage Changes and Interface Definitions
3.1  MarketEngine storage delta
Only one new state variable is added to MarketEngine, consuming one slot from the existing 48-slot __gap:
// Before: uint256[48] __gap;
// After:
IYieldRouter public yieldRouter;   // slot N  (was __gap[0])
uint16       public yieldFeeBps;   // packed into same slot as above
uint256[46]  __gap;                // 48 - 2 used = 46 remaining

UUPS Safety  Appending variables before the __gap preserves all existing slot assignments. The two new variables (yieldRouter + yieldFeeBps) pack into one 256-bit slot. The gap shrinks from 48 to 46 slots. All existing mappings and structs remain at their original storage addresses.

3.2  IYieldRouter interface
YieldRouter exposes a minimal interface to the engine:
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IYieldRouter {

    /// @notice Deploy `amount` of stakeToken into the yield source.
    /// @dev    Called by MarketEngine on every depositToSide().
    /// @param  templateId  Template identifier for per-market accounting.
    /// @param  amount      Raw stakeToken amount (6 decimals for USDT).
    function deposit(bytes32 templateId, uint256 amount) external;

    /// @notice Withdraw `principalAmount` + accrued yield and transfer total to engine.
    /// @dev    Called by MarketEngine at resolveEpoch / executeRollingRound.
    /// @param  templateId       Template identifier.
    /// @param  principalAmount  Original deposit amount (without yield).
    /// @return gross            Actual USDT returned (principal + yield).
    function withdraw(bytes32 templateId, uint256 principalAmount)
        external returns (uint256 gross);

    /// @notice Current aToken balance attributed to this template.
    /// @dev    Read-only. Used by UI and off-chain monitoring.
    function balanceOf(bytes32 templateId) external view returns (uint256 aTokenBalance);

    /// @notice Emergency sweep: withdraw all aTokens for a template.
    /// @dev    Only callable by engine admin. Used in pause/recovery flows.
    function emergencyWithdraw(bytes32 templateId) external returns (uint256 amount);

}

3.3  MarketTypes additions
No changes to MarketTypes.sol structs or enums. The Epoch struct, Ledger struct, and all reserve accounting remain byte-for-byte identical. The yieldRouter is not embedded in any per-epoch or per-template struct.

4. YieldRouter.sol — Full Specification
4.1  Constructor and immutables
contract YieldRouter is IYieldRouter, Ownable2Step {

    IERC20  public immutable stakeToken;   // USDT on Arbitrum
    IPool   public immutable aavePool;     // Aave v3 IPool proxy
    IERC20  public immutable aToken;       // aUSDT
    address public immutable engine;       // MarketEngine proxy

    /// @dev Per-template accumulated principal deposited (not including yield).
    mapping(bytes32 => uint256) public principalByTemplate;

    /// @dev Per-template aToken shares (raw aToken units held for this template).
    mapping(bytes32 => uint256) public aTokenSharesByTemplate;

    uint256 public constant BUFFER_BPS = 500; // 5% kept in engine as liquidity buffer

    constructor(
        address _stakeToken,
        address _aavePool,
        address _aToken,
        address _engine
    ) Ownable(msg.sender) {
        stakeToken = IERC20(_stakeToken);
        aavePool   = IPool(_aavePool);
        aToken     = IERC20(_aToken);
        engine     = _engine;
        // Pre-approve Aave pool for max amount (save gas on each deposit)
        stakeToken.approve(_aavePool, type(uint256).max);
    }
}

4.2  deposit()
function deposit(bytes32 templateId, uint256 amount) external override {
    require(msg.sender == engine, "YR: only engine");
    require(amount > 0, "YR: zero amount");

    // Pull USDT from engine (engine must have approved YieldRouter)
    stakeToken.transferFrom(engine, address(this), amount);

    // Record aToken balance BEFORE supply so we can calculate shares minted
    uint256 aBefore = aToken.balanceOf(address(this));

    // Supply to Aave — mints aUSDT to this contract
    aavePool.supply(address(stakeToken), amount, address(this), 0);

    uint256 aAfter  = aToken.balanceOf(address(this));
    uint256 minted  = aAfter - aBefore;   // aToken shares attributed to this deposit

    principalByTemplate[templateId]    += amount;
    aTokenSharesByTemplate[templateId] += minted;

    emit YieldDeposited(templateId, amount, minted);
}

4.3  withdraw()
function withdraw(bytes32 templateId, uint256 principalAmount)
    external override returns (uint256 gross) {
    require(msg.sender == engine, "YR: only engine");

    uint256 principal = principalByTemplate[templateId];
    require(principalAmount <= principal, "YR: over-withdraw");

    // Proportional share of aTokens for this withdrawal
    uint256 totalShares = aTokenSharesByTemplate[templateId];
    uint256 sharesToRedeem = (totalShares * principalAmount) / principal;

    // Redeem aTokens — Aave returns USDT directly to engine
    // Using type(uint256).max redeems all aTokens held for this template
    // Using sharesToRedeem for partial redemptions (rolling markets)
    gross = aavePool.withdraw(
        address(stakeToken),
        sharesToRedeem,         // aToken amount (1:1 approx at low utilisation)
        engine                  // recipient: engine receives USDT directly
    );

    principalByTemplate[templateId]    -= principalAmount;
    aTokenSharesByTemplate[templateId] -= sharesToRedeem;

    emit YieldWithdrawn(templateId, principalAmount, gross);
}

Aave withdraw() return value  IPool.withdraw() returns the actual USDT amount transferred. Due to the rebasing model, gross >= principalAmount. The difference (gross - principalAmount) is the accrued yield for that template since the last deposit. This is exactly the value the engine uses to compute net yield after fees.

4.4  balanceOf() and emergencyWithdraw()
function balanceOf(bytes32 templateId)
    external view override returns (uint256) {
    return aTokenSharesByTemplate[templateId];
}

function emergencyWithdraw(bytes32 templateId)
    external override returns (uint256 amount) {
    require(msg.sender == engine || msg.sender == owner(), "YR: unauthorized");
    uint256 shares = aTokenSharesByTemplate[templateId];
    if (shares == 0) return 0;
    amount = aavePool.withdraw(address(stakeToken), shares, engine);
    principalByTemplate[templateId]    = 0;
    aTokenSharesByTemplate[templateId] = 0;
    emit EmergencyWithdraw(templateId, amount);
}


5. MarketEngine Modifications
5.1  Overview of call-site changes
Three methods in MarketEngine.sol are modified. No other methods are touched.
Method	Change
_depositToSide()	After MarketMath active-reserve update: call yieldRouter.deposit(templateId, netDeposit)
_finishResolveEpoch()	Before computing claim liability: call yieldRouter.withdraw(templateId, principal); compute yield delta; adjust claimLiabilityTotal
initialize()	Accept new param: address _yieldRouter, uint16 _yieldFeeBps

5.2  _depositToSide() diff
// ── EXISTING (unchanged above this line) ──────────────────
MarketMath.addToActiveReserve(ledger, netDeposit);

// ── NEW: route collateral to yield source ─────────────────
if (address(yieldRouter) != address(0)) {
    // Approve router to pull from engine (one-time or per-tx)
    stakeToken.approve(address(yieldRouter), netDeposit);
    yieldRouter.deposit(templateId, netDeposit);
}
// ── EXISTING (unchanged below this line) ──────────────────
emit Deposited(templateId, epochId, beneficiary, outcome, netDeposit);

Gas note  The stakeToken.approve() here uses a pattern of approving exactly netDeposit, not max. This avoids an unlimited approval on the engine contract. Gas cost of approve() on Arbitrum at 0.021 gwei is ~$0.002.

5.3  _finishResolveEpoch() diff
// ── EXISTING: checkpoint B written, winning mask computed ──
(bool voided, uint256 mask) = _applyResolver(templateId, e, ...);

// ── NEW: redeem yield and account for it ──────────────────
uint256 grossFromAave = e.totalPool; // fallback: use raw pool
uint256 yieldAmount   = 0;

if (address(yieldRouter) != address(0)) {
    try yieldRouter.withdraw(templateId, e.totalPool) returns (uint256 gross) {
        grossFromAave = gross;
        yieldAmount   = gross > e.totalPool ? gross - e.totalPool : 0;
    } catch {
        // Aave withdraw failed (utilisation cap or pause)
        // Engine already holds the 5% buffer; totalPool still valid
        emit YieldRouterWithdrawFailed(templateId, e.id, e.totalPool);
        // yieldAmount stays 0 — users get back principal only
    }
}

// Deduct protocol yield fee (sent to treasury reserve)
uint256 yieldFee = (yieldAmount * uint256(yieldFeeBps)) / 10_000;
uint256 netYield = yieldAmount - yieldFee;
if (yieldFee > 0) MarketMath.addToFeeReserve(ledger, yieldFee);

// Inflate the epoch pool by net yield so claim math distributes it
// Note: totalPool is read-only on-chain after resolve; yield is added
// to claimLiabilityTotal directly via MarketMath, not to epoch.totalPool
e.yieldAccruedNet = uint128(netYield);  // new field on Epoch struct

// ── EXISTING: compute claim liability (now includes netYield) ─
MarketMath.computeEpochClaimLiabilityStorage(e, ledger, netYield);

5.4  MarketMath.computeEpochClaimLiabilityStorage() signature change
A single parameter is added to carry net yield into the claim liability calculation:
// BEFORE
function computeEpochClaimLiabilityStorage(
    MarketTypes.Epoch storage e,
    MarketTypes.Ledger storage ledger
) internal { ... }

// AFTER
function computeEpochClaimLiabilityStorage(
    MarketTypes.Epoch storage e,
    MarketTypes.Ledger storage ledger,
    uint256 netYield          // 0 if yield routing disabled
) internal {
    uint256 effectivePool = e.totalPool + netYield;
    // ... rest of fee + liability math uses effectivePool instead of e.totalPool
}

5.5  New Epoch struct field
One uint128 field is appended to MarketTypes.Epoch to record the net yield per epoch for event emission and UI querying. This is append-only and consumes space in the existing padding at the end of the Epoch struct:
// In MarketTypes.sol — Epoch struct (append after existing fields)
uint128 public yieldAccruedNet;   // net yield credited to this epoch (0 if no router)
uint128 public yieldAccruedGross; // gross yield before protocol fee (for analytics)

Storage layout safety  Solidity structs stored in mappings can have fields appended without disturbing existing slot assignments, as long as existing fields are not reordered or removed. The Epoch struct currently ends with bool fields and then 256-bit slots for pools. Appending two uint128 values packs into one new 256-bit slot at the end.


6. The 5% Liquidity Buffer Model
6.1  Rationale
Aave v3 can reach 100% utilisation on a market temporarily, at which point IPool.withdraw() reverts. If the engine routes 100% of collateral to Aave, a utilisation spike at resolve time would cause the epoch to get stuck. The buffer model prevents this.
6.2  Implementation
In _depositToSide(), only 95% of netDeposit is routed to YieldRouter. The remaining 5% stays in the engine's raw token balance (already tracked in ledger.activeReserveTotal):
uint256 routeAmount = netDeposit - (netDeposit * BUFFER_BPS / 10_000);
uint256 bufferHeld  = netDeposit - routeAmount; // stays in engine
if (address(yieldRouter) != address(0) && routeAmount > 0) {
    stakeToken.approve(address(yieldRouter), routeAmount);
    yieldRouter.deposit(templateId, routeAmount);
}

6.3  Resolution with buffer
At resolve time, the engine calls yieldRouter.withdraw(templateId, routedPrincipal). If successful, gross = routedPrincipal + yield. Combined with the 5% buffer already in the engine, the engine holds 100% of principal + yield. If withdraw() fails, the engine holds only the 5% buffer — which is enough to resolve the epoch at the original principal value. Winners get their stakes back correctly; they simply do not receive yield for that epoch.
Buffer cost  The 5% buffer earns no yield. At 3% APY, the opportunity cost of the buffer is 3% × 5% = 0.15% of total deposit per year. This is a negligible cost compared to the settlement risk it eliminates.


7. Yield Accounting and Fee Distribution
7.1  Per-user yield allocation
Yield is distributed pro-rata by totalStake. Every participant — winner and loser — receives yield proportional to their stake in the epoch. This is mechanically equivalent to inflating the epoch pool by netYield and then running the existing claim math. No new claim logic is needed.
Example: epoch totalPool = $10,000. APY = 3%. Duration = 30 days. Gross yield = $10,000 × 3% × (30/365) = $24.66. Protocol fee at 10% = $2.47. Net yield to participants = $22.19.
A user with $1,000 stake (10% of pool) receives $2.22 net yield on top of their normal claim. This is paid out via the standard claim() / claimMany() path — no new function needed.
7.2  Fee flow
Source	Destination	Notes
Gross yield from Aave	Engine balance	Returned by IPool.withdraw() as extra USDT above principal
yieldFee (10% of gross)	ledger.feeReserveTotal	Added to fee reserve; withdrawn via existing withdrawFees()
Net yield (90% of gross)	Epoch claimLiabilityTotal	Added to claim pool; distributed pro-rata via claim()
Settlement fee on net yield	ledger.feeReserveTotal	Normal settlementFeeBps applies to the inflated pool (principal + net yield)

7.3  Rolling markets: partial redemptions
In rolling mode, executeRollingRound() resolves epoch k-1 and opens epoch k+1. Each rolling epoch has its own deposit/withdrawal cycle. The YieldRouter tracks aToken shares per templateId, not per epochId. For rolling markets, this means the router aggregates all outstanding rolling collateral under one templateId bucket.
When resolving epoch k-1 in rolling mode, the engine passes e[k-1].totalPool as the principalAmount to yieldRouter.withdraw(). The router proportionally redeems that fraction of the templateId bucket and returns gross. The remaining aToken shares continue to accrue yield for subsequent epochs.
Rolling accumulation  For a high-frequency rolling BTC-5m market with $10K daily volume, the aToken bucket grows and shrinks every 5 minutes. The router handles this correctly because it tracks aToken shares proportionally, not absolute amounts. Each 5-minute partial redemption is correct regardless of prior epoch sizes.


8. New Events and View Functions
8.1  Events emitted by MarketEngine
/// @notice Emitted when yield is credited to a resolved epoch.
event EpochYieldAccrued(
    bytes32 indexed templateId,
    uint64  indexed epochId,
    uint256 grossYield,
    uint256 yieldFee,
    uint256 netYield
);

/// @notice Emitted when the yield router withdraw() call reverts (fallback path).
event YieldRouterWithdrawFailed(
    bytes32 indexed templateId,
    uint64  indexed epochId,
    uint256 principal
);

/// @notice Emitted when yieldRouter address is updated by admin.
event YieldRouterSet(address indexed oldRouter, address indexed newRouter);

8.2  Events emitted by YieldRouter
event YieldDeposited(bytes32 indexed templateId, uint256 principal, uint256 aTokensMinted);
event YieldWithdrawn(bytes32 indexed templateId, uint256 principal, uint256 grossUSDT);
event EmergencyWithdraw(bytes32 indexed templateId, uint256 amount);

8.3  New view functions on MarketEngine
/// @notice Returns yield info for a resolved epoch.
function getEpochYield(bytes32 templateId, uint64 epochId)
    external view
    returns (uint128 grossYield, uint128 netYield);

/// @notice Returns current aToken balance held by router for a template.
function getTemplateATokenBalance(bytes32 templateId)
    external view
    returns (uint256 aTokenBalance);


9. ERC-1155 Position Tokens (Optional Enhancement)
9.1  Current position model
Currently, user positions are stored as pure storage mappings: positions[positionKey(templateId, epochId)][user]. They are not transferable and have no token representation. This is intentional for simplicity, but it limits composability.
9.2  ERC-1155 position tokens — design
With yield routing, positions become more valuable as financial instruments because they carry embedded yield exposure. Wrapping them as ERC-1155 tokens unlocks secondary markets, collateralisation in other protocols, and wallet-level visibility.
Token ID encoding:
// Encode (templateId, epochId, outcomeIndex) into a uint256 token ID
function encodePositionId(
    bytes32 templateId,
    uint64  epochId,
    uint8   outcomeIndex
) public pure returns (uint256 tokenId) {
    tokenId = uint256(templateId)
        | (uint256(epochId)       << 8)   // bits 8–71
        | (uint256(outcomeIndex)  << 72);  // bits 72–79
}

Implementation approach — two options:
•	Option A (Minimal): Add a PositionToken.sol ERC-1155 contract. On depositToSide(), MarketEngine calls positionToken.mint(user, tokenId, amount). On claim(), engine calls positionToken.burn(user, tokenId, amount). This is a clean separation — PositionToken holds no funds and has no access to the engine.
•	Option B (Integrated): MarketEngine inherits ERC1155Upgradeable (OpenZeppelin). _depositToSide() calls _mint(). _claimOne() calls _burn(). This reduces contract count but bloats MarketEngine further.
Option A is recommended. It keeps MarketEngine's upgrade surface narrow and allows the position token to be upgraded independently.
ERC-1155 and yield routing are independent  ERC-1155 tokenisation does not require yield routing, and yield routing does not require ERC-1155. They can be deployed together or separately. This document specifies yield routing as the primary upgrade. ERC-1155 is a second-order enhancement.

9.3  Yield-bearing position semantics
If ERC-1155 is implemented alongside yield routing, a position token's intrinsic value at resolution equals:
     intrinsicValue = (userStake / totalWinningStake) × (claimLiabilityTotal + netYield × userStake / totalPool)
This is mechanically identical to the existing claim math with netYield added to the pool. The ERC-1155 token represents the right to call claim(), which returns the above value. Off-chain pricing of position tokens uses this formula.

10. Implementation Plan
10.1  Phase breakdown
#	Task	Effort	Notes
1	Write YieldRouter.sol	1.5 days	~180 lines. Immutables + 2 mappings + 4 functions. Max approve pattern.
2	Write IYieldRouter.sol	0.5 days	Interface only. 4 function signatures + NatSpec.
3	MarketEngine storage delta	0.5 days	Add yieldRouter + yieldFeeBps + __gap reduction. Epoch struct append.
4	_depositToSide() patch	0.5 days	Buffer split + conditional yieldRouter.deposit() call.
5	_finishResolveEpoch() patch	1 day	try/catch withdraw, yield delta, fee split, MarketMath call update.
6	MarketMath signature update	0.5 days	Add netYield param to computeEpochClaimLiabilityStorage().
7	Unit tests — YieldRouter	1.5 days	Mock IPool. Test deposit/withdraw/proportional share/emergency.
8	Integration tests — engine	2 days	Fork Arbitrum mainnet. Test full epoch lifecycle with real Aave v3.
9	Halt/recovery tests	1 day	Simulate Aave withdraw() revert (mock utilisation cap). Assert fallback.
10	Gas snapshot update	0.5 days	Run forge test --gas-report; update .gas-snapshot.
11	Deploy script update	0.5 days	script/production/DeployProduction.s.sol: deploy YieldRouter after adapter; pass to engine initialize.
12	UpgradeMarketEngine.s.sol	0.5 days	UUPS upgrade on testnet + mainnet. setYieldRouter() admin call.
13	Internal audit / review	2 days	Scope: YieldRouter.sol + 3 diff hunks. Focus: reentrancy, over-withdraw, share accounting.
—	Total	12.5 days	~2.5 engineer-weeks solo


11. Risk Register
Risk	Likelihood	Impact	Mitigation
Aave utilisation spike at resolve	Low	High	5% buffer in engine. try/catch in resolveEpoch. YieldRouterWithdrawFailed event triggers keeper alert. Market resolves at principal value; yield deferred.
Aave protocol pause (Guardian)	Very low	High	emergencyWithdraw() callable by admin. Engine admin can set yieldRouter = address(0) to disable routing globally without an upgrade.
Aave exploit / bad debt	Very low	Critical	Protocol risk cannot be eliminated. Mitigated by using only established blue-chip pools (USDT on Arbitrum, 3+ years live). No leverage, no exotic assets.
aToken share accounting bug	Low	High	Thorough unit tests of proportional share math. Invariant: sum(aTokenSharesByTemplate) <= aToken.balanceOf(router) always.
Reentrancy via Aave callback	Very low	Medium	YieldRouter is called from within ReentrancyGuardTransient context in engine. YieldRouter itself has no state that can be reentered destructively. Aave v3 pool is not reentrant.
Rolling market yield attribution error	Medium	Medium	Proportional share model tested with multi-epoch fork tests. Each epoch withdraw is isolated by templateId bucket. Invariant checked after every test.
APY drops to near zero	Medium	Low	Yield routing is additive, not required. If APY is < 0.5%, admin can set yieldRouter = address(0) temporarily. No user impact beyond losing a small yield benefit.


12. Deployment Checklist
12.1  Pre-deployment (testnet)
1.	Deploy ChainlinkAdapter(sequencerFeed) — unchanged.
2.	Deploy YieldRouter(USDT_ARBITRUM, AAVE_V3_POOL_ARBITRUM, aUSDT_ARBITRUM, ENGINE_PROXY).
3.	Deploy new MarketEngine implementation (not proxy — UUPS upgrade).
4.	Call Upgrades.upgradeProxy(ENGINE_PROXY, newImpl, upgradeData) with upgradeData = abi.encodeCall(MarketEngineV2.initializeV2, (yieldRouterAddr, 1000)).
5.	Verify yieldRouter != address(0) via engine.yieldRouter().
6.	Verify yieldFeeBps == 1000 via engine.yieldFeeBps().
7.	Run smoke test: open 1 epoch, deposit, fast-forward time, resolve, claim. Assert claimAmount > stakeAmount.
8.	Check router.principalByTemplate(templateId) == 0 after full claim sweep.
12.2  Pre-deployment (mainnet)
9.	Confirm Aave v3 USDT pool on Arbitrum is active and USDT is not frozen (check pool.getReserveData(USDT_ARBITRUM).configuration.frozen bit).
10.	Confirm aUSDT address matches Aave documentation (0x6ab707Aca953eDAeFBc4fD23bA73294241490620 on Arbitrum One).
11.	Confirm Aave v3 Pool proxy address (0x794a61358D6845594F94dc1DB02A252b5b4814aD on Arbitrum One).
12.	Run full fork test suite against Arbitrum mainnet fork.
13.	Multisig review of upgrade calldata before broadcast.
14.	Broadcast via Gnosis Safe with 2-of-N confirmation.
15.	Post-deploy: monitor YieldDeposited events for first 24 hours.
12.3  Key contract addresses (Arbitrum One)
Contract	Address
USDT (Arbitrum)	0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9
Aave v3 IPool proxy	0x794a61358D6845594F94dc1DB02A252b5b4814aD
aUSDT token	0x6ab707Aca953eDAeFBc4fD23bA73294241490620
Sequencer uptime feed	0xFdB631F5EE196F0ed6FAa767959853A9F217697D


13. Testing Strategy
13.1  Unit tests (MockAavePool)
A MockAavePool contract simulates supply() and withdraw() deterministically. It mints mock aTokens at 1:1, then applies a configurable interestMultiplier to simulate yield. Test cases:
•	deposit(): verify principalByTemplate and aTokenSharesByTemplate increment correctly.
•	withdraw() proportional: deposit 3 amounts to same templateId, withdraw the first, assert correct share deduction.
•	withdraw() full redemption: deposit then withdraw full principal, assert aTokenSharesByTemplate == 0.
•	emergencyWithdraw(): assert all aTokens returned, mappings zeroed.
•	withdraw() revert simulation: configure MockAavePool to revert; assert engine emits YieldRouterWithdrawFailed and epoch resolves at principal.
•	Yield fee split: configure 10% yieldFeeBps; assert feeReserveTotal increases by yieldFee after resolve.
13.2  Fork tests (Arbitrum mainnet fork)
Run with: forge test --fork-url $ARBITRUM_RPC --match-path test/fork/YieldRouterFork.t.sol
•	Supply USDT to Aave via router, warp 30 days, withdraw, assert gross > principal.
•	Rolling BTC-5m: run 10 executeRollingRound iterations with real Aave, assert monotonically increasing yield per epoch.
•	Manual weekly Threshold: open epoch, deposit $1000, warp 7 days, resolve, claim, assert claim > $1000.
•	Utilisation simulation: drain Aave USDT pool to 99% via flashloan, trigger resolve, assert fallback path activates.
13.3  Invariants (Foundry invariant suite)
// Invariant 1: Router aToken balance >= sum of all template aToken shares
function invariant_aTokenConservation() external {
    uint256 total = 0;
    for (uint i = 0; i < templateIds.length; i++) {
        total += router.aTokenSharesByTemplate(templateIds[i]);
    }
    assertLe(total, aToken.balanceOf(address(router)));
}

// Invariant 2: No free money — gross withdrawn <= principal + accrued interest
function invariant_noFreeYield() external {
    assertLe(totalWithdrawnGross, totalDepositedPrincipal + aave.totalAccruedInterest());
}


14. Monitoring and Operational Runbook
14.1  Key metrics to watch
Metric	Alert threshold	Action
YieldRouterWithdrawFailed event count	> 0 / day	Check Aave utilisation. If > 95%, reduce BUFFER_BPS or temporarily disable routing.
router.aToken.balanceOf() drift vs sum of shares	> 1 USDT	Investigate rounding. Run emergencyWithdraw + re-deposit to rebalance.
Aave USDT supply APY	< 0.5% for 7 days	Consider disabling routing via setYieldRouter(address(0)) until rates recover.
Aave pool status (frozen/paused)	Any change	Immediately call emergencyWithdraw for all templates. Disable routing.

14.2  Admin functions added to MarketEngine
/// @notice Update the yield router address. Pass address(0) to disable routing.
function setYieldRouter(address _yieldRouter, uint16 _feeBps) external onlyAdmin {
    emit YieldRouterSet(address(yieldRouter), _yieldRouter);
    yieldRouter = IYieldRouter(_yieldRouter);
    yieldFeeBps = _feeBps;
}

/// @notice Emergency: withdraw all aTokens for a template to engine.
function yieldEmergencyWithdraw(bytes32 templateId) external onlyAdmin {
    require(address(yieldRouter) != address(0), "no router");
    uint256 amount = yieldRouter.emergencyWithdraw(templateId);
    // Returned USDT sits in engine balance — counted in ledger.activeReserveTotal
    emit YieldEmergencyWithdrawn(templateId, amount);
}


15. Complete Change Summary
File	Type	Summary
src/interfaces/IYieldRouter.sol	New	4-function interface: deposit, withdraw, balanceOf, emergencyWithdraw
src/YieldRouter.sol	New	~180 lines. Aave v3 wrapper. Per-template aToken share accounting.
src/MarketEngine.sol	Modified	Storage: +yieldRouter, +yieldFeeBps, __gap 48→46. _depositToSide: buffer split + yieldRouter.deposit(). _finishResolveEpoch: yieldRouter.withdraw() with try/catch + yield fee split. initialize: 2 new params. setYieldRouter() admin fn. yieldEmergencyWithdraw() admin fn. 5 new events.
src/math/MarketMath.sol	Modified	computeEpochClaimLiabilityStorage: +netYield param; uses effectivePool = totalPool + netYield
src/types/MarketTypes.sol	Modified	Epoch struct: +uint128 yieldAccruedNet, +uint128 yieldAccruedGross (append-only)
script/production/DeployProduction.s.sol	Modified	Deploy YieldRouter after ChainlinkAdapter. Pass to engine initialize.
script/UpgradeMarketEngine.s.sol	Modified	upgradeProxy call + initializeV2 with yieldRouter + yieldFeeBps
test/YieldRouter.t.sol	New	Unit tests with MockAavePool (all deposit/withdraw/share/emergency paths)
test/fork/YieldRouterFork.t.sol	New	Arbitrum mainnet fork integration tests
test/mocks/MockAavePool.sol	New	Deterministic Aave IPool mock with configurable interest multiplier and revert flag


End of document.  RetroPick Yield Routing Upgrade — v1.0
