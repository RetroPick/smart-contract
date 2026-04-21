// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IYieldRouterV2} from "../../src/interfaces/IYieldRouterV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Test helper: accepts deposits, then returns only a configurable fraction of principal on withdraw.
///      Used to simulate principal loss / shortfall at the yield-router boundary.
contract MockPartialYieldRouter is IYieldRouterV2 {
    IERC20 public immutable stakeToken;

    uint16 public withdrawReturnBps;
    bool public revertOnWithdraw;

    constructor(IERC20 stakeToken_, uint16 withdrawReturnBps_) {
        stakeToken = stakeToken_;
        withdrawReturnBps = withdrawReturnBps_;
    }

    function setWithdrawReturnBps(uint16 bps) external {
        withdrawReturnBps = bps;
    }

    function setRevertOnWithdraw(bool v) external {
        revertOnWithdraw = v;
    }

    function deposit(bytes32, uint256 amount) external override {
        stakeToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(bytes32, uint256 amount) external override returns (uint256 grossAmount) {
        if (revertOnWithdraw) revert();
        grossAmount = (amount * uint256(withdrawReturnBps)) / 10_000;
        stakeToken.transfer(msg.sender, grossAmount);
    }

    function balanceOf(bytes32) external view override returns (uint256) {
        return stakeToken.balanceOf(address(this));
    }

    function emergencyWithdraw(bytes32) external override returns (uint256 grossAmount) {
        grossAmount = stakeToken.balanceOf(address(this));
        stakeToken.transfer(msg.sender, grossAmount);
    }

    function yieldRouterApiVersion() external pure override returns (uint256) {
        return 1;
    }

    function depositScaled(bytes32, uint256 amount) external override returns (uint256 attributionUnits) {
        stakeToken.transferFrom(msg.sender, address(this), amount);
        return amount;
    }

    function depositDetailed(bytes32, uint256 amount)
        external
        override
        returns (uint256 principalAdded, uint256 attributionUnitsAdded)
    {
        stakeToken.transferFrom(msg.sender, address(this), amount);
        return (amount, amount);
    }

    function withdrawScaled(bytes32, uint256 principalAmount) external override returns (uint256 grossAmount) {
        if (revertOnWithdraw) revert();
        grossAmount = (principalAmount * uint256(withdrawReturnBps)) / 10_000;
        stakeToken.transfer(msg.sender, grossAmount);
    }

    function withdrawDetailed(bytes32, uint256 principalAmount)
        external
        override
        returns (uint256 grossAmount, uint256 principalConsumed, uint256 attributionUnitsBurned)
    {
        if (revertOnWithdraw) revert();
        grossAmount = (principalAmount * uint256(withdrawReturnBps)) / 10_000;
        stakeToken.transfer(msg.sender, grossAmount);
        return (grossAmount, principalAmount, principalAmount);
    }

    function withdrawAttribution(bytes32, uint256 attributionUnits)
        external
        override
        returns (uint256 grossAmount, uint256 principalConsumed, uint256 attributionUnitsBurned)
    {
        if (revertOnWithdraw) revert();
        grossAmount = (attributionUnits * uint256(withdrawReturnBps)) / 10_000;
        stakeToken.transfer(msg.sender, grossAmount);
        return (grossAmount, attributionUnits, attributionUnits);
    }

    function currentValueOf(bytes32) external view override returns (uint256) {
        return stakeToken.balanceOf(address(this));
    }

    function previewValueByAttribution(bytes32, uint256 attributionUnits)
        external
        view
        override
        returns (uint256 currentValue)
    {
        return (attributionUnits * uint256(withdrawReturnBps)) / 10_000;
    }

    function claimLmRewards(bytes32)
        external
        pure
        override
        returns (address[] memory rewardsList, uint256[] memory amounts)
    {
        return (new address[](0), new uint256[](0));
    }

    function pendingLmRewards(bytes32)
        external
        pure
        override
        returns (address[] memory tokens, uint256[] memory pending)
    {
        return (new address[](0), new uint256[](0));
    }

    function setTemplateYieldPath(bytes32, IYieldRouterV2.YieldPath) external pure override {}

    function getTemplateYieldPath(bytes32) external pure override returns (IYieldRouterV2.YieldPath) {
        return IYieldRouterV2.YieldPath.AToken;
    }

    function globalScaledBalance() external view override returns (uint256) {
        return stakeToken.balanceOf(address(this));
    }

    function principalOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function scaledPrincipalOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function stataSharesOf(bytes32) external pure override returns (uint256) {
        return 0;
    }
}
