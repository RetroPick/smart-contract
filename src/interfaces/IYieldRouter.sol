// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IYieldRouter
/// @notice Pluggable yield backend interface for RetroPick `MarketEngine`.
/// @dev Router implementations hold yield-bearing assets on behalf of the engine and account per templateId.
interface IYieldRouter {
    /// @notice Deploy `amount` of stakeToken into the yield source.
    /// @dev Called by `MarketEngine` after it has received stakeToken from the user.
    function deposit(bytes32 templateId, uint256 amount) external;

    /// @notice Withdraw `principalAmount` (plus any accrued yield) to the engine.
    /// @dev Called by `MarketEngine` during epoch resolution. Implementations must transfer stakeToken to the engine.
    /// @return grossAmount Actual stakeToken amount returned to the engine (principal + yield, if any).
    function withdraw(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);

    /// @notice Current yield-bearing balance attributable to `templateId` in router-native units.
    /// @dev For Aave, this is the aToken share amount attributed to the template.
    function balanceOf(bytes32 templateId) external view returns (uint256);

    /// @notice Emergency: withdraw all yield-bearing assets attributable to `templateId` to the engine.
    /// @dev Intended for pause/recovery flows.
    function emergencyWithdraw(bytes32 templateId) external returns (uint256 grossAmount);
}

