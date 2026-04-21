// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {YieldRouterAaveV3} from "../../../src/yield/YieldRouterAaveV3.sol";
import {MockAavePool} from "../../../src/test/MockAavePool.sol";
import {MockAToken} from "../../../src/test/MockAToken.sol";

contract MarketEnginePostResolveClaimsYieldTest is MarketEngineBase {
    MockAToken internal aToken;
    MockAavePool internal pool;
    YieldRouterAaveV3 internal router;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public override {
        super.setUp();

        aToken = new MockAToken();
        pool = new MockAavePool(address(token), address(aToken));
        router = new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);
    }

    function _initManualThresholdMarket(bytes32 tid, string memory slug, uint64 t0) internal {
        vm.prank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate(slug));
        vm.prank(admin);
        engine.initializeMarket(tid);

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, uint64(t0), uint64(t0 + 10), uint64(t0 + 20));
    }

    function test_resolved_claims_are_re_routed_and_accrue_post_resolve_yield() public {
        bytes32 tid = _tid("post-resolve-yield");
        uint64 t0 = 5_000_000;
        _initManualThresholdMarket(tid, "post-resolve-yield", t0);

        token.mint(alice, 1000);
        token.mint(bob, 1000);

        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 1, 1000);
        vm.stopPrank();

        vm.warp(t0 + 11);
        oracle.set(feed, 100e8, uint64(t0 + 11), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 21);
        oracle.set(feed, 200e8, uint64(t0 + 21), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        MarketTypes.Epoch memory resolved = engine.epochs(tid, 1);
        assertEq(resolved.claimLiabilityTotal, 1990);
        assertEq(engine.totalRoutedPrincipal(), 1990);

        MarketEngine.EpochView memory epochView = engine.getEpochView(tid, 1);
        assertTrue(epochView.settledClaimRoutingEnabled);
        assertEq(epochView.settledClaimBaseOutstanding, 1990);
        assertEq(epochView.settledClaimPrincipalOutstanding, 1990);
        assertEq(epochView.settledClaimCurrentValue, 1990);

        (, uint256 claimsVault,) = engine.getVaultBalances(tid);
        assertEq(claimsVault, 0, "claims were re-routed after resolve");

        pool.setYieldBps(1_000); // 10% post-resolve yield on withdraw

        MarketEngine.PositionView memory positionView = engine.getPositionView(tid, 1, alice);
        assertTrue(positionView.settledClaimRoutingEnabled);
        assertEq(positionView.pendingClaimAmount, 1990);

        uint256 before = token.balanceOf(alice);
        vm.prank(alice);
        engine.claim(tid, 1);
        uint256 payout = token.balanceOf(alice) - before;

        assertEq(payout, 2189, "winner receives post-resolve yield");
        assertEq(engine.totalRoutedPrincipal(), 0);

        vm.prank(bob);
        vm.expectRevert();
        engine.claim(tid, 1);
    }

    function test_refund_epochs_do_not_re_route_claims() public {
        bytes32 tid = _tid("post-resolve-refund");
        uint64 t0 = 5_100_000;
        _initManualThresholdMarket(tid, "post-resolve-refund", t0);

        token.mint(alice, 1000);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000);
        vm.stopPrank();

        vm.prank(worker);
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

        (, uint256 claimsVault,) = engine.getVaultBalances(tid);
        assertEq(claimsVault, 1000, "refund liabilities stay local");
        assertEq(engine.totalRoutedPrincipal(), 0);

        uint256 before = token.balanceOf(alice);
        vm.prank(alice);
        engine.claim(tid, 1);
        assertEq(token.balanceOf(alice) - before, 1000);
    }

    function test_paused_recovery_can_convert_routed_settled_claims_back_to_local_claims() public {
        bytes32 tid = _tid("post-resolve-recover");
        uint64 t0 = 5_200_000;
        _initManualThresholdMarket(tid, "post-resolve-recover", t0);

        token.mint(alice, 1000);
        token.mint(bob, 1000);

        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 1, 1000);
        vm.stopPrank();

        vm.warp(t0 + 11);
        oracle.set(feed, 100e8, uint64(t0 + 11), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 21);
        oracle.set(feed, 200e8, uint64(t0 + 21), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        pool.setYieldBps(1_000);

        vm.startPrank(admin);
        engine.pauseProgram(true);
        engine.yieldEmergencyWithdraw(tid);
        uint256 recovered = engine.unreconciledRecoveredByTemplate(tid);
        assertEq(recovered, 2189);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert();
        engine.claim(tid, 1);

        vm.startPrank(admin);
        engine.recoverRoutedSettledClaims(tid, 1, recovered);
        engine.pauseProgram(false);
        vm.stopPrank();

        (, uint256 claimsVault,) = engine.getVaultBalances(tid);
        assertEq(claimsVault, 2189, "recovered routed claims moved back local");
        assertEq(engine.totalRoutedPrincipal(), 0);

        uint256 before = token.balanceOf(alice);
        vm.prank(alice);
        engine.claim(tid, 1);
        assertEq(token.balanceOf(alice) - before, 2189);
    }
}
