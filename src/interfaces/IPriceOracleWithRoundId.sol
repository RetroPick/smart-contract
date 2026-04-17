// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IPriceOracleWithRoundId
/// @notice Optional extension for `IPriceOracle` implementations that can expose oracle round IDs.
/// @dev
/// Intended for Chainlink `AggregatorV3Interface` adapters. Engines should treat this interface as optional
/// and fall back to `IPriceOracle.getNormalizedPrice` when not implemented.
///
/// `roundId` allows engines to enforce monotonic oracle progression (e.g., strict increase per template or per feed)
/// and to surface round ids in events for indexers.
///
/// **RetroPick `MarketEngine` behavior:** When a feed is first read with round-id support, the engine records whether
/// the cursor used `roundId`. If a later read would **downgrade** from round-id mode to plain `IPriceOracle` only
/// (e.g. `try getNormalizedPriceWithRoundId` fails after previously succeeding), the engine **reverts** (`InvalidOracleFeed`)
/// instead of silently losing monotonicity. Publish-time monotonicity is enforced even when `roundId` is absent.
///
/// **ERC-165:** This repo does not require `supportsInterface` on oracle adapters; detection is via `try/catch` at the
/// engine plus the cursor downgrade guard above. Third-party stacks MAY wrap adapters with ERC-165 if they prefer static introspection.
interface IPriceOracleWithRoundId {
    /// @notice Get latest normalized price plus the oracle round id.
    /// @param feedId Adapter-specific feed identifier.
    /// @param maxAgeSeconds Maximum allowed age of oracle publish time.
    /// @param nowTs ABI-compat parameter; production adapters MUST ignore it for freshness (use `block.timestamp`).
    /// @return roundId Oracle-specific round id (e.g. Chainlink `roundId`).
    /// @return priceE8 Normalized price scaled to 8 decimals.
    /// @return publishTime Oracle update timestamp used for freshness/monotonicity.
    /// @return confidenceE8 Optional confidence band scaled to e8 (0 if unsupported).
    function getNormalizedPriceWithRoundId(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external
        view
        returns (uint80 roundId, int256 priceE8, uint64 publishTime, uint256 confidenceE8);
}

