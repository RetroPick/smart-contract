// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketTypes} from "../types/MarketTypes.sol";

/// @title Resolvers
/// @notice Pure resolution logic for determining winning outcomes from oracle checkpoints and template params.
/// @dev
/// This library intentionally contains no storage writes; it is called by `MarketEngine` during resolve.
/// All functions assume the engine has already enforced:
/// - correct epoch status transitions (locked before resolve),
/// - oracle freshness/confidence checks, and
/// - checkpoint existence where required.
///
/// Winners are returned as a bitmask: `mask = 1 << outcomeIndex`.
library Resolvers {
    error InvalidEpochState();
    error InvalidTemplate();

    /// @notice Resolve a Direction market (binary up/down) from checkpoint A (lock) and B (resolve).
    /// @dev
    /// Outcome indices:
    /// - outcome 0: price went up (`b > a`)
    /// - outcome 1: price went down (`b < a`) OR equal when `voidOnEqual=false`
    ///
    /// If `voidOnEqual=true` and `b == a`, the epoch is voided (refund mode).
    /// @return voided When true, treat as refund mode (no winning side).
    /// @return mask Bitmask of winning outcomes; undefined if voided.
    function resolveDirection(
        MarketTypes.OracleCheckpoint memory a,
        MarketTypes.OracleCheckpoint memory b,
        bool voidOnEqual
    ) internal pure returns (bool voided, uint256 mask) {
        if (!a.written || !b.written) revert InvalidEpochState();
        if (b.valueE8 > a.valueE8) return (false, uint256(1) << 0);
        if (b.valueE8 < a.valueE8) return (false, uint256(1) << 1);
        if (voidOnEqual) return (true, 0);
        return (false, uint256(1) << 1);
    }

    /// @notice Resolve a Threshold market (binary yes/no) at checkpoint B.
    /// @dev
    /// - outcome 0: YES (condition satisfied)
    /// - outcome 1: NO
    ///
    /// Condition:
    /// - `AtOrAbove`: YES if `b.valueE8 >= thresholdValueE8`
    /// - `Below`: YES if `b.valueE8 < thresholdValueE8`
    function resolveThreshold(
        MarketTypes.Condition condition,
        int256 thresholdValueE8,
        MarketTypes.OracleCheckpoint memory b
    ) internal pure returns (uint256 mask) {
        if (!b.written) revert InvalidEpochState();
        bool yes =
            condition == MarketTypes.Condition.AtOrAbove ? b.valueE8 >= thresholdValueE8 : b.valueE8 < thresholdValueE8;
        return yes ? (uint256(1) << 0) : (uint256(1) << 1);
    }

    /// @notice Resolve a RangeClose market by selecting a bucket index at checkpoint B.
    /// @dev
    /// `rangeBoundsE8` defines the bucket boundaries (strictly increasing for the used prefix).
    /// Bucket selection for `outcomeCount` buckets:
    /// - idx = 0 if `value < bounds[0]`
    /// - idx = i if `bounds[i-1] <= value < bounds[i]` for i in [1..outcomeCount-2]
    /// - idx = outcomeCount-1 otherwise
    function resolveRangeClose(
        MarketTypes.OracleCheckpoint memory b,
        uint8 outcomeCount,
        int256[7] memory rangeBoundsE8
    ) internal pure returns (uint256 mask) {
        if (!b.written) revert InvalidEpochState();
        if (outcomeCount < 2) revert InvalidTemplate();
        int256 value = b.valueE8;
        uint256 idx;
        if (value < rangeBoundsE8[0]) {
            idx = 0;
        } else {
            idx = uint256(outcomeCount) - 1;
            for (uint256 i = 1; i < uint256(outcomeCount) - 1; i++) {
                if (value < rangeBoundsE8[i]) {
                    idx = i;
                    break;
                }
            }
        }
        return uint256(1) << idx;
    }
}
