// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/test/MockERC20.sol";
import {MockAToken} from "../src/test/MockAToken.sol";
import {MockAavePool} from "../src/test/MockAavePool.sol";
import {YieldRouterAaveV3} from "../src/yield/YieldRouterAaveV3.sol";
import {IYieldRouterV2} from "../src/interfaces/IYieldRouterV2.sol";

contract YieldRouterAaveV3Test is Test {
    MockERC20 internal stake;
    MockAToken internal aToken;
    MockAavePool internal pool;
    YieldRouterAaveV3 internal router;

    address internal engine = address(this);
    bytes32 internal t0 = keccak256("t0");
    bytes32 internal t1 = keccak256("t1");

    function setUp() public {
        stake = new MockERC20();
        aToken = new MockAToken();
        pool = new MockAavePool(address(stake), address(aToken));
        router = new YieldRouterAaveV3(address(stake), address(pool), address(aToken), engine);
    }

    function test_deposit_mintsSharesAndTracksPrincipal() public {
        stake.mint(engine, 1000);
        stake.approve(address(router), 1000);

        router.deposit(t0, 1000);

        assertEq(router.principalByTemplate(t0), 1000);
        assertEq(router.sharesByTemplate(t0), 1000);
        assertEq(aToken.balanceOf(address(router)), 1000);
    }

    function test_withdraw_partial_isProportional() public {
        pool.setYieldBps(500); // 5% on withdraw

        stake.mint(engine, 10_000);
        stake.approve(address(router), 10_000);

        router.deposit(t0, 6000);
        router.deposit(t0, 4000);

        uint256 balBefore = stake.balanceOf(engine);
        uint256 gross = router.withdraw(t0, 5000);
        uint256 balAfter = stake.balanceOf(engine);

        assertEq(balAfter - balBefore, gross);
        assertGt(gross, 5000);
        assertEq(router.principalByTemplate(t0), 5000);
        assertEq(router.sharesByTemplate(t0), 5000);
    }

    function test_emergencyWithdraw_zerosState() public {
        stake.mint(engine, 1000);
        stake.approve(address(router), 1000);
        router.deposit(t1, 1000);

        uint256 gross = router.emergencyWithdraw(t1);
        assertGt(gross, 0);

        assertEq(router.principalByTemplate(t1), 0);
        assertEq(router.sharesByTemplate(t1), 0);
    }

    function test_onlyEngine_guard_on_mutating_paths() public {
        stake.mint(engine, 1000);
        stake.approve(address(router), 1000);

        vm.prank(address(0xBEEF));
        vm.expectRevert(YieldRouterAaveV3.OnlyEngine.selector);
        router.depositScaled(t0, 1000);

        vm.prank(address(0xBEEF));
        vm.expectRevert(YieldRouterAaveV3.OnlyEngine.selector);
        router.withdrawScaled(t0, 1);
    }

    function test_emergencyWithdraw_reverts_for_unauthorized() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(YieldRouterAaveV3.Unauthorized.selector);
        router.emergencyWithdraw(t0);
    }

    function test_emergencyWithdraw_returns_zero_when_no_shares() public {
        uint256 out = router.emergencyWithdraw(t0);
        assertEq(out, 0);
    }

    function test_setTemplateYieldPath_allows_only_AToken_path() public {
        router.setTemplateYieldPath(t0, IYieldRouterV2.YieldPath.AToken);

        vm.expectRevert(YieldRouterAaveV3.Unauthorized.selector);
        router.setTemplateYieldPath(t0, IYieldRouterV2.YieldPath.StataToken);
    }

    function test_withdraw_reverts_on_zero_and_overwithdraw() public {
        vm.expectRevert(YieldRouterAaveV3.ZeroAmount.selector);
        router.withdraw(t0, 0);

        stake.mint(engine, 100);
        stake.approve(address(router), 100);
        router.deposit(t0, 100);

        vm.expectRevert(YieldRouterAaveV3.OverWithdraw.selector);
        router.withdraw(t0, 101);
    }

    function test_withdraw_full_clears_principal_and_shares() public {
        stake.mint(engine, 1000);
        stake.approve(address(router), 1000);
        router.deposit(t0, 1000);
        router.withdraw(t0, 1000);
        assertEq(router.principalByTemplate(t0), 0);
        assertEq(router.sharesByTemplate(t0), 0);
    }

    function test_claimLmRewards_empty_and_only_engine() public view {
        (address[] memory tokens, uint256[] memory amounts) = router.claimLmRewards(t0);
        assertEq(tokens.length, 0);
        assertEq(amounts.length, 0);
    }

    function test_claimLmRewards_reverts_for_non_engine() public {
        vm.prank(address(0xABCD));
        vm.expectRevert(YieldRouterAaveV3.OnlyEngine.selector);
        router.claimLmRewards(t0);
    }
}

