// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IYieldRouter} from "../interfaces/IYieldRouter.sol";
import {IYieldRouterV2} from "../interfaces/IYieldRouterV2.sol";
import {IPoolAaveV3} from "./interfaces/IPoolAaveV3.sol";

/// @title YieldRouterAaveV3
/// @notice Aave v3 yield router that holds aTokens and accounts balances per `templateId`.
/// @dev
/// - Pulls `stakeToken` from the engine on deposit.
/// - Supplies into Aave v3 pool, receiving `aToken` (rebasing receipt token).
/// - Withdraws proportional aToken shares by principal accounting, sending `stakeToken` directly to engine.
/// - Implements `IYieldRouterV2` for dispatcher typing; scaled views map to legacy share accounting.
contract YieldRouterAaveV3 is IYieldRouter, IYieldRouterV2, Ownable2Step {
    using SafeERC20 for IERC20;

    IERC20 public immutable STAKE_TOKEN;
    IPoolAaveV3 public immutable AAVE_POOL;
    IERC20 public immutable A_TOKEN;
    address public immutable ENGINE;

    /// @dev Per-template outstanding principal (in stakeToken units).
    mapping(bytes32 templateId => uint256) public principalByTemplate;

    /// @dev Per-template attributed aToken share balance (in aToken units).
    mapping(bytes32 templateId => uint256) public sharesByTemplate;

    error OnlyEngine();
    error Unauthorized();
    error ZeroAmount();
    error OverWithdraw();
    error InvalidAddress();

    event YieldDeposited(bytes32 indexed templateId, uint256 principal, uint256 sharesMinted);
    event YieldWithdrawn(bytes32 indexed templateId, uint256 principal, uint256 sharesRedeemed, uint256 grossReturned);
    event EmergencyWithdraw(bytes32 indexed templateId, uint256 sharesRedeemed, uint256 grossReturned);

    constructor(address stakeToken_, address aavePool_, address aToken_, address engine_) Ownable(msg.sender) {
        if (stakeToken_ == address(0) || aavePool_ == address(0) || aToken_ == address(0) || engine_ == address(0)) {
            revert InvalidAddress();
        }
        STAKE_TOKEN = IERC20(stakeToken_);
        AAVE_POOL = IPoolAaveV3(aavePool_);
        A_TOKEN = IERC20(aToken_);
        ENGINE = engine_;

        // Pre-approve pool; use USDT-safe forceApprove.
        STAKE_TOKEN.forceApprove(aavePool_, type(uint256).max);
    }

    modifier onlyEngine() {
        if (msg.sender != ENGINE) revert OnlyEngine();
        _;
    }

    function _deposit(bytes32 templateId, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();

        // slither-disable-next-line arbitrary-send-erc20 -- `from` is immutable ENGINE; `onlyEngine` gates callers; pulls engine vault, not arbitrary users.
        STAKE_TOKEN.safeTransferFrom(ENGINE, address(this), amount);

        uint256 beforeBal = A_TOKEN.balanceOf(address(this));
        AAVE_POOL.supply(address(STAKE_TOKEN), amount, address(this), 0);
        uint256 afterBal = A_TOKEN.balanceOf(address(this));
        uint256 minted = afterBal - beforeBal;

        principalByTemplate[templateId] += amount;
        sharesByTemplate[templateId] += minted;

        emit YieldDeposited(templateId, amount, minted);
    }

    // slither-disable-next-line reentrancy-no-eth -- `onlyEngine`; Aave v3 pool does not reenter; accounting updated from actual withdraw result.
    function _withdraw(bytes32 templateId, uint256 principalAmount) internal returns (uint256 grossAmount) {
        if (principalAmount == 0) revert ZeroAmount();

        uint256 principal = principalByTemplate[templateId];
        if (principalAmount > principal) revert OverWithdraw();

        uint256 totalShares = sharesByTemplate[templateId];
        uint256 sharesToRedeem = principalAmount == principal ? totalShares : (totalShares * principalAmount) / principal;

        grossAmount = AAVE_POOL.withdraw(address(STAKE_TOKEN), sharesToRedeem, ENGINE);

        principalByTemplate[templateId] = principal - principalAmount;
        sharesByTemplate[templateId] = totalShares - sharesToRedeem;

        emit YieldWithdrawn(templateId, principalAmount, sharesToRedeem, grossAmount);
    }

    function deposit(bytes32 templateId, uint256 amount) external override onlyEngine {
        _deposit(templateId, amount);
    }

    function withdraw(bytes32 templateId, uint256 principalAmount) external override onlyEngine returns (uint256 grossAmount) {
        return _withdraw(templateId, principalAmount);
    }

    function balanceOf(bytes32 templateId) external view override returns (uint256) {
        return sharesByTemplate[templateId];
    }

    // slither-disable-next-line reentrancy-no-eth -- `onlyEngine`/owner; Aave pool does not reenter; full template unwind.
    function emergencyWithdraw(bytes32 templateId) external override returns (uint256 grossAmount) {
        if (msg.sender != ENGINE && msg.sender != owner()) revert Unauthorized();

        uint256 shares = sharesByTemplate[templateId];
        if (shares == 0) return 0;

        grossAmount = AAVE_POOL.withdraw(address(STAKE_TOKEN), shares, ENGINE);

        principalByTemplate[templateId] = 0;
        sharesByTemplate[templateId] = 0;

        emit EmergencyWithdraw(templateId, shares, grossAmount);
    }

    // --- IYieldRouterV2 (compat layer; legacy rebasing share accounting) ---

    function depositScaled(bytes32 templateId, uint256 amount) external override onlyEngine returns (uint256 attributionUnits) {
        uint256 sharesBefore = sharesByTemplate[templateId];
        _deposit(templateId, amount);
        return sharesByTemplate[templateId] - sharesBefore;
    }

    function withdrawScaled(bytes32 templateId, uint256 principalAmount)
        external
        override
        onlyEngine
        returns (uint256 grossAmount)
    {
        return _withdraw(templateId, principalAmount);
    }

    /// @dev Lower-bound view: tracked principal (excludes unmodeled aToken rebase in this legacy router).
    function currentValueOf(bytes32 templateId) external view override returns (uint256) {
        return principalByTemplate[templateId];
    }

    /// @dev No-op LM path; stricter `view` than `IYieldRouterV2` is valid (see `YieldRouterV2` for mutating claim).
    function claimLmRewards(bytes32 templateId)
        external
        view
        override
        onlyEngine
        returns (address[] memory rewardsList, uint256[] memory amounts)
    {
        templateId;
        rewardsList = new address[](0);
        amounts = new uint256[](0);
    }

    function pendingLmRewards(bytes32 templateId)
        external
        pure
        override
        returns (address[] memory tokens, uint256[] memory pending)
    {
        templateId;
        return (new address[](0), new uint256[](0));
    }

    /// @dev Only `AToken` supported; stricter `view` than `IYieldRouterV2` (see `YieldRouterV2` for storage path set).
    function setTemplateYieldPath(bytes32 templateId, IYieldRouterV2.YieldPath path) external view override onlyOwner {
        templateId;
        if (path != IYieldRouterV2.YieldPath.AToken) revert Unauthorized();
    }

    function getTemplateYieldPath(bytes32) external pure override returns (IYieldRouterV2.YieldPath) {
        return IYieldRouterV2.YieldPath.AToken;
    }

    function globalScaledBalance() external view override returns (uint256) {
        return A_TOKEN.balanceOf(address(this));
    }

    function principalOf(bytes32 templateId) external view override returns (uint256) {
        return principalByTemplate[templateId];
    }

    function scaledPrincipalOf(bytes32 templateId) external view override returns (uint256) {
        return sharesByTemplate[templateId];
    }

    function stataSharesOf(bytes32) external pure override returns (uint256) {
        return 0;
    }
}

