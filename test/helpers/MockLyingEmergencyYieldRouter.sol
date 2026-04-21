// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IYieldRouterV2} from "../../src/interfaces/IYieldRouterV2.sol";

/// @dev Test helper: fakes successful routing and lies during emergency recovery by returning a gross amount
///      without transferring stake tokens back to the engine.
contract MockLyingEmergencyYieldRouter is IYieldRouterV2 {
    uint256 public immutable fakeRecoveredAmount;

    constructor(uint256 fakeRecoveredAmount_) {
        fakeRecoveredAmount = fakeRecoveredAmount_;
    }

    function deposit(bytes32, uint256) external pure override {}

    function withdraw(bytes32, uint256) external pure override returns (uint256 grossAmount) {
        return 0;
    }

    function balanceOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function emergencyWithdraw(bytes32) external view override returns (uint256 grossAmount) {
        return fakeRecoveredAmount;
    }

    function yieldRouterApiVersion() external pure override returns (uint256) {
        return 1;
    }

    function depositScaled(bytes32, uint256 amount) external pure override returns (uint256 attributionUnits) {
        return amount;
    }

    function depositDetailed(bytes32, uint256 amount)
        external
        pure
        override
        returns (uint256 principalAdded, uint256 attributionUnitsAdded)
    {
        return (amount, amount);
    }

    function withdrawScaled(bytes32, uint256) external pure override returns (uint256 grossAmount) {
        return 0;
    }

    function withdrawDetailed(bytes32, uint256 principalAmount)
        external
        pure
        override
        returns (uint256 grossAmount, uint256 principalConsumed, uint256 attributionUnitsBurned)
    {
        return (0, principalAmount, principalAmount);
    }

    function withdrawAttribution(bytes32, uint256 attributionUnits)
        external
        pure
        override
        returns (uint256 grossAmount, uint256 principalConsumed, uint256 attributionUnitsBurned)
    {
        return (0, attributionUnits, attributionUnits);
    }

    function currentValueOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function previewValueByAttribution(bytes32, uint256) external pure override returns (uint256) {
        return 0;
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

    function globalScaledBalance() external pure override returns (uint256) {
        return 0;
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
