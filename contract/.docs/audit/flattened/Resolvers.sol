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

// src/logic/Resolvers.sol

library Resolvers {
    error InvalidEpochState();
    error InvalidTemplate();

    /// @return voided When true, treat as refund mode (no winning side).
    /// @return mask Bitmask of winning outcomes (Rust `1u64 << idx`); undefined if voided.
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

