// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title YieldAccounting
/// @notice Ray math (1e27) aligned with Aave v3 `WadRayMath` rounding for scaled balance accounting.
library YieldAccounting {
    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 5e26;
    uint256 internal constant BPS_DENOM = 10_000;

    error YieldAccountingDivZero();

    function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        return (a * b + HALF_RAY) / RAY;
    }

    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) revert YieldAccountingDivZero();
        return (a * RAY + b / 2) / b;
    }

    function scaledToReal(uint256 scaledBalance, uint256 liquidityIndex) internal pure returns (uint256) {
        return rayMul(scaledBalance, liquidityIndex);
    }

    function realToScaled(uint256 realAmount, uint256 liquidityIndex) internal pure returns (uint256) {
        return rayDiv(realAmount, liquidityIndex);
    }

    function computeYield(uint256 scaledBalance, uint256 liquidityIndex, uint256 originalPrincipal, uint256 feeBps)
        internal
        pure
        returns (uint256 grossValue, uint256 grossYield, uint256 netYield, uint256 fee)
    {
        grossValue = scaledToReal(scaledBalance, liquidityIndex);
        grossYield = grossValue > originalPrincipal ? grossValue - originalPrincipal : 0;
        fee = (grossYield * feeBps) / BPS_DENOM;
        netYield = grossYield - fee;
    }

    /// @notice Underlying to withdraw for a partial principal redemption (floor rounding).
    function proportionalUnderlying(
        uint256 totalScaled,
        uint256 totalPrincipal,
        uint256 withdrawPrincipal,
        uint256 liquidityIndex
    ) internal pure returns (uint256 underlyingOut) {
        if (withdrawPrincipal == 0 || totalPrincipal == 0) return 0;
        uint256 totalValue = scaledToReal(totalScaled, liquidityIndex);
        if (withdrawPrincipal >= totalPrincipal) return totalValue;
        return (totalValue * withdrawPrincipal) / totalPrincipal;
    }
}
