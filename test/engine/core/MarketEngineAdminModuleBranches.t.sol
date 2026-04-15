// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
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
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.yieldEmergencyWithdraw(tid);
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
