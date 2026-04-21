// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {MarketEngineState} from "../MarketEngineState.sol";
import {IMarketEngine} from "../IMarketEngine.sol";
import {MarketTypes} from "../../types/MarketTypes.sol";
import {MarketMath} from "../../math/MarketMath.sol";
import {IYieldRouterV2} from "../../interfaces/IYieldRouterV2.sol";

/// @notice Read-only module for dispatcher-routed views.
contract MarketEngineViewModule is MarketEngineState {
    using MarketTypes for MarketTypes.Epoch;

    uint256 internal constant PROBABILITY_SCALE_E6 = 1_000_000;
    uint256 internal constant DISPLAY_PERCENT_SCALE_E4 = 10_000;
    uint256 internal constant PAYOUT_MULTIPLIER_SCALE_E6 = 1_000_000;

    function getMarketView(bytes32 templateId) external view returns (IMarketEngine.MarketView memory view_) {
        MarketTypes.Template storage t = _requireTemplate(templateId);
        MarketTypes.Ledger storage ledger = _ledgers[templateId];

        view_.templateId = templateId;
        view_.slug = t.slug;
        view_.assetSymbol = t.assetSymbol;
        view_.marketType = t.marketType;
        view_.executionMode = t.executionMode;
        view_.templateOracleKind = t.templateOracleKind;
        view_.oracleClass = t.oracleClass;
        view_.eventOracle = t.eventOracle;
        view_.outcomeCount = t.outcomeCount;
        view_.active = t.active;
        view_.activeEpochId = ledger.activeEpochId;
        view_.globalPaused = globalPaused;
        view_.userOpsBlocked = _userOpsBlocked(ledger, t.executionMode);
        view_.rollingPhase = ledger.rollingPhase;
        view_.rollingHaltReason = ledger.rollingHaltReason;
        view_.switchFeeBps = t.switchFeeBps;
        view_.settlementFeeBps = t.settlementFeeBps;
        view_.yieldRouterAssigned = address(yieldRouter) != address(0);
    }

    function getEpochView(bytes32 templateId, uint64 epochId) external view returns (IMarketEngine.EpochView memory view_) {
        MarketTypes.Epoch storage e = _requireEpoch(templateId, epochId);
        view_ = _buildEpochView(templateId, e);
    }

    function getActiveEpochView(bytes32 templateId) external view returns (IMarketEngine.EpochView memory view_) {
        MarketTypes.Template storage t = _requireTemplate(templateId);
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized || ledger.activeEpochId == 0) revert InvalidEpochState();
        MarketTypes.Epoch storage e = _epochs[templateId][ledger.activeEpochId];
        if (!e.exists) revert InvalidEpochState();
        t;
        view_ = _buildEpochView(templateId, e);
    }

    function getOutcomeViews(bytes32 templateId, uint64 epochId)
        external
        view
        returns (IMarketEngine.OutcomeView[] memory views)
    {
        MarketTypes.Epoch storage e = _requireEpoch(templateId, epochId);
        uint8 outcomeCount = e.outcomeCount;
        views = new IMarketEngine.OutcomeView[](outcomeCount);

        bool isActiveQuote = _isActiveQuote(e);
        uint256 totalPool_ = e.totalPool;
        for (uint8 i = 0; i < outcomeCount; i++) {
            uint256 poolSize = e.outcomePools[i];
            uint256 impliedProbabilityE6;
            uint256 displayPercentE4;
            uint256 grossPayoutXE6;
            if (totalPool_ != 0 && poolSize != 0) {
                impliedProbabilityE6 = (poolSize * PROBABILITY_SCALE_E6) / totalPool_;
                displayPercentE4 = (poolSize * DISPLAY_PERCENT_SCALE_E4) / totalPool_;
                if (isActiveQuote) {
                    grossPayoutXE6 = (totalPool_ * PAYOUT_MULTIPLIER_SCALE_E6) / poolSize;
                }
            }

            views[i] = IMarketEngine.OutcomeView({
                outcomeIndex: i,
                poolSize: poolSize,
                impliedProbabilityE6: impliedProbabilityE6,
                displayPercentE4: displayPercentE4,
                isWinner: ((e.winningOutcomeMask >> i) & 1) == 1,
                isActiveQuote: isActiveQuote,
                grossPayoutXE6: grossPayoutXE6
            });
        }
    }

    function getPositionView(bytes32 templateId, uint64 epochId, address user)
        external
        view
        returns (IMarketEngine.PositionView memory view_)
    {
        MarketTypes.Epoch storage e = _requireEpoch(templateId, epochId);
        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = _positions[pk][user];

        view_.initialized = pos.initialized;
        view_.claimed = pos.claimed;
        view_.stakes = pos.stakes;
        view_.totalStake = pos.totalStake;
        view_.entryFeesPaid = pos.entryFeesPaid;
        view_.switchFeesPaid = pos.switchFeesPaid;
        view_.claimedAmount = pos.claimedAmount;

        if (e.claimable && !pos.claimed) {
            SettledClaimRouting storage bucket = _settledClaimRouting[templateId][epochId];
            view_.settledClaimRoutingEnabled = bucket.enabled;
            if (bucket.enabled) {
                if (bucket.baseOutstanding != 0 && bucket.attributionOutstanding != 0) {
                    uint256 currentBucketValue =
                        yieldRouter.previewValueByAttribution(templateId, bucket.attributionOutstanding);
                    if (bucket.refundMode) {
                        view_.pendingRefundAmount =
                            (pos.totalStake * currentBucketValue) / bucket.baseOutstanding;
                    } else {
                        (uint256 baseEntitlement, uint256 winningStake) =
                            MarketMath.computeTotalUserEntitlementResolvedStorage(e, pos.stakes);
                        view_.winningStake = winningStake;
                        if (baseEntitlement != 0) {
                            if (bucket.baseOutstanding == baseEntitlement) {
                                view_.pendingClaimAmount = currentBucketValue;
                            } else {
                                view_.pendingClaimAmount =
                                    (baseEntitlement * currentBucketValue) / bucket.baseOutstanding;
                            }
                        }
                    }
                }
            } else if (e.refundMode) {
                view_.pendingRefundAmount = MarketMath.computeRefundTotal(pos.totalStake);
            } else {
                uint256 remainingClaims = e.claimLiabilityTotal - e.claimedTotal;
                (view_.pendingClaimAmount, view_.winningStake) =
                    MarketMath.computeClaimPayoutStorage(e, pos.stakes, remainingClaims);
            }
        }

        view_.claimableNow = e.claimable && !pos.claimed && (view_.pendingClaimAmount != 0 || view_.pendingRefundAmount != 0);
        if (view_.settledClaimRoutingEnabled && (globalPaused || _unreconciledRecoveredByTemplate[templateId] != 0)) {
            view_.claimableNow = false;
        }
        view_.status = _positionStatus(e, pos, view_.claimableNow);
    }

    function getTemplateYieldView(bytes32 templateId)
        external
        view
        returns (IMarketEngine.TemplateYieldView memory view_)
    {
        _requireTemplate(templateId);

        IYieldRouterV2 r = yieldRouter;
        view_.routerAssigned = address(r) != address(0);
        view_.routerDisabled = yieldRouterDisabled;
        view_.recoveryPending = _unreconciledRecoveredByTemplate[templateId] != 0;
        view_.yieldFeeBpsCurrent = yieldFeeBps;

        if (!view_.routerAssigned) return view_;

        view_.yieldPath = r.getTemplateYieldPath(templateId);
        view_.currentPrincipal = r.principalOf(templateId);
        view_.currentValue = r.currentValueOf(templateId);
        view_.scaledPrincipal = r.scaledPrincipalOf(templateId);
        view_.stataShares = r.stataSharesOf(templateId);
        if (view_.currentValue > view_.currentPrincipal) {
            view_.unrealizedYieldAmount = view_.currentValue - view_.currentPrincipal;
        }
        if (view_.currentPrincipal != 0) {
            view_.yieldRatioE6 = (view_.unrealizedYieldAmount * PROBABILITY_SCALE_E6) / view_.currentPrincipal;
        }
    }

    function getOperatorTemplateView(bytes32 templateId)
        external
        view
        returns (IMarketEngine.OperatorTemplateView memory view_)
    {
        MarketTypes.Template storage t = _requireTemplate(templateId);
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        MarketTypes.VaultBalances storage vault = _vaults[templateId];

        view_.activeEpochId = ledger.activeEpochId;
        view_.lastResolvedEpochId = ledger.lastResolvedEpochId;
        view_.haltedAtEpochId = ledger.haltedAtEpochId;
        view_.rollingNextEpochId = ledger.rollingNextEpochId;
        view_.rollingPhase = ledger.rollingPhase;
        view_.rollingHaltReason = ledger.rollingHaltReason;
        view_.activeVault = vault.active;
        view_.claimsVault = vault.claims;
        view_.feesVault = vault.fees;
        view_.templateRoutedPrincipal = _templateRoutedPrincipal[templateId];
        view_.templateSettledClaimsRoutedPrincipal = _templateSettledClaimsRoutedPrincipal[templateId];
        view_.unreconciledRecoveredAmount = _unreconciledRecoveredByTemplate[templateId];
        view_.userOpsBlocked = _userOpsBlocked(ledger, t.executionMode);
        view_.unsafeToUnpauseForTemplate =
            view_.unreconciledRecoveredAmount != 0
                || (yieldRouterDisabled
                    && (view_.templateRoutedPrincipal != 0 || view_.templateSettledClaimsRoutedPrincipal != 0));
    }

    function getOperatorGlobalView() external view returns (IMarketEngine.OperatorGlobalView memory view_) {
        view_.globalPaused = globalPaused;
        view_.yieldRouter = address(yieldRouter);
        view_.yieldRouterDisabled = yieldRouterDisabled;
        view_.yieldRouterFailureCount = yieldRouterFailureCount;
        view_.totalRoutedPrincipal = totalRoutedPrincipal;
        view_.totalUnreconciledRecovered = totalUnreconciledRecovered;
        view_.admin = admin;
        view_.treasury = treasury;
        view_.workerAuthority = workerAuthority;
        view_.priceOracle = address(priceOracle);
        view_.rateOracle = address(rateOracle);
        view_.smartDataOracle = address(smartDataOracle);
        view_.macroOracle = address(macroOracle);
        view_.equityOracle = address(equityOracle);
    }

    function getUserEpochs(bytes32 templateId, address user, uint256 cursor, uint256 size)
        external
        view
        returns (uint64[] memory epochIds, uint256 nextCursor)
    {
        uint64[] storage src = _userEpochs[templateId][user];
        uint256 n = src.length;
        if (cursor >= n) return (new uint64[](0), cursor);
        uint256 boundedSize = size;
        if (boundedSize > MAX_USER_EPOCHS_PAGE_SIZE) boundedSize = MAX_USER_EPOCHS_PAGE_SIZE;
        uint256 end = cursor + boundedSize;
        if (end > n) end = n;
        uint256 outLen = end - cursor;
        epochIds = new uint64[](outLen);
        for (uint256 i = 0; i < outLen; i++) {
            epochIds[i] = src[cursor + i];
        }
        nextCursor = end;
    }

    function getVaultBalances(bytes32 templateId) external view returns (uint256 active, uint256 claims, uint256 fees) {
        MarketTypes.VaultBalances storage v = _vaults[templateId];
        return (v.active, v.claims, v.fees);
    }

    function getRollingLifecycle(bytes32 templateId)
        external
        view
        returns (
            MarketTypes.RollingPhase phase,
            MarketTypes.RollingHaltReason haltReason,
            uint64 haltedAtEpochId,
            uint64 rollingNextEpochId,
            uint64 activeEpochId,
            uint64 lastResolvedEpochId
        )
    {
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        return (
            ledger.rollingPhase,
            ledger.rollingHaltReason,
            ledger.haltedAtEpochId,
            ledger.rollingNextEpochId,
            ledger.activeEpochId,
            ledger.lastResolvedEpochId
        );
    }

    function getEpoch(bytes32 templateId, uint64 epochId) external view returns (MarketTypes.Epoch memory) {
        return _epochs[templateId][epochId];
    }

    function unreconciledRecoveredByTemplate(bytes32 templateId) external view returns (uint256) {
        return _unreconciledRecoveredByTemplate[templateId];
    }

    function _requireTemplate(bytes32 templateId) internal view returns (MarketTypes.Template storage t) {
        t = _templates[templateId];
        if (t.version == 0 || !_ledgers[templateId].initialized) revert InvalidTemplate();
    }

    function _requireEpoch(bytes32 templateId, uint64 epochId) internal view returns (MarketTypes.Epoch storage e) {
        _requireTemplate(templateId);
        e = _epochs[templateId][epochId];
        if (!e.exists) revert InvalidEpochState();
    }

    function _buildEpochView(bytes32 templateId, MarketTypes.Epoch storage e)
        internal
        view
        returns (IMarketEngine.EpochView memory view_)
    {
        view_.templateId = templateId;
        view_.epochId = e.epochId;
        view_.status = e.status;
        view_.cancelReason = e.cancelReason;
        view_.openAt = e.timing.openAt;
        view_.lockAt = e.timing.lockAt;
        view_.resolveAt = e.timing.resolveAt;
        view_.createdAt = e.createdAt;
        view_.lockedAt = e.lockedAt;
        view_.resolvedAt = e.resolvedAt;
        view_.totalPool = e.totalPool;
        view_.totalPositions = e.totalPositions;
        view_.claimable = e.claimable;
        view_.refundMode = e.refundMode;
        view_.winningOutcomeMask = e.winningOutcomeMask;
        view_.claimLiabilityTotal = e.claimLiabilityTotal;
        view_.totalRefundLiability = e.totalRefundLiability;
        view_.settlementFeeTotal = e.settlementFeeTotal;
        view_.claimedTotal = e.claimedTotal;
        view_.remainingWinningStake = e.remainingWinningStake;
        view_.routedPrincipal = e.routedPrincipal;
        SettledClaimRouting storage bucket = _settledClaimRouting[templateId][e.epochId];
        view_.settledClaimRoutingEnabled = bucket.enabled;
        view_.settledClaimBaseOutstanding = bucket.baseOutstanding;
        view_.settledClaimPrincipalOutstanding = bucket.principalOutstanding;
        if (bucket.enabled && bucket.attributionOutstanding != 0 && address(yieldRouter) != address(0)) {
            view_.settledClaimCurrentValue = yieldRouter.previewValueByAttribution(templateId, bucket.attributionOutstanding);
        }
        view_.oracleMaxDelaySeconds = e.effectiveOracleMaxDelaySeconds(oracleConfig.maxDelaySeconds);
        view_.oracleMaxConfidenceBps = e.effectiveOracleMaxConfidenceBps(oracleConfig.maxConfidenceBps);
        view_.checkpointA = e.checkpointA;
        view_.checkpointB = e.checkpointB;
        view_.hasSecondaryCheckpoints = e.checkpointA_B.written || e.checkpointB_B.written;
        view_.hasCompositeCheckpoints = e.compositeFeedCount != 0;
    }

    function _userOpsBlocked(MarketTypes.Ledger storage ledger, MarketTypes.ExecutionMode mode)
        internal
        view
        returns (bool)
    {
        if (globalPaused) return true;
        return mode == MarketTypes.ExecutionMode.Rolling && ledger.rollingPhase == MarketTypes.RollingPhase.Halted;
    }

    function _isActiveQuote(MarketTypes.Epoch storage e) internal view returns (bool) {
        return e.status == MarketTypes.EpochStatus.Open || e.status == MarketTypes.EpochStatus.Locked;
    }

    function _positionStatus(MarketTypes.Epoch storage e, MarketTypes.Position storage pos, bool claimableNow)
        internal
        view
        returns (IMarketEngine.PositionViewStatus)
    {
        if (pos.claimed) return IMarketEngine.PositionViewStatus.Claimed;
        if (claimableNow) return IMarketEngine.PositionViewStatus.Claimable;
        if (pos.totalStake == 0) return IMarketEngine.PositionViewStatus.NoPosition;
        if (e.claimable) return IMarketEngine.PositionViewStatus.SettledNoPayout;
        return IMarketEngine.PositionViewStatus.Active;
    }
}
