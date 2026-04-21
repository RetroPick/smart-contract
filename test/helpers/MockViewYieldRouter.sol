// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IYieldRouterV2} from "../../src/interfaces/IYieldRouterV2.sol";

/// @dev Minimal configurable router used for read-surface tests.
contract MockViewYieldRouter is IYieldRouterV2 {
    uint256 internal _currentValue;
    uint256 internal _principal;
    uint256 internal _scaledPrincipal;
    uint256 internal _stataShares;
    YieldPath internal _path;

    function setTemplateState(
        uint256 currentValue_,
        uint256 principal_,
        uint256 scaledPrincipal_,
        uint256 stataShares_,
        YieldPath path_
    ) external {
        _currentValue = currentValue_;
        _principal = principal_;
        _scaledPrincipal = scaledPrincipal_;
        _stataShares = stataShares_;
        _path = path_;
    }

    function deposit(bytes32, uint256) external pure override {}

    function withdraw(bytes32, uint256) external pure override returns (uint256) {
        return 0;
    }

    function balanceOf(bytes32) external view override returns (uint256) {
        return _currentValue;
    }

    function emergencyWithdraw(bytes32) external pure override returns (uint256) {
        return 0;
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

    function withdrawScaled(bytes32, uint256) external pure override returns (uint256) {
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

    function currentValueOf(bytes32) external view override returns (uint256) {
        return _currentValue;
    }

    function previewValueByAttribution(bytes32, uint256 attributionUnits)
        external
        view
        override
        returns (uint256 currentValue)
    {
        if (_scaledPrincipal == 0) return 0;
        return (attributionUnits * _currentValue) / _scaledPrincipal;
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

    function setTemplateYieldPath(bytes32, YieldPath path_) external override {
        _path = path_;
    }

    function getTemplateYieldPath(bytes32) external view override returns (YieldPath) {
        return _path;
    }

    function globalScaledBalance() external view override returns (uint256) {
        return _scaledPrincipal;
    }

    function principalOf(bytes32) external view override returns (uint256) {
        return _principal;
    }

    function scaledPrincipalOf(bytes32) external view override returns (uint256) {
        return _scaledPrincipal;
    }

    function stataSharesOf(bytes32) external view override returns (uint256) {
        return _stataShares;
    }
}
