// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketTypes} from "../types/MarketTypes.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
    /// Walk `bounds[0..outcomeCount-2]` for the first `value < bounds[i]`; if none, `idx = outcomeCount - 1`.
    /// Equivalently: idx = 0 iff `value < bounds[0]`; idx = i for `bounds[i-1] <= value < bounds[i]`; else last bucket.
    function resolveRangeClose(
        MarketTypes.OracleCheckpoint memory b,
        uint8 outcomeCount,
        int256[7] memory rangeBoundsE8
    ) internal pure returns (uint256 mask) {
        if (!b.written) revert InvalidEpochState();
        if (outcomeCount < 2) revert InvalidTemplate();
        int256 value = b.valueE8;
        uint256 idx = uint256(outcomeCount) - 1;
        for (uint256 i = 0; i < uint256(outcomeCount) - 1; i++) {
            if (value < rangeBoundsE8[i]) {
                idx = i;
                break;
            }
        }
        return uint256(1) << idx;
    }

    function resolveAnchor(
        MarketTypes.Condition condition,
        int256 anchorPriceE8,
        MarketTypes.OracleCheckpoint memory b
    ) internal pure returns (uint256 mask) {
        return resolveThreshold(condition, anchorPriceE8, b);
    }

    function resolveVelocity(
        MarketTypes.OracleCheckpoint memory a,
        MarketTypes.OracleCheckpoint memory b,
        uint8 outcomeCount,
        uint32[7] memory velocityBoundsE4
    ) internal pure returns (uint256 mask) {
        if (!a.written || !b.written) revert InvalidEpochState();
        if (outcomeCount < 2) revert InvalidTemplate();
        int256 delta = b.valueE8 - a.valueE8;
        uint256 absDelta = uint256(delta < 0 ? -delta : delta);
        uint256 absBase = uint256(a.valueE8 < 0 ? -a.valueE8 : a.valueE8);
        if (absBase == 0) revert InvalidEpochState();
        if (absBase < MarketTypes.MIN_VELOCITY_BASE_ABS_E8) revert InvalidEpochState();
        uint256 moveBpsE4 = (absDelta * 10_000) / absBase;
        uint256 idx;
        if (moveBpsE4 < velocityBoundsE4[0]) {
            idx = 0;
        } else {
            idx = uint256(outcomeCount) - 1;
            for (uint256 i = 1; i < uint256(outcomeCount) - 1; i++) {
                if (moveBpsE4 < velocityBoundsE4[i]) {
                    idx = i;
                    break;
                }
            }
        }
        return uint256(1) << idx;
    }

    function resolveLadder(
        MarketTypes.OracleCheckpoint memory b,
        uint8 outcomeCount,
        int256[7] memory ladderBoundsE8
    ) internal pure returns (uint256 mask) {
        return resolveRangeClose(b, outcomeCount, ladderBoundsE8);
    }

    function resolveConvergence(
        MarketTypes.OracleCheckpoint memory a1,
        MarketTypes.OracleCheckpoint memory a2,
        MarketTypes.OracleCheckpoint memory b1,
        MarketTypes.OracleCheckpoint memory b2,
        uint16 toleranceBps
    ) internal pure returns (bool voided, uint256 mask) {
        if (!a1.written || !a2.written || !b1.written || !b2.written) revert InvalidEpochState();
        uint256 openSpread = uint256((a1.valueE8 - a2.valueE8) < 0 ? (a2.valueE8 - a1.valueE8) : (a1.valueE8 - a2.valueE8));
        uint256 closeSpread =
            uint256((b1.valueE8 - b2.valueE8) < 0 ? (b2.valueE8 - b1.valueE8) : (b1.valueE8 - b2.valueE8));
        uint256 band = Math.mulDiv(openSpread, uint256(toleranceBps), 10_000);
        // Compare without `closeSpread + band` / `openSpread + band` to avoid uint256 add overflow on extreme spreads.
        if (closeSpread < openSpread) {
            uint256 narrowedBy = openSpread - closeSpread;
            if (band < narrowedBy) return (false, uint256(1) << 0);
        }
        if (closeSpread > openSpread) {
            uint256 widenedBy = closeSpread - openSpread;
            if (widenedBy > band) return (false, uint256(1) << 1);
        }
        return (true, 0);
    }

    function resolveComposite(
        MarketTypes.CompositeLogic logic,
        uint8 feedCount,
        MarketTypes.Condition[4] memory conditions,
        int256[4] memory thresholdsE8,
        MarketTypes.OracleCheckpoint[4] memory checkpointsB
    ) internal pure returns (uint256 mask) {
        if (feedCount == 0 || feedCount > 4) revert InvalidTemplate();
        uint256 trueCount = 0;
        for (uint256 i = 0; i < feedCount; i++) {
            if (!checkpointsB[i].written) revert InvalidEpochState();
            bool met = conditions[i] == MarketTypes.Condition.AtOrAbove
                ? checkpointsB[i].valueE8 >= thresholdsE8[i]
                : checkpointsB[i].valueE8 < thresholdsE8[i];
            if (met) trueCount++;
        }
        bool result;
        if (logic == MarketTypes.CompositeLogic.And) {
            result = trueCount == feedCount;
        } else if (logic == MarketTypes.CompositeLogic.Or) {
            result = trueCount > 0;
        } else {
            // Majority: at least half of feeds pass (e.g. 1 of 2, 2 of 3, 2 of 4). Ties count toward YES.
            result = 2 * trueCount >= feedCount;
        }
        return result ? (uint256(1) << 0) : (uint256(1) << 1);
    }

    /// @dev `upperBoundE8` must exceed `lowerBoundE8` (enforced when the template is upserted for Corridor).
    function resolveCorridor(int256 highE8, int256 lowE8, int256 upperBoundE8, int256 lowerBoundE8)
        internal
        pure
        returns (uint256 mask)
    {
        if (highE8 >= upperBoundE8) return uint256(1) << 1;
        if (lowE8 <= lowerBoundE8) return uint256(1) << 2;
        return uint256(1) << 0;
    }

    function resolveCascade(int256 highE8, int256 lowE8, uint8 outcomeCount, int256[7] memory boundsE8, bool downward)
        internal
        pure
        returns (uint256 mask)
    {
        if (outcomeCount < 2) revert InvalidTemplate();
        uint256 levelsReached = 0;
        uint256 maxLevels = uint256(outcomeCount) - 1;
        for (uint256 i = 0; i < maxLevels; i++) {
            if (downward) {
                if (lowE8 <= boundsE8[i]) levelsReached++;
            } else {
                if (highE8 >= boundsE8[i]) levelsReached++;
            }
        }
        if (levelsReached >= outcomeCount) levelsReached = outcomeCount - 1;
        return uint256(1) << levelsReached;
    }
}
