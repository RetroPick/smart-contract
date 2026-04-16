// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Aave aToken / debt token scaled balance interface.
interface IScaledBalanceToken {
    function scaledBalanceOf(address user) external view returns (uint256);
}
