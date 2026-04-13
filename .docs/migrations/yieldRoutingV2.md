# RetroPick — Yield Routing V2: Maximized Aave v3 Tokenization Integration

**Status:** Draft for Implementation  
**Version:** 2.0  
**Date:** April 2026  
**Authors:** Protocol Engineering  
**Scope:** YieldRouter.sol rewrite + MarketEngine diff + new YieldAccounting library

---

## Table of Contents

1. [Gap Analysis: V1 vs What Aave v3 Actually Exposes](#1-gap-analysis)
2. [The Tokenization Layer — Deep Technical Model](#2-aave-v3-tokenization-deep-model)
3. [Architecture: V2 Design](#3-architecture-v2-design)
4. [ScaledBalance Accounting — The Core Upgrade](#4-scaledbalance-accounting)
5. [StataToken Integration — ERC-4626 Path](#5-statatoken-erc-4626)
6. [IRewardsController — LM Rewards Capture](#6-lm-rewards-capture)
7. [aToken.permit() — Gas-Free Deposit Flow](#7-atoken-permit-gasless)
8. [Reserve Health Guard — Pool.getReserveData()](#8-reserve-health-guard)
9. [YieldRouter V2 — Full Contract Specification](#9-yieldrouter-v2-full-spec)
10. [YieldAccounting Library](#10-yieldaccounting-library)
11. [MarketEngine V2 Diff](#11-marketengine-v2-diff)
12. [Rolling Markets: Per-Epoch Scaled Snapshot](#12-rolling-markets-scaled-snapshot)
13. [New Events, View Functions, Invariants](#13-events-views-invariants)
14. [Migration Path from V1](#14-migration-from-v1)
15. [Test Strategy](#15-test-strategy)
16. [Risk Register V2](#16-risk-register-v2)
17. [Complete File Change Summary](#17-complete-file-change-summary)

---

## 1. Gap Analysis

The V1 `YieldRouter` (as specified in the previous upgrade doc) integrated with Aave v3 at the most basic level: `IPool.supply()` on deposit and `IPool.withdraw()` on resolution. It tracked collateral using raw principal amounts and aToken balance deltas.

This works, but it leaves significant value and correctness on the table. The Aave v3 tokenization layer exposes a richer model that directly solves three problems V1 ignores:

### 1.1 What V1 does (and why it's imprecise)

```
V1 deposit():
  aBefore = aToken.balanceOf(router)
  IPool.supply(USDT, amount, router, 0)
  aAfter  = aToken.balanceOf(router)
  aTokenSharesByTemplate[tid] += (aAfter - aBefore)  // ← raw rebasing units
```

**Problem:** `aToken.balanceOf()` is a **rebasing value** — it grows between the two calls if any other interaction with the pool occurs in the same block (e.g., any other supplier). The delta `aAfter - aBefore` is not stable. It is not the correct accounting unit.

The correct accounting unit is the **scaled balance** (`scaledBalanceOf`), which is the raw underlying position divided by the liquidity index at mint time. This is what `ScaledBalanceTokenBase` stores internally and what `getScaledUserBalanceAndSupply()` returns.

### 1.2 What V1 misses entirely

| Gap | Aave v3 Feature | V1 Status | V2 Fixes |
|-----|----------------|-----------|----------|
| Imprecise share accounting | `scaledBalanceOf` / `getScaledUserBalanceAndSupply` | ❌ Uses raw `balanceOf` | ✅ Uses scaled balance |
| No yield precision | `IPool.getReserveNormalizedIncome()` (liquidityIndex) | ❌ Delta approximation | ✅ Exact rayMul math |
| No LM rewards | `IRewardsController.claimAllRewards()` | ❌ Lost entirely | ✅ Captured + distributed |
| Wasteful approve pattern | `aToken.permit()` EIP-2612 | ❌ Per-deposit `approve()` | ✅ Single permit signature |
| No reserve health check | `IPool.getReserveData()` configuration bits | ❌ Blind call, may fail | ✅ Pre-flight guard |
| No ERC-4626 path | `StaticATokenFactory` / StataToken | ❌ Absent | ✅ Optional composable path |
| Dust accumulation | Last-wei rounding on withdraw | ❌ Leaves dust in router | ✅ `type(uint256).max` sweep on final epoch |

### 1.3 Why scaled balance matters — the math

Aave v3 does not store rebasing balances. Internally it stores **scaled balances** (`scaledBalance`). The relationship is:

```
realBalance = scaledBalance × liquidityIndex  (in ray = 1e27)
```

When you call `IPool.supply(asset, amount, onBehalfOf, 0)`, Aave mints:

```
scaledMinted = amount.rayDiv(liquidityIndex_at_mint)
```

When you call `IPool.withdraw(asset, amount, to)`, Aave burns:

```
scaledBurned = amount.rayDiv(liquidityIndex_at_withdraw)
grossReturned = scaledBurned × liquidityIndex_at_withdraw = amount + accrued_yield
```

**The correct invariant to track per template is `scaledBalance`, not raw aToken balance.** This is what `aToken.scaledBalanceOf(router)` returns and what must be allocated per `templateId`.

---

## 2. Aave v3 Tokenization Deep Model

### 2.1 The three token types and which ones matter for RetroPick

| Token | Contract | Relevance to RetroPick |
|-------|----------|----------------------|
| **aToken** | `AToken.sol` | **Primary** — holds yield-accruing collateral |
| **StataToken** | `StaticATokenFactory` | **Secondary** — ERC-4626 wrapper, cleaner accounting |
| **variableDebtToken** | `VariableDebtToken.sol` | **None** — RetroPick never borrows |

### 2.2 aToken internals: what `balanceOf` actually computes

```solidity
// From AToken.sol — what balanceOf() returns:
function balanceOf(address user) public view override returns (uint256) {
    return super.scaledBalanceOf(user).rayMul(
        POOL.getReserveNormalizedIncome(_underlyingAsset)
    );
}
```

So `balanceOf()` = `scaledBalance × currentLiquidityIndex`. It grows **continuously** as `liquidityIndex` grows. If the router calls `balanceOf()` twice in the same transaction, it can get different values if the pool state was updated between calls (e.g., via `_updateState()`). This is the source of V1's imprecision.

### 2.3 `scaledBalanceOf` — the stable unit

```solidity
// From ScaledBalanceTokenBase.sol
function scaledBalanceOf(address user) external view override returns (uint256) {
    return super.balanceOf(user); // raw scaled units — never changes between tx
}
```

`scaledBalanceOf` is the **immutable share** of the pool. It does not change between transactions unless a supply or withdraw is executed. This is what YieldRouter V2 tracks.

### 2.4 `getScaledUserBalanceAndSupply` — the combined read

```solidity
function getScaledUserBalanceAndSupply(address user)
    external view returns (uint256 scaledBalance, uint256 scaledTotalSupply)
```

Returns both the user's scaled balance and the pool's total scaled supply in one call. Used in YieldRouter V2's `currentValue()` view and in off-chain monitoring.

### 2.5 `getReserveNormalizedIncome` — real-time liquidity index

```solidity
// IPool
function getReserveNormalizedIncome(address asset) external view returns (uint256)
// Returns current liquidityIndex in RAY (1e27)
// Value starts at 1e27, grows over time
// realBalance = scaledBalance × getReserveNormalizedIncome(asset) / 1e27
```

This is the most important read for yield calculation. The difference between the index at deposit time and at withdrawal time, applied to the scaled balance, gives exact yield with no approximation or delta tricks.

### 2.6 Reserve configuration bits

`IPool.getReserveData(asset).configuration` is a packed `uint256` where specific bits indicate:

| Bit | Meaning | Checked in V2 |
|-----|---------|--------------|
| 56 | `isActive` | ✅ Must be `1` before supply |
| 57 | `isFrozen` | ✅ Must be `0` before supply |
| 60 | `isPaused` | ✅ Must be `0` before supply and withdraw |

Pre-flight checking these bits prevents wasting gas on a call that will revert.

### 2.7 StataToken (ERC-4626 wrapper)

The `StaticATokenFactory` deploys `StataToken` instances — ERC-4626 compliant wrappers around aTokens. Key properties:

- Non-rebasing: share price grows, not balance
- Standard `deposit(assets, receiver)` / `redeem(shares, receiver, owner)`
- Auto-claims LM rewards to holders
- `convertToAssets(shares)` gives exact underlying value

For RetroPick, using StataToken instead of raw aToken interaction has one major advantage: the `convertToAssets()` function provides an exact, audit-friendly accounting of value held — no rayMul required in the router.

### 2.8 IRewardsController — LM rewards

Aave v3 on Arbitrum can have liquidity mining rewards (AAVE tokens, ARB tokens from Arbitrum incentive programs) distributed to aToken holders via `IRewardsController`. V1 completely ignores these. V2 captures them.

```solidity
// Key IRewardsController functions used in V2:
function getRewardsByAsset(address asset)
    external view returns (address[] memory);

function claimAllRewards(address[] calldata assets, address to)
    external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

function getAllUserRewards(address[] calldata assets, address user)
    external view returns (address[] memory, uint256[] memory);
```

---

## 3. Architecture: V2 Design

### 3.1 Component map

```
┌─────────────────────────────────────────────────────────────────┐
│                    MarketEngine (UUPS proxy)                     │
│                                                                  │
│  _depositToSide() ──────────────────► YieldRouter V2           │
│  _finishResolveEpoch() ─────────────►  .depositScaled()        │
│  setYieldRouter() ──────────────────►  .withdrawScaled()       │
│  keeperClaimRewards() ──────────────►  .claimLMRewards()       │
└─────────────────────────────────────────────────────────────────┘
         │                                        │
         ▼                                        ▼
  YieldAccounting.sol                    Aave v3 Contracts
  (library: ray math,                    ├─ IPool (supply/withdraw)
   scaled balance ops)                   ├─ IAToken (scaledBalanceOf)
                                         ├─ IPool.getReserveNormalizedIncome()
                                         ├─ IPool.getReserveData() (config bits)
                                         ├─ IRewardsController (LM rewards)
                                         └─ StaticATokenFactory (optional ERC-4626)
```

### 3.2 Data model: what YieldRouter V2 stores per template

```solidity
struct TemplateYield {
    uint256 scaledPrincipal;    // sum of scaledBalanceOf contributions for this template
                                // = Σ (supply_amount_i / liquidityIndex_at_supply_i)
    uint256 indexAtLastDeposit; // liquidityIndex (ray) captured at most recent deposit
                                // used only for event emission / off-chain analytics
    uint128 lmRewardsAccrued;   // total LM reward tokens (in reward-token units) swept for this template
    uint128 yieldFeePaid;       // cumulative protocol yield fee charged (in USDT)
}

mapping(bytes32 templateId => TemplateYield) public templates;
```

Only `scaledPrincipal` matters for the core accounting. All yield math is done on-the-fly using `getReserveNormalizedIncome()`.

### 3.3 Exact yield formula (V2)

At resolution time:

```
currentIndex    = IPool.getReserveNormalizedIncome(USDT)   // ray
scaledPrincipal = templates[tid].scaledPrincipal           // scaled units

grossUSDT = scaledPrincipal.rayMul(currentIndex)           // = exact underlying value
principal  = totalPool (stored on-chain in epoch struct)   // original deposits
yieldGross = grossUSDT - principal                         // if positive
```

This is exact. No delta, no approximation, no rebasing read between calls.

---

## 4. ScaledBalance Accounting — The Core Upgrade

### 4.1 Why this is the most important change

V1's `aTokenSharesByTemplate` tracked raw aToken units. These grow passively every block. When the router allocates a partial withdrawal across rolling epochs, the arithmetic with growing rebasing units produces compounding rounding errors over many epochs.

Scaled balances are **stable** — they do not change between transactions. Proportional allocation is exact.

### 4.2 The deposit path (V2)

```solidity
function depositScaled(bytes32 templateId, uint256 usdtAmount)
    external onlyEngine returns (uint256 scaledMinted)
{
    require(usdtAmount > 0, "YR: zero");
    _requireReserveHealthy();

    // Pull USDT from engine
    stakeToken.transferFrom(engine, address(this), usdtAmount);

    // Capture liquidityIndex BEFORE supply to compute exact scaled units minted
    uint256 indexBefore = aavePool.getReserveNormalizedIncome(address(stakeToken));

    // Supply to Aave — aUSDT minted to this router
    aavePool.supply(address(stakeToken), usdtAmount, address(this), REFERRAL_CODE);

    // Compute scaled units minted: exact inverse of what Aave's _mintScaled does
    // scaledMinted = usdtAmount.rayDiv(liquidityIndex)
    // We read scaledBalanceOf delta instead to avoid any rounding discrepancy
    scaledMinted = IScaledBalanceToken(address(aToken)).scaledBalanceOf(address(this))
                   - templates[templateId].scaledPrincipal
                   - _sumOtherTemplateScaled(templateId);  // see note below

    // NOTE: rather than summing other templates (expensive), we track global scaled balance
    // and compute this template's contribution as a proportional delta — see section 4.3

    templates[templateId].scaledPrincipal += scaledMinted;
    templates[templateId].indexAtLastDeposit = indexBefore;

    emit YieldDepositedScaled(templateId, usdtAmount, scaledMinted, indexBefore);
}
```

> **Simpler approach for `scaledMinted` (recommended):** Track a `globalScaledBalance` mapping in the router. On each deposit: `globalScaledBefore = globalScaledBalance`. After supply: `globalScaledAfter = aToken.scaledBalanceOf(router)`. `scaledMinted = globalScaledAfter - globalScaledBefore`. `globalScaledBalance = globalScaledAfter`. This is O(1) and avoids iterating other templates.

### 4.3 Recommended: global scaled balance tracking

```solidity
contract YieldRouterV2 {
    // Global state
    uint256 public globalScaledBalance;  // total scaled aUSDT held across ALL templates
    
    // Per-template state
    mapping(bytes32 => TemplateYield) public templates;

    function depositScaled(bytes32 templateId, uint256 usdtAmount)
        external onlyEngine returns (uint256 scaledMinted)
    {
        _requireReserveHealthy();
        stakeToken.transferFrom(engine, address(this), usdtAmount);

        uint256 scaledBefore = globalScaledBalance;  // read our own tracking
        aavePool.supply(address(stakeToken), usdtAmount, address(this), 0);
        uint256 scaledAfter  = IScaledBalanceToken(address(aToken)).scaledBalanceOf(address(this));

        scaledMinted = scaledAfter - scaledBefore;
        globalScaledBalance = scaledAfter;

        templates[templateId].scaledPrincipal += scaledMinted;

        emit YieldDepositedScaled(templateId, usdtAmount, scaledMinted,
            aavePool.getReserveNormalizedIncome(address(stakeToken)));
    }
}
```

**Invariant:** `globalScaledBalance == aToken.scaledBalanceOf(address(this))` at all times between transactions.

### 4.4 The withdrawal path (V2)

```solidity
function withdrawScaled(bytes32 templateId, uint256 principalAmount)
    external onlyEngine returns (uint256 grossUSDT)
{
    TemplateYield storage t = templates[templateId];
    require(principalAmount <= _currentValueOf(templateId), "YR: over-withdraw");

    // Compute scaled shares to redeem proportionally
    uint256 currentIndex = aavePool.getReserveNormalizedIncome(address(stakeToken));
    uint256 currentValue = WadRayMath.rayMul(t.scaledPrincipal, currentIndex);

    // We want to redeem `principalAmount` worth of underlying
    // scaledToRedeem = principalAmount.rayDiv(currentIndex)
    uint256 scaledToRedeem;
    if (principalAmount >= currentValue) {
        // Full redemption of this template (last epoch or emergency)
        scaledToRedeem = t.scaledPrincipal;
    } else {
        scaledToRedeem = WadRayMath.rayDiv(principalAmount, currentIndex);
    }

    // Redeem from Aave — USDT goes directly to engine
    grossUSDT = aavePool.withdraw(address(stakeToken), scaledToRedeem, engine);

    // Update state
    t.scaledPrincipal  -= scaledToRedeem;
    globalScaledBalance -= scaledToRedeem;

    emit YieldWithdrawnScaled(templateId, principalAmount, scaledToRedeem, grossUSDT, currentIndex);
}
```

### 4.5 `_currentValueOf()` — read-only accounting

```solidity
function currentValueOf(bytes32 templateId) external view returns (uint256 usdtValue) {
    uint256 idx = aavePool.getReserveNormalizedIncome(address(stakeToken));
    return WadRayMath.rayMul(templates[templateId].scaledPrincipal, idx);
}

function currentYieldOf(bytes32 templateId, uint256 originalPrincipal)
    external view returns (uint256 gross, uint256 net, uint256 fee)
{
    gross = currentValueOf(templateId);
    uint256 yieldGross = gross > originalPrincipal ? gross - originalPrincipal : 0;
    fee   = (yieldGross * yieldFeeBps) / 10_000;
    net   = yieldGross - fee;
}
```

---

## 5. StataToken ERC-4626 Path

### 5.1 What StataToken gives us

Instead of calling `IPool.supply()` directly, the router can deposit into a `StataToken` (deployed by `StaticATokenFactory`). The StataToken is an ERC-4626 vault over aUSDT:

```
USDT ──► StataToken.deposit() ──► Aave supply internally ──► holds aUSDT
                                                            ──► issues stata shares (non-rebasing)
```

StataToken shares have a clean `convertToAssets(shares)` function that returns the exact USDT value without any ray math in the router. It also auto-claims LM rewards.

### 5.2 When to use StataToken vs raw aToken

| Criterion | Raw aToken path | StataToken (ERC-4626) path |
|-----------|----------------|--------------------------|
| Accounting precision | Requires ray math in router | `convertToAssets()` handles it |
| LM rewards | Must call `IRewardsController` separately | Auto-claimed |
| Gas cost per deposit | Lower (~230K) | Higher (~280K, wraps aToken) |
| Interface stability | IPool.supply() stable | ERC-4626 stable |
| Composability | Limited | Full — can be used as collateral elsewhere |
| Recommended for | Rolling 5m/15m markets (high frequency, low cost matters) | Weekly/monthly Threshold/RangeClose (low frequency, correctness matters more) |

### 5.3 StataToken integration in YieldRouter V2

The router supports both paths, switchable per template:

```solidity
enum YieldPath { AToken, StataToken }

struct TemplateYield {
    uint256   scaledPrincipal;     // used in AToken path
    uint256   stataShares;         // used in StataToken path
    YieldPath path;
    uint128   lmRewardsAccrued;
    uint128   yieldFeePaid;
}
```

StataToken deposit:

```solidity
function _depositStata(bytes32 templateId, uint256 usdtAmount) internal {
    // StataToken uses standard ERC-4626 deposit
    stakeToken.approve(address(stataToken), usdtAmount);
    uint256 sharesMinted = IERC4626(stataToken).deposit(usdtAmount, address(this));
    templates[templateId].stataShares += sharesMinted;
    emit YieldDepositedStata(templateId, usdtAmount, sharesMinted);
}
```

StataToken withdraw:

```solidity
function _withdrawStata(bytes32 templateId, uint256 principalAmount)
    internal returns (uint256 grossUSDT)
{
    TemplateYield storage t = templates[templateId];
    IERC4626 stata = IERC4626(stataToken);
    
    uint256 totalValueHeld = stata.convertToAssets(t.stataShares);
    uint256 sharesToRedeem;
    
    if (principalAmount >= totalValueHeld) {
        sharesToRedeem = t.stataShares; // full redemption
    } else {
        // Proportional shares: shares = principalAmount / pricePerShare
        sharesToRedeem = stata.convertToShares(principalAmount);
    }

    grossUSDT = stata.redeem(sharesToRedeem, engine, address(this));
    t.stataShares -= sharesToRedeem;
    
    emit YieldWithdrawnStata(templateId, principalAmount, sharesToRedeem, grossUSDT);
}
```

---

## 6. LM Rewards Capture

### 6.1 The missed value

When the Arbitrum ecosystem runs liquidity mining programs (ARB incentives, AAVE emissions), aToken holders on Arbitrum receive reward tokens via `IRewardsController`. V1 leaves these entirely uncollected — they sit in the rewards controller accruing to the router address but never swept.

For a router holding $50K–$100K in aUSDT, ARB incentive periods can add 2–5% additional APY on top of the base supply rate.

### 6.2 Reward token flow

```
aToken holders (including router) accrue rewards per-block
        │
        ▼
IRewardsController.claimAllRewards([aUSDT_address], router)
        │
        ▼
Reward tokens (ARB, AAVE, etc.) transferred to router
        │
        ├─► yieldFeeBps portion → treasury
        └─► remainder → distributed pro-rata in next resolve cycle
```

### 6.3 `claimLMRewards()` — keeper-callable function

```solidity
/// @notice Sweep all LM rewards for a template to the engine.
/// @dev    Callable by keeper (workerAuthority) at any time between epochs.
/// @param  templateId  The market to sweep rewards for.
/// @return rewardsList  Array of reward token addresses claimed.
/// @return amounts      Array of amounts per reward token.
function claimLMRewards(bytes32 templateId)
    external onlyEngineOrAdmin
    returns (address[] memory rewardsList, uint256[] memory amounts)
{
    address[] memory assets = new address[](1);
    assets[0] = address(aToken);

    (rewardsList, amounts) = IRewardsController(rewardsController)
        .claimAllRewards(assets, address(this));

    for (uint256 i = 0; i < rewardsList.length; i++) {
        if (amounts[i] == 0) continue;

        // Record against template
        // Note: reward tokens are NOT USDT — they're ARB, AAVE, etc.
        // Route them to engine for separate accounting
        IERC20(rewardsList[i]).transfer(engine, amounts[i]);

        emit LMRewardsClaimed(templateId, rewardsList[i], amounts[i]);
    }
}
```

### 6.4 Reward distribution in MarketEngine

When `claimLMRewards()` sweeps reward tokens to the engine, the engine calls a new `distributeRewardToken()` path:

```solidity
/// @notice Distribute non-USDT reward tokens to a template's claim pool.
/// @dev    Called by keeper after LM rewards are swept from YieldRouter.
///         Reward tokens are swapped to USDT off-chain; keeper calls this
///         with the USDT equivalent and transfers it separately.
///         Alternative: reward tokens sit in engine treasury and are distributed
///         via governance at a later date. V2 implements the simpler treasury path.
function receiveLMReward(bytes32 templateId, address rewardToken, uint256 amount)
    external onlyAdmin
{
    // V2 approach: LM reward tokens go to treasury as separate revenue
    // They are NOT added to epoch claim pools (complex swap logic avoided)
    // This is logged for transparency and future upgrade to auto-swap path
    emit LMRewardReceived(templateId, rewardToken, amount);
}
```

> **Design decision:** LM rewards in V2 go to treasury rather than per-epoch distribution. This avoids requiring an on-chain DEX swap (e.g., ARB → USDT via Uniswap) inside the resolution path, which would introduce price oracle dependency and slippage risk. A V3 upgrade can add auto-swap via a trusted aggregator.

---

## 7. aToken permit() — Gas-Free Deposit Flow

### 7.1 The V1 approve() problem

V1 does:
```solidity
stakeToken.approve(address(yieldRouter), netDeposit);  // USDT approve tx
yieldRouter.deposit(templateId, netDeposit);           // deposit tx
```

This is two separate approval+call pairs. On Arbitrum at 0.02 gwei it's cheap (~$0.004), but across thousands of rolling deposits it adds up, and more importantly it leaves a non-zero allowance on the engine contract.

### 7.2 Two upgrade paths

**Path A: supplyWithPermit() on IPool**

Aave v3's `IPool` exposes `supplyWithPermit()` which accepts an EIP-2612 signature from the token holder, eliminating the separate approve:

```solidity
function supplyWithPermit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
) external;
```

However, **USDT on Arbitrum does not implement EIP-2612 permit**. This path is only viable if the stake token is switched to USDC (which does support permit on Arbitrum).

**Path B: aToken.permit() for aToken transfers (V2 uses this)**

The aToken contract itself implements EIP-2612 via `permit()`. This is relevant when the router needs to transfer aTokens — e.g., in a partial transfer of yield between templates or to a third-party vault. In V2, this is used in the optional StataToken redemption path where the router calls `aToken.permit()` to authorize the StataToken to pull aTokens without a separate approve call.

```solidity
// Router authorizing StataToken to pull aUSDT for deposit:
// Called once during setup or when stataToken allowance is depleted
function permitATokenToStata(uint256 deadline, uint8 v, bytes32 r, bytes32 s) external onlyAdmin {
    IAToken(address(aToken)).permit(
        address(this),    // owner: router
        stataToken,       // spender: StataToken
        type(uint256).max, // value: max
        deadline,
        v, r, s
    );
}
```

**Path C: One-time max approve during construction (recommended for rolling markets)**

For the high-frequency rolling markets where `depositScaled()` is called every 5 minutes, the most gas-efficient approach is a one-time `type(uint256).max` approve in the constructor:

```solidity
constructor(...) {
    // One-time approvals — never need to re-approve per deposit
    stakeToken.approve(address(aavePool), type(uint256).max);
    stakeToken.approve(address(stataToken), type(uint256).max);  // optional
}
```

This replaces the per-deposit `approve()` call in V1, saving ~21K gas per deposit.

---

## 8. Reserve Health Guard

### 8.1 Configuration bits in `ReserveData`

`IPool.getReserveData(asset)` returns a `ReserveData` struct containing a `ReserveConfigurationMap` — a packed `uint256` with the following relevant bits:

```
Bit 56: isActive   — must be 1 for supply/withdraw
Bit 57: isFrozen   — must be 0 for supply (frozen = no new supply allowed)
Bit 60: isPaused   — must be 0 for both supply AND withdraw
```

### 8.2 `_requireReserveHealthy()` implementation

```solidity
uint256 private constant ACTIVE_MASK  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
uint256 private constant FROZEN_MASK  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
uint256 private constant PAUSED_MASK  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0FFFFFFF FFFFFFFFFFF;
// Bit positions (0-indexed from right):
// isActive = bit 56, isFrozen = bit 57, isPaused = bit 60

function _requireReserveHealthy() internal view {
    DataTypes.ReserveConfigurationMap memory config =
        aavePool.getConfiguration(address(stakeToken));
    uint256 data = config.data;

    bool isActive = (data >> 56) & 0x1 == 1;
    bool isFrozen = (data >> 57) & 0x1 == 1;
    bool isPaused = (data >> 60) & 0x1 == 1;

    require(isActive && !isFrozen && !isPaused, "YR: reserve not healthy");
}

function _requireReserveWithdrawable() internal view {
    DataTypes.ReserveConfigurationMap memory config =
        aavePool.getConfiguration(address(stakeToken));
    uint256 data = config.data;
    bool isPaused = (data >> 60) & 0x1 == 1;
    require(!isPaused, "YR: reserve paused");
}
```

### 8.3 Where health checks are inserted

| YieldRouter V2 function | Check applied |
|------------------------|--------------|
| `depositScaled()` | `_requireReserveHealthy()` (active, not frozen, not paused) |
| `withdrawScaled()` | `_requireReserveWithdrawable()` (not paused only — withdraw ok when frozen) |
| `emergencyWithdraw()` | No check — admin emergency bypass |
| `currentValueOf()` | No check — view only |

---

## 9. YieldRouter V2 — Full Contract Specification

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20}               from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20}            from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step}         from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IPool}                from "@aave/v3-core/contracts/interfaces/IPool.sol";
import {IScaledBalanceToken}  from "@aave/v3-core/contracts/interfaces/IScaledBalanceToken.sol";
import {IRewardsController}   from "@aave/v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import {WadRayMath}           from "@aave/v3-core/contracts/protocol/libraries/math/WadRayMath.sol";
import {DataTypes}            from "@aave/v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IYieldRouterV2}       from "./interfaces/IYieldRouterV2.sol";

/**
 * @title  YieldRouterV2
 * @notice Routes RetroPick collateral to Aave v3 for yield generation.
 *         Uses scaled balance accounting for precision across rolling epochs.
 *         Captures LM rewards via IRewardsController.
 *         Pre-flight checks reserve health before each interaction.
 *
 * @dev    Storage layout (append-only for potential proxy upgrade):
 *         slot 0: stakeToken
 *         slot 1: aavePool
 *         slot 2: aToken
 *         slot 3: rewardsController
 *         slot 4: engine
 *         slot 5: yieldFeeBps
 *         slot 6: globalScaledBalance
 *         slot 7: templates mapping
 */
contract YieldRouterV2 is IYieldRouterV2, Ownable2Step {
    using SafeERC20  for IERC20;
    using WadRayMath for uint256;

    // ─── Immutables ─────────────────────────────────────────────────────────
    IERC20               public immutable stakeToken;        // USDT on Arbitrum
    IPool                public immutable aavePool;          // Aave v3 Pool proxy
    IERC20               public immutable aToken;            // aUSDT
    IRewardsController   public immutable rewardsController; // Aave rewards
    address              public immutable engine;            // MarketEngine proxy

    // ─── Mutable state ──────────────────────────────────────────────────────
    uint16               public yieldFeeBps;                 // protocol fee on yield (bps)
    uint256              public globalScaledBalance;         // total scaled aUSDT held

    // ─── Per-template accounting ─────────────────────────────────────────────
    struct TemplateYield {
        uint256 scaledPrincipal;    // stable scaled units (sum of rayDiv contributions)
        uint128 lmRewardsSwept;     // total LM reward tokens swept (informational)
        uint128 yieldFeePaidUsdt;   // cumulative yield fee collected in USDT
    }
    mapping(bytes32 => TemplateYield) public templates;

    // ─── Constants ──────────────────────────────────────────────────────────
    uint16  public constant MAX_FEE_BPS = 2000; // 20% max yield fee
    uint256 public constant BUFFER_BPS  = 500;  // 5% of deposits kept in engine

    // ─── Modifiers ──────────────────────────────────────────────────────────
    modifier onlyEngine() {
        require(msg.sender == engine, "YR: only engine");
        _;
    }
    modifier onlyEngineOrOwner() {
        require(msg.sender == engine || msg.sender == owner(), "YR: unauthorized");
        _;
    }

    // ─── Constructor ────────────────────────────────────────────────────────
    constructor(
        address _stakeToken,
        address _aavePool,
        address _aToken,
        address _rewardsController,
        address _engine,
        uint16  _yieldFeeBps
    ) Ownable(msg.sender) {
        require(_yieldFeeBps <= MAX_FEE_BPS, "YR: fee too high");

        stakeToken        = IERC20(_stakeToken);
        aavePool          = IPool(_aavePool);
        aToken            = IERC20(_aToken);
        rewardsController = IRewardsController(_rewardsController);
        engine            = _engine;
        yieldFeeBps       = _yieldFeeBps;

        // One-time max approval — eliminates per-deposit approve() gas cost
        IERC20(_stakeToken).approve(_aavePool, type(uint256).max);
    }

    // ─── Core: depositScaled ─────────────────────────────────────────────────
    /**
     * @notice Supply USDT to Aave v3 and record scaled balance for templateId.
     * @dev    Called by engine on every _depositToSide() with the 95% routed portion.
     *         Uses scaled balance delta to precisely track the template's pool share.
     * @param  templateId   Template receiving the deposit.
     * @param  usdtAmount   Raw USDT amount (6 decimals).
     * @return scaledMinted Scaled aUSDT units attributed to this deposit.
     */
    function depositScaled(bytes32 templateId, uint256 usdtAmount)
        external override onlyEngine
        returns (uint256 scaledMinted)
    {
        require(usdtAmount > 0, "YR: zero amount");
        _requireReserveHealthy();

        // Pull USDT from engine (engine approved router in constructor / one-time)
        stakeToken.safeTransferFrom(engine, address(this), usdtAmount);

        // Snapshot scaled balance before supply
        uint256 scaledBefore = globalScaledBalance;

        // Supply to Aave — mints aUSDT to this contract
        aavePool.supply(address(stakeToken), usdtAmount, address(this), 0);

        // Compute exact scaled units minted using aToken.scaledBalanceOf
        uint256 scaledAfter  = IScaledBalanceToken(address(aToken)).scaledBalanceOf(address(this));
        scaledMinted         = scaledAfter - scaledBefore;

        // Update state
        globalScaledBalance                    = scaledAfter;
        templates[templateId].scaledPrincipal += scaledMinted;

        emit YieldDepositedScaled(
            templateId,
            usdtAmount,
            scaledMinted,
            aavePool.getReserveNormalizedIncome(address(stakeToken))
        );
    }

    // ─── Core: withdrawScaled ────────────────────────────────────────────────
    /**
     * @notice Redeem USDT from Aave v3 proportional to principalAmount.
     * @dev    Called by engine at resolveEpoch / executeRollingRound.
     *         Returns gross USDT (principal + yield) directly to engine.
     *         Uses try/catch in engine; this function does NOT catch.
     * @param  templateId       Template being resolved.
     * @param  principalAmount  Original deposit amount to redeem against.
     * @return grossUSDT        Actual USDT returned (>= principalAmount if yield accrued).
     */
    function withdrawScaled(bytes32 templateId, uint256 principalAmount)
        external override onlyEngine
        returns (uint256 grossUSDT)
    {
        _requireReserveWithdrawable();

        TemplateYield storage t = templates[templateId];
        require(t.scaledPrincipal > 0, "YR: no deposit");

        uint256 currentIndex = aavePool.getReserveNormalizedIncome(address(stakeToken));
        uint256 currentValue = t.scaledPrincipal.rayMul(currentIndex);

        uint256 scaledToRedeem;
        if (principalAmount >= currentValue) {
            // Full redemption — sweep all scaled units for this template
            scaledToRedeem = t.scaledPrincipal;
        } else {
            // Partial redemption — proportional to principalAmount
            // scaledToRedeem = principalAmount.rayDiv(currentIndex)
            scaledToRedeem = principalAmount.rayDiv(currentIndex);
            // Guard: never redeem more than we hold
            if (scaledToRedeem > t.scaledPrincipal) {
                scaledToRedeem = t.scaledPrincipal;
            }
        }

        // Redeem from Aave — USDT sent directly to engine
        // Pass scaledToRedeem as aToken amount (1 scaled unit ≈ 1 aToken in value)
        grossUSDT = aavePool.withdraw(address(stakeToken), scaledToRedeem, engine);

        // Update state
        t.scaledPrincipal   -= scaledToRedeem;
        globalScaledBalance -= scaledToRedeem;

        emit YieldWithdrawnScaled(
            templateId,
            principalAmount,
            scaledToRedeem,
            grossUSDT,
            currentIndex
        );
    }

    // ─── LM Rewards ──────────────────────────────────────────────────────────
    /**
     * @notice Claim all accrued LM rewards for the aUSDT held by this router.
     * @dev    Keeper calls this periodically (e.g., weekly) or before major resolutions.
     *         Reward tokens (ARB, AAVE, etc.) are transferred to engine treasury.
     * @param  templateId  The template to attribute rewards to (for event/analytics only).
     */
    function claimLMRewards(bytes32 templateId)
        external override onlyEngineOrOwner
        returns (address[] memory rewardsList, uint256[] memory amounts)
    {
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);

        (rewardsList, amounts) = rewardsController.claimAllRewards(assets, address(this));

        for (uint256 i = 0; i < rewardsList.length; i++) {
            if (amounts[i] == 0) continue;
            IERC20(rewardsList[i]).safeTransfer(engine, amounts[i]);
            templates[templateId].lmRewardsSwept += uint128(amounts[i]);
            emit LMRewardsClaimed(templateId, rewardsList[i], amounts[i]);
        }
    }

    // ─── Emergency ───────────────────────────────────────────────────────────
    /**
     * @notice Emergency withdrawal — redeem ALL aUSDT for a template.
     * @dev    Admin-only. Bypasses reserve health check.
     *         Use when Aave pool is paused or being migrated.
     */
    function emergencyWithdraw(bytes32 templateId)
        external override onlyEngineOrOwner
        returns (uint256 grossUSDT)
    {
        TemplateYield storage t = templates[templateId];
        if (t.scaledPrincipal == 0) return 0;

        // Attempt type(uint256).max withdraw — redeems full aToken balance
        try aavePool.withdraw(address(stakeToken), type(uint256).max, engine)
            returns (uint256 amount)
        {
            grossUSDT = amount;
        } catch {
            // If pool is fully paused, transfer raw aTokens to engine
            uint256 aBalance = aToken.balanceOf(address(this));
            aToken.safeTransfer(engine, aBalance);
            grossUSDT = aBalance; // approximate in aToken units
        }

        globalScaledBalance -= t.scaledPrincipal;
        t.scaledPrincipal    = 0;

        emit EmergencyWithdraw(templateId, grossUSDT);
    }

    // ─── View functions ───────────────────────────────────────────────────────
    function currentValueOf(bytes32 templateId) external view override returns (uint256) {
        uint256 idx = aavePool.getReserveNormalizedIncome(address(stakeToken));
        return templates[templateId].scaledPrincipal.rayMul(idx);
    }

    function currentYieldOf(bytes32 templateId, uint256 originalPrincipal)
        external view override
        returns (uint256 gross, uint256 netYield, uint256 fee)
    {
        gross = this.currentValueOf(templateId);
        uint256 yieldGross = gross > originalPrincipal ? gross - originalPrincipal : 0;
        fee    = (yieldGross * yieldFeeBps) / 10_000;
        netYield = yieldGross - fee;
    }

    function pendingLMRewards(bytes32 /*templateId*/)
        external view override
        returns (address[] memory tokens, uint256[] memory pending)
    {
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        (tokens, pending) = rewardsController.getAllUserRewards(assets, address(this));
    }

    // ─── Reserve health internals ────────────────────────────────────────────
    function _requireReserveHealthy() internal view {
        DataTypes.ReserveConfigurationMap memory cfg =
            aavePool.getConfiguration(address(stakeToken));
        uint256 data  = cfg.data;
        bool isActive = (data >> 56) & 1 == 1;
        bool isFrozen = (data >> 57) & 1 == 1;
        bool isPaused = (data >> 60) & 1 == 1;
        require(isActive && !isFrozen && !isPaused, "YR: reserve not healthy");
    }

    function _requireReserveWithdrawable() internal view {
        DataTypes.ReserveConfigurationMap memory cfg =
            aavePool.getConfiguration(address(stakeToken));
        bool isPaused = (cfg.data >> 60) & 1 == 1;
        require(!isPaused, "YR: reserve paused");
    }

    // ─── Admin ────────────────────────────────────────────────────────────────
    function setYieldFeeBps(uint16 newFeeBps) external onlyOwner {
        require(newFeeBps <= MAX_FEE_BPS, "YR: fee too high");
        emit YieldFeeBpsUpdated(yieldFeeBps, newFeeBps);
        yieldFeeBps = newFeeBps;
    }

    /// @dev Rescue tokens accidentally sent to this contract.
    ///      Cannot rescue aToken (the yield-bearing asset managed by this contract).
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(aToken), "YR: cannot rescue aToken");
        IERC20(token).safeTransfer(to, amount);
    }
}
```

---

## 10. YieldAccounting Library

A pure library that provides ray math helpers and yield calculation utilities. Separating this allows reuse in tests and other contracts.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title  YieldAccounting
 * @notice Pure library for Aave v3 scaled balance yield calculations.
 *         All ray math (1e27 precision) matches Aave's WadRayMath exactly.
 */
library YieldAccounting {

    uint256 internal constant RAY         = 1e27;
    uint256 internal constant HALF_RAY    = 5e26;
    uint256 internal constant BPS_DENOM   = 10_000;

    /// @notice Multiply a uint256 by a ray (1e27 scale), rounding half up.
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        return (a * b + HALF_RAY) / RAY;
    }

    /// @notice Divide a uint256 by a ray, rounding half up.
    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "YA: div by zero");
        return (a * RAY + b / 2) / b;
    }

    /**
     * @notice Compute the current real value of a scaled position.
     * @param  scaledBalance    Scaled units held (from scaledBalanceOf).
     * @param  liquidityIndex   Current Aave liquidityIndex (from getReserveNormalizedIncome).
     * @return realValue        Underlying USDT value of the position.
     */
    function scaledToReal(uint256 scaledBalance, uint256 liquidityIndex)
        internal pure returns (uint256 realValue)
    {
        return rayMul(scaledBalance, liquidityIndex);
    }

    /**
     * @notice Compute scaled units for a given real amount at the current index.
     * @param  realAmount       Underlying USDT amount.
     * @param  liquidityIndex   Current Aave liquidityIndex.
     * @return scaled           Scaled units equivalent.
     */
    function realToScaled(uint256 realAmount, uint256 liquidityIndex)
        internal pure returns (uint256 scaled)
    {
        return rayDiv(realAmount, liquidityIndex);
    }

    /**
     * @notice Compute gross yield, net yield, and fee from a scaled position.
     * @param  scaledBalance    Current scaled units.
     * @param  liquidityIndex   Current Aave liquidityIndex.
     * @param  originalPrincipal  Original USDT deposited.
     * @param  feeBps           Protocol yield fee in basis points.
     */
    function computeYield(
        uint256 scaledBalance,
        uint256 liquidityIndex,
        uint256 originalPrincipal,
        uint256 feeBps
    ) internal pure returns (
        uint256 grossValue,
        uint256 grossYield,
        uint256 netYield,
        uint256 fee
    ) {
        grossValue  = scaledToReal(scaledBalance, liquidityIndex);
        grossYield  = grossValue > originalPrincipal ? grossValue - originalPrincipal : 0;
        fee         = (grossYield * feeBps) / BPS_DENOM;
        netYield    = grossYield - fee;
    }

    /**
     * @notice Proportional scaled units for a partial withdrawal.
     * @param  totalScaled      Total scaled units for the template.
     * @param  totalPrincipal   Total original principal for the template.
     * @param  withdrawAmount   Amount to withdraw.
     * @param  liquidityIndex   Current index.
     * @return scaledToRedeem   Scaled units to pass to IPool.withdraw().
     */
    function proportionalScaled(
        uint256 totalScaled,
        uint256 totalPrincipal,
        uint256 withdrawAmount,
        uint256 liquidityIndex
    ) internal pure returns (uint256 scaledToRedeem) {
        // Option A: proportional by value fraction
        uint256 totalValue = scaledToReal(totalScaled, liquidityIndex);
        if (withdrawAmount >= totalValue) return totalScaled;
        // scaledToRedeem = totalScaled * withdrawAmount / totalValue
        scaledToRedeem = (totalScaled * withdrawAmount) / totalValue;
        // Guard: never exceed total
        if (scaledToRedeem > totalScaled) scaledToRedeem = totalScaled;
    }
}
```

---

## 11. MarketEngine V2 Diff

### 11.1 Storage additions (append to __gap)

```solidity
// Before (existing):
IYieldRouter    public yieldRouter;    // V1 interface
uint16          public yieldFeeBps;
uint256[46]     __gap;

// After (V2):
IYieldRouterV2  public yieldRouter;    // upgraded to V2 interface
uint16          public yieldFeeBps;
bool            public lmRewardsEnabled;  // flag: keeper claims LM rewards
uint256[45]     __gap;                 // 46 - 1 = 45
```

### 11.2 `_depositToSide()` V2 diff

```solidity
// ── EXISTING: MarketMath active reserve update ─────────────────
MarketMath.addToActiveReserve(ledger, netDeposit);

// ── V2: Route 95% to yield router (5% buffer stays in engine) ──
if (address(yieldRouter) != address(0)) {
    uint256 routeAmount = netDeposit - (netDeposit * YieldRouterV2.BUFFER_BPS() / 10_000);
    if (routeAmount > 0) {
        stakeToken.safeApprove(address(yieldRouter), routeAmount);
        try yieldRouter.depositScaled(templateId, routeAmount) {
            // success — scaled balance tracked in router
        } catch {
            // deposit to Aave failed (frozen/paused) — engine holds full amount
            emit YieldRouterDepositFailed(templateId, routeAmount);
        }
    }
}

// ── EXISTING: emit Deposited event ────────────────────────────
emit Deposited(templateId, epochId, beneficiary, outcome, netDeposit);
```

### 11.3 `_finishResolveEpoch()` V2 diff

```solidity
// ── EXISTING: resolver computes winning mask ───────────────────
(bool voided, uint256 mask) = _applyResolver(templateId, e, checkpointA, checkpointB);

// ── V2: Withdraw from yield router with exact ray accounting ───
uint256 grossFromAave  = e.totalPool;  // fallback: plain pool
uint256 yieldAmount    = 0;

if (address(yieldRouter) != address(0)) {
    // Compute 95% of totalPool (what was actually routed)
    uint256 routedPrincipal = e.totalPool
        - (e.totalPool * YieldRouterV2.BUFFER_BPS() / 10_000);

    try yieldRouter.withdrawScaled(templateId, routedPrincipal)
        returns (uint256 gross)
    {
        grossFromAave = gross + (e.totalPool - routedPrincipal); // gross + buffer
        yieldAmount   = grossFromAave > e.totalPool
                        ? grossFromAave - e.totalPool
                        : 0;
    } catch {
        emit YieldRouterWithdrawFailed(templateId, e.id, e.totalPool);
        // fallback: engine holds buffer; yield = 0; epoch resolves at principal
    }
}

// ── V2: Yield fee split ────────────────────────────────────────
uint256 yieldFee  = (yieldAmount * uint256(yieldFeeBps)) / 10_000;
uint256 netYield  = yieldAmount - yieldFee;
if (yieldFee > 0) MarketMath.addToFeeReserve(ledger, yieldFee);

// ── V2: Record yield on epoch (new Epoch struct fields) ────────
e.yieldGross = uint128(yieldAmount);
e.yieldNet   = uint128(netYield);

// ── V2: Inflate claim liability by netYield ────────────────────
MarketMath.computeEpochClaimLiabilityStorage(e, ledger, netYield);

if (yieldAmount > 0) {
    emit EpochYieldAccrued(templateId, e.id, yieldAmount, yieldFee, netYield,
        aavePool.getReserveNormalizedIncome(address(stakeToken)));
}

// ── EXISTING: set epoch claimable ─────────────────────────────
e.claimable = true;
```

### 11.4 New keeper function: `keeperClaimLMRewards()`

```solidity
/// @notice Sweep LM rewards from the yield router to engine treasury.
/// @dev    Callable by workerAuthority. Rewards (ARB, AAVE) go to treasury.
///         Not time-critical — can be called weekly or on any convenient block.
function keeperClaimLMRewards(bytes32 templateId) external onlyWorkerOrAdmin {
    if (address(yieldRouter) == address(0)) revert NoYieldRouter();
    if (!lmRewardsEnabled) return;

    (address[] memory tokens, uint256[] memory amounts) =
        yieldRouter.claimLMRewards(templateId);

    for (uint256 i = 0; i < tokens.length; i++) {
        if (amounts[i] > 0) {
            // LM rewards are non-USDT tokens; they go to treasury directly
            // They are NOT mixed with USDT claim pools (avoids DEX dependency)
            emit LMRewardReceived(templateId, tokens[i], amounts[i]);
        }
    }
}
```

---

## 12. Rolling Markets: Per-Epoch Scaled Snapshot

### 12.1 The rolling challenge

In rolling mode, `executeRollingRound()` resolves epoch `k-1`, locks epoch `k`, and opens `k+1` — all in one transaction. The yield router holds a single `scaledPrincipal` bucket per `templateId` that accumulates across all open rolling epochs.

When resolving epoch `k-1`, the engine must pass only that epoch's share of `scaledPrincipal` to `withdrawScaled()`.

### 12.2 Per-epoch scaled snapshot

V2 introduces a `scaledSnapshot` stored on each epoch at lock time:

```solidity
// Epoch struct addition (append-only):
uint128 scaledSnapshot;   // scaledPrincipal in router at the moment this epoch was locked
```

At `lockEpoch()` / `genesisLockRolling()` / `executeRollingRound()` lock step:

```solidity
// After locking checkpoint A:
if (address(yieldRouter) != address(0)) {
    // Snapshot the scaled principal attributed to this epoch
    // = total template scaledPrincipal at lock time × (this epoch's pool / total pool at lock)
    // Simplified: snapshot the current router scaledPrincipal for this epoch
    e.scaledSnapshot = uint128(
        yieldRouter.templates(templateId).scaledPrincipal
    );
}
```

At resolution, `withdrawScaled(templateId, routedPrincipal)` uses the current `scaledPrincipal` proportionally — which is exactly the right fraction since deposits during epoch `k` (which rolled into `k+1`) are still in the bucket. The proportional math in `withdrawScaled()` handles this correctly.

### 12.3 Why the proportional math is correct for rolling

For a rolling market with overlapping epochs:

```
Time:         t0       t5       t10      t15
              │        │        │        │
Epoch:        [─── k-1 ────][─── k ────][── k+1 ──
                              ↑lock k    ↑resolve k-1
```

At `t10` (executeRollingRound):
- Router holds `scaledPrincipal = S_k-1 + S_k` (both epochs)
- Engine calls `withdrawScaled(tid, routedPrincipal[k-1])`
- `withdrawScaled()` computes `scaledToRedeem = S_k-1 × currentIndex / currentValue`
- This correctly redeems only the k-1 fraction, leaving S_k intact

---

## 13. New Events, View Functions, Invariants

### 13.1 YieldRouter V2 events

```solidity
event YieldDepositedScaled(
    bytes32 indexed templateId,
    uint256 usdtAmount,
    uint256 scaledMinted,
    uint256 liquidityIndex    // for off-chain APY calculation
);

event YieldWithdrawnScaled(
    bytes32 indexed templateId,
    uint256 principalRequested,
    uint256 scaledRedeemed,
    uint256 grossUSDT,
    uint256 liquidityIndex
);

event LMRewardsClaimed(
    bytes32 indexed templateId,
    address indexed rewardToken,
    uint256 amount
);

event EmergencyWithdraw(bytes32 indexed templateId, uint256 amount);
event YieldFeeBpsUpdated(uint16 oldBps, uint16 newBps);
```

### 13.2 MarketEngine V2 events

```solidity
event EpochYieldAccrued(
    bytes32 indexed templateId,
    uint64  indexed epochId,
    uint256 yieldGross,
    uint256 yieldFee,
    uint256 yieldNet,
    uint256 liquidityIndexAtResolution  // allows off-chain APY verification
);

event YieldRouterDepositFailed(bytes32 indexed templateId, uint256 attemptedAmount);
event YieldRouterWithdrawFailed(bytes32 indexed templateId, uint64 epochId, uint256 principal);
event LMRewardReceived(bytes32 indexed templateId, address indexed token, uint256 amount);
```

### 13.3 Critical invariants (Foundry invariant tests)

```solidity
/// INV-1: Router's aToken scaled balance == sum of all template scaledPrincipals
function invariant_scaledBalanceConservation() external view {
    uint256 sumScaled = 0;
    for (uint i = 0; i < templateIds.length; i++) {
        sumScaled += router.templates(templateIds[i]).scaledPrincipal;
    }
    assertEq(
        sumScaled,
        router.globalScaledBalance(),
        "scaled balance mismatch"
    );
}

/// INV-2: globalScaledBalance <= aToken.scaledBalanceOf(router)
function invariant_globalScaledLeAaveScaled() external view {
    uint256 aaveScaled = IScaledBalanceToken(address(aToken))
        .scaledBalanceOf(address(router));
    assertLe(
        router.globalScaledBalance(),
        aaveScaled + 1, // +1 for rounding tolerance
        "router claims more scaled than Aave holds"
    );
}

/// INV-3: currentValueOf(tid) >= epoch.totalPool for all resolved epochs
function invariant_yieldNonNegative() external view {
    for (uint i = 0; i < templateIds.length; i++) {
        bytes32 tid = templateIds[i];
        uint256 val = router.currentValueOf(tid);
        uint256 principal = engine.ledgers(tid).activeReserveTotal;
        // yield can be 0 but never negative (USDT doesn't deflate in Aave)
        assertGe(val + 1, principal, "negative yield on template");
    }
}

/// INV-4: No free money — total withdrawn <= total deposited + accrued interest
function invariant_noFreeYield() external view {
    assertLe(
        totalWithdrawnGross,
        totalDepositedPrincipal + estimatedMaxAccruedInterest,
        "withdrew more than possible"
    );
}
```

---

## 14. Migration Path from V1

### 14.1 State at migration time

At V1→V2 migration, the V1 router holds:
- Raw `aTokenSharesByTemplate[tid]` (V1 rebasing units)
- Live aUSDT in Aave

### 14.2 Migration steps

```
1. Admin calls engine.pauseProgram(true)
2. For each active templateId:
   a. engine.yieldEmergencyWithdraw(templateId)  // pulls all aUSDT back to engine as USDT
   b. Records grossUSDT returned
3. Deploy YieldRouterV2 with same addresses
4. UUPS upgrade MarketEngine to V2 implementation
5. Call engine.setYieldRouterV2(newRouter, feeBps) on upgraded engine
6. For each templateId: engine re-deposits into V2 router
   // engine.keeperReDepositToYieldRouter(templateId, amount)
7. engine.pauseProgram(false)
```

The critical step is (2a): emergency withdrawal from V1 router converts rebasing aToken shares to exact USDT, then V2 router re-deposits cleanly using scaled balance accounting. No mathematical carry-over of V1's imprecise shares.

### 14.3 Zero-downtime variant (for rolling markets with 5-min intervals)

For rolling markets that cannot tolerate a pause:

1. Deploy V2 router but do NOT set it on the engine yet
2. At the next `executeRollingRound()`, the old V1 router handles resolve+deposit for the transitioning epoch
3. Admin calls `setYieldRouterV2()` between rounds
4. Next `executeRollingRound()` uses V2 router for the new epoch's deposit

The worst case is one epoch resolving with V1 (slightly imprecise yield) and the next with V2 (exact). Financially this is immaterial — a few wei of yield rounding.

---

## 15. Test Strategy

### 15.1 Unit tests — pure math (no fork)

```solidity
// test/YieldAccountingLib.t.sol
contract YieldAccountingLibTest is Test {
    using YieldAccounting for *;

    function test_scaledToReal_identity() public {
        // At index = 1 RAY, scaled == real
        assertEq(YieldAccounting.scaledToReal(1e6, 1e27), 1e6);
    }

    function test_scaledToReal_doubledIndex() public {
        // At index = 2 RAY, 1e6 scaled = 2e6 real
        assertEq(YieldAccounting.scaledToReal(1e6, 2e27), 2e6);
    }

    function test_computeYield_basic() public {
        (uint256 gross, uint256 grossYield, uint256 net, uint256 fee) =
            YieldAccounting.computeYield(1000e6, 1.03e27, 1000e6, 1000); // 10% fee
        assertApproxEqAbs(gross, 1030e6, 1);
        assertApproxEqAbs(grossYield, 30e6, 1);
        assertApproxEqAbs(fee, 3e6, 1);
        assertApproxEqAbs(net, 27e6, 1);
    }

    function test_proportionalScaled_partial() public {
        // 50% withdrawal should return 50% of scaled
        uint256 result = YieldAccounting.proportionalScaled(
            2000, // totalScaled
            1000e6, // totalPrincipal
            500e6,  // withdrawAmount = 50% of value
            1.0e27  // index
        );
        assertApproxEqAbs(result, 1000, 1); // ~50% of scaled
    }
}
```

### 15.2 Router unit tests — MockAavePool V2

```solidity
// test/mocks/MockAavePoolV2.sol
// Simulates scaledBalanceOf, getReserveNormalizedIncome, getConfiguration correctly
// Supports configurable liquidityIndex growth per time warp
// Supports freeze/pause bit simulation for health guard tests

contract MockAavePoolV2 {
    uint256 public liquidityIndex = 1e27; // starts at 1 RAY
    mapping(address => uint256) public scaledBalances;
    bool public frozen;
    bool public paused;
    bool public active = true;

    function supply(address, uint256 amount, address onBehalfOf, uint16) external {
        uint256 scaled = WadRayMath.rayDiv(amount, liquidityIndex);
        scaledBalances[onBehalfOf] += scaled;
    }

    function withdraw(address, uint256 scaledAmount, address to) external returns (uint256) {
        uint256 real = WadRayMath.rayMul(scaledAmount, liquidityIndex);
        scaledBalances[msg.sender] -= scaledAmount;
        IERC20(usdt).transfer(to, real);
        return real;
    }

    function getReserveNormalizedIncome(address) external view returns (uint256) {
        return liquidityIndex;
    }

    function getConfiguration(address) external view returns (DataTypes.ReserveConfigurationMap memory) {
        uint256 data = 0;
        if (active)  data |= (1 << 56);
        if (frozen)  data |= (1 << 57);
        if (paused)  data |= (1 << 60);
        return DataTypes.ReserveConfigurationMap({data: data});
    }

    // Test helper: grow the index to simulate time passing
    function warpIndex(uint256 newIndex) external { liquidityIndex = newIndex; }
}
```

### 15.3 Integration / fork tests

```bash
# Run with Arbitrum mainnet fork
forge test --fork-url $ARBITRUM_RPC \
           --match-path "test/fork/YieldRouterV2Fork.t.sol" \
           --fork-block-number 285000000

# Key test cases:
# - depositScaled + warp 30 days + withdrawScaled: assert gross > principal
# - scaledBalanceOf invariant holds across 50 rolling epoch iterations
# - Reserve health guard: freeze USDT market (as pool admin), assert deposit reverts
# - LM rewards: use Arbitrum ARB incentive program, claimLMRewards, assert tokens swept
# - Migration: V1 emergency withdraw + V2 re-deposit, assert no value loss
```

### 15.4 Invariant test harness

```bash
forge test --match-path "test/invariant/YieldRouterV2Invariant.t.sol" \
           --fuzz-runs 10000

# Fuzzer drives random sequences of:
# - depositScaled(templateId, amount)
# - withdrawScaled(templateId, amount)
# - warpIndex(newIndex)
# - claimLMRewards(templateId)
# After each: check INV-1 through INV-4
```

---

## 16. Risk Register V2

| Risk | Likelihood | Impact | V2 Mitigation vs V1 |
|------|-----------|--------|---------------------|
| Scaled balance rounding error | Very low | Low | V2 uses exact rayMul/rayDiv, not delta on rebasing balance. Off-by-one bounded by WadRayMath precision (1e-27). |
| Aave pool frozen (no new supply) | Low | Medium | V2 `_requireReserveHealthy()` checks frozen bit — deposit fails cleanly instead of reverting inside Aave's internal revert path. Engine try/catch handles gracefully. |
| Aave pool paused (no supply OR withdraw) | Very low | High | V2 `_requireReserveWithdrawable()` on withdraw. Emergency withdraw transfers raw aTokens to engine if pool is unresponsive. |
| globalScaledBalance desync | Very low | High | INV-1 and INV-2 invariant tests catch any desync in CI. Strict +/- accounting on every deposit/withdraw. |
| LM reward tokens accumulate in router | Medium | Low | V2 `claimLMRewards()` callable by keeper. Keeper monitoring alert if unclaimed > 7 days. |
| Rolling partial withdrawal precision | Low | Medium | V2 proportional scaled math exact to ray precision. Fork test with 100+ epoch simulation. |
| IRewardsController address changes | Low | Low | Immutable in router. If changed by Aave governance, deploy new router and migrate. |
| Rounding dust in `scaledPrincipal` | Medium | Very low | After all epochs of a template resolve, `scaledPrincipal` may have 1-2 wei dust. `emergencyWithdraw()` sweeps with `type(uint256).max`. |

---

## 17. Complete File Change Summary

### New files

| File | Lines (est.) | Description |
|------|-------------|-------------|
| `src/interfaces/IYieldRouterV2.sol` | ~60 | V2 interface: depositScaled, withdrawScaled, claimLMRewards, currentValueOf, etc. |
| `src/YieldRouterV2.sol` | ~280 | Full V2 router with scaled accounting, LM rewards, reserve health guard |
| `src/libraries/YieldAccounting.sol` | ~100 | Pure library: rayMul/rayDiv, scaledToReal, computeYield, proportionalScaled |
| `test/YieldAccountingLib.t.sol` | ~120 | Unit tests for YieldAccounting library |
| `test/YieldRouterV2.t.sol` | ~350 | Unit tests with MockAavePoolV2 |
| `test/fork/YieldRouterV2Fork.t.sol` | ~250 | Arbitrum mainnet fork integration tests |
| `test/invariant/YieldRouterV2Invariant.t.sol` | ~150 | Foundry invariant harness |
| `test/mocks/MockAavePoolV2.sol` | ~120 | Configurable mock with scaledBalanceOf, index growth, freeze/pause bits |

### Modified files

| File | Change summary |
|------|---------------|
| `src/MarketEngine.sol` | Storage: `IYieldRouter` → `IYieldRouterV2`, add `lmRewardsEnabled` bool. `_depositToSide()`: use `depositScaled()`. `_finishResolveEpoch()`: use `withdrawScaled()` with ray-exact yield accounting. New `keeperClaimLMRewards()`. New events. |
| `src/types/MarketTypes.sol` | Epoch struct: append `uint128 yieldGross`, `uint128 yieldNet`, `uint128 scaledSnapshot`. |
| `src/math/MarketMath.sol` | `computeEpochClaimLiabilityStorage()`: already updated in V1 for `netYield` param — no further change needed. |
| `script/Deploy.s.sol` | Deploy `YieldRouterV2` after adapter. Add `IRewardsController` address as param. |
| `script/UpgradeMarketEngine.s.sol` | Upgrade to V2 impl + migrate router from V1 to V2. |

### Removed/replaced files

| File | Action |
|------|--------|
| `src/YieldRouter.sol` (V1) | Retained for migration period; deprecated after all templates migrated |
| `src/interfaces/IYieldRouter.sol` (V1) | Retained; V2 interface is additive, not a replacement in the type system |

---

## Appendix A: Aave v3 Addresses (Arbitrum One)

| Contract | Address |
|----------|---------|
| USDT | `0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9` |
| aUSDT | `0x6ab707Aca953eDAeFBc4fD23bA73294241490620` |
| Aave v3 Pool proxy | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |
| Pool Addresses Provider | `0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb` |
| Rewards Controller | `0x929EC64c34a17401F460460D4B9390518E5B473e` |
| StaticATokenFactory | `0x411D79b8cC43384FDE66CaBf9b6a17180c842511` |
| Sequencer uptime feed | `0xFdB631F5EE196F0ed6FAa767959853A9F217697D` |

---

## Appendix B: Ray Math Quick Reference

```
RAY = 1e27

// aToken balance = scaledBalance × liquidityIndex / RAY
// liquidityIndex starts at 1e27, grows with each second of interest

// When supply(USDT, 1000e6):
//   scaledMinted = 1000e6 × RAY / liquidityIndex
//   e.g. at index 1.03e27: scaledMinted = 1000e6 × 1e27 / 1.03e27 ≈ 970.87e6

// When withdraw with 970.87e6 scaled at new index 1.06e27:
//   realReturned = 970.87e6 × 1.06e27 / 1e27 ≈ 1029.12e6
//   yield = 1029.12e6 - 1000e6 = 29.12e6 (≈ 2.9% on 30 days at 35% APY)
```

---

*End of document.*