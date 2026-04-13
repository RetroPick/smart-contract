// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IYieldRouterV2} from "../interfaces/IYieldRouterV2.sol";
import {YieldAccounting} from "../libraries/YieldAccounting.sol";
import {IPoolAaveV3, ReserveConfigurationMap} from "./interfaces/IPoolAaveV3.sol";
import {IScaledBalanceToken} from "./interfaces/IScaledBalanceToken.sol";
import {IRewardsController} from "./interfaces/IRewardsController.sol";

/// @title YieldRouterV2
/// @notice Aave v3 yield router: scaled aToken accounting and optional ERC-4626 StataToken path.
/// @dev Mutating entrypoints are `onlyEngine`. Accounting updates after Aave/4626 calls are acceptable here because
/// the engine is expected to use `nonReentrant` on user ops and trusted admin sets this router address.
contract YieldRouterV2 is IYieldRouterV2, Ownable2Step {
    using SafeERC20 for IERC20;
    using YieldAccounting for uint256;

    IERC20 public immutable STAKE_TOKEN;
    IPoolAaveV3 public immutable AAVE_POOL;
    IERC20 public immutable A_TOKEN;
    IRewardsController public immutable REWARDS_CONTROLLER;
    IERC4626 public immutable STATA_TOKEN;
    address public immutable ENGINE;

    /// @notice Total scaled aToken units held across all AToken-path templates (matches `scaledBalanceOf` when only AToken path is used).
    uint256 public globalScaledBalance;

    struct TemplateYield {
        uint256 principal;
        uint256 scaledPrincipal;
        uint256 stataShares;
        IYieldRouterV2.YieldPath path;
    }

    mapping(bytes32 templateId => TemplateYield) internal _templates;

    error OnlyEngine();
    error Unauthorized();
    error ZeroAmount();
    error InvalidAddress();
    error OverWithdraw();
    error ReserveNotHealthy();
    error ReservePaused();
    error StataNotConfigured();
    error CannotChangePath();

    event YieldDepositedScaled(
        bytes32 indexed templateId, uint256 stakeAmount, uint256 attributionUnits, uint256 liquidityIndex
    );
    event YieldDepositedStata(bytes32 indexed templateId, uint256 stakeAmount, uint256 sharesMinted);
    event YieldWithdrawnScaled(
        bytes32 indexed templateId,
        uint256 principalRequested,
        uint256 scaledBurned,
        uint256 grossReturned,
        uint256 liquidityIndex
    );
    event YieldWithdrawnStata(bytes32 indexed templateId, uint256 principalRequested, uint256 sharesBurned, uint256 grossReturned);
    event TemplateYieldPathSet(bytes32 indexed templateId, IYieldRouterV2.YieldPath path);
    event LMRewardsClaimed(bytes32 indexed templateId, address indexed rewardToken, uint256 amount);
    event EmergencyWithdrawV2(bytes32 indexed templateId, uint256 grossReturned);

    modifier onlyEngine() {
        if (msg.sender != ENGINE) revert OnlyEngine();
        _;
    }

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
        STAKE_TOKEN = IERC20(stakeToken_);
        AAVE_POOL = IPoolAaveV3(aavePool_);
        A_TOKEN = IERC20(aToken_);
        REWARDS_CONTROLLER = IRewardsController(rewardsController_);
        STATA_TOKEN = IERC4626(stataToken_);
        ENGINE = engine_;

        STAKE_TOKEN.forceApprove(aavePool_, type(uint256).max);
        if (stataToken_ != address(0)) {
            STAKE_TOKEN.forceApprove(stataToken_, type(uint256).max);
        }
    }

    // --- IYieldRouter (compat) ---

    function deposit(bytes32 templateId, uint256 amount) external override onlyEngine {
        _depositScaled(templateId, amount);
    }

    function withdraw(bytes32 templateId, uint256 principalAmount) external override onlyEngine returns (uint256 grossAmount) {
        return _withdrawScaled(templateId, principalAmount);
    }

    function balanceOf(bytes32 templateId) external view override returns (uint256) {
        return currentValueOf(templateId);
    }

    function emergencyWithdraw(bytes32 templateId) external override returns (uint256 grossAmount) {
        if (msg.sender != ENGINE && msg.sender != owner()) revert Unauthorized();
        TemplateYield storage t = _templates[templateId];
        uint256 p = t.principal;
        if (p == 0) return 0;
        // Full template unwind (per-template accounting); never use pool max-withdraw for multi-template safety.
        grossAmount = _withdrawScaled(templateId, p);
        emit EmergencyWithdrawV2(templateId, grossAmount);
    }

    // --- IYieldRouterV2 ---

    function depositScaled(bytes32 templateId, uint256 amount)
        external
        override
        onlyEngine
        returns (uint256 attributionUnits)
    {
        return _depositScaled(templateId, amount);
    }

    function withdrawScaled(bytes32 templateId, uint256 principalAmount)
        external
        override
        onlyEngine
        returns (uint256 grossAmount)
    {
        return _withdrawScaled(templateId, principalAmount);
    }

    // slither-disable-next-line reentrancy-no-eth -- `onlyEngine`; Aave/ERC-4626 do not reenter this contract; CEI would mis-account shares vs actual balances.
    function _depositScaled(bytes32 templateId, uint256 amount) internal returns (uint256 attributionUnits) {
        if (amount == 0) revert ZeroAmount();
        TemplateYield storage t = _templates[templateId];
        if (t.path == IYieldRouterV2.YieldPath.StataToken) {
            if (address(STATA_TOKEN) == address(0)) revert StataNotConfigured();
            _requireReserveHealthy();
            // slither-disable-next-line arbitrary-send-erc20 -- `from` is immutable ENGINE; `onlyEngine` gates callers.
            STAKE_TOKEN.safeTransferFrom(ENGINE, address(this), amount);
            uint256 shares = STATA_TOKEN.deposit(amount, address(this));
            t.principal += amount;
            t.stataShares += shares;
            emit YieldDepositedStata(templateId, amount, shares);
            return shares;
        }
        _requireReserveHealthy();
        // slither-disable-next-line arbitrary-send-erc20 -- `from` is immutable ENGINE; `onlyEngine` gates callers.
        STAKE_TOKEN.safeTransferFrom(ENGINE, address(this), amount);
        uint256 scaledBefore = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
        AAVE_POOL.supply(address(STAKE_TOKEN), amount, address(this), 0);
        uint256 scaledAfter = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
        attributionUnits = scaledAfter - scaledBefore;
        globalScaledBalance = scaledAfter;
        t.principal += amount;
        t.scaledPrincipal += attributionUnits;
        uint256 idx = AAVE_POOL.getReserveNormalizedIncome(address(STAKE_TOKEN));
        emit YieldDepositedScaled(templateId, amount, attributionUnits, idx);
    }

    // slither-disable-next-line reentrancy-no-eth -- `onlyEngine`; pool redeem/withdraw does not reenter; state follows actual burned shares.
    function _withdrawScaled(bytes32 templateId, uint256 principalAmount) internal returns (uint256 grossAmount) {
        if (principalAmount == 0) revert ZeroAmount();
        TemplateYield storage t = _templates[templateId];
        uint256 p = t.principal;
        if (principalAmount > p) revert OverWithdraw();

        if (t.path == IYieldRouterV2.YieldPath.StataToken) {
            if (address(STATA_TOKEN) == address(0)) revert StataNotConfigured();
            _requireReserveWithdrawable();
            uint256 sharesTotal = t.stataShares;
            if (sharesTotal == 0) revert OverWithdraw();
            uint256 totalAssets = STATA_TOKEN.convertToAssets(sharesTotal);
            uint256 underlyingRequest = principalAmount == p ? totalAssets : (totalAssets * principalAmount) / p;
            uint256 sharesToRedeem = principalAmount == p ? sharesTotal : STATA_TOKEN.convertToShares(underlyingRequest);
            if (sharesToRedeem > sharesTotal) sharesToRedeem = sharesTotal;
            grossAmount = STATA_TOKEN.redeem(sharesToRedeem, ENGINE, address(this));
            t.stataShares = sharesTotal - sharesToRedeem;
            t.principal = p - principalAmount;
            emit YieldWithdrawnStata(templateId, principalAmount, sharesToRedeem, grossAmount);
            return grossAmount;
        }

        _requireReserveWithdrawable();
        uint256 s = t.scaledPrincipal;
        if (s == 0) revert OverWithdraw();
        uint256 idx = AAVE_POOL.getReserveNormalizedIncome(address(STAKE_TOKEN));
        // Never pass type(uint256).max here: multiple templates may share one router / one aToken position.
        uint256 underlyingToWithdraw = principalAmount == p
            ? s.scaledToReal(idx)
            : YieldAccounting.proportionalUnderlying(s, p, principalAmount, idx);

        uint256 scaledBefore = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
        grossAmount = AAVE_POOL.withdraw(address(STAKE_TOKEN), underlyingToWithdraw, ENGINE);
        uint256 scaledAfter = IScaledBalanceToken(address(A_TOKEN)).scaledBalanceOf(address(this));
        uint256 scaledBurned = scaledBefore - scaledAfter;

        if (principalAmount == p) {
            t.scaledPrincipal = 0;
        } else {
            if (scaledBurned > t.scaledPrincipal) {
                t.scaledPrincipal = 0;
            } else {
                t.scaledPrincipal -= scaledBurned;
            }
        }
        globalScaledBalance = scaledAfter;
        t.principal = p - principalAmount;
        emit YieldWithdrawnScaled(templateId, principalAmount, scaledBurned, grossAmount, idx);
    }

    function currentValueOf(bytes32 templateId) public view override returns (uint256) {
        TemplateYield storage t = _templates[templateId];
        if (t.path == IYieldRouterV2.YieldPath.StataToken) {
            if (address(STATA_TOKEN) == address(0)) return 0;
            return STATA_TOKEN.convertToAssets(t.stataShares);
        }
        uint256 idx = AAVE_POOL.getReserveNormalizedIncome(address(STAKE_TOKEN));
        return t.scaledPrincipal.scaledToReal(idx);
    }

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
                emit LMRewardsClaimed(templateId, rewardsList[i], amounts[i]);
            }
        }
    }

    function pendingLmRewards(bytes32 templateId)
        external
        view
        override
        returns (address[] memory tokens, uint256[] memory pending)
    {
        templateId;
        address rc = address(REWARDS_CONTROLLER);
        if (rc == address(0)) {
            return (new address[](0), new uint256[](0));
        }
        address[] memory assets = new address[](1);
        assets[0] = address(A_TOKEN);
        // slither-disable-next-line unused-return -- full tuple is returned to caller; detector noise on external view.
        return IRewardsController(rc).getAllUserRewards(assets, address(this));
    }

    function setTemplateYieldPath(bytes32 templateId, IYieldRouterV2.YieldPath path) external override onlyOwner {
        TemplateYield storage t = _templates[templateId];
        if (t.principal != 0 || t.scaledPrincipal != 0 || t.stataShares != 0) revert CannotChangePath();
        if (path == IYieldRouterV2.YieldPath.StataToken && address(STATA_TOKEN) == address(0)) revert StataNotConfigured();
        t.path = path;
        emit TemplateYieldPathSet(templateId, path);
    }

    function getTemplateYieldPath(bytes32 templateId) external view override returns (IYieldRouterV2.YieldPath) {
        return _templates[templateId].path;
    }

    function principalOf(bytes32 templateId) external view override returns (uint256) {
        return _templates[templateId].principal;
    }

    function scaledPrincipalOf(bytes32 templateId) external view override returns (uint256) {
        return _templates[templateId].scaledPrincipal;
    }

    function stataSharesOf(bytes32 templateId) external view override returns (uint256) {
        return _templates[templateId].stataShares;
    }

    // --- internals ---

    function _requireReserveHealthy() internal view {
        ReserveConfigurationMap memory cfg = AAVE_POOL.getConfiguration(address(STAKE_TOKEN));
        uint256 data = cfg.data;
        bool isActive = (data >> 56) & 1 == 1;
        bool isFrozen = (data >> 57) & 1 == 1;
        bool isPaused = (data >> 60) & 1 == 1;
        if (!isActive || isFrozen || isPaused) revert ReserveNotHealthy();
    }

    function _requireReserveWithdrawable() internal view {
        ReserveConfigurationMap memory cfg = AAVE_POOL.getConfiguration(address(STAKE_TOKEN));
        bool isPaused = (cfg.data >> 60) & 1 == 1;
        if (isPaused) revert ReservePaused();
    }

    /// @notice Rescue stray ERC20 (not aToken).
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(A_TOKEN)) revert InvalidAddress();
        IERC20(token).safeTransfer(to, amount);
    }
}
