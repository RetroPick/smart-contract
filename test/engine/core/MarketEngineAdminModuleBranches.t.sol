// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {MarketEngineState} from "../../../src/engine/MarketEngineState.sol";
import {MockERC20} from "../../../src/test/MockERC20.sol";
import {MockAToken} from "../../../src/test/MockAToken.sol";
import {MockAavePool} from "../../../src/test/MockAavePool.sol";
import {YieldRouterAaveV3} from "../../../src/yield/YieldRouterAaveV3.sol";

contract MarketEngineAdminModuleBranchesTest is MarketEngineBase {
    function test_setWorkerAuthority_revertsForUnauthorizedAndZeroAddress() public {
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.setWorkerAuthority(address(0x1234));

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidAuthority()")));
        engine.setWorkerAuthority(address(0));
    }

    function test_setTreasury_revertsForUnauthorizedAndZeroAddress() public {
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.setTreasury(address(0x1234));

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidAuthority()")));
        engine.setTreasury(address(0));
    }

    function test_setYieldRouter_revertsOnInvalidFeeAndClearsLmFlagOnZeroRouter() public {
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidFeeBps()")));
        engine.setYieldRouter(address(0x1234), 10_001);

        MockAToken aToken = new MockAToken();
        MockAavePool pool = new MockAavePool(address(token), address(aToken));
        YieldRouterAaveV3 router =
            new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.startPrank(admin);
        engine.setYieldRouter(address(router), 100);
        engine.setLmRewardsEnabled(true);
        assertTrue(engine.lmRewardsEnabled());
        engine.setYieldRouter(address(0), 100);
        vm.stopPrank();

        assertEq(address(engine.yieldRouter()), address(0));
        assertEq(engine.yieldFeeBps(), 0);
        assertFalse(engine.lmRewardsEnabled());
    }

    function test_setLmRewardsEnabled_revertsWhenRouterIsUnset() public {
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.setLmRewardsEnabled(true);
    }

    function test_keeperClaimLmRewards_revertsWhenRouterUnsetOrCallerUnauthorized() public {
        bytes32 tid = _tid("unset-router");

        vm.prank(address(0x999));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.keeperClaimLmRewards(tid);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.keeperClaimLmRewards(tid);
    }

    function test_keeperClaimLmRewards_returnsEarlyWhenLmDisabled() public {
        MockAToken aToken = new MockAToken();
        MockAavePool pool = new MockAavePool(address(token), address(aToken));
        YieldRouterAaveV3 router =
            new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);

        vm.prank(worker);
        engine.keeperClaimLmRewards(bytes32("template"));
    }

    function test_yieldEmergencyWithdraw_revertsForUnauthorizedAndUnsetRouter() public {
        bytes32 tid = bytes32("t");

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.yieldEmergencyWithdraw(tid);

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("ProtocolPaused()")));
        engine.yieldEmergencyWithdraw(tid);
    }

    function test_reconcileEpochRoutedPrincipal_reverts_when_protocol_not_paused() public {
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("ProtocolPaused()")));
        engine.reconcileEpochRoutedPrincipal(bytes32("t"), 1, 1);
    }

    function test_yieldEmergencyWithdraw_reverts_when_router_unset_even_if_paused() public {
        bytes32 tid = bytes32("t");

        vm.startPrank(admin);
        engine.pauseProgram(true);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.yieldEmergencyWithdraw(tid);
        vm.stopPrank();
    }

    function test_resetYieldRouterFailures_revertsForUnauthorized() public {
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.resetYieldRouterFailures();
    }

    function test_resetYieldRouterFailures_requires_pause_after_disablement() public {
        MockAToken aToken = new MockAToken();
        MockAavePool pool = new MockAavePool(address(token), address(aToken));
        YieldRouterAaveV3 router =
            new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);

        uint64[3] memory starts = [uint64(610_000), uint64(611_000), uint64(612_000)];
        string[3] memory slugs = ["reset_a", "reset_b", "reset_c"];

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
        }

        assertEq(engine.yieldRouterFailureCount(), 3);
        assertTrue(engine.yieldRouterDisabled());

        vm.prank(admin);
        vm.expectRevert(MarketEngineState.ProtocolPaused.selector);
        engine.resetYieldRouterFailures();

        vm.startPrank(admin);
        engine.pauseProgram(true);
        vm.expectRevert(abi.encodeWithSelector(MarketEngineState.UnsafeToUnpause.selector, true, uint256(0)));
        engine.pauseProgram(false);
        engine.resetYieldRouterFailures();
        engine.pauseProgram(false);
        vm.stopPrank();

        assertEq(engine.yieldRouterFailureCount(), 0);
        assertFalse(engine.yieldRouterDisabled());
    }

    function test_setYieldRouter_sameRouter_doesNotClear_disabled_state() public {
        MockAToken aToken = new MockAToken();
        MockAavePool pool = new MockAavePool(address(token), address(aToken));
        YieldRouterAaveV3 router =
            new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);

        uint64[3] memory starts = [uint64(620_000), uint64(621_000), uint64(622_000)];
        string[3] memory slugs = ["same_a", "same_b", "same_c"];

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
        }

        assertEq(engine.yieldRouterFailureCount(), 3);
        assertTrue(engine.yieldRouterDisabled());

        vm.prank(admin);
        engine.setYieldRouter(address(router), 25);

        assertEq(address(engine.yieldRouter()), address(router));
        assertEq(engine.yieldFeeBps(), 25);
        assertEq(engine.yieldRouterFailureCount(), 3);
        assertTrue(engine.yieldRouterDisabled());
    }

    function test_withdrawFees_revertsOnZeroAmountAndInsufficientReserve() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("fees"));
        bytes32 tid = _tid("fees");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("NothingToClaim()")));
        engine.withdrawFees(tid, 0);

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("NothingToClaim()")));
        engine.withdrawFees(tid, 1);
    }

    function test_withdrawFees_transfersToTreasuryAndUpdatesVault() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("fees-ok"));
        bytes32 tid = _tid("fees-ok");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 1_100_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 10, t0 + 20);

        address userA = address(0xABCD);
        address userB = address(0xBCDE);
        token.mint(userA, 1000e18);
        token.mint(userB, 1000e18);
        vm.startPrank(userA);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000e18);
        vm.stopPrank();
        vm.startPrank(userB);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 1, 1000e18);
        vm.stopPrank();

        vm.warp(t0 + 11);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 21);
        oracle.set(feed, 120e8, t0 + 21, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        (, uint256 claimsBefore, uint256 feesBefore) = engine.getVaultBalances(tid);
        assertGt(feesBefore, 0);
        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.prank(admin);
        engine.withdrawFees(tid, feesBefore);

        (, uint256 claimsAfter, uint256 feesAfter) = engine.getVaultBalances(tid);
        assertEq(claimsAfter, claimsBefore);
        assertEq(feesAfter, 0);
        assertEq(token.balanceOf(treasury), treasuryBefore + feesBefore);
    }
}
