// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEventOracle
/// @notice Trusted reporter path: signed payloads settle non–price-feed markets into oracle checkpoints.
/// @dev `marketId` MUST match `MarketEngineState.positionKey(templateId, epochId)`.
interface IEventOracle {
    event ResultPosted(
        bytes32 indexed marketId,
        int256 result,
        uint64 observedAt,
        bytes32 dataSourceHash,
        address indexed submittedBy
    );

    event LockSamplePosted(
        bytes32 indexed marketId,
        int256 valueE8,
        uint64 observedAt,
        bytes32 dataSourceHash,
        address indexed submittedBy
    );
    event OhlcPosted(
        bytes32 indexed marketId,
        int256 highE8,
        int256 lowE8,
        int256 closeE8,
        uint64 observedAt,
        bytes32 dataSourceHash,
        address indexed submittedBy
    );

    /// @notice Resolve scalar for settlement (checkpoint B).
    function getResult(bytes32 marketId) external view returns (int256 result, bool resolved);

    /// @notice Wall-clock style observation time committed in the signed resolve payload.
    function getResolveObservedAt(bytes32 marketId) external view returns (uint64);

    /// @notice `keccak256(bytes(utf8Source))` from the signed resolve payload.
    function getResolveDataSourceHash(bytes32 marketId) external view returns (bytes32);

    /// @notice Full URI is not stored on-chain; returns empty. Index `ResultPosted` + backend for audit.
    function getDataSource(bytes32 marketId) external view returns (string memory);

    /// @notice Lock-time sample for Direction markets (checkpoint A).
    function getLockSample(bytes32 marketId)
        external
        view
        returns (int256 valueE8, uint64 observedAt, bool written);

    function getOhlcResult(bytes32 marketId)
        external
        view
        returns (int256 highE8, int256 lowE8, int256 closeE8, uint64 observedAt, bool written);
}
