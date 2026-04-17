// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
/// - `nowTs` exists for ABI compatibility with tests/mocks. **Production adapters MUST NOT** use caller-supplied
///   `nowTs` for staleness, monotonicity, or sequencer grace: those checks MUST use `block.timestamp` (or an
///   equivalent non-spoofable clock), otherwise an attacker can pass a fake `nowTs` to make stale prices appear fresh.
///
/// **Spot / rate feeds:** For economically meaningful asset prices, `priceE8` SHOULD be strictly positive; adapters
/// MUST reject non-positive `answer` values from upstream feeds where negatives are invalid.
///
/// **Clock / freshness:** Freshness compares oracle `publishTime` / `updatedAt` to `block.timestamp` (consensus clock,
/// small manipulation bound on PoS). Templates SHOULD use `maxAgeSeconds` **well above** that bound (and above reporter
/// / network jitter), or brief oracle lag can cause user-visible lock/resolve failures—this is an operational parameter,
/// not a proof that the live price equals some external “wall clock.”
interface IPriceOracle {
    /// @notice Get latest normalized price for a feed with freshness guarantees.
    /// @param feedId Adapter-specific feed identifier (Chainlink proxy address encoded in bytes32 for ChainlinkAdapter).
    /// @param maxAgeSeconds Maximum allowed age of oracle publish time.
    /// @param nowTs ABI-compat; production adapters MUST ignore it for freshness (see interface `@dev`).
    /// @return priceE8 Normalized price scaled to 8 decimals.
    /// @return publishTime Oracle update timestamp used for freshness/monotonicity.
    /// @return confidenceE8 Optional confidence band scaled to e8 (0 if unsupported).
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external
        view
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);
}
