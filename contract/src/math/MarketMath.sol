// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketTypes} from "../types/MarketTypes.sol";

/// @title MarketMath
/// @notice Pure/accounting math used by `MarketEngine` for fees, settlement liabilities, and claim payouts.
/// @dev
/// NOTES: Terminology
/// - totalPool: total stake deposited into an epoch across all outcomes (net of switch fees).
/// - winningPool: stake deposited on the winning outcome(s).
/// - losingPool: `totalPool - winningPool`.
/// - settlementFee: protocol fee charged at resolve (may be assessed on totalPool or losingPool).
/// - claimLiabilityTotal: total amount reserved into claims for payouts/refunds for an epoch.
///
/// INVARIANTS:
/// - If `winningPool == 0`, the engine prefers liveness/fairness: refund the entire pool and charge no fees.
/// - Switch fee uses ceil rounding to avoid under-collecting due to integer truncation.
/// - Claim payout uses a last-claimer remainder rule to avoid dust remaining trapped in an epoch.
library MarketMath {
    using MarketTypes for MarketTypes.Epoch;

    error MathOverflow();
    error NoWinningOutcome();

    uint256 internal constant BPS_DENOMINATOR = MarketTypes.BPS_DENOMINATOR;

    /// @notice Compute switch fee and net transferred stake for `switchSide`.
    /// @dev Fee rounding is ceiling:
    /// `fee = ceil(grossAmount * switchFeeBps / 10_000)`.
    /// This avoids systematic fee under-collection from truncation.
    function computeSwitch(uint256 grossAmount, uint16 switchFeeBps) internal pure returns (uint256 net, uint256 fee) {
        if (switchFeeBps == 0) return (grossAmount, 0);
        fee = (grossAmount * uint256(switchFeeBps) + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
        if (fee > grossAmount) revert MathOverflow();
        net = grossAmount - fee;
    }

    /// @notice Compute settlement fee charged at resolve.
    /// @dev If `feeOnLosingPool=true`, fee base is losingPool; otherwise base is totalPool.
    function computeSettlementFee(uint256 totalPool, uint256 losingPool, uint16 feeBps, bool feeOnLosingPool)
        internal
        pure
        returns (uint256)
    {
        uint256 base = feeOnLosingPool ? losingPool : totalPool;
        return (base * uint256(feeBps)) / BPS_DENOMINATOR;
    }

    function winningPoolTotal(uint256 winningMask, uint8 outcomeCount, uint256[8] memory outcomePools)
        internal
        pure
        returns (uint256 sum)
    {
        for (uint256 i = 0; i < outcomeCount; i++) {
            if ((winningMask >> i) & 1 == 1) {
                sum += outcomePools[i];
            }
        }
    }

    /// @notice Decompose resolve outputs into claim liability + settlement fee.
    /// @dev
    /// - If `winningPool == 0`, returns `(totalPool, 0, totalPool)` meaning refund everything, no fees.
    /// - Otherwise:
    ///   - `settlementFee` is computed from `totalPool` or `losingPool`.
    ///   - `distributableLosingPool = losingPool - settlementFee`.
    ///   - `claimLiabilityTotal = winningPool + distributableLosingPool`.
    function computeClaimLiabilityComponents(
        uint256 totalPool,
        uint256 winningPool,
        uint16 feeBps,
        bool feeOnLosingPool
    ) internal pure returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool) {
        // Liveness preference: if nobody bet the winning side, refund the whole pool (no fees).
        if (winningPool == 0) return (totalPool, 0, totalPool);
        if (totalPool < winningPool) revert MathOverflow();
        uint256 losingPool = totalPool - winningPool;
        settlementFee = computeSettlementFee(totalPool, losingPool, feeBps, feeOnLosingPool);
        if (losingPool < settlementFee) revert MathOverflow();
        distributableLosingPool = losingPool - settlementFee;
        claimLiabilityTotal = winningPool + distributableLosingPool;
    }

    /// @notice Compute claim liability totals for a resolved epoch (memory variant).
    function computeEpochClaimLiability(MarketTypes.Epoch memory epoch, uint16 feeBps, bool feeOnLosingPool)
        internal
        pure
        returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool)
    {
        uint256 wp = epoch.winningPoolTotal();
        return computeClaimLiabilityComponents(epoch.totalPool, wp, feeBps, feeOnLosingPool);
    }

    /// @notice Compute claim liability totals for a resolved epoch (storage variant, avoids memory copy).
    function computeEpochClaimLiabilityStorage(MarketTypes.Epoch storage epoch, uint16 feeBps, bool feeOnLosingPool)
        internal
        view
        returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool)
    {
        uint256 wp = 0;
        for (uint256 i = 0; i < epoch.outcomeCount; i++) {
            if ((epoch.winningOutcomeMask >> i) & 1 == 1) {
                wp += epoch.outcomePools[i];
            }
        }
        return computeClaimLiabilityComponents(epoch.totalPool, wp, feeBps, feeOnLosingPool);
    }

    function totalWinningStake(uint256 winningMask, uint8 outcomeCount, uint256[8] memory stakes)
        internal
        pure
        returns (uint256 s)
    {
        for (uint256 i = 0; i < outcomeCount; i++) {
            if ((winningMask >> i) & 1 == 1) {
                s += stakes[i];
            }
        }
    }

    /// @notice Compute a user’s total entitlement (stake + share of distributable losing pool) for a resolved epoch.
    /// @dev Returns 0 if user has no winning stake.
    function computeTotalUserEntitlementResolved(
        MarketTypes.Epoch memory epoch,
        uint256[8] memory stakes,
        uint16 settlementFeeBps,
        bool feeOnLosingPool
    ) internal pure returns (uint256) {
        uint256 userWinning = totalWinningStake(epoch.winningOutcomeMask, epoch.outcomeCount, stakes);
        if (userWinning == 0) return 0;
        uint256 winningPool = epoch.winningPoolTotal();
        (,, uint256 distributableLosing) =
            computeClaimLiabilityComponents(epoch.totalPool, winningPool, settlementFeeBps, feeOnLosingPool);
        uint256 proRata = (userWinning * distributableLosing) / winningPool;
        return userWinning + proRata;
    }

    /// @notice Compute claim payout for a user position (memory epoch).
    /// @dev Implements “last-claimer remainder”: if the user is the last remaining winner, payout equals `claimsReserveTotal`.
    function computeClaimPayout(MarketTypes.Epoch memory epoch, uint256[8] memory stakes, uint256 claimsReserveTotal)
        internal
        pure
        returns (uint256 payout, uint256 userWinningStake_)
    {
        userWinningStake_ = totalWinningStake(epoch.winningOutcomeMask, epoch.outcomeCount, stakes);
        if (userWinningStake_ == 0) return (0, 0);

        uint256 entitlement =
            computeTotalUserEntitlementResolved(epoch, stakes, epoch.settlementFeeBps, epoch.feeOnLosingPool);

        if (epoch.remainingWinningStake == userWinningStake_) {
            payout = claimsReserveTotal;
        } else {
            payout = entitlement;
        }
        return (payout, userWinningStake_);
    }

    /// @notice Compute claim payout for a user position (storage epoch, L2 hot path).
    /// @dev
    /// Avoids copying full `Epoch` to memory. Implements per-epoch last-claimer remainder:
    /// if `epoch.remainingWinningStake == userWinningStake_`, payout equals `remainingClaimsForEpoch`.
    function computeClaimPayoutStorage(
        MarketTypes.Epoch storage epoch,
        uint256[8] memory stakes,
        uint256 remainingClaimsForEpoch
    ) internal view returns (uint256 payout, uint256 userWinningStake_) {
        userWinningStake_ = totalWinningStake(epoch.winningOutcomeMask, epoch.outcomeCount, stakes);
        if (userWinningStake_ == 0) return (0, 0);

        uint256 winningPool = 0;
        for (uint256 i = 0; i < epoch.outcomeCount; i++) {
            if ((epoch.winningOutcomeMask >> i) & 1 == 1) {
                winningPool += epoch.outcomePools[i];
            }
        }
        (,, uint256 distributableLosing) =
            computeClaimLiabilityComponents(epoch.totalPool, winningPool, epoch.settlementFeeBps, epoch.feeOnLosingPool);
        uint256 entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool;

        if (epoch.remainingWinningStake == userWinningStake_) {
            payout = remainingClaimsForEpoch;
        } else {
            payout = entitlement;
        }
        return (payout, userWinningStake_);
    }

    /// @notice Compute refund amount in refund-mode epochs.
    /// @dev Currently full refund of `totalStake`.
    function computeRefundTotal(uint256 totalStake) internal pure returns (uint256) {
        return totalStake;
    }

    /// @notice Move `amount` from active collateral to claims reserve (ledger accounting).
    function reserveClaimsFromActive(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
        ledger.claimsReserveTotal += amount;
    }

    /// @notice Move `amount` from active collateral to fee reserve (ledger accounting).
    function reserveFeesFromActive(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
        ledger.feeReserveTotal += amount;
    }

    /// @notice Release claims reserve when paying out a claim/refund.
    function releaseClaimOnWithdraw(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.claimsReserveTotal = _sub(ledger.claimsReserveTotal, amount);
    }

    /// @notice Release fee reserve when withdrawing fees to treasury.
    function releaseFeeOnWithdraw(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.feeReserveTotal = _sub(ledger.feeReserveTotal, amount);
    }

    /// @notice Increase active collateral total when depositing into an epoch.
    function increaseActiveCollateral(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal += amount;
    }

    /// @notice Decrease active collateral total (guarded subtract).
    function decreaseActiveCollateral(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
    }

    function _sub(uint256 a, uint256 b) private pure returns (uint256) {
        if (a < b) revert MathOverflow();
        return a - b;
    }
}
