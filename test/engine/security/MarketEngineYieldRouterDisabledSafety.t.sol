// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {MarketEngineState} from "../../../src/engine/MarketEngineState.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockAToken} from "../../../src/test/MockAToken.sol";
import {MockAavePool} from "../../../src/test/MockAavePool.sol";
import {YieldRouterAaveV3} from "../../../src/yield/YieldRouterAaveV3.sol";

/// @notice Safety tests for already-disabled yield-router state.
contract MarketEngineYieldRouterDisabledSafetyTest is MarketEngineBase {
    MockAToken internal aToken;
    MockAavePool internal pool;
    YieldRouterAaveV3 internal router;

    function setUp() public override {
        super.setUp();
        aToken = new MockAToken();
        pool = new MockAavePool(address(token), address(aToken));
        router = new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
    }

    function _disableRouterViaRollingFailures() internal {
        uint64[3] memory starts = [uint64(700_000), uint64(701_000), uint64(702_000)];
        string[3] memory slugs = ["dis_r_a", "dis_r_b", "dis_r_c"];

        for (uint256 i = 0; i < 3; ++i) {
            bytes32 tid = _tid(slugs[i]);
            vm.startPrank(admin);
            engine.upsertTemplate(_directionRollingTemplate(slugs[i], 100, 10));
            engine.initializeMarket(tid);
            vm.stopPrank();

            uint64 t0 = starts[i];
            vm.warp(t0);
            vm.prank(worker);
            engine.genesisStartRolling(tid);

            vm.warp(t0 + 50);
            engine.depositToSide(tid, 1, 0, 20e18);

            vm.warp(t0 + 100);
            oracle.set(feed, 100e8, t0 + 100, 0);
            vm.prank(worker);
            engine.genesisLockRolling(tid);

            vm.warp(t0 + 150);
            engine.depositToSide(tid, 2, 0, 20e18);

            pool.setRevertWithdraw(true);
            vm.warp(t0 + 200);
            oracle.set(feed, 120e8, t0 + 200, 0);
            vm.prank(worker);
            engine.executeRollingRound(tid);
            pool.setRevertWithdraw(false);
        }

        assertEq(engine.yieldRouterFailureCount(), 3);
        assertTrue(engine.yieldRouterDisabled());
    }

    function test_manualResolve_reverts_when_router_disabled_and_principal_still_routed() public {
        bytes32 tid = _tid("manual-disabled");
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("manual-disabled"));
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 710_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 10, t0 + 20);

        engine.depositToSide(tid, 1, 0, 1000 ether);
        uint256 routed = engine.epochs(tid, 1).routedPrincipal;
        assertGt(routed, 0);

        _disableRouterViaRollingFailures();

        vm.warp(t0 + 11);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 21);
        oracle.set(feed, 200e8, t0 + 21, 0);
        vm.prank(worker);
        vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
        engine.resolveEpoch(tid, 1);

        MarketTypes.Epoch memory e = engine.epochs(tid, 1);
        assertEq(uint256(e.status), uint256(MarketTypes.EpochStatus.Locked));
        assertEq(e.routedPrincipal, routed);
        assertFalse(e.claimable);
    }

    function test_cancelRollingWhileHalted_reverts_when_router_disabled_and_principal_still_routed() public {
        bytes32 tid = _tid("rolling-disabled");
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rolling-disabled", 100, 10));
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 720_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        uint256 routed = engine.epochs(tid, 1).routedPrincipal;
        assertGt(routed, 0);

        _disableRouterViaRollingFailures();

        vm.startPrank(admin);
        engine.haltRollingMarket(tid);
        engine.pauseProgram(true);
        vm.expectRevert(MarketEngineState.YieldRouterDisabledState.selector);
        engine.cancelRollingEpochWhileHalted(tid, 1, MarketTypes.CancelReason.EmergencyPaused, false);
        vm.stopPrank();

        MarketTypes.Epoch memory e = engine.epochs(tid, 1);
        assertEq(uint256(e.status), uint256(MarketTypes.EpochStatus.Open));
        assertEq(e.routedPrincipal, routed);
        assertFalse(e.claimable);
    }
}
