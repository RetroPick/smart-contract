// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IYieldRouterV2} from "../../src/interfaces/IYieldRouterV2.sol";

/// @dev Test helper: fakes deposit success (returns attribution units without pulling stake tokens)
///      and always reverts on withdrawal. Used to trigger the yield-withdrawal failure path in
///      cancelEpoch and cancelRollingEpochWhileHalted.
contract MockBrokenYieldRouter is IYieldRouterV2 {
    error WithdrawAlwaysFails();

    // --- IYieldRouter ---

    function deposit(bytes32, uint256) external override {}

    function withdraw(bytes32, uint256) external pure override returns (uint256) {
        revert WithdrawAlwaysFails();
    }

    function balanceOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function emergencyWithdraw(bytes32) external pure override returns (uint256) {
        revert WithdrawAlwaysFails();
    }

    // --- IYieldRouterV2 ---

    function yieldRouterApiVersion() external pure override returns (uint256) {
        return 1;
    }

    /// @dev Returns 1 attribution unit without pulling tokens — fakes a successful deposit.
    ///      Engine will set routedPrincipal > 0 but tokens stay in engine (mock never transfers).
    function depositScaled(bytes32, uint256) external pure override returns (uint256) {
        return 1;
    }

    function depositDetailed(bytes32, uint256 amount)
        external
        pure
        override
        returns (uint256 principalAdded, uint256 attributionUnitsAdded)
    {
        return (amount, 1);
    }

    function withdrawScaled(bytes32, uint256) external pure override returns (uint256) {
        revert WithdrawAlwaysFails();
    }

    function withdrawDetailed(bytes32, uint256)
        external
        pure
        override
        returns (uint256, uint256, uint256)
    {
        revert WithdrawAlwaysFails();
    }

    function withdrawAttribution(bytes32, uint256)
        external
        pure
        override
        returns (uint256, uint256, uint256)
    {
        revert WithdrawAlwaysFails();
    }

    function currentValueOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function previewValueByAttribution(bytes32, uint256) external pure override returns (uint256) {
        return 0;
    }

    function claimLmRewards(bytes32) external pure override returns (address[] memory tokens, uint256[] memory amounts) {}

    function pendingLmRewards(bytes32) external pure override returns (address[] memory tokens, uint256[] memory amounts) {}

    function setTemplateYieldPath(bytes32, IYieldRouterV2.YieldPath) external override {}

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
