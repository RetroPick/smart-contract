// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineState} from "../MarketEngineState.sol";
import {MarketTypes} from "../../types/MarketTypes.sol";
import {MarketMath} from "../../math/MarketMath.sol";
import {Resolvers} from "../../logic/Resolvers.sol";
import {SettlementLogic} from "../../logic/SettlementLogic.sol";
import {IEventOracle} from "../../interfaces/IEventOracle.sol";
import {IPriceOracle} from "../../interfaces/IPriceOracle.sol";
import {IPriceOracleWithRoundId} from "../../interfaces/IPriceOracleWithRoundId.sol";
import {IYieldRouterV2} from "../../interfaces/IYieldRouterV2.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/// @notice Core manual lifecycle module.
/// @dev Extracted from monolith with storage-preserving semantics.
contract MarketEngineCoreLifecycleModule is MarketEngineState, ReentrancyGuardTransient {
    using MarketTypes for MarketTypes.Epoch;
    using MarketMath for MarketTypes.Ledger;

    struct ResolveData {
        int256 priceE8;
        uint64 publishTime;
        uint256 confidenceE8;
        uint80 oracleRoundId;
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
        MarketTypes.OracleKind templateOracleKind;
        MarketTypes.OracleClass oracleClass;
        address eventOracle;
        bool cascadeDownward;
        int256 anchorPriceE8;
        uint32[7] velocityBoundsE4;
        int256[7] ladderBoundsE8;
        uint16[8] ladderPayoutWeightsBps;
        bytes32 oracleFeedIdB;
        uint16 spreadToleranceBps;
        bytes32[4] compositeFeedIds;
        MarketTypes.Condition[4] compositeConditions;
        uint8 compositeFeedCount;
        MarketTypes.CompositeLogic compositeLogic;
        int256[4] compositeAbsoluteThresholdsE8;
    }

    function upsertTemplate(UpsertTemplateParams calldata p) external {
        _authAdmin();
        if (bytes(p.slug).length == 0 || bytes(p.slug).length > MarketTypes.SLUG_MAX_LEN) revert InvalidTemplate();
        if (bytes(p.assetSymbol).length == 0 || bytes(p.assetSymbol).length > MarketTypes.ASSET_SYMBOL_MAX_LEN) {
            revert InvalidTemplate();
        }
        if (p.switchFeeBps > maxSwitchFeeBps) revert InvalidFeeBps();
        if (p.outcomeCount == 0 || p.outcomeCount > maxOutcomes) revert TooManyOutcomes();
        _validateOracleParams(p);

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
        t.templateOracleKind = p.templateOracleKind;
        t.oracleClass = p.oracleClass;
        t.eventOracle = p.eventOracle;
        t.cascadeDownward = p.cascadeDownward;
        t.anchorPriceE8 = p.anchorPriceE8;
        t.velocityBoundsE4 = p.velocityBoundsE4;
        t.ladderBoundsE8 = p.ladderBoundsE8;
        t.ladderPayoutWeightsBps = p.ladderPayoutWeightsBps;
        t.oracleFeedIdB = p.oracleFeedIdB;
        t.spreadToleranceBps = p.spreadToleranceBps;
        t.compositeFeedIds = p.compositeFeedIds;
        t.compositeConditions = p.compositeConditions;
        t.compositeFeedCount = p.compositeFeedCount;
        t.compositeLogic = p.compositeLogic;
        t.compositeAbsoluteThresholdsE8 = p.compositeAbsoluteThresholdsE8;

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
        _authAdminOrWorker();
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
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        uint256 n = templateIds.length;
        _validateBatchSize(n);
        if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
            revert InvalidTemplate();
        }
        for (uint256 i = 0; i < n; i++) {
            _openEpoch(templateIds[i], epochIds[i], openAt[i], lockAt[i], resolveAt[i]);
        }
    }

    function lockEpoch(bytes32 templateId, uint64 epochId) external {
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        _lockEpoch(templateId, epochId);
    }

    function lockEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external {
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        uint256 n = templateIds.length;
        _validateBatchSize(n);
        if (n != epochIds.length) revert InvalidTemplate();
        for (uint256 i = 0; i < n; i++) {
            _lockEpoch(templateIds[i], epochIds[i]);
        }
    }

    function resolveEpoch(bytes32 templateId, uint64 epochId) external nonReentrant {
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        _resolveEpoch(templateId, epochId);
    }

    function resolveEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external nonReentrant {
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        uint256 n = templateIds.length;
        _validateBatchSize(n);
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
        _authAdminOrWorker();
        if (globalPaused && msg.sender != admin) revert ProtocolPaused();
        if (reason == MarketTypes.CancelReason.NoneReason) revert InvalidEpochState();
        MarketTypes.Template storage t = _templates[templateId];
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (
            t.executionMode == MarketTypes.ExecutionMode.Rolling && ledger.rollingPhase == MarketTypes.RollingPhase.Live
        ) {
            revert ManualModeOnly();
        }
        if (!ledger.initialized) revert InvalidTemplate();
        _requireActiveEpoch(ledger, epochId);
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (e.routedPrincipal > 0) _requireNoUnreconciledRecovery(templateId);
        if (!(e.status == MarketTypes.EpochStatus.Open || e.status == MarketTypes.EpochStatus.Locked)) {
            revert InvalidEpochState();
        }

        IYieldRouterV2 r = yieldRouter;
        if (address(r) != address(0) && e.routedPrincipal > 0) {
            uint256 routedPrincipal = e.routedPrincipal;
            _tryWithdrawRoutedForCancel(r, templateId, epochId, routedPrincipal, ledger);
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
        e.winningPoolTotal = 0;
        e.cancelReason = reason;
        e.refundMode = true;
        e.claimable = true;
        e.status = voided ? MarketTypes.EpochStatus.Voided : MarketTypes.EpochStatus.Cancelled;
        e.resolvedAt = uint64(block.timestamp);
        ledger.lastResolvedEpochId = epochId;
        _tryRouteSettledClaimsAfterSettlement(templateId, epochId, ledger, e);
        emit EpochCancelled(templateId, epochId, uint8(reason));
    }

    function _openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) internal {
        if (_templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
        if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();
        uint64 nowTs = uint64(block.timestamp);
        if (lockAt <= nowTs) revert InvalidTiming();
        if (lockAt - openAt < MIN_MANUAL_DEPOSIT_WINDOW) revert InvalidTiming();
        if (resolveAt - lockAt < MIN_MANUAL_LOCK_WINDOW) revert InvalidTiming();
        if (resolveAt - openAt > MAX_MANUAL_EPOCH_DURATION) revert InvalidTiming();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.version == 0) revert InvalidTemplate();
        if (!t.active) revert TemplateInactive();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        _requireCanOpenNextEpoch(ledger, epochId);
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (e.exists) revert EpochAlreadyExists();

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
        _snapshotEpochTemplateMarketConfig(e, t);
        _snapshotEpochOracleAdapter(templateId, epochId, t.templateOracleKind, t.oracleClass);
        _epochYieldFeeBps[templateId][epochId] = yieldFeeBps;
        ledger.activeEpochId = epochId;
        emit EpochOpened(templateId, epochId, openAt, lockAt, resolveAt);
    }

    function _lockEpoch(bytes32 templateId, uint64 epochId) internal {
        if (!configInitialized) revert NotInitialized();
        if (_templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        uint64 nowTs = uint64(block.timestamp);
        if (!e.isLockable(nowTs)) revert TooEarlyToLock();
        if (MarketTypes.requiresCheckpointAOnLock(e)) {
            if (e.templateOracleKind == MarketTypes.OracleKind.TrustedReporter) revert InvalidTemplate();
            uint64 maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(e, oracleConfig.maxDelaySeconds);
            uint16 maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(e, oracleConfig.maxConfidenceBps);
            IPriceOracle epochOracle = _resolveEpochOracle(templateId, epochId, e.oracleClass);
            _applyLockWithOracleReads(templateId, epochId, e, epochOracle, maxDelay, maxConf, nowTs);
        } else {
            _applyLock(templateId, epochId, 0, 0, 0, 0, 0, 0, nowTs);
        }
    }

    function _applyLockWithOracleReads(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.Epoch storage e,
        IPriceOracle epochOracle,
        uint64 maxDelay,
        uint16 maxConf,
        uint64 nowTs
    ) internal {
        (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId) =
            _readOracleOrRevert(templateId, epochOracle, e.oracleFeedId, maxDelay, nowTs);
        _applyLock(templateId, epochId, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelay, maxConf, nowTs);
        if (e.marketType == MarketTypes.MarketType.Convergence) {
            (int256 price2, uint64 publish2, uint256 conf2,) =
                _readOracleOrRevert(templateId, epochOracle, e.oracleFeedIdB, maxDelay, nowTs);
            _enforceConfidence(price2, conf2, maxConf);
            e.checkpointA_B = MarketTypes.OracleCheckpoint({
                valueE8: price2, publishTime: publish2, confidenceE8: _toConf128(conf2), written: true
            });
        } else if (e.marketType == MarketTypes.MarketType.Composite) {
            for (uint256 i = 0; i < e.compositeFeedCount; i++) {
                (int256 pI, uint64 tI, uint256 cI,) =
                    _readOracleOrRevert(templateId, epochOracle, e.compositeFeedIds[i], maxDelay, nowTs);
                _enforceConfidence(pI, cI, maxConf);
                e.compositeCheckpointsA[i] = MarketTypes.OracleCheckpoint({
                    valueE8: pI, publishTime: tI, confidenceE8: _toConf128(cI), written: true
                });
            }
        }
    }

    function _resolveEpoch(bytes32 templateId, uint64 epochId) internal {
        if (!configInitialized) revert NotInitialized();
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
        ResolveData memory rd = ResolveData({priceE8: 0, publishTime: 0, confidenceE8: 0, oracleRoundId: 0});
        if (e.templateOracleKind == MarketTypes.OracleKind.TrustedReporter) {
            {
                (rd.priceE8, rd.publishTime, rd.confidenceE8, rd.oracleRoundId) =
                    _readEventOracleForResolve(templateId, epochId, e);
                rd.publishTime = _applyTrustedReporterOhlcIfNeeded(templateId, epochId, e, rd.publishTime);
            }
        } else {
            {
                IPriceOracle epochOracle = _resolveEpochOracle(templateId, epochId, e.oracleClass);
                (rd.priceE8, rd.publishTime, rd.confidenceE8, rd.oracleRoundId) =
                    _readOracleOrRevert(templateId, epochOracle, e.oracleFeedId, maxDelay, nowTs);
                if (e.marketType == MarketTypes.MarketType.Convergence) {
                    _resolveConvergenceCheckpointB(templateId, epochOracle, e, maxDelay, maxConf, nowTs);
                } else if (e.marketType == MarketTypes.MarketType.Composite) {
                    _resolveCompositeCheckpointB(templateId, epochOracle, e, maxDelay, maxConf, nowTs);
                }
            }
        }
        _enforceConfidence(rd.priceE8, rd.confidenceE8, maxConf);
        _finishResolveEpochManual(
            templateId, epochId, rd.priceE8, rd.publishTime, rd.confidenceE8, rd.oracleRoundId, maxDelay, nowTs
        );
    }

    function _applyTrustedReporterOhlcIfNeeded(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.Epoch storage e,
        uint64 publishTime
    ) internal returns (uint64) {
        if (e.marketType != MarketTypes.MarketType.Corridor && e.marketType != MarketTypes.MarketType.Cascade) {
            return publishTime;
        }

        (int256 highE8, int256 lowE8,, uint64 observedAt, bool written) =
            IEventOracle(e.eventOracle).getOhlcResult(positionKey(templateId, epochId));
        if (!written) revert InvalidOracleFeed();

        e.epochHighE8 = highE8;
        e.epochLowE8 = lowE8;
        e.ohlcWritten = true;
        return observedAt;
    }

    function _resolveConvergenceCheckpointB(
        bytes32 templateId,
        IPriceOracle epochOracle,
        MarketTypes.Epoch storage e,
        uint64 maxDelay,
        uint16 maxConf,
        uint64 nowTs
    ) internal {
        (int256 p2, uint64 t2, uint256 c2,) =
            _readOracleOrRevert(templateId, epochOracle, e.oracleFeedIdB, maxDelay, nowTs);
        _enforceConfidence(p2, c2, maxConf);
        e.checkpointB_B =
            MarketTypes.OracleCheckpoint({valueE8: p2, publishTime: t2, confidenceE8: _toConf128(c2), written: true});
    }

    function _resolveCompositeCheckpointB(
        bytes32 templateId,
        IPriceOracle epochOracle,
        MarketTypes.Epoch storage e,
        uint64 maxDelay,
        uint16 maxConf,
        uint64 nowTs
    ) internal {
        for (uint256 i = 0; i < e.compositeFeedCount; i++) {
            (int256 pI, uint64 tI, uint256 cI,) =
                _readOracleOrRevert(templateId, epochOracle, e.compositeFeedIds[i], maxDelay, nowTs);
            _enforceConfidence(pI, cI, maxConf);
            e.compositeCheckpointsB[i] =
                MarketTypes.OracleCheckpoint({valueE8: pI, publishTime: tI, confidenceE8: _toConf128(cI), written: true});
        }
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

        uint256 grossYield = _withdrawRoutedPrincipalOnResolve(templateId, epochId);
        (uint256 yieldFee, uint256 netYield) = _applyGrossYield(templateId, epochId, ledger, grossYield);

        SettlementLogic.Outputs memory outputs = SettlementLogic.compute(e, netYield);
        _applyResolveAccounting(templateId, epochId, ledger, e, outputs, nowTs);
        _emitResolveEvents(templateId, epochId, outputs, oracleRoundId);
        _finalizeYieldAccounting(templateId, epochId, ledger, grossYield, yieldFee, netYield, outputs.refundMode);
        _tryRouteSettledClaimsAfterSettlement(templateId, epochId, ledger, e);
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
            if (!e.validateCheckpointAPublishTime(publishTime, nowTs, maxDelaySeconds)) {
                revert InvalidOraclePublishTime();
            }
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

    /// @dev Isolated for stack depth; uses `stakeToken` balance delta (not router return) for yield on cancel.
    function _tryWithdrawRoutedForCancel(
        IYieldRouterV2 r,
        bytes32 templateId,
        uint64 epochId,
        uint256 routedPrincipal,
        MarketTypes.Ledger storage ledger
    ) private {
        MarketTypes.Epoch storage ep = _epochs[templateId][epochId];
        uint256 received = _balanceDeltaAfterWithdrawScaled(r, templateId, routedPrincipal);
        ep.routedPrincipal = 0;
        totalRoutedPrincipal -= routedPrincipal;
        _templateRoutedPrincipal[templateId] -= routedPrincipal;
        if (received > routedPrincipal) {
            uint256 gy = received - routedPrincipal;
            _vaults[templateId].fees += gy;
            ledger.feeReserveTotal += gy;
        }
    }

    function _withdrawRoutedPrincipalOnResolve(bytes32 templateId, uint64 epochId)
        internal
        returns (uint256 grossYield)
    {
        IYieldRouterV2 r = yieldRouter;
        if (address(r) == address(0)) return 0;

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        uint256 routedPrincipal = e.routedPrincipal;
        if (routedPrincipal < 1) return 0;
        if (yieldRouterDisabled) revert YieldRouterDisabledState();
        _requireNoUnreconciledRecovery(templateId);

        uint256 received = _balanceDeltaAfterWithdrawScaled(r, templateId, routedPrincipal);
        e.routedPrincipal = 0;
        totalRoutedPrincipal -= routedPrincipal;
        _templateRoutedPrincipal[templateId] -= routedPrincipal;
        if (received > routedPrincipal) return received - routedPrincipal;
        return 0;
    }

    function _recordYieldRouterFailure() internal {
        if (yieldRouterFailureCount < MAX_YIELD_ROUTER_FAILURES) {
            yieldRouterFailureCount += 1;
        }
        if (!yieldRouterDisabled && yieldRouterFailureCount >= MAX_YIELD_ROUTER_FAILURES) {
            yieldRouterDisabled = true;
            emit YieldRouterDisabled();
        }
        emit YieldRouterFailureRecorded(yieldRouterFailureCount, yieldRouterDisabled);
    }

    function _applyGrossYield(bytes32 templateId, uint64 epochId, MarketTypes.Ledger storage ledger, uint256 grossYield)
        internal
        returns (uint256 yieldFee, uint256 netYield)
    {
        if (grossYield < 1) return (0, 0);

        _vaults[templateId].active += grossYield;
        ledger.increaseActiveCollateral(grossYield);

        uint256 bps = uint256(_epochYieldFeeBps[templateId][epochId]);
        uint256 q = grossYield / 10_000;
        uint256 r = grossYield % 10_000;
        yieldFee = (q * bps) + ((r * bps) / 10_000);
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
        if (grossYield < 1) return;

        if (refundMode) {
            _vaults[templateId].active -= netYield;
            _vaults[templateId].fees += netYield;
            MarketMath.reserveFeesFromActive(ledger, netYield);
            netYield = 0;
        }
        emit EpochYieldAccrued(templateId, epochId, grossYield, yieldFee, netYield);
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
        if (priceE8 == type(int256).min) revert InvalidOraclePrice();
        uint256 limit = MarketTypes.confidenceLimitE8(priceE8, maxConfidenceBps, MarketTypes.MIN_ABSOLUTE_CONFIDENCE_E8);
        return confidenceE8 <= limit;
    }

    function _validateOracleParams(UpsertTemplateParams calldata p) internal pure {
        if (p.templateOracleKind == MarketTypes.OracleKind.Chainlink) {
            if (p.oracleFeedId == bytes32(0)) revert InvalidOracleFeed();
            if (p.eventOracle != address(0)) revert InvalidOracleFeed();
        } else if (p.templateOracleKind == MarketTypes.OracleKind.TrustedReporter) {
            if (p.eventOracle == address(0)) revert InvalidOracleFeed();
            if (p.oracleFeedId != bytes32(0)) revert InvalidOracleFeed();
            if (
                p.marketType == MarketTypes.MarketType.Direction || p.marketType == MarketTypes.MarketType.Velocity
                    || p.marketType == MarketTypes.MarketType.Convergence
                    || p.marketType == MarketTypes.MarketType.Composite
            ) revert InvalidTemplate();
            if (p.executionMode == MarketTypes.ExecutionMode.Rolling) revert RollingInvalidParams();
        } else {
            revert InvalidOracleFeed();
        }
    }

    function _readEventOracleForResolve(bytes32 templateId, uint64 epochId, MarketTypes.Epoch storage e)
        internal
        view
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId)
    {
        if (e.eventOracle == address(0)) revert InvalidOracleFeed();
        bytes32 marketId = positionKey(templateId, epochId);
        IEventOracle o = IEventOracle(e.eventOracle);
        (int256 result, bool resolved) = o.getResult(marketId);
        if (!resolved) revert InvalidOracleFeed();
        priceE8 = result;
        publishTime = o.getResolveObservedAt(marketId);
        confidenceE8 = 0;
        oracleRoundId = 0;
    }

    function _readOracleOrRevert(
        bytes32 templateId,
        IPriceOracle oracleBase,
        bytes32 feedId,
        uint64 maxDelay,
        uint64 nowTs
    )
        internal
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId)
    {
        IPriceOracleWithRoundId oracle = IPriceOracleWithRoundId(address(oracleBase));
        try oracle
            .getNormalizedPriceWithRoundId(feedId, maxDelay, nowTs) returns (
            uint80 rid, int256 p, uint64 pt, uint256 c
        ) {
            _enforceAndUpdateOracleCursor(templateId, feedId, rid, pt, true);
            return (p, pt, c, rid);
        } catch {
            (priceE8, publishTime, confidenceE8) = oracleBase.getNormalizedPrice(feedId, maxDelay, nowTs);
            _enforceAndUpdateOracleCursor(templateId, feedId, 0, publishTime, false);
            return (priceE8, publishTime, confidenceE8, 0);
        }
    }

    function _enforceAndUpdateOracleCursor(
        bytes32 templateId,
        bytes32 feedId,
        uint80 oracleRoundId,
        uint64 publishTime,
        bool supportsRoundId
    ) internal {
        OracleCursor storage c = lastOracleCursorByTemplateFeed[templateId][feedId];
        bool priorUsesRoundId = oracleCursorUsesRoundId[templateId][feedId];

        // Prevent cursor mode downgrades/upgrades after initialization; switching source semantics can bypass monotonicity.
        if (c.publishTime != 0 && priorUsesRoundId != supportsRoundId) {
            revert InvalidOracleFeed();
        }
        if (supportsRoundId && oracleRoundId == 0) {
            revert InvalidOracleFeed();
        }
        if (supportsRoundId && oracleRoundId < c.roundId) {
            revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
        }
        if (publishTime < c.publishTime) {
            revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
        }
        c.roundId = supportsRoundId ? oracleRoundId : 0;
        c.publishTime = publishTime;
        oracleCursorUsesRoundId[templateId][feedId] = supportsRoundId;
        if (supportsRoundId && oracleRoundId > lastOracleRoundIdByTemplate[templateId]) {
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
        } else if (t.marketType == MarketTypes.MarketType.Convergence || t.marketType == MarketTypes.MarketType.Composite) {
            if (t.outcomeCount != 2) revert InvalidTemplate();
            if (t.thresholdRule != MarketTypes.ThresholdRule.Absolute) revert InvalidTemplate();
            if (t.marketType == MarketTypes.MarketType.Convergence && t.oracleFeedIdB == bytes32(0)) revert InvalidTemplate();
            if (
                t.marketType == MarketTypes.MarketType.Composite
                    && (t.compositeFeedCount < 2 || t.compositeFeedCount > 4 || t.compositeFeedIds[0] == bytes32(0))
            ) revert InvalidTemplate();
        } else if (t.marketType == MarketTypes.MarketType.Cascade) {
            if (t.outcomeCount < 2) revert InvalidTemplate();
            uint256 maxLevels = uint256(t.outcomeCount) - 1;
            for (uint256 i = 1; i < maxLevels; i++) {
                if (t.cascadeDownward) {
                    if (!(t.rangeBoundsE8[i] < t.rangeBoundsE8[i - 1])) revert InvalidTemplate();
                } else {
                    if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
                }
            }
        } else if (t.marketType == MarketTypes.MarketType.Corridor) {
            // `Resolvers.resolveCorridor` uses outcomes 0=in-band, 1=upper breach, 2=lower breach.
            if (t.outcomeCount != 3) revert InvalidTemplate();
            if (!(t.rangeBoundsE8[0] < t.rangeBoundsE8[1])) revert InvalidTemplate();
            for (uint256 i = 2; i < uint256(t.outcomeCount) - 1; i++) {
                if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
            }
        } else {
            if (t.outcomeCount < 2) revert InvalidTemplate();
            for (uint256 i = 1; i < uint256(t.outcomeCount) - 1; i++) {
                if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
            }
        }
        if (
            t.executionMode == MarketTypes.ExecutionMode.Rolling
                && (
                    t.marketType == MarketTypes.MarketType.Convergence || t.marketType == MarketTypes.MarketType.Composite
                        || t.marketType == MarketTypes.MarketType.Corridor || t.marketType == MarketTypes.MarketType.Cascade
                )
        ) revert RollingInvalidParams();
        if (t.oracleMaxConfidenceBps > 0 && t.oracleMaxConfidenceBps > 10_000) revert InvalidFeeBps();
    }
}
