// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineState} from "../MarketEngineState.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {MarketTypes} from "../../types/MarketTypes.sol";
import {MarketMath} from "../../math/MarketMath.sol";
import {IYieldRouterV2} from "../../interfaces/IYieldRouterV2.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice User operations and claims module extracted from monolithic MarketEngine.
/// @dev Runs via delegatecall from `MarketEngineDispatcher`. External entrypoints use `nonReentrant` so yield-router
/// callbacks cannot nest user ops (defense in depth alongside trusted `yieldRouter` admin gating).
contract MarketEngineUserOpsClaimsModule is MarketEngineState, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;
    using MarketMath for MarketTypes.Ledger;
    using MarketTypes for MarketTypes.Epoch;

    function depositToSide(bytes32 templateId, uint64 epochId, uint8 outcomeIndex, uint256 amount)
        external
        nonReentrant
    {
        if (globalPaused) revert ProtocolPaused();
        _depositToSide(msg.sender, msg.sender, templateId, epochId, outcomeIndex, amount);
    }

    function depositToSideFor(
        address beneficiary,
        bytes32 templateId,
        uint64 epochId,
        uint8 outcomeIndex,
        uint256 amount
    ) external nonReentrant {
        if (globalPaused) revert ProtocolPaused();
        if (!isDepositExecutor[msg.sender]) revert NotDepositExecutor();
        if (beneficiary == address(0)) revert Unauthorized();
        _depositToSide(msg.sender, beneficiary, templateId, epochId, outcomeIndex, amount);
    }

    function switchSide(bytes32 templateId, uint64 epochId, uint8 fromOutcome, uint8 toOutcome, uint256 grossAmount)
        external
        nonReentrant
    {
        if (globalPaused) revert ProtocolPaused();
        if (!configInitialized) revert Unauthorized();
        _requireNoUnreconciledRecovery(templateId);
        if (grossAmount == 0) revert ZeroStake();
        if (fromOutcome == toOutcome) revert InvalidOutcome();
        if (fromOutcome >= MarketTypes.MAX_OUTCOMES || toOutcome >= MarketTypes.MAX_OUTCOMES) revert InvalidOutcome();

        MarketTypes.Template storage t = _templates[templateId];
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (
            t.executionMode == MarketTypes.ExecutionMode.Rolling
                && ledger.rollingPhase == MarketTypes.RollingPhase.Halted
        ) {
            revert RollingHaltedUserOps();
        }
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!(uint256(fromOutcome) < uint256(e.outcomeCount) && uint256(toOutcome) < uint256(e.outcomeCount))) {
            revert InvalidOutcome();
        }
        uint64 nowTs = uint64(block.timestamp);
        if (!e.isEpochOpen(nowTs)) revert BettingClosed();

        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = _positions[pk][msg.sender];
        if (pos.stakes[fromOutcome] < grossAmount) revert InsufficientSourceStake();

        (uint256 netAmount, uint256 feeAmount) = MarketMath.computeSwitch(grossAmount, e.switchFeeBps);
        if (netAmount == 0) revert AmountTooSmall();

        if (!e.allowMultiSidePositions) {
            if (!_isSingleSidedOn(pos, fromOutcome, e.outcomeCount)) revert SingleSideViolation();
            if (grossAmount != pos.stakes[fromOutcome]) revert PartialSwitchDisallowed();
        }

        pos.stakes[fromOutcome] -= grossAmount;
        pos.stakes[toOutcome] += netAmount;
        if (pos.stakes[fromOutcome] == 0) {
            pos.occupiedMask &= ~uint8(1 << fromOutcome);
        }
        pos.occupiedMask |= uint8(1 << toOutcome);
        pos.totalStake -= feeAmount;
        pos.switchFeesPaid += feeAmount;

        e.outcomePools[fromOutcome] -= grossAmount;
        e.outcomePools[toOutcome] += netAmount;
        e.totalPool -= feeAmount;
        e.switchFeeTotal += feeAmount;

        if (feeAmount > 0) {
            MarketTypes.VaultBalances storage vault = _vaults[templateId];
            vault.active -= feeAmount;
            vault.fees += feeAmount;
            MarketMath.reserveFeesFromActive(ledger, feeAmount);
            _withdrawSwitchFeePrincipal(templateId, epochId, feeAmount, vault, ledger);
        }
        emit SideSwitched(templateId, epochId, msg.sender, fromOutcome, toOutcome, grossAmount, feeAmount, netAmount);
    }

    function claim(bytes32 templateId, uint64 epochId) external nonReentrant {
        uint256 amount = _claimOne(templateId, epochId, msg.sender);
        stakeToken.safeTransfer(msg.sender, amount);
        emit Claimed(templateId, epochId, msg.sender, amount);
    }

    function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
        _validateBatchSize(epochIds.length);
        if (!configInitialized) revert Unauthorized();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        uint256 total = 0;
        for (uint256 i = 0; i < epochIds.length; i++) {
            uint256 amt = _claimOneIfClaimable(templateId, epochIds[i], msg.sender, ledger);
            if (amt == 0) continue;
            total += amt;
            emit Claimed(templateId, epochIds[i], msg.sender, amt);
        }
        if (total == 0) revert NothingToClaim();
        stakeToken.safeTransfer(msg.sender, total);
    }

    function _depositToSide(
        address payer,
        address beneficiary,
        bytes32 templateId,
        uint64 epochId,
        uint8 outcomeIndex,
        uint256 amount
    ) internal {
        if (!configInitialized) revert Unauthorized();
        _requireNoUnreconciledRecovery(templateId);
        if (amount == 0) revert ZeroStake();
        if (outcomeIndex >= MarketTypes.MAX_OUTCOMES) revert InvalidOutcome();
        MarketTypes.Template storage t = _templates[templateId];
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (
            t.executionMode == MarketTypes.ExecutionMode.Rolling
                && ledger.rollingPhase == MarketTypes.RollingPhase.Halted
        ) {
            revert RollingHaltedUserOps();
        }
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!(uint256(outcomeIndex) < uint256(e.outcomeCount))) revert InvalidOutcome();
        uint64 nowTs = uint64(block.timestamp);
        if (!e.isEpochOpen(nowTs)) revert BettingClosed();

        uint256 balanceBefore = stakeToken.balanceOf(address(this));
        stakeToken.safeTransferFrom(payer, address(this), amount);
        uint256 balanceAfter = stakeToken.balanceOf(address(this));
        if (balanceAfter < balanceBefore) revert YieldRouterBalanceInvariant();
        if (balanceAfter - balanceBefore != amount) revert NonStandardStakeToken();

        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = _positions[pk][beneficiary];
        if (!pos.initialized) {
            pos.version = MarketTypes.VERSION;
            pos.initialized = true;
            e.totalPositions += 1;
            _userEpochs[templateId][beneficiary].push(epochId);
            emit UserEpochIndexed(templateId, epochId, beneficiary);
        }

        if (!_canDepositToOutcome(pos, outcomeIndex, e.outcomeCount, e.allowMultiSidePositions)) {
            revert SingleSideViolation();
        }

        pos.stakes[outcomeIndex] += amount;
        pos.occupiedMask |= uint8(1 << outcomeIndex);
        pos.totalStake += amount;
        e.outcomePools[outcomeIndex] += amount;
        e.totalPool += amount;
        ledger.increaseActiveCollateral(amount);
        _vaults[templateId].active += amount;

        IYieldRouterV2 r = yieldRouter;
        if (address(r) != address(0)) {
            uint256 routeAmount = (amount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
            if (routeAmount > 0) {
                if (yieldRouterDisabled) {
                    emit YieldRouterDepositFailed(templateId, routeAmount);
                } else {
                    try r.depositScaled(templateId, routeAmount) returns (uint256 attributionUnits) {
                        if (attributionUnits > 0) {
                            _recordRoutedPrincipal(templateId, e, routeAmount);
                        } else {
                            emit YieldRouterDepositFailed(templateId, routeAmount);
                        }
                    }
                    catch {
                        emit YieldRouterDepositFailed(templateId, routeAmount);
                    }
                }
            }
        }
        emit PositionDeposited(templateId, epochId, beneficiary, outcomeIndex, amount);
    }

    function _claimOne(bytes32 templateId, uint64 epochId, address user) internal returns (uint256 amount) {
        if (!configInitialized) revert Unauthorized();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!e.claimable) revert ClaimNotAvailable();

        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = _positions[pk][user];
        if (pos.claimed) revert AlreadyClaimed();

        SettledClaimRouting storage bucket = _settledClaimRouting[templateId][epochId];
        if (bucket.enabled) {
            amount = _claimOneRoutedSettled(templateId, epochId, user, e, pos, bucket);
            if (amount == 0) revert NothingToClaim();
            return amount;
        }

        uint256 winningStake;
        if (e.refundMode) {
            amount = MarketMath.computeRefundTotal(pos.totalStake);
            winningStake = 0;
        } else if (_isSingleOutcomePosition(pos)) {
            uint8 outcomeIndex = _singleOutcomeIndex(pos.occupiedMask);
            uint256 remainingClaims = e.claimLiabilityTotal - e.claimedTotal;
            (amount, winningStake) =
                MarketMath.computeSingleOutcomeClaimPayoutStorage(e, outcomeIndex, pos.totalStake, remainingClaims);
        } else {
            uint256[8] memory stakes = pos.stakes;
            uint256 remainingClaims = e.claimLiabilityTotal - e.claimedTotal;
            (amount, winningStake) = MarketMath.computeClaimPayoutStorage(e, stakes, remainingClaims);
        }

        if (amount == 0) revert NothingToClaim();
        pos.claimedAmount = amount;
        pos.claimed = true;
        e.claimedTotal += amount;
        if (!e.refundMode) e.remainingWinningStake -= winningStake;

        MarketMath.releaseClaimOnWithdraw(ledger, amount);
        _vaults[templateId].claims -= amount;
    }

    function _claimOneIfClaimable(bytes32 templateId, uint64 epochId, address user, MarketTypes.Ledger storage ledger)
        internal
        returns (uint256 amount)
    {
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (!e.claimable) return 0;

        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = _positions[pk][user];
        if (pos.claimed) return 0;

        SettledClaimRouting storage bucket = _settledClaimRouting[templateId][epochId];
        if (bucket.enabled) {
            return _claimOneRoutedSettled(templateId, epochId, user, e, pos, bucket);
        }

        uint256 winningStake;
        if (e.refundMode) {
            amount = MarketMath.computeRefundTotal(pos.totalStake);
            winningStake = 0;
        } else if (_isSingleOutcomePosition(pos)) {
            uint8 outcomeIndex = _singleOutcomeIndex(pos.occupiedMask);
            uint256 remainingClaims = e.claimLiabilityTotal - e.claimedTotal;
            (amount, winningStake) =
                MarketMath.computeSingleOutcomeClaimPayoutStorage(e, outcomeIndex, pos.totalStake, remainingClaims);
        } else {
            uint256[8] memory stakes = pos.stakes;
            uint256 remainingClaims = e.claimLiabilityTotal - e.claimedTotal;
            (amount, winningStake) = MarketMath.computeClaimPayoutStorage(e, stakes, remainingClaims);
        }

        if (amount == 0) return 0;
        pos.claimedAmount = amount;
        pos.claimed = true;
        e.claimedTotal += amount;
        if (!e.refundMode) e.remainingWinningStake -= winningStake;

        MarketMath.releaseClaimOnWithdraw(ledger, amount);
        _vaults[templateId].claims -= amount;
    }

    function _claimOneRoutedSettled(
        bytes32 templateId,
        uint64 epochId,
        address user,
        MarketTypes.Epoch storage e,
        MarketTypes.Position storage pos,
        SettledClaimRouting storage bucket
    ) internal returns (uint256 amount) {
        if (globalPaused) revert ProtocolPaused();
        _requireNoUnreconciledRecovery(templateId);

        (uint256 baseEntitlement, uint256 winningStake) = _computeRoutedSettledBaseEntitlement(e, pos, bucket);
        if (baseEntitlement == 0 || bucket.baseOutstanding == 0 || bucket.attributionOutstanding == 0) return 0;

        IYieldRouterV2 r = yieldRouter;
        uint256 attributionToWithdraw = bucket.baseOutstanding == baseEntitlement
            ? bucket.attributionOutstanding
            : Math.mulDiv(bucket.attributionOutstanding, baseEntitlement, bucket.baseOutstanding, Math.Rounding.Floor);
        if (attributionToWithdraw == 0) return 0;

        uint256 principalConsumed;
        uint256 attributionBurned;
        (amount, principalConsumed, attributionBurned) = r.withdrawAttribution(templateId, attributionToWithdraw);
        if (amount == 0 || attributionBurned == 0) return 0;
        _finalizeRoutedSettledClaim(
            templateId,
            epochId,
            user,
            e,
            pos,
            bucket,
            baseEntitlement,
            winningStake,
            amount,
            principalConsumed,
            attributionBurned
        );
    }

    function _computeRoutedSettledBaseEntitlement(
        MarketTypes.Epoch storage e,
        MarketTypes.Position storage pos,
        SettledClaimRouting storage bucket
    ) internal view returns (uint256 baseEntitlement, uint256 winningStake) {
        if (bucket.refundMode) {
            return (MarketMath.computeRefundTotal(pos.totalStake), 0);
        }
        if (_isSingleOutcomePosition(pos)) {
            return MarketMath.computeTotalUserEntitlementResolvedSingleSidedStorage(
                e, _singleOutcomeIndex(pos.occupiedMask), pos.totalStake
            );
        }
        uint256[8] memory stakes = pos.stakes;
        return MarketMath.computeTotalUserEntitlementResolvedStorage(e, stakes);
    }

    function _finalizeRoutedSettledClaim(
        bytes32 templateId,
        uint64 epochId,
        address user,
        MarketTypes.Epoch storage e,
        MarketTypes.Position storage pos,
        SettledClaimRouting storage bucket,
        uint256 baseEntitlement,
        uint256 winningStake,
        uint256 amount,
        uint256 principalConsumed,
        uint256 attributionBurned
    ) internal {
        pos.claimedAmount = amount;
        pos.claimed = true;
        e.claimedTotal += baseEntitlement;
        if (!bucket.refundMode) e.remainingWinningStake -= winningStake;

        bucket.baseOutstanding -= baseEntitlement;
        if (principalConsumed > bucket.principalOutstanding) {
            bucket.principalOutstanding = 0;
        } else {
            bucket.principalOutstanding -= principalConsumed;
        }
        if (attributionBurned > bucket.attributionOutstanding) {
            bucket.attributionOutstanding = 0;
        } else {
            bucket.attributionOutstanding -= attributionBurned;
        }
        totalRoutedPrincipal -= principalConsumed;
        _templateSettledClaimsRoutedPrincipal[templateId] -= principalConsumed;
        if (bucket.baseOutstanding == 0 || bucket.attributionOutstanding == 0) {
            bucket.enabled = false;
            bucket.principalOutstanding = 0;
            bucket.attributionOutstanding = 0;
            bucket.baseOutstanding = 0;
            emit EpochSettledClaimsRoutingDisabled(templateId, epochId);
        }
        emit EpochSettledClaimPaid(
            templateId, epochId, user, baseEntitlement, amount, principalConsumed, attributionBurned
        );
    }

    function _requireActiveEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (epochId != ledger.activeEpochId) revert EpochNotActive();
    }

    function _canDepositToOutcome(
        MarketTypes.Position storage pos,
        uint8 outcomeIndex,
        uint8,
        bool allowMultiSide
    ) internal view returns (bool) {
        if (allowMultiSide) return true;
        if (pos.totalStake == 0) return true;
        return (pos.occupiedMask & ~uint8(1 << outcomeIndex)) == 0;
    }

    function _isSingleSidedOn(MarketTypes.Position storage pos, uint8 outcomeIndex, uint8)
        internal
        view
        returns (bool)
    {
        uint8 mask = pos.occupiedMask;
        if ((mask & uint8(1 << outcomeIndex)) == 0) return false;
        return (mask & ~uint8(1 << outcomeIndex)) == 0;
    }

    function _isSingleOutcomePosition(MarketTypes.Position storage pos) internal view returns (bool) {
        uint8 mask = pos.occupiedMask;
        return mask != 0 && (mask & (mask - 1)) == 0;
    }

    function _singleOutcomeIndex(uint8 mask) internal pure returns (uint8 idx) {
        while ((mask & 1) == 0) {
            unchecked {
                ++idx;
            }
            mask >>= 1;
        }
    }

    function _withdrawSwitchFeePrincipal(
        bytes32 templateId,
        uint64 epochId,
        uint256 feeAmount,
        MarketTypes.VaultBalances storage vault,
        MarketTypes.Ledger storage ledger
    ) internal {
        IYieldRouterV2 r = yieldRouter;
        if (address(r) == address(0)) return;

        uint256 principalToWithdraw = (feeAmount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
        if (principalToWithdraw == 0) return;
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (principalToWithdraw > e.routedPrincipal) principalToWithdraw = e.routedPrincipal;
        if (principalToWithdraw == 0) return;

        uint256 grossReturned = _balanceDeltaAfterWithdrawScaled(r, templateId, principalToWithdraw);
        e.routedPrincipal -= principalToWithdraw;
        totalRoutedPrincipal -= principalToWithdraw;
        _templateRoutedPrincipal[templateId] -= principalToWithdraw;
        if (grossReturned > principalToWithdraw) {
            uint256 grossYield = grossReturned - principalToWithdraw;
            vault.fees += grossYield;
            ledger.feeReserveTotal += grossYield;
        }
    }

    function _recordRoutedPrincipal(bytes32 templateId, MarketTypes.Epoch storage e, uint256 routeAmount) internal {
        e.routedPrincipal += routeAmount;
        totalRoutedPrincipal += routeAmount;
        _templateRoutedPrincipal[templateId] += routeAmount;
    }
}
