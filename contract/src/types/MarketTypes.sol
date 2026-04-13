// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MarketTypes
/// @notice Canonical enums/structs/helpers for RetroPick `MarketEngine`.
/// @dev
/// NOTES: Design goals
/// - Single-engine, many markets: types are keyed by `templateId` and `epochId`.
/// - Bounded arrays: `MAX_OUTCOMES=8` to keep stake/pool arrays bounded and L2-friendly.
/// - Packed storage: structs are ordered to minimize slots (especially `OracleCheckpoint`).
///
/// NOTES: Epoch lifecycle (conceptual)
/// Manual mode:
/// - `Open` → `Locked` → `Resolved` (or `Cancelled` / `Voided`)
///
/// Rolling mode:
/// - Same statuses, but keeper progression follows a pipeline (see `MarketEngine` docs).
///
/// NOTES: Push-oracle publishTime semantics
/// For push oracles like Chainlink, the oracle-provided `publishTime` (e.g. `updatedAt`) can be earlier
/// than `lockAt/resolveAt` but still be the freshest available data at execution time.
/// Therefore publishTime validation is based on:
/// - non-zero, non-future timestamp
/// - staleness window vs `nowTs` (`maxDelaySeconds`)
/// - for checkpoint B: monotonicity vs checkpoint A publishTime if checkpoint A exists
///
/// This keeps the engine compatible with Chainlink-style feeds and avoids false negatives.
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

    /// @dev Manual = discrete open/lock/resolve txs (classic lifecycle). Rolling = Pancake-style pipeline.
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

    /// @notice Oracle sample captured at lock (A) or resolve (B).
    /// @dev Packed to reduce storage:
    /// - one slot for `valueE8`
    /// - one slot for `confidenceE8` + `publishTime` + `written`
    ///
    /// `valueE8` is normalized to 8 decimals across the engine.
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

    /// @notice Template = market definition keyed by `templateId`.
    /// @dev Small fields first for packed warm slots; strings last (dynamic).
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
        /// @dev 0 = inherit global `oracleConfig.maxDelaySeconds` (snapshot copied to each epoch at open).
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

    /// @notice Epoch = one round instance for a template.
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

    /// @notice True if epoch is open for betting at `nowTs`.
    /// @dev Requires status `Open` and time window `[openAt, lockAt)`.
    function isEpochOpen(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Open && nowTs >= e.timing.openAt && nowTs < e.timing.lockAt;
    }

    /// @notice True if epoch can be locked at `nowTs`.
    /// @dev Requires status `Open` and `nowTs >= lockAt`.
    function isLockable(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Open && nowTs >= e.timing.lockAt;
    }

    /// @notice True if epoch can be resolved at `nowTs`.
    /// @dev Requires status `Locked` and `nowTs >= resolveAt`.
    function isResolvable(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Locked && nowTs >= e.timing.resolveAt;
    }

    /// @notice Whether this market type requires checkpoint A (lock-time oracle sample).
    /// @dev Direction markets compare checkpoint B vs checkpoint A to determine up/down.
    function requiresCheckpointAOnLock(Epoch storage e) internal view returns (bool) {
        return e.marketType == MarketType.Direction;
    }

    /// @notice Validate publishTime freshness for push oracles.
    /// @dev Rules:
    /// - rejects future timestamps (`publishTime > nowTs`)
    /// - enforces staleness window (`nowTs - publishTime <= maxDelaySeconds`)
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

    /// @notice Validate lock-time checkpoint A publishTime.
    /// @dev Freshness-only for push-oracles.
    /// Do NOT require `publishTime >= lockAt`; Chainlink `updatedAt` may be earlier than lockAt while still fresh.
    function validateCheckpointAPublishTime(Epoch storage, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
        internal
        pure
        returns (bool)
    {
        return validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds);
    }

    /// @notice Validate resolve-time checkpoint B publishTime.
    /// @dev Rules:
    /// - freshness vs now/maxDelaySeconds
    /// - monotonic vs checkpoint A publishTime if checkpoint A exists
    function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
        internal
        view
        returns (bool)
    {
        if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
        if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
        return true;
    }

    /// @notice Total pool size across winning outcomes (memory epoch).
    function winningPoolTotal(Epoch memory e) internal pure returns (uint256 sum) {
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if ((e.winningOutcomeMask >> i) & 1 == 1) {
                sum += e.outcomePools[i];
            }
        }
    }

    /// @notice Total pool size across winning outcomes (storage epoch).
    function winningPoolTotalStorage(Epoch storage e) internal view returns (uint256 sum) {
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if ((e.winningOutcomeMask >> i) & 1 == 1) {
                sum += e.outcomePools[i];
            }
        }
    }

    /// @notice Effective staleness window: epoch snapshot if non-zero, else global.
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
