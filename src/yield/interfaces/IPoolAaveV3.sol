// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Aave v3 pool configuration map (packed `uint256`, same layout as Aave `ReserveConfigurationMap`).
struct ReserveConfigurationMap {
    uint256 data;
}

/// @notice Minimal Aave v3 `IPool` interface for supply/withdraw plus reads used by yield v2.
interface IPoolAaveV3 {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /// @param amount Underlying amount to withdraw; `type(uint256).max` withdraws full caller aToken position.
    function withdraw(address asset, uint256 amount, address to) external returns (uint256 withdrawn);

    /// @notice Ray-scaled liquidity index for the reserve (starts at 1e27).
    function getReserveNormalizedIncome(address asset) external view returns (uint256);

    function getConfiguration(address asset) external view returns (ReserveConfigurationMap memory);
}

