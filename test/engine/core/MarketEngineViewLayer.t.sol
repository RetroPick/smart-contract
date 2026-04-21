// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {IYieldRouterV2} from "../../../src/interfaces/IYieldRouterV2.sol";
import {MockPartialYieldRouter} from "../../helpers/MockPartialYieldRouter.sol";
import {MockViewYieldRouter} from "../../helpers/MockViewYieldRouter.sol";

contract MarketEngineViewLayerTest is MarketEngineBase {
    function test_market_epoch_outcome_and_position_views_follow_current_accounting() public {
        bytes32 tid = _tid("view-dir");

        vm.startPrank(admin);
        engine.upsertTemplate(_directionManualTemplate("view-dir"));
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 1_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        address user = address(0xCAFE);
        address other = address(0xBEEF);
        token.mint(user, 1_000 ether);
        token.mint(other, 1_000 ether);

        vm.startPrank(user);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 600 ether);
        vm.stopPrank();

        vm.startPrank(other);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 1, 400 ether);
        vm.stopPrank();

        MarketEngine.MarketView memory marketView = engine.getMarketView(tid);
        assertEq(marketView.templateId, tid);
        assertEq(marketView.activeEpochId, 1);
        assertEq(uint8(marketView.marketType), uint8(MarketTypes.MarketType.Direction));
        assertEq(uint8(marketView.executionMode), uint8(MarketTypes.ExecutionMode.Manual));
        assertFalse(marketView.globalPaused);
        assertFalse(marketView.userOpsBlocked);
        assertFalse(marketView.yieldRouterAssigned);

        MarketEngine.EpochView memory activeEpochView = engine.getActiveEpochView(tid);
        assertEq(activeEpochView.epochId, 1);
        assertEq(uint8(activeEpochView.status), uint8(MarketTypes.EpochStatus.Open));
        assertEq(activeEpochView.totalPool, 1_000 ether);
        assertEq(activeEpochView.totalPositions, 2);
        assertFalse(activeEpochView.claimable);

        MarketEngine.OutcomeView[] memory liveOutcomeViews = engine.getOutcomeViews(tid, 1);
        assertEq(liveOutcomeViews.length, 2);
        assertEq(liveOutcomeViews[0].poolSize, 600 ether);
        assertEq(liveOutcomeViews[0].impliedProbabilityE6, 600_000);
        assertEq(liveOutcomeViews[0].displayPercentE4, 6_000);
        assertTrue(liveOutcomeViews[0].isActiveQuote);
        assertEq(liveOutcomeViews[0].grossPayoutXE6, 1_666_666);
        assertEq(liveOutcomeViews[1].grossPayoutXE6, 2_500_000);

        MarketEngine.PositionView memory livePositionView = engine.getPositionView(tid, 1, user);
        assertEq(uint8(livePositionView.status), uint8(MarketEngine.PositionViewStatus.Active));
        assertEq(livePositionView.totalStake, 600 ether);
        assertEq(livePositionView.stakes[0], 600 ether);
        assertFalse(livePositionView.claimableNow);
        assertEq(livePositionView.pendingClaimAmount, 0);

        vm.warp(t0 + 200);
        oracle.set(feed, 100e8, uint64(t0 + 200), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 110e8, uint64(t0 + 300), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        MarketEngine.EpochView memory resolvedEpochView = engine.getEpochView(tid, 1);
        assertEq(uint8(resolvedEpochView.status), uint8(MarketTypes.EpochStatus.Resolved));
        assertTrue(resolvedEpochView.claimable);
        assertFalse(resolvedEpochView.refundMode);
        assertEq(resolvedEpochView.winningOutcomeMask, 1);
        assertEq(resolvedEpochView.claimLiabilityTotal, 996 ether);
        assertEq(resolvedEpochView.settlementFeeTotal, 4 ether);
        assertEq(resolvedEpochView.remainingWinningStake, 600 ether);

        MarketEngine.OutcomeView[] memory settledOutcomeViews = engine.getOutcomeViews(tid, 1);
        assertFalse(settledOutcomeViews[0].isActiveQuote);
        assertTrue(settledOutcomeViews[0].isWinner);
        assertEq(settledOutcomeViews[0].grossPayoutXE6, 0);
        assertFalse(settledOutcomeViews[1].isWinner);

        MarketEngine.PositionView memory claimablePositionView = engine.getPositionView(tid, 1, user);
        assertEq(uint8(claimablePositionView.status), uint8(MarketEngine.PositionViewStatus.Claimable));
        assertTrue(claimablePositionView.claimableNow);
        assertEq(claimablePositionView.pendingClaimAmount, 996 ether);
        assertEq(claimablePositionView.pendingRefundAmount, 0);
        assertEq(claimablePositionView.winningStake, 600 ether);

        vm.prank(user);
        engine.claim(tid, 1);

        MarketEngine.PositionView memory claimedPositionView = engine.getPositionView(tid, 1, user);
        assertEq(uint8(claimedPositionView.status), uint8(MarketEngine.PositionViewStatus.Claimed));
        assertTrue(claimedPositionView.claimed);
        assertEq(claimedPositionView.claimedAmount, 996 ether);
        assertFalse(claimedPositionView.claimableNow);
    }

    function test_templateYieldView_reports_current_non_annualized_snapshot() public {
        bytes32 tid = _tid("yield-view");

        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("yield-view"));
        engine.initializeMarket(tid);
        vm.stopPrank();

        MarketEngine.TemplateYieldView memory noRouterView = engine.getTemplateYieldView(tid);
        assertFalse(noRouterView.routerAssigned);
        assertFalse(noRouterView.routerDisabled);
        assertEq(noRouterView.currentPrincipal, 0);
        assertEq(uint8(noRouterView.yieldPath), uint8(IYieldRouterV2.YieldPath.AToken));

        MockViewYieldRouter router = new MockViewYieldRouter();
        router.setTemplateState(1_100 ether, 1_000 ether, 900 ether, 50 ether, IYieldRouterV2.YieldPath.StataToken);

        vm.prank(admin);
        engine.setYieldRouter(address(router), 25);

        MarketEngine.TemplateYieldView memory yieldView = engine.getTemplateYieldView(tid);
        assertTrue(yieldView.routerAssigned);
        assertFalse(yieldView.routerDisabled);
        assertFalse(yieldView.recoveryPending);
        assertEq(uint8(yieldView.yieldPath), uint8(IYieldRouterV2.YieldPath.StataToken));
        assertEq(yieldView.currentPrincipal, 1_000 ether);
        assertEq(yieldView.currentValue, 1_100 ether);
        assertEq(yieldView.unrealizedYieldAmount, 100 ether);
        assertEq(yieldView.yieldRatioE6, 100_000);
        assertEq(yieldView.scaledPrincipal, 900 ether);
        assertEq(yieldView.stataShares, 50 ether);
        assertEq(yieldView.yieldFeeBpsCurrent, 25);
    }

    function test_operator_views_surface_pause_router_recovery_and_template_routed_principal() public {
        bytes32 tid = _tid("ops-view");

        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("ops-view"));
        engine.initializeMarket(tid);
        vm.stopPrank();

        MockPartialYieldRouter router = new MockPartialYieldRouter(token, 10_000);
        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);

        uint64 t0 = 2_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        address user = address(0xCAFE);
        token.mint(user, 1_000 ether);
        vm.startPrank(user);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 1_000 ether);
        vm.stopPrank();

        MarketEngine.OperatorTemplateView memory healthyTemplateView = engine.getOperatorTemplateView(tid);
        assertEq(healthyTemplateView.templateRoutedPrincipal, 950 ether);
        assertEq(healthyTemplateView.activeVault, 1_000 ether);
        assertEq(healthyTemplateView.unreconciledRecoveredAmount, 0);
        assertFalse(healthyTemplateView.userOpsBlocked);
        assertFalse(healthyTemplateView.unsafeToUnpauseForTemplate);

        vm.prank(admin);
        engine.pauseProgram(true);
        vm.prank(admin);
        engine.yieldEmergencyWithdraw(tid);

        MarketEngine.OperatorTemplateView memory recoveryTemplateView = engine.getOperatorTemplateView(tid);
        assertEq(recoveryTemplateView.templateRoutedPrincipal, 950 ether);
        assertEq(recoveryTemplateView.unreconciledRecoveredAmount, 950 ether);
        assertTrue(recoveryTemplateView.userOpsBlocked);
        assertTrue(recoveryTemplateView.unsafeToUnpauseForTemplate);

        MarketEngine.OperatorGlobalView memory globalView = engine.getOperatorGlobalView();
        assertTrue(globalView.globalPaused);
        assertEq(globalView.yieldRouter, address(router));
        assertFalse(globalView.yieldRouterDisabled);
        assertEq(globalView.totalRoutedPrincipal, 950 ether);
        assertEq(globalView.totalUnreconciledRecovered, 950 ether);
        assertEq(globalView.admin, admin);
        assertEq(globalView.treasury, treasury);
        assertEq(globalView.workerAuthority, worker);
        assertEq(globalView.priceOracle, address(oracle));
    }
}
