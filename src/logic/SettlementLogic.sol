// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketTypes} from "../types/MarketTypes.sol";
import {MarketMath} from "../math/MarketMath.sol";
import {Resolvers} from "./Resolvers.sol";

/// @title SettlementLogic
/// @notice Shared resolve-time outcome selection and liability math for manual and rolling lifecycles.
/// @dev Single implementation avoids manual/rolling settlement drift.
library SettlementLogic {
    struct Outputs {
        bool refundMode;
        uint256 winningMask;
        uint256 claimLiabilityTotal;
        uint256 settlementFeeTotal;
    }

    /// @notice Compute winning side(s), refund mode, and liability splits given checkpoints and `netYield` baked into pool via caller.
    function compute(MarketTypes.Epoch storage e, uint256 netYield) internal returns (Outputs memory outputs) {
        if (e.marketType == MarketTypes.MarketType.Direction) {
            (bool voided, uint256 mask) = Resolvers.resolveDirection(e.checkpointA, e.checkpointB, e.equalPriceVoids);
            if (voided) {
                outputs.refundMode = true;
                outputs.winningMask = 0;
                outputs.claimLiabilityTotal = e.totalPool;
                outputs.settlementFeeTotal = 0;
                return outputs;
            }
            outputs.refundMode = false;
            outputs.winningMask = mask;
            e.winningOutcomeMask = mask;
        } else if (e.marketType == MarketTypes.MarketType.Threshold) {
            outputs.refundMode = false;
            int256 effectiveThreshold = e.absoluteThresholdValueE8;
            if (e.anchorPriceE8 != 0) {
                effectiveThreshold = e.anchorPriceE8;
            }
            outputs.winningMask = Resolvers.resolveThreshold(e.condition, effectiveThreshold, e.checkpointB);
            e.winningOutcomeMask = outputs.winningMask;
        } else if (e.marketType == MarketTypes.MarketType.RangeClose) {
            outputs.refundMode = false;
            outputs.winningMask = Resolvers.resolveRangeClose(e.checkpointB, e.outcomeCount, e.rangeBoundsE8);
            e.winningOutcomeMask = outputs.winningMask;
        } else if (e.marketType == MarketTypes.MarketType.Velocity) {
            outputs.refundMode = false;
            outputs.winningMask =
                Resolvers.resolveVelocity(e.checkpointA, e.checkpointB, e.outcomeCount, e.velocityBoundsE4);
            e.winningOutcomeMask = outputs.winningMask;
        } else if (e.marketType == MarketTypes.MarketType.Ladder) {
            outputs.refundMode = false;
            outputs.winningMask = Resolvers.resolveLadder(e.checkpointB, e.outcomeCount, e.ladderBoundsE8);
            e.winningOutcomeMask = outputs.winningMask;
        } else if (e.marketType == MarketTypes.MarketType.Convergence) {
            (bool voidedCv, uint256 maskCv) = Resolvers.resolveConvergence(
                e.checkpointA, e.checkpointA_B, e.checkpointB, e.checkpointB_B, e.spreadToleranceBps
            );
            if (voidedCv) {
                outputs.refundMode = true;
                outputs.winningMask = 0;
                outputs.claimLiabilityTotal = e.totalPool;
                outputs.settlementFeeTotal = 0;
                return outputs;
            }
            outputs.refundMode = false;
            outputs.winningMask = maskCv;
            e.winningOutcomeMask = maskCv;
        } else if (e.marketType == MarketTypes.MarketType.Composite) {
            int256[4] memory thresholds;
            bool allUnset = true;
            for (uint256 i = 0; i < e.compositeFeedCount; i++) {
                if (e.compositeAbsoluteThresholdsE8[i] != 0) allUnset = false;
            }
            for (uint256 i = 0; i < e.compositeFeedCount; i++) {
                thresholds[i] = allUnset ? e.absoluteThresholdValueE8 : e.compositeAbsoluteThresholdsE8[i];
            }
            outputs.refundMode = false;
            outputs.winningMask = Resolvers.resolveComposite(
                e.compositeLogic, e.compositeFeedCount, e.compositeConditions, thresholds, e.compositeCheckpointsB
            );
            e.winningOutcomeMask = outputs.winningMask;
        } else if (e.marketType == MarketTypes.MarketType.Corridor) {
            outputs.refundMode = false;
            // Corridor: rangeBoundsE8[0] = lower bound, [1] = upper (strictly lower < upper; enforced at upsert).
            int256 lowerBound = e.rangeBoundsE8[0];
            int256 upperBound = e.rangeBoundsE8[1];
            outputs.winningMask = Resolvers.resolveCorridor(e.epochHighE8, e.epochLowE8, upperBound, lowerBound);
            e.winningOutcomeMask = outputs.winningMask;
        } else {
            outputs.refundMode = false;
            outputs.winningMask = Resolvers.resolveCascade(
                e.epochHighE8, e.epochLowE8, e.outcomeCount, e.rangeBoundsE8, e.cascadeDownward
            );
            e.winningOutcomeMask = outputs.winningMask;
        }
        uint256 effectiveTotalPool = e.totalPool + netYield;
        uint256 winningPool = 0;
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if (((outputs.winningMask >> i) & 1) != 0) winningPool += e.outcomePools[i];
        }
        e.winningPoolTotal = winningPool;
        if (e.marketType == MarketTypes.MarketType.Ladder) {
            uint8 winnerIdx = 0;
            for (uint8 i = 0; i < e.outcomeCount; i++) {
                if (((outputs.winningMask >> i) & 1) != 0) {
                    winnerIdx = i;
                    break;
                }
            }
            uint16 winnerWeight = e.ladderPayoutWeightsBps[winnerIdx];
            // slither-disable-next-line unused-return -- third return is `distributableLosingPool`; only claim + fee used here.
            (outputs.claimLiabilityTotal, outputs.settlementFeeTotal,) = MarketMath.computeLadderLiabilityComponents(
                effectiveTotalPool, winningPool, e.settlementFeeBps, e.feeOnLosingPool, winnerWeight
            );
        } else {
            // slither-disable-next-line unused-return -- third return is `distributableLosingPool`; only claim + fee used here.
            (outputs.claimLiabilityTotal, outputs.settlementFeeTotal,) = MarketMath.computeClaimLiabilityComponents(
                effectiveTotalPool, winningPool, e.settlementFeeBps, e.feeOnLosingPool
            );
        }
    }
}
