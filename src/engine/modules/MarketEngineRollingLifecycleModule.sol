// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineState} from "../MarketEngineState.sol";
import {MarketTypes} from "../../types/MarketTypes.sol";
import {MarketMath} from "../../math/MarketMath.sol";
import {SettlementLogic} from "../../logic/SettlementLogic.sol";
import {IPriceOracle} from "../../interfaces/IPriceOracle.sol";
import {IPriceOracleWithRoundId} from "../../interfaces/IPriceOracleWithRoundId.sol";
import {IYieldRouterV2} from "../../interfaces/IYieldRouterV2.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/// @notice Rolling lifecycle module extracted from monolithic MarketEngine.
/// @dev Preserves halt-first liveness semantics from legacy engine.
contract MarketEngineRollingLifecycleModule is MarketEngineState, ReentrancyGuardTransient {
    using MarketTypes for MarketTypes.Epoch;
    using MarketMath for MarketTypes.Ledger;

    struct OracleSample {
        int256 priceE8;
        uint64 publishTime;
        uint256 confidenceE8;
        uint80 oracleRoundId;
    }

    function genesisStartRolling(bytes32 templateId) external {
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.version == 0) revert InvalidTemplate();
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.Uninitialized) revert RollingGenesisAlreadyStarted();

        uint64 ts = uint64(block.timestamp);
        uint64 opened = _openRollingEpoch(templateId, ts, t);
        ledger.rollingPhase = MarketTypes.RollingPhase.GenesisOpen;
        emit RollingGenesisStarted(
            templateId, opened, uint64(ts + t.rollingIntervalSeconds), uint64(ts + 2 * t.rollingIntervalSeconds)
        );
    }

    function genesisLockRolling(bytes32 templateId) external nonReentrant {
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.GenesisOpen) revert RollingWrongPhase();

        uint64 k = ledger.activeEpochId;
        _requireActiveEpoch(ledger, k);
        MarketTypes.Epoch storage e1 = _epochs[templateId][k];
        uint64 nowTs = uint64(block.timestamp);
        if (nowTs < e1.timing.lockAt) revert TooEarlyToLock();
        if (nowTs > e1.timing.lockAt + t.rollingBufferSeconds) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnLock, k);
            return;
        }

        if (MarketTypes.requiresCheckpointAOnLock(e1)) {
            bool lockApplied = _applyGenesisLockWithOracle(templateId, k, e1, e1.oracleFeedId, nowTs);
            if (!lockApplied) {
                return;
            }
        } else {
            _applyLock(templateId, k, 0, 0, 0, 0, 0, 0, nowTs);
        }

        uint64 newOpen = _openRollingEpoch(templateId, nowTs, t);
        ledger.rollingPhase = MarketTypes.RollingPhase.Live;
        emit RollingGenesisLocked(templateId, k, newOpen);
    }

    function executeRollingRound(bytes32 templateId) external nonReentrant {
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        _executeRollingRoundCore(templateId);
    }

    function executeRollingRoundBatch(bytes32[] calldata templateIds) external nonReentrant {
        _authAdminOrWorker();
        if (globalPaused) revert ProtocolPaused();
        uint256 n = templateIds.length;
        _validateBatchSize(n);
        for (uint256 i = 0; i < n; i++) {
            _executeRollingRoundCore(templateIds[i]);
        }
    }

    function haltRollingMarket(bytes32 templateId) external {
        _authAdmin();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (
            ledger.rollingPhase != MarketTypes.RollingPhase.GenesisOpen
                && ledger.rollingPhase != MarketTypes.RollingPhase.Live
        ) revert RollingWrongPhase();
        _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.ManualAdmin, ledger.activeEpochId);
    }

    function resetRollingLifecycle(bytes32 templateId, uint64 nextRollingEpochId) external {
        _authAdmin();
        if (!globalPaused) revert ProtocolPaused();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.Halted) revert RollingWrongPhase();
        uint64 hi = ledger.lastResolvedEpochId;
        if (ledger.activeEpochId > hi) hi = ledger.activeEpochId;
        if (!_isRollingEpochCleared(templateId, ledger.activeEpochId)) revert InvalidRollingRecovery();
        if (ledger.activeEpochId > 1 && !_isRollingEpochCleared(templateId, ledger.activeEpochId - 1)) {
            revert InvalidRollingRecovery();
        }
        if (nextRollingEpochId == 0 || nextRollingEpochId <= hi) revert InvalidRollingRecovery();

        ledger.rollingPhase = MarketTypes.RollingPhase.Uninitialized;
        ledger.rollingHaltReason = MarketTypes.RollingHaltReason.NoneReason;
        ledger.haltedAtEpochId = 0;
        ledger.rollingNextEpochId = nextRollingEpochId;
        ledger.activeEpochId = 0;
        emit RollingLifecycleReset(templateId, nextRollingEpochId);
    }

    function cancelRollingEpochWhileHalted(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.CancelReason reason,
        bool voided
    ) external nonReentrant {
        _authAdmin();
        if (!globalPaused) revert ProtocolPaused();
        if (reason == MarketTypes.CancelReason.NoneReason) revert InvalidEpochState();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.Halted) revert RollingWrongPhase();

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!e.exists) revert InvalidEpochState();
        if (e.routedPrincipal > 0) _requireNoUnreconciledRecovery(templateId);
        if (!(e.status == MarketTypes.EpochStatus.Open || e.status == MarketTypes.EpochStatus.Locked)) {
            revert InvalidEpochState();
        }

        // Attempt yield router withdrawal before setting refund mode so tokens are in engine for claims.
        _tryWithdrawForRollingCancel(templateId, e, ledger);

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
        if (epochId > ledger.lastResolvedEpochId) {
            ledger.lastResolvedEpochId = epochId;
        }
        _tryRouteSettledClaimsAfterSettlement(templateId, epochId, ledger, e);
        emit EpochCancelled(templateId, epochId, uint8(reason));
    }

    // slither-disable-next-line reentrancy-no-eth -- only from `executeRollingRound*` (`nonReentrant`); resolve→lock→open ordering is intentional.
    function _executeRollingRoundCore(bytes32 templateId) internal {
        if (!configInitialized) revert Unauthorized();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.Live) revert RollingWrongPhase();
        _requireNoUnreconciledRecovery(templateId);

        uint64 k = ledger.activeEpochId;
        if (k < 2) revert InvalidEpochState();
        uint64 prev = k - 1;
        MarketTypes.Epoch storage ePrev = _epochs[templateId][prev];
        MarketTypes.Epoch storage eCur = _epochs[templateId][k];
        uint64 nowTs = uint64(block.timestamp);

        if (nowTs < ePrev.timing.resolveAt) revert TooEarlyToResolve();
        if (nowTs > ePrev.timing.resolveAt + t.rollingBufferSeconds) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnResolve, prev);
            return;
        }
        if (nowTs < eCur.timing.lockAt) revert TooEarlyToLock();
        if (nowTs > eCur.timing.lockAt + t.rollingBufferSeconds) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnLock, k);
            return;
        }

        uint64 maxDelay;
        uint16 maxConf;
        if (MarketTypes.requiresCheckpointAOnLock(eCur)) {
            uint64 dPrev = MarketTypes.effectiveOracleMaxDelaySeconds(ePrev, oracleConfig.maxDelaySeconds);
            uint64 dCur = MarketTypes.effectiveOracleMaxDelaySeconds(eCur, oracleConfig.maxDelaySeconds);
            maxDelay = dPrev < dCur ? dPrev : dCur;
            uint16 cPrev = MarketTypes.effectiveOracleMaxConfidenceBps(ePrev, oracleConfig.maxConfidenceBps);
            uint16 cCur = MarketTypes.effectiveOracleMaxConfidenceBps(eCur, oracleConfig.maxConfidenceBps);
            maxConf = cPrev < cCur ? cPrev : cCur;
        } else {
            maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(ePrev, oracleConfig.maxDelaySeconds);
            maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(ePrev, oracleConfig.maxConfidenceBps);
        }

        if (!_resolveAndLockRound(templateId, prev, k, maxDelay, maxConf, nowTs)) {
            return;
        }
        uint64 newOpen = _openRollingEpoch(templateId, nowTs, t);
        emit RollingRoundExecuted(templateId, prev, k, newOpen);
    }

    function _openRollingEpoch(bytes32 templateId, uint64 startTs, MarketTypes.Template storage t)
        internal
        returns (uint64 openedEpochId)
    {
        if (t.version == 0) revert InvalidTemplate();
        if (!t.active) revert TemplateInactive();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        uint64 epochId = ledger.rollingNextEpochId;
        if (epochId == 0) revert InvalidEpochState();

        uint64 inter = t.rollingIntervalSeconds;
        if (inter < MIN_ROLLING_INTERVAL_SECONDS || inter > MAX_ROLLING_INTERVAL_SECONDS) revert RollingInvalidParams();
        uint64 openAt = startTs;
        uint64 lockAt = startTs + inter;
        uint64 resolveAt = startTs + 2 * inter;
        if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();

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
        _snapshotEpochTemplateMarketConfig(e, t);
        _snapshotEpochOracleAdapter(templateId, epochId, t.templateOracleKind, t.oracleClass);
        _epochYieldFeeBps[templateId][epochId] = yieldFeeBps;

        ledger.activeEpochId = epochId;
        ledger.rollingNextEpochId = epochId + 1;
        openedEpochId = epochId;
        emit EpochOpened(templateId, epochId, openAt, lockAt, resolveAt);
    }

    function _applyGenesisLockWithOracle(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.Epoch storage e,
        bytes32 oracleFeedId,
        uint64 nowTs
    ) internal returns (bool) {
        uint64 maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(e, oracleConfig.maxDelaySeconds);
        uint16 maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(e, oracleConfig.maxConfidenceBps);
        IPriceOracle epochOracle = _resolveEpochOracle(templateId, epochId, e.oracleClass);
        (bool ok, OracleSample memory sample) =
            _tryReadOracleSample(templateId, epochOracle, oracleFeedId, maxDelay, nowTs);
        if (!ok) {
            _haltRollingOracleFailure(templateId, epochId);
            return false;
        }
        if (!_confidenceWithinBand(sample.priceE8, sample.confidenceE8, maxConf)) {
            _haltRollingOracleConfidenceWide(templateId, epochId);
            return false;
        }
        if (!e.isLockable(nowTs)) revert TooEarlyToLock();
        if (e.checkpointA.written) revert CheckpointAlreadyWritten();
        if (!e.validateCheckpointAPublishTime(sample.publishTime, nowTs, maxDelay)) revert InvalidOraclePublishTime();
        e.checkpointA = MarketTypes.OracleCheckpoint({
            valueE8: sample.priceE8,
            publishTime: sample.publishTime,
            confidenceE8: _toConf128(sample.confidenceE8),
            written: true
        });
        e.status = MarketTypes.EpochStatus.Locked;
        e.lockedAt = nowTs;
        emit EpochLocked(templateId, epochId, e.checkpointA.valueE8, e.checkpointA.publishTime);
        emit EpochLockedV2(
            templateId, epochId, e.checkpointA.valueE8, e.checkpointA.publishTime, sample.oracleRoundId
        );
        return true;
    }

    function _finishResolveEpochRolling(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
        uint80 oracleRoundId,
        uint64 maxDelaySeconds
    ) internal {
        uint64 nowTs = uint64(block.timestamp);
        _finishResolveEpoch(
            templateId, epochId, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelaySeconds, true, nowTs
        );
    }

    // slither-disable-next-line reentrancy-no-eth -- reachable only from `performUpkeep` (`nonReentrant`); yield router is trusted.
    function _resolveAndLockRound(
        bytes32 templateId,
        uint64 prevEpochId,
        uint64 lockEpochId,
        uint64 maxDelay,
        uint16 maxConf,
        uint64 nowTs
    ) internal returns (bool) {
        MarketTypes.Epoch storage ePrev = _epochs[templateId][prevEpochId];
        MarketTypes.Epoch storage eCur = _epochs[templateId][lockEpochId];
        bool needsCheckpointA = MarketTypes.requiresCheckpointAOnLock(eCur);
        IPriceOracle prevOracle = _resolveEpochOracle(templateId, prevEpochId, ePrev.oracleClass);

        (bool ok, OracleSample memory sample) =
            _tryReadOracleSample(templateId, prevOracle, ePrev.oracleFeedId, maxDelay, nowTs);
        if (!ok) {
            _haltRollingOracleFailure(templateId, lockEpochId);
            return false;
        }
        if (needsCheckpointA && (eCur.oracleClass != ePrev.oracleClass || eCur.oracleFeedId != ePrev.oracleFeedId)) {
            _haltRollingOracleFailure(templateId, lockEpochId);
            return false;
        }
        if (needsCheckpointA && address(_resolveEpochOracle(templateId, lockEpochId, eCur.oracleClass)) != address(prevOracle)) {
            _haltRollingOracleFailure(templateId, lockEpochId);
            return false;
        }
        if (!_confidenceWithinBand(sample.priceE8, sample.confidenceE8, maxConf)) {
            _haltRollingOracleConfidenceWide(templateId, lockEpochId);
            return false;
        }
        _resolvePreviousEpochFromSample(templateId, prevEpochId, maxDelay, nowTs, sample);
        _applyLockFromSample(templateId, lockEpochId, maxDelay, maxConf, nowTs, needsCheckpointA, sample);
        return true;
    }

    function _resolvePreviousEpochFromSample(
        bytes32 templateId,
        uint64 prevEpochId,
        uint64 maxDelay,
        uint64 nowTs,
        OracleSample memory sample
    ) internal {
        _finishResolveEpoch(
            templateId,
            prevEpochId,
            sample.priceE8,
            sample.publishTime,
            sample.confidenceE8,
            sample.oracleRoundId,
            maxDelay,
            true,
            nowTs
        );
    }

    function _applyLockFromSample(
        bytes32 templateId,
        uint64 lockEpochId,
        uint64 maxDelay,
        uint16 maxConf,
        uint64 nowTs,
        bool needsCheckpointA,
        OracleSample memory sample
    ) internal {
        if (needsCheckpointA) {
            _applyLock(
                templateId,
                lockEpochId,
                sample.priceE8,
                sample.publishTime,
                sample.confidenceE8,
                sample.oracleRoundId,
                maxDelay,
                maxConf,
                nowTs
            );
            return;
        }
        _applyLock(templateId, lockEpochId, 0, 0, 0, 0, 0, 0, nowTs);
    }

    function _haltRollingOracleFailure(bytes32 templateId, uint64 epochId) internal {
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        ledger.rollingPhase = MarketTypes.RollingPhase.Halted;
        ledger.rollingHaltReason = MarketTypes.RollingHaltReason.OracleFailure;
        ledger.haltedAtEpochId = epochId;
        emit RollingHalted(templateId, uint8(MarketTypes.RollingHaltReason.OracleFailure), epochId);
    }

    function _haltRollingOracleConfidenceWide(bytes32 templateId, uint64 epochId) internal {
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        ledger.rollingPhase = MarketTypes.RollingPhase.Halted;
        ledger.rollingHaltReason = MarketTypes.RollingHaltReason.OracleConfidenceWide;
        ledger.haltedAtEpochId = epochId;
        emit RollingHalted(templateId, uint8(MarketTypes.RollingHaltReason.OracleConfidenceWide), epochId);
    }

    // slither-disable-next-line reentrancy-no-eth -- caller holds `nonReentrant` (rolling worker path); trusted `yieldRouter`.
    function _finishResolveEpoch(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
        uint80 oracleRoundId,
        uint64 maxDelaySeconds,
        bool rollingLink,
        uint64 nowTs
    ) internal {
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (rollingLink) {
            if (epochId + 1 != ledger.activeEpochId) revert InvalidEpochState();
        } else {
            if (epochId != ledger.activeEpochId) revert EpochNotActive();
        }

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!e.isResolvable(nowTs)) revert TooEarlyToResolve();
        if (e.checkpointB.written) revert CheckpointAlreadyWritten();
        if (!e.validateCheckpointBPublishTime(publishTime, nowTs, maxDelaySeconds)) revert InvalidOraclePublishTime();
        e.checkpointB = MarketTypes.OracleCheckpoint({
            valueE8: priceE8, publishTime: publishTime, confidenceE8: _toConf128(confidenceE8), written: true
        });

        uint256 grossYield = _withdrawResolvePrincipal(templateId, epochId, rollingLink);
        if (rollingLink && !_isRollingResolveActive(templateId)) return;
        (uint256 yieldFee, uint256 netYield) = _applyGrossYield(templateId, epochId, ledger, grossYield);

        SettlementLogic.Outputs memory outputs = SettlementLogic.compute(e, netYield);
        _applyResolveAccounting(templateId, epochId, ledger, e, outputs, nowTs);
        _emitResolveEvents(templateId, epochId, outputs, oracleRoundId);
        _finalizeYieldAccounting(templateId, epochId, ledger, grossYield, yieldFee, netYield, outputs.refundMode);
        _tryRouteSettledClaimsAfterSettlement(templateId, epochId, ledger, e);
    }

    function _withdrawResolvePrincipal(bytes32 templateId, uint64 epochId, bool rollingLink)
        internal
        returns (uint256 grossYield)
    {
        IYieldRouterV2 r = yieldRouter;
        if (address(r) == address(0)) return 0;

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        uint256 routedPrincipal = e.routedPrincipal;
        if (routedPrincipal < 1) return 0;
        if (yieldRouterDisabled) {
            emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
            if (rollingLink) {
                _haltRolling(
                    templateId, _ledgers[templateId], MarketTypes.RollingHaltReason.OracleFailure, _ledgers[templateId].activeEpochId
                );
                return 0;
            }
            revert YieldRouterDisabledState();
        }

        uint256 b0 = stakeToken.balanceOf(address(this));
        try r.withdrawScaled(templateId, routedPrincipal) returns (uint256) {
            uint256 b1 = stakeToken.balanceOf(address(this));
            if (b1 < b0) revert YieldRouterBalanceInvariant();
            uint256 received = b1 - b0;
            if (received < routedPrincipal) {
                emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal - received);
                _recordYieldRouterFailure();
                if (rollingLink) {
                    _haltRolling(templateId, _ledgers[templateId], MarketTypes.RollingHaltReason.OracleFailure, epochId + 1);
                    return 0;
                }
                revert YieldRouterShortfall(routedPrincipal, received);
            }
            e.routedPrincipal = 0;
            totalRoutedPrincipal -= routedPrincipal;
            _templateRoutedPrincipal[templateId] -= routedPrincipal;
            if (received > routedPrincipal) return received - routedPrincipal;
            return 0;
        } catch {
            emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
            _recordYieldRouterFailure();
            if (rollingLink) {
                _haltRolling(
                    templateId,
                    _ledgers[templateId],
                    MarketTypes.RollingHaltReason.OracleFailure,
                    _ledgers[templateId].activeEpochId
                );
                return 0;
            }
            return 0;
        }
    }

    // slither-disable-next-line reentrancy-no-eth -- nonReentrant guard on caller; admin-gated; router trusted by admin config.
    function _tryWithdrawForRollingCancel(
        bytes32 templateId,
        MarketTypes.Epoch storage e,
        MarketTypes.Ledger storage ledger
    ) private {
        IYieldRouterV2 r = yieldRouter;
        if (address(r) == address(0) || e.routedPrincipal == 0) return;
        if (yieldRouterDisabled) revert YieldRouterDisabledState();
        uint256 rp = e.routedPrincipal;
        uint256 gained = _balanceDeltaAfterWithdrawScaled(r, templateId, rp);
        e.routedPrincipal = 0;
        totalRoutedPrincipal -= rp;
        _templateRoutedPrincipal[templateId] -= rp;
        if (gained > rp) {
            uint256 excess = gained - rp;
            _vaults[templateId].fees += excess;
            ledger.feeReserveTotal += excess;
        }
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

    function _isRollingResolveActive(bytes32 templateId) internal view returns (bool) {
        return _ledgers[templateId].rollingPhase == MarketTypes.RollingPhase.Live;
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

    function _haltRolling(
        bytes32 templateId,
        MarketTypes.Ledger storage ledger,
        MarketTypes.RollingHaltReason reason,
        uint64 atEpoch
    ) internal {
        ledger.rollingPhase = MarketTypes.RollingPhase.Halted;
        ledger.rollingHaltReason = reason;
        ledger.haltedAtEpochId = atEpoch;
        emit RollingHalted(templateId, uint8(reason), atEpoch);
    }

    function _isRollingEpochCleared(bytes32 templateId, uint64 epochId) internal view returns (bool) {
        if (epochId == 0) return true;
        MarketTypes.EpochStatus status = _epochs[templateId][epochId].status;
        return status != MarketTypes.EpochStatus.Open && status != MarketTypes.EpochStatus.Locked;
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

    function _tryReadOracle(
        bytes32 templateId,
        IPriceOracle oracleBase,
        bytes32 feedId,
        uint64 maxDelay,
        uint64 nowTs
    )
        internal
        returns (bool ok, int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId)
    {
        IPriceOracleWithRoundId oracle = IPriceOracleWithRoundId(address(oracleBase));
        try oracle
            .getNormalizedPriceWithRoundId(feedId, maxDelay, nowTs) returns (
            uint80 rid, int256 p, uint64 pt, uint256 c
        ) {
            _enforceAndUpdateOracleCursor(templateId, feedId, rid, pt, true);
            return (true, p, pt, c, rid);
        } catch {
            try oracleBase.getNormalizedPrice(feedId, maxDelay, nowTs) returns (
                int256 p2,
                uint64 pt2,
                uint256 c2
            ) {
                _enforceAndUpdateOracleCursor(templateId, feedId, 0, pt2, false);
                return (true, p2, pt2, c2, 0);
            } catch {
                return (false, 0, 0, 0, 0);
            }
        }
    }

    function _tryReadOracleSample(
        bytes32 templateId,
        IPriceOracle oracleBase,
        bytes32 feedId,
        uint64 maxDelay,
        uint64 nowTs
    ) internal returns (bool ok, OracleSample memory sample) {
        (ok, sample.priceE8, sample.publishTime, sample.confidenceE8, sample.oracleRoundId) =
            _tryReadOracle(templateId, oracleBase, feedId, maxDelay, nowTs);
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
}
