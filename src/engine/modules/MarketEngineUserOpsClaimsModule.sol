// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineState} from "../MarketEngineState.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {MarketTypes} from "../../types/MarketTypes.sol";
import {MarketMath} from "../../math/MarketMath.sol";
import {IYieldRouterV2} from "../../interfaces/IYieldRouterV2.sol";

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

        uint256 balBefore = stakeToken.balanceOf(address(this));
        stakeToken.safeTransferFrom(payer, address(this), amount);
        uint256 received = stakeToken.balanceOf(address(this)) - balBefore;
        if (received != amount) revert NonStandardStakeToken();

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
        pos.totalStake += amount;
        e.outcomePools[outcomeIndex] += amount;
        e.totalPool += amount;
        ledger.increaseActiveCollateral(amount);
        _vaults[templateId].active += amount;

        IYieldRouterV2 r = yieldRouter;
        if (address(r) != address(0)) {
            uint256 routeAmount = (amount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
            if (routeAmount > 0) {
                stakeToken.forceApprove(address(r), routeAmount);
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
                stakeToken.forceApprove(address(r), 0);
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

        uint256 winningStake;
        if (e.refundMode) {
            amount = MarketMath.computeRefundTotal(pos.totalStake);
            winningStake = 0;
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

        uint256 winningStake;
        if (e.refundMode) {
            amount = MarketMath.computeRefundTotal(pos.totalStake);
            winningStake = 0;
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

    function _requireActiveEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (epochId != ledger.activeEpochId) revert EpochNotActive();
    }

    function _canDepositToOutcome(
        MarketTypes.Position storage pos,
        uint8 outcomeIndex,
        uint8 outcomeCount,
        bool allowMultiSide
    ) internal view returns (bool) {
        if (allowMultiSide) return true;
        if (pos.totalStake == 0) return true;
        for (uint256 i = 0; i < outcomeCount; i++) {
            if (i != outcomeIndex && pos.stakes[i] != 0) return false;
        }
        return true;
    }

    function _isSingleSidedOn(MarketTypes.Position storage pos, uint8 outcomeIndex, uint8 outcomeCount)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < outcomeCount; i++) {
            if (i != outcomeIndex && pos.stakes[i] != 0) return false;
        }
        return true;
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
