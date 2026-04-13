// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPriceOracle
/// @notice Chain-agnostic normalized oracle surface for `MarketEngine`.
/// @dev
/// The engine expects prices normalized to e8 decimals (`priceE8`).
/// For Chainlink adapters, `feedId` typically encodes the feed proxy address as:
/// `bytes32(uint256(uint160(proxy)))`.
///
/// Time semantics:
/// - `publishTime` is the oracle’s own update timestamp (e.g. Chainlink `updatedAt`).
/// - `maxAgeSeconds` is a freshness window enforced by the adapter.
/// - `nowTs` is passed through for test mocks; production adapters may ignore it and use `block.timestamp`.
interface IPriceOracle {
    /// @notice Get latest normalized price for a feed with freshness guarantees.
    /// @param feedId Adapter-specific feed identifier (Chainlink proxy address encoded in bytes32 for ChainlinkAdapter).
    /// @param maxAgeSeconds Maximum allowed age of oracle publish time.
    /// @param nowTs Caller-supplied time reference (primarily for mocks/tests).
    /// @return priceE8 Normalized price scaled to 8 decimals.
    /// @return publishTime Oracle update timestamp used for freshness/monotonicity.
    /// @return confidenceE8 Optional confidence band scaled to e8 (0 if unsupported).
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external
        view
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);
}
