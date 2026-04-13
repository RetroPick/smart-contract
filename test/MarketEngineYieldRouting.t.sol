// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "./MarketEngineBase.t.sol";
import {YieldRouterAaveV3} from "../src/yield/YieldRouterAaveV3.sol";
import {YieldRouterV2} from "../src/yield/YieldRouterV2.sol";
import {MarketEngineState} from "../src/engine/MarketEngineState.sol";
import {MockAavePool} from "../src/test/MockAavePool.sol";
import {MockAToken} from "../src/test/MockAToken.sol";
import {MockERC20} from "../src/test/MockERC20.sol";
import {MockRewardsController} from "../src/test/MockRewardsController.sol";

contract MarketEngineYieldRoutingTest is MarketEngineBase {
    MockAToken internal aToken;
    MockAavePool internal pool;
    YieldRouterAaveV3 internal router;

    address internal alice = address(0xA71CE);
    address internal bob = address(0xB0B01);

    function setUp() public override {
        super.setUp();

        aToken = new MockAToken();
        pool = new MockAavePool(address(token), address(aToken));
        router = new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.prank(admin);
        engine.setYieldRouter(address(router), 1000); // 10% yield fee
    }

    function _initManualThresholdMarket(bytes32 tid, uint64 t0) internal {
        vm.prank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("thr"));
        vm.prank(admin);
        engine.initializeMarket(tid);

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, uint64(t0), uint64(t0 + 10), uint64(t0 + 20));
    }

    function test_manualResolve_winnerGetsNetYield() public {
        bytes32 tid = _tid("thr");
        uint64 t0 = 1_000_000;
        _initManualThresholdMarket(tid, t0);

        pool.setYieldBps(2000); // 20% gross yield on withdraw in mock

        token.mint(alice, 1000);
        token.mint(bob, 1000);

        vm.startPrank(alice);
        token.approve(address(engine), 1000);
        engine.depositToSide(tid, 1, 0, 1000); // YES
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(engine), 1000);
        engine.depositToSide(tid, 1, 1, 1000); // NO
        vm.stopPrank();

        // Resolve outcome = YES (AtOrAbove 100e8), set oracle to 200e8 at resolve.
        vm.warp(t0 + 21);
        oracle.set(feed, 200e8, uint64(t0 + 21), 0);

        vm.prank(worker);
        engine.lockEpoch(tid, 1); // threshold: no checkpoint A, but transitions to Locked

        vm.warp(t0 + 25);
        oracle.set(feed, 200e8, uint64(t0 + 25), 0);

        uint256 aliceBalBefore = token.balanceOf(alice);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        vm.prank(alice);
        engine.claim(tid, 1);
        uint256 alicePayout = token.balanceOf(alice) - aliceBalBefore;

        // Net yield credited to winners only: payout should exceed principal.
        assertGt(alicePayout, 1000);

        vm.prank(bob);
        vm.expectRevert();
        engine.claim(tid, 1);
    }

    function test_manualResolve_revertsIfYieldWithdrawReverts() public {
        bytes32 tid = _tid("thr");
        uint64 t0 = 2_000_000;
        _initManualThresholdMarket(tid, t0);

        token.mint(alice, 1000);
        vm.startPrank(alice);
        token.approve(address(engine), 1000);
        engine.depositToSide(tid, 1, 0, 1000);
        vm.stopPrank();

        vm.warp(t0 + 21);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 25);
        oracle.set(feed, 200e8, uint64(t0 + 25), 0);

        pool.setRevertWithdraw(true);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("YieldWithdrawFailed()")));
        engine.resolveEpoch(tid, 1);
    }

    function test_deposit_yieldV2_frozenReserve_emitsYieldRouterDepositFailed() public {
        bytes32 tid2 = _tid("thr-v2");
        uint64 t0 = 4_000_000;
        vm.prank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("thr-v2"));
        vm.prank(admin);
        engine.initializeMarket(tid2);

        YieldRouterV2 r2 = new YieldRouterV2(address(token), address(pool), address(aToken), address(0), address(0), address(engine));
        vm.prank(admin);
        engine.setYieldRouter(address(r2), 1000);

        pool.setReserveFlags(true, true, false);

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid2, 1, uint64(t0), uint64(t0 + 10), uint64(t0 + 20));

        token.mint(alice, 1000);
        vm.startPrank(alice);
        token.approve(address(engine), 1000);

        uint256 route = (1000 * 9500) / 10_000;
        vm.expectEmit(true, true, true, true);
        emit MarketEngineState.YieldRouterDepositFailed(tid2, route);

        engine.depositToSide(tid2, 1, 0, 1000);
        vm.stopPrank();

        pool.setReserveFlags(true, false, false);
    }

    function test_keeperClaimLmRewards_transfersToEngine() public {
        MockERC20 rewardTok = new MockERC20();
        MockRewardsController rc = new MockRewardsController(address(rewardTok));
        rewardTok.mint(address(rc), 50e18);

        YieldRouterV2 r2 = new YieldRouterV2(
            address(token), address(pool), address(aToken), address(rc), address(0), address(engine)
        );
        vm.startPrank(admin);
        engine.setYieldRouter(address(r2), 0);
        engine.setLmRewardsEnabled(true);
        vm.stopPrank();

        vm.prank(worker);
        engine.keeperClaimLmRewards(bytes32(0));

        assertEq(rewardTok.balanceOf(address(engine)), 50e18);
    }
}

