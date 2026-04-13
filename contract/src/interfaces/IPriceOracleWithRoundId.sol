// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPriceOracleWithRoundId
/// @notice Optional extension for `IPriceOracle` implementations that can expose oracle round IDs.
/// @dev
/// Intended for Chainlink `AggregatorV3Interface` adapters. Engines should treat this interface as optional
/// and fall back to `IPriceOracle.getNormalizedPrice` when not implemented.
///
/// `roundId` allows engines to enforce monotonic oracle progression (e.g., strict increase per template or per feed)
/// and to surface round ids in events for indexers.
interface IPriceOracleWithRoundId {
    /// @notice Get latest normalized price plus the oracle round id.
    /// @param feedId Adapter-specific feed identifier.
    /// @param maxAgeSeconds Maximum allowed age of oracle publish time.
    /// @param nowTs Caller-supplied time reference (primarily for mocks/tests).
    /// @return roundId Oracle-specific round id (e.g. Chainlink `roundId`).
    /// @return priceE8 Normalized price scaled to 8 decimals.
    /// @return publishTime Oracle update timestamp used for freshness/monotonicity.
    /// @return confidenceE8 Optional confidence band scaled to e8 (0 if unsupported).
    function getNormalizedPriceWithRoundId(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external
        view
        returns (uint80 roundId, int256 priceE8, uint64 publishTime, uint256 confidenceE8);
}

