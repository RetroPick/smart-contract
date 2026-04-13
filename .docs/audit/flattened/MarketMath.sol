// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// src/types/MarketTypes.sol

/// @dev Mirrors `retropick_market_engine_v5` Anchor state + packed storage for L2 gas.
library MarketTypes {
    uint8 internal constant VERSION = 1;
    uint8 internal constant MAX_OUTCOMES = 8;
    uint8 internal constant RANGE_BOUNDS_LEN = MAX_OUTCOMES - 1;
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant SLUG_MAX_LEN = 32;
    uint256 internal constant ASSET_SYMBOL_MAX_LEN = 16;

    enum MarketType {
        Direction,
        Threshold,
        RangeClose
    }

    enum Condition {
        AtOrAbove,
        Below
    }

    enum ThresholdRule {
        None,
        Absolute
    }

    enum EpochStatus {
        Scheduled,
        Open,
        Locked,
        Resolved,
        Cancelled,
        Voided
    }

    enum OracleKind {
        Chainlink
    }

    enum CancelReason {
        NoneReason,
        OracleUnavailable,
        OracleStale,
        InvalidTemplate,
        InvalidTiming,
        EmergencyPaused,
        ManualAdminCancel
    }

    /// @dev Manual = discrete open/lock/resolve txs (Anchor v5 parity). Rolling = Pancake-style pipeline.
    enum ExecutionMode {
        Manual,
        Rolling
    }

    /// @dev Rolling lifecycle per ledger; see rolling-rounds.md.
    enum RollingPhase {
        Uninitialized,
        GenesisOpen,
        Live,
        Halted
    }

    /// @dev Why a rolling template entered `RollingPhase.Halted` (stored on ledger).
    enum RollingHaltReason {
        NoneReason,
        BufferMissOnLock,
        BufferMissOnResolve,
        OracleFailure,
        OracleConfidenceWide,
        ManualAdmin
    }

    struct OracleConfig {
        OracleKind oracleKind;
        uint64 maxDelaySeconds;
        uint16 maxConfidenceBps;
    }

    /// @dev Packed: one slot for price + one slot for conf/publishTime/written (vs ~4 slots naive).
    struct OracleCheckpoint {
        int256 valueE8;
        uint128 confidenceE8;
        uint64 publishTime;
        bool written;
    }

    struct MarketTiming {
        uint64 openAt;
        uint64 lockAt;
        uint64 resolveAt;
    }

    /// @dev Small fields first for single warm slots; strings last (dynamic).
    struct Template {
        uint8 version;
        MarketType marketType;
        Condition condition;
        ThresholdRule thresholdRule;
        bool active;
        uint8 outcomeCount;
        uint16 switchFeeBps;
        uint16 settlementFeeBps;
        bool equalPriceVoids;
        bool feeOnLosingPool;
        bool allowMultiSidePositions;
        ExecutionMode executionMode;
        uint64 rollingIntervalSeconds;
        uint64 rollingBufferSeconds;
        string slug;
        string assetSymbol;
        bytes32 oracleFeedId;
        int256 absoluteThresholdValueE8;
        int256[RANGE_BOUNDS_LEN] rangeBoundsE8;
        /// @dev 0 = inherit global `Config.oracle_config.max_delay_seconds` (snapshot copied to each epoch at open).
        uint64 oracleMaxDelaySeconds;
        /// @dev 0 = inherit global `max_confidence_bps`.
        uint16 oracleMaxConfidenceBps;
    }

    struct Ledger {
        bool initialized;
        uint8 version;
        uint64 activeEpochId;
        uint64 lastResolvedEpochId;
        uint64 rollingNextEpochId;
        uint64 haltedAtEpochId;
        uint256 activeCollateralTotal;
        uint256 claimsReserveTotal;
        uint256 feeReserveTotal;
        uint256 insuranceReserveTotal;
        RollingPhase rollingPhase;
        RollingHaltReason rollingHaltReason;
    }

    struct VaultBalances {
        uint256 active;
        uint256 claims;
        uint256 fees;
    }

    /// @dev Hot small fields packed at the front; `timing`+`createdAt` share one slot when possible.
    struct Epoch {
        uint8 version;
        EpochStatus status;
        CancelReason cancelReason;
        uint8 outcomeCount;
        MarketType marketType;
        Condition condition;
        uint16 switchFeeBps;
        uint16 settlementFeeBps;
        bool equalPriceVoids;
        bool feeOnLosingPool;
        bool allowMultiSidePositions;
        bool refundMode;
        bool claimable;
        bool exists;
        uint64 epochId;
        uint32 totalPositions;
        MarketTiming timing;
        uint64 createdAt;
        uint64 lockedAt;
        uint64 resolvedAt;
        /// @dev Snapshot from template at open; 0 = use global at effective* time.
        uint64 oracleMaxDelaySeconds;
        /// @dev Snapshot from template at open; 0 = use global.
        uint16 oracleMaxConfidenceBps;
        OracleCheckpoint checkpointA;
        OracleCheckpoint checkpointB;
        bytes32 oracleFeedId;
        int256 absoluteThresholdValueE8;
        int256[RANGE_BOUNDS_LEN] rangeBoundsE8;
        uint256 winningOutcomeMask;
        uint256 totalPool;
        uint256[MAX_OUTCOMES] outcomePools;
        uint256 switchFeeTotal;
        uint256 settlementFeeTotal;
        uint256 claimLiabilityTotal;
        uint256 totalRefundLiability;
        uint256 claimedTotal;
        uint256 remainingWinningStake;
    }

    struct Position {
        uint8 version;
        uint256[MAX_OUTCOMES] stakes;
        uint256 totalStake;
        uint256 switchFeesPaid;
        uint256 entryFeesPaid;
        uint256 claimedAmount;
        bool claimed;
        bool initialized;
    }

    function isEpochOpen(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Open && nowTs >= e.timing.openAt && nowTs < e.timing.lockAt;
    }

    function isLockable(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Open && nowTs >= e.timing.lockAt;
    }

    function isResolvable(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Locked && nowTs >= e.timing.resolveAt;
    }

    function requiresCheckpointAOnLock(Epoch storage e) internal view returns (bool) {
        return e.marketType == MarketType.Direction;
    }

    /// @dev Push-oracle compatible freshness check.
    ///      - rejects future timestamps (publishTime > nowTs)
    ///      - enforces staleness window (nowTs - publishTime <= maxDelaySeconds)
    function validatePublishTimeFresh(uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
        internal
        pure
        returns (bool)
    {
        if (publishTime == 0) return false;
        if (publishTime > nowTs) return false;
        unchecked {
            return (nowTs - publishTime) <= maxDelaySeconds;
        }
    }

    /// @dev Checkpoint A time rule for push-oracles: freshness only.
    ///      (Do NOT require publishTime >= lockAt; Chainlink `updatedAt` may be before lockAt.)
    function validateCheckpointAPublishTime(Epoch storage, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
        internal
        pure
        returns (bool)
    {
        return validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds);
    }

    /// @dev Checkpoint B time rule for push-oracles:
    ///      - freshness vs now/maxDelaySeconds
    ///      - monotonic vs checkpoint A publishTime if A exists
    function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
        internal
        view
        returns (bool)
    {
        if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
        if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
        return true;
    }

    function winningPoolTotal(Epoch memory e) internal pure returns (uint256 sum) {
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if ((e.winningOutcomeMask >> i) & 1 == 1) {
                sum += e.outcomePools[i];
            }
        }
    }

    function winningPoolTotalStorage(Epoch storage e) internal view returns (uint256 sum) {
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if ((e.winningOutcomeMask >> i) & 1 == 1) {
                sum += e.outcomePools[i];
            }
        }
    }

    /// @notice Effective staleness window: epoch snapshot if non-zero, else global (Anchor `effective_oracle_max_delay_seconds`).
    function effectiveOracleMaxDelaySeconds(Epoch storage e, uint64 globalDelaySeconds) internal view returns (uint64) {
        if (e.oracleMaxDelaySeconds > 0) return e.oracleMaxDelaySeconds;
        return globalDelaySeconds;
    }

    /// @notice Effective confidence cap: epoch snapshot if non-zero, else global.
    function effectiveOracleMaxConfidenceBps(Epoch storage e, uint16 globalMaxConfidenceBps)
        internal
        view
        returns (uint16)
    {
        if (e.oracleMaxConfidenceBps > 0) return e.oracleMaxConfidenceBps;
        return globalMaxConfidenceBps;
    }
}

// src/math/MarketMath.sol

library MarketMath {
    using MarketTypes for MarketTypes.Epoch;

    error MathOverflow();
    error NoWinningOutcome();

    uint256 internal constant BPS_DENOMINATOR = MarketTypes.BPS_DENOMINATOR;

    function computeSwitch(uint256 grossAmount, uint16 switchFeeBps) internal pure returns (uint256 net, uint256 fee) {
        if (switchFeeBps == 0) return (grossAmount, 0);
        fee = (grossAmount * uint256(switchFeeBps) + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
        if (fee > grossAmount) revert MathOverflow();
        net = grossAmount - fee;
    }

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

    function computeClaimLiabilityComponents(
        uint256 totalPool,
        uint256 winningPool,
        uint16 feeBps,
        bool feeOnLosingPool
    ) internal pure returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool) {
        if (winningPool == 0) revert NoWinningOutcome();
        if (totalPool < winningPool) revert MathOverflow();
        uint256 losingPool = totalPool - winningPool;
        settlementFee = computeSettlementFee(totalPool, losingPool, feeBps, feeOnLosingPool);
        if (losingPool < settlementFee) revert MathOverflow();
        distributableLosingPool = losingPool - settlementFee;
        claimLiabilityTotal = winningPool + distributableLosingPool;
    }

    function computeEpochClaimLiability(MarketTypes.Epoch memory epoch, uint16 feeBps, bool feeOnLosingPool)
        internal
        pure
        returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool)
    {
        uint256 wp = epoch.winningPoolTotal();
        return computeClaimLiabilityComponents(epoch.totalPool, wp, feeBps, feeOnLosingPool);
    }

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

    /// @dev Avoids copying full `Epoch` to memory on each claim (L2 hot path).
    function computeClaimPayoutStorage(
        MarketTypes.Epoch storage epoch,
        uint256[8] memory stakes,
        uint256 claimsReserveTotal
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
            payout = claimsReserveTotal;
        } else {
            payout = entitlement;
        }
        return (payout, userWinningStake_);
    }

    function computeRefundTotal(uint256 totalStake) internal pure returns (uint256) {
        return totalStake;
    }

    function reserveClaimsFromActive(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
        ledger.claimsReserveTotal += amount;
    }

    function reserveFeesFromActive(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
        ledger.feeReserveTotal += amount;
    }

    function releaseClaimOnWithdraw(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.claimsReserveTotal = _sub(ledger.claimsReserveTotal, amount);
    }

    function releaseFeeOnWithdraw(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.feeReserveTotal = _sub(ledger.feeReserveTotal, amount);
    }

    function increaseActiveCollateral(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal += amount;
    }

    function decreaseActiveCollateral(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
    }

    function _sub(uint256 a, uint256 b) private pure returns (uint256) {
        if (a < b) revert MathOverflow();
        return a - b;
    }
}

