// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// src/interfaces/IPriceOracle.sol

/// @notice Chain-agnostic normalized oracle surface for the market engine.
/// @dev `feedId` encodes the Chainlink feed proxy address as `bytes32(uint256(uint160(proxy)))`.
///      `nowTs` is ignored by on-chain adapters (staleness uses `block.timestamp` / feed timestamps).
///      Mocks may use `nowTs` in tests.
interface IPriceOracle {
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external
        view
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);
}

