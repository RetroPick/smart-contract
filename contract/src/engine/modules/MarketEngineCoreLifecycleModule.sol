// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineState} from "../MarketEngineState.sol";
import {MarketTypes} from "../../types/MarketTypes.sol";
import {MarketMath} from "../../math/MarketMath.sol";
import {Resolvers} from "../../logic/Resolvers.sol";
import {IPriceOracleWithRoundId} from "../../interfaces/IPriceOracleWithRoundId.sol";
import {IYieldRouterV2} from "../../interfaces/IYieldRouterV2.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/// @notice Core manual lifecycle module.
/// @dev Extracted from monolith with storage-preserving semantics.
contract MarketEngineCoreLifecycleModule is MarketEngineState, ReentrancyGuardTransient {
    using MarketTypes for MarketTypes.Epoch;
    using MarketMath for MarketTypes.Ledger;

    struct SettlementOutputs {
        bool refundMode;
        uint256 winningMask;
        uint256 claimLiabilityTotal;
        uint256 settlementFeeTotal;
    }

    struct UpsertTemplateParams {
        string slug;
        string assetSymbol;
        bytes32 oracleFeedId;
        MarketTypes.MarketType marketType;
        MarketTypes.Condition condition;
        MarketTypes.ThresholdRule thresholdRule;
        bool active;
        uint8 outcomeCount;
        int256 absoluteThresholdValueE8;
        int256[7] rangeBoundsE8;
        uint16 switchFeeBps;
        uint16 settlementFeeBps;
        bool allowMultiSidePositions;
        MarketTypes.ExecutionMode executionMode;
        uint64 rollingIntervalSeconds;
        uint64 rollingBufferSeconds;
        uint64 oracleMaxDelaySeconds;
        uint16 oracleMaxConfidenceBps;
    }

    function upsertTemplate(UpsertTemplateParams calldata p) external {
        if (msg.sender != admin) revert Unauthorized();
        if (bytes(p.slug).length == 0 || bytes(p.slug).length > MarketTypes.SLUG_MAX_LEN) revert InvalidTemplate();
        if (bytes(p.assetSymbol).length == 0 || bytes(p.assetSymbol).length > MarketTypes.ASSET_SYMBOL_MAX_LEN) {
            revert InvalidTemplate();
        }
        if (p.switchFeeBps > maxSwitchFeeBps) revert InvalidFeeBps();
        if (p.outcomeCount == 0 || p.outcomeCount > maxOutcomes) revert TooManyOutcomes();
        if (p.oracleFeedId == bytes32(0)) revert InvalidOracleFeed();

        bytes32 tid = templateIdFromSlug(p.slug);
        MarketTypes.Template storage t = _templates[tid];
        if (t.version != 0) {
            if (keccak256(bytes(t.slug)) != keccak256(bytes(p.slug))) revert InvalidTemplate();
        } else {
            t.version = MarketTypes.VERSION;
        }

        t.slug = p.slug;
        t.assetSymbol = p.assetSymbol;
        t.oracleFeedId = p.oracleFeedId;
        t.marketType = p.marketType;
        t.condition = p.condition;
        t.thresholdRule = p.thresholdRule;
        t.active = p.active;
        t.outcomeCount = p.outcomeCount;
        t.absoluteThresholdValueE8 = p.absoluteThresholdValueE8;
        t.rangeBoundsE8 = p.rangeBoundsE8;
        t.switchFeeBps = p.switchFeeBps;
        t.settlementFeeBps = p.settlementFeeBps;
        t.equalPriceVoids = true;
        t.feeOnLosingPool = true;
        t.allowMultiSidePositions = p.allowMultiSidePositions;
        t.executionMode = p.executionMode;
        t.rollingIntervalSeconds = p.rollingIntervalSeconds;
        t.rollingBufferSeconds = p.rollingBufferSeconds;
        t.oracleMaxDelaySeconds = p.oracleMaxDelaySeconds;
        t.oracleMaxConfidenceBps = p.oracleMaxConfidenceBps;

        if (p.executionMode == MarketTypes.ExecutionMode.Rolling) {
            if (p.rollingIntervalSeconds == 0) revert RollingInvalidParams();
            if (!(p.rollingBufferSeconds < p.rollingIntervalSeconds)) revert RollingInvalidParams();
        }
        _validateTemplate(t);
        emit TemplateUpserted(
            tid, p.slug, uint8(uint256(p.marketType)), p.outcomeCount, p.oracleMaxDelaySeconds, p.oracleMaxConfidenceBps
        );
    }

    function openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) external {
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
        if (globalPaused) revert ProtocolPaused();
        _openEpoch(templateId, epochId, openAt, lockAt, resolveAt);
    }

    function openEpochsBatch(
        bytes32[] calldata templateIds,
        uint64[] calldata epochIds,
        uint64[] calldata openAt,
        uint64[] calldata lockAt,
        uint64[] calldata resolveAt
    ) external {
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
        if (globalPaused) revert ProtocolPaused();
        uint256 n = templateIds.length;
        if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
            revert InvalidTemplate();
        }
        for (uint256 i = 0; i < n; i++) {
            _openEpoch(templateIds[i], epochIds[i], openAt[i], lockAt[i], resolveAt[i]);
        }
    }

    function lockEpoch(bytes32 templateId, uint64 epochId) external {
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
        if (globalPaused) revert ProtocolPaused();
        _lockEpoch(templateId, epochId);
    }

    function lockEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external {
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
        if (globalPaused) revert ProtocolPaused();
        uint256 n = templateIds.length;
        if (n != epochIds.length) revert InvalidTemplate();
        for (uint256 i = 0; i < n; i++) {
            _lockEpoch(templateIds[i], epochIds[i]);
        }
    }

    function resolveEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
        if (globalPaused) revert ProtocolPaused();
        _resolveEpoch(templateId, epochId);
    }

    function resolveEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external nonReentrant {
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
        if (globalPaused) revert ProtocolPaused();
        uint256 n = templateIds.length;
        if (n != epochIds.length) revert InvalidTemplate();
        for (uint256 i = 0; i < n; i++) {
            _resolveEpoch(templateIds[i], epochIds[i]);
        }
    }

    // slither-disable-next-line reentrancy-no-eth -- external `nonReentrant`; trusted `yieldRouter`; CEI ordering intentional after `withdrawScaled`.
    function cancelEpoch(bytes32 templateId, uint64 epochId, MarketTypes.CancelReason reason, bool voided)
        external
        nonReentrant
    {
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
        if (globalPaused && msg.sender != admin) revert ProtocolPaused();
        if (!configInitialized) revert Unauthorized();
        if (reason == MarketTypes.CancelReason.NoneReason) revert InvalidEpochState();
        MarketTypes.Template storage t = _templates[templateId];
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (t.executionMode == MarketTypes.ExecutionMode.Rolling && ledger.rollingPhase == MarketTypes.RollingPhase.Live) {
            revert ManualModeOnly();
        }
        if (!ledger.initialized) revert InvalidTemplate();
        _requireActiveEpoch(ledger, epochId);
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!(e.status == MarketTypes.EpochStatus.Open || e.status == MarketTypes.EpochStatus.Locked)) {
            revert InvalidEpochState();
        }

        IYieldRouterV2 r = yieldRouter;
        if (address(r) != address(0) && e.totalPool > 0) {
            uint256 routedPrincipal = (e.totalPool * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
            if (routedPrincipal > 0) {
                try r.withdrawScaled(templateId, routedPrincipal) returns (uint256 grossReturned) {
                    if (grossReturned > routedPrincipal) {
                        uint256 grossYield = grossReturned - routedPrincipal;
                        _vaults[templateId].fees += grossYield;
                        ledger.feeReserveTotal += grossYield;
                    }
                } catch {
                    emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
                    revert YieldWithdrawFailed();
                }
            }
        }

        uint256 refundLiability = e.totalPool;
        if (refundLiability > 0) {
            _vaults[templateId].active -= refundLiability;
            _vaults[templateId].claims += refundLiability;
            MarketMath.reserveClaimsFromActive(ledger, refundLiability);
        }

        e.claimLiabilityTotal = 0;
        e.totalRefundLiability = refundLiability;
        e.settlementFeeTotal = 0;
        e.winningOutcomeMask = 0;
        e.remainingWinningStake = 0;
        e.cancelReason = reason;
        e.refundMode = true;
        e.claimable = true;
        e.status = voided ? MarketTypes.EpochStatus.Voided : MarketTypes.EpochStatus.Cancelled;
        e.resolvedAt = uint64(block.timestamp);
        ledger.lastResolvedEpochId = epochId;
        emit EpochCancelled(templateId, epochId, uint8(reason));
    }

    function _openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) internal {
        if (_templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
        if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.version == 0) revert InvalidTemplate();
        if (!t.active) revert TemplateInactive();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        _requireCanOpenNextEpoch(ledger, epochId);
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (e.exists) revert EpochAlreadyExists();

        uint64 nowTs = uint64(block.timestamp);
        e.version = MarketTypes.VERSION;
        e.status = MarketTypes.EpochStatus.Open;
        e.cancelReason = MarketTypes.CancelReason.NoneReason;
        e.outcomeCount = t.outcomeCount;
        e.marketType = t.marketType;
        e.condition = t.condition;
        e.switchFeeBps = t.switchFeeBps;
        e.settlementFeeBps = t.settlementFeeBps;
        e.equalPriceVoids = t.equalPriceVoids;
        e.feeOnLosingPool = t.feeOnLosingPool;
        e.allowMultiSidePositions = t.allowMultiSidePositions;
        e.refundMode = false;
        e.claimable = false;
        e.exists = true;
        e.epochId = epochId;
        e.totalPositions = 0;
        e.timing = MarketTypes.MarketTiming({openAt: openAt, lockAt: lockAt, resolveAt: resolveAt});
        e.createdAt = nowTs;
        e.oracleMaxDelaySeconds = t.oracleMaxDelaySeconds;
        e.oracleMaxConfidenceBps = t.oracleMaxConfidenceBps;
        e.oracleFeedId = t.oracleFeedId;
        e.absoluteThresholdValueE8 = t.absoluteThresholdValueE8;
        e.rangeBoundsE8 = t.rangeBoundsE8;
        ledger.activeEpochId = epochId;
        emit EpochOpened(templateId, epochId, openAt, lockAt, resolveAt);
    }

    function _lockEpoch(bytes32 templateId, uint64 epochId) internal {
        if (!configInitialized) revert Unauthorized();
        if (_templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        uint64 nowTs = uint64(block.timestamp);
        if (!e.isLockable(nowTs)) revert TooEarlyToLock();
        if (MarketTypes.requiresCheckpointAOnLock(e)) {
            uint64 maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(e, oracleConfig.maxDelaySeconds);
            uint16 maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(e, oracleConfig.maxConfidenceBps);
            (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId) =
                _readOracleOrRevert(templateId, e.oracleFeedId, maxDelay, nowTs);
            _applyLock(templateId, epochId, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelay, maxConf, nowTs);
        } else {
            _applyLock(templateId, epochId, 0, 0, 0, 0, 0, 0, nowTs);
        }
    }

    function _resolveEpoch(bytes32 templateId, uint64 epochId) internal {
        if (!configInitialized) revert Unauthorized();
        if (_templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        _requireActiveEpoch(ledger, epochId);
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        uint64 nowTs = uint64(block.timestamp);
        if (!e.isResolvable(nowTs)) revert TooEarlyToResolve();
        if (e.checkpointB.written) revert CheckpointAlreadyWritten();

        uint64 maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(e, oracleConfig.maxDelaySeconds);
        uint16 maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(e, oracleConfig.maxConfidenceBps);
        (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId) =
            _readOracleOrRevert(templateId, e.oracleFeedId, maxDelay, nowTs);
        _enforceConfidence(priceE8, confidenceE8, maxConf);
        _finishResolveEpochManual(templateId, epochId, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelay, nowTs);
    }

    // slither-disable-next-line reentrancy-no-eth -- only reachable from `resolveEpoch*` (`nonReentrant`); trusted `yieldRouter`.
    function _finishResolveEpochManual(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
        uint80 oracleRoundId,
        uint64 maxDelaySeconds,
        uint64 nowTs
    ) internal {
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (epochId != ledger.activeEpochId) revert EpochNotActive();
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!e.isResolvable(nowTs)) revert TooEarlyToResolve();
        if (e.checkpointB.written) revert CheckpointAlreadyWritten();
        if (!e.validateCheckpointBPublishTime(publishTime, nowTs, maxDelaySeconds)) revert InvalidOraclePublishTime();
        e.checkpointB = MarketTypes.OracleCheckpoint({
            valueE8: priceE8, publishTime: publishTime, confidenceE8: _toConf128(confidenceE8), written: true
        });

        uint256 grossYield = _withdrawRoutedPrincipalOnResolve(templateId, epochId, e.totalPool);
        (uint256 yieldFee, uint256 netYield) = _applyGrossYield(templateId, ledger, grossYield);

        SettlementOutputs memory outputs = _computeSettlementOutputsWithEffectivePool(e, netYield);
        _applyResolveAccounting(templateId, epochId, ledger, e, outputs, nowTs);
        _emitResolveEvents(templateId, epochId, outputs, oracleRoundId);
        _finalizeYieldAccounting(templateId, epochId, ledger, grossYield, yieldFee, netYield, outputs.refundMode);
    }

    function _applyLock(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
        uint80 oracleRoundId,
        uint64 maxDelaySeconds,
        uint16 maxConfBps,
        uint64 nowTs
    ) internal {
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!e.isLockable(nowTs)) revert TooEarlyToLock();
        if (MarketTypes.requiresCheckpointAOnLock(e)) {
            if (e.checkpointA.written) revert CheckpointAlreadyWritten();
            _enforceConfidence(priceE8, confidenceE8, maxConfBps);
            if (!e.validateCheckpointAPublishTime(publishTime, nowTs, maxDelaySeconds)) revert InvalidOraclePublishTime();
            e.checkpointA = MarketTypes.OracleCheckpoint({
                valueE8: priceE8, publishTime: publishTime, confidenceE8: _toConf128(confidenceE8), written: true
            });
        }
        e.status = MarketTypes.EpochStatus.Locked;
        e.lockedAt = nowTs;
        emit EpochLocked(templateId, epochId, e.checkpointA.valueE8, e.checkpointA.publishTime);
        if (MarketTypes.requiresCheckpointAOnLock(e)) {
            emit EpochLockedV2(templateId, epochId, e.checkpointA.valueE8, e.checkpointA.publishTime, oracleRoundId);
        }
    }

    function _withdrawRoutedPrincipalOnResolve(bytes32 templateId, uint64 epochId, uint256 totalPool)
        internal
        returns (uint256 grossYield)
    {
        IYieldRouterV2 r = yieldRouter;
        if (address(r) == address(0) || totalPool == 0) return 0;

        uint256 routedPrincipal = (totalPool * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
        if (routedPrincipal == 0) return 0;

        try r.withdrawScaled(templateId, routedPrincipal) returns (uint256 grossReturned) {
            if (grossReturned > routedPrincipal) return grossReturned - routedPrincipal;
            return 0;
        } catch {
            emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
            revert YieldWithdrawFailed();
        }
    }

    function _applyGrossYield(bytes32 templateId, MarketTypes.Ledger storage ledger, uint256 grossYield)
        internal
        returns (uint256 yieldFee, uint256 netYield)
    {
        if (grossYield == 0) return (0, 0);

        _vaults[templateId].active += grossYield;
        ledger.increaseActiveCollateral(grossYield);

        yieldFee = (grossYield * uint256(yieldFeeBps)) / 10_000;
        netYield = grossYield - yieldFee;
        if (yieldFee > 0) {
            _vaults[templateId].active -= yieldFee;
            _vaults[templateId].fees += yieldFee;
            MarketMath.reserveFeesFromActive(ledger, yieldFee);
        }
    }

    function _finalizeYieldAccounting(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.Ledger storage ledger,
        uint256 grossYield,
        uint256 yieldFee,
        uint256 netYield,
        bool refundMode
    ) internal {
        if (grossYield == 0) return;

        if (refundMode) {
            _vaults[templateId].active -= netYield;
            _vaults[templateId].fees += netYield;
            MarketMath.reserveFeesFromActive(ledger, netYield);
            netYield = 0;
        }
        emit EpochYieldAccrued(templateId, epochId, grossYield, yieldFee, netYield);
    }

    function _applyResolveAccounting(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.Ledger storage ledger,
        MarketTypes.Epoch storage e,
        SettlementOutputs memory outputs,
        uint64 nowTs
    ) internal {
        if (outputs.claimLiabilityTotal > 0) {
            _vaults[templateId].active -= outputs.claimLiabilityTotal;
            _vaults[templateId].claims += outputs.claimLiabilityTotal;
            MarketMath.reserveClaimsFromActive(ledger, outputs.claimLiabilityTotal);
        }
        if (outputs.settlementFeeTotal > 0) {
            _vaults[templateId].active -= outputs.settlementFeeTotal;
            _vaults[templateId].fees += outputs.settlementFeeTotal;
            MarketMath.reserveFeesFromActive(ledger, outputs.settlementFeeTotal);
        }
        e.winningOutcomeMask = outputs.winningMask;
        e.claimLiabilityTotal = outputs.refundMode ? 0 : outputs.claimLiabilityTotal;
        e.totalRefundLiability = outputs.refundMode ? outputs.claimLiabilityTotal : 0;
        e.settlementFeeTotal = outputs.settlementFeeTotal;
        e.refundMode = outputs.refundMode;
        e.claimable = true;
        e.status = outputs.refundMode ? MarketTypes.EpochStatus.Voided : MarketTypes.EpochStatus.Resolved;
        e.resolvedAt = nowTs;
        ledger.lastResolvedEpochId = epochId;
        _setRemainingWinningStake(templateId, epochId, outputs.refundMode);
    }

    function _emitResolveEvents(bytes32 templateId, uint64 epochId, SettlementOutputs memory outputs, uint80 oracleRoundId)
        internal
    {
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        emit EpochResolved(
            templateId,
            epochId,
            outputs.winningMask,
            outputs.claimLiabilityTotal,
            outputs.settlementFeeTotal,
            outputs.refundMode
        );
        emit EpochResolvedV2(templateId, epochId, oracleRoundId, e.checkpointB.valueE8, e.checkpointB.publishTime);
    }

    function _setRemainingWinningStake(bytes32 templateId, uint64 epochId, bool refundMode) internal {
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (refundMode) {
            e.remainingWinningStake = 0;
            return;
        }
        uint256 sum = 0;
        uint8 n = e.outcomeCount;
        for (uint256 i = 0; i < uint256(n); i++) {
            if (((e.winningOutcomeMask >> i) & 1) == 1) sum += e.outcomePools[i];
        }
        e.remainingWinningStake = sum;
    }

    function _computeSettlementOutputsWithEffectivePool(MarketTypes.Epoch storage e, uint256 netYield)
        internal
        returns (SettlementOutputs memory outputs)
    {
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
            outputs.winningMask = Resolvers.resolveThreshold(e.condition, e.absoluteThresholdValueE8, e.checkpointB);
            e.winningOutcomeMask = outputs.winningMask;
        } else {
            outputs.refundMode = false;
            outputs.winningMask = Resolvers.resolveRangeClose(e.checkpointB, e.outcomeCount, e.rangeBoundsE8);
            e.winningOutcomeMask = outputs.winningMask;
        }
        uint256 effectiveTotalPool = e.totalPool + netYield;
        uint256 winningPool = 0;
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if (((outputs.winningMask >> i) & 1) == 1) winningPool += e.outcomePools[i];
        }
        // slither-disable-next-line unused-return -- third return is `distributableLosingPool`; only claim + fee used here.
        (outputs.claimLiabilityTotal, outputs.settlementFeeTotal,) =
            MarketMath.computeClaimLiabilityComponents(effectiveTotalPool, winningPool, e.settlementFeeBps, e.feeOnLosingPool);
    }

    function _requireCanOpenNextEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (ledger.activeEpochId != ledger.lastResolvedEpochId) revert PreviousEpochUnresolved();
        if (epochId != ledger.activeEpochId + 1) revert EpochAlreadyExists();
    }

    function _requireActiveEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (epochId != ledger.activeEpochId) revert EpochNotActive();
    }

    function _toConf128(uint256 confidenceE8) internal pure returns (uint128) {
        if (confidenceE8 > type(uint128).max) revert ConfidenceOverflow();
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint128(confidenceE8);
    }

    function _enforceConfidence(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps) internal pure {
        if (!_confidenceWithinBand(priceE8, confidenceE8, maxConfidenceBps)) revert OracleConfidenceTooWide();
    }

    function _confidenceWithinBand(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps)
        internal
        pure
        returns (bool)
    {
        uint256 abs;
        assembly {
            abs := priceE8
            if slt(priceE8, 0) { abs := sub(0, priceE8) }
        }
        // slither-disable-next-line incorrect-equality -- detects `type(int256).min` (no positive absolute value in int256).
        if (abs == (1 << 255)) revert InvalidOraclePrice();
        uint256 limit = (abs * uint256(maxConfidenceBps)) / 10_000;
        return confidenceE8 <= limit;
    }

    function _readOracleOrRevert(bytes32 templateId, bytes32 feedId, uint64 maxDelay, uint64 nowTs)
        internal
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId)
    {
        try IPriceOracleWithRoundId(address(priceOracle)).getNormalizedPriceWithRoundId(feedId, maxDelay, nowTs) returns (
            uint80 rid, int256 p, uint64 pt, uint256 c
        ) {
            _enforceAndUpdateOracleCursor(templateId, feedId, rid, pt);
            return (p, pt, c, rid);
        } catch {
            (priceE8, publishTime, confidenceE8) = priceOracle.getNormalizedPrice(feedId, maxDelay, nowTs);
            _enforceAndUpdateOracleCursor(templateId, feedId, 0, publishTime);
            return (priceE8, publishTime, confidenceE8, 0);
        }
    }

    function _enforceAndUpdateOracleCursor(bytes32 templateId, bytes32 feedId, uint80 oracleRoundId, uint64 publishTime)
        internal
    {
        OracleCursor storage c = lastOracleCursorByTemplateFeed[templateId][feedId];
        if (oracleRoundId < c.roundId) {
            revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
        }
        // slither-disable-next-line incorrect-equality -- same round id must not move publish time backwards.
        if (oracleRoundId == c.roundId && publishTime < c.publishTime) {
            revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
        }
        c.roundId = oracleRoundId;
        c.publishTime = publishTime;
        if (oracleRoundId > lastOracleRoundIdByTemplate[templateId]) {
            lastOracleRoundIdByTemplate[templateId] = oracleRoundId;
        }
    }

    function _validateTemplate(MarketTypes.Template storage t) internal view {
        if (t.outcomeCount > maxOutcomes) revert TooManyOutcomes();
        if (t.switchFeeBps > 10_000 || t.settlementFeeBps > 10_000) revert InvalidFeeBps();
        if (t.marketType == MarketTypes.MarketType.Direction) {
            if (t.outcomeCount != 2) revert InvalidTemplate();
            if (t.thresholdRule != MarketTypes.ThresholdRule.None) revert InvalidTemplate();
            if (!t.equalPriceVoids) revert InvalidTemplate();
        } else if (t.marketType == MarketTypes.MarketType.Threshold) {
            if (t.outcomeCount != 2) revert InvalidTemplate();
            if (t.thresholdRule != MarketTypes.ThresholdRule.Absolute) revert InvalidTemplate();
        } else {
            if (t.outcomeCount < 2) revert InvalidTemplate();
            for (uint256 i = 1; i < uint256(t.outcomeCount) - 1; i++) {
                if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
            }
        }
        if (t.oracleMaxConfidenceBps > 0 && t.oracleMaxConfidenceBps > 10_000) revert InvalidFeeBps();
    }
}
