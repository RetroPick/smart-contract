// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

import {YieldRouterV2} from "../src/yield/YieldRouterV2.sol";
import {IYieldRouterV2} from "../src/interfaces/IYieldRouterV2.sol";
import {MockERC20} from "../src/test/MockERC20.sol";
import {MockAToken} from "../src/test/MockAToken.sol";
import {MockAavePool} from "../src/test/MockAavePool.sol";
import {MockRewardsController} from "../src/test/MockRewardsController.sol";

contract YieldRouterV2Test is Test {
    MockERC20 internal stake;
    MockAToken internal aToken;
    MockAavePool internal pool;
    MockRewardsController internal rewards;
    MockERC20 internal rewardTok;
    ERC4626Mock internal stata;
    YieldRouterV2 internal router;

    address internal engine = makeAddr("engine");
    bytes32 internal tid = keccak256("t1");

    function setUp() public {
        stake = new MockERC20();
        aToken = new MockAToken();
        pool = new MockAavePool(address(stake), address(aToken));
        rewardTok = new MockERC20();
        rewards = new MockRewardsController(address(rewardTok));
        stata = new ERC4626Mock(address(stake));

        router = new YieldRouterV2(address(stake), address(pool), address(aToken), address(rewards), address(0), engine);

        stake.mint(engine, 1_000_000e18);
        vm.prank(engine);
        stake.approve(address(router), type(uint256).max);

        pool.setYieldBps(500);
    }

    function test_depositScaled_tracks_scaled_and_principal() public {
        vm.prank(engine);
        uint256 units = router.depositScaled(tid, 1000e18);
        assertGt(units, 0);
        assertEq(router.principalOf(tid), 1000e18);
        assertEq(router.scaledPrincipalOf(tid), units);
        assertEq(router.globalScaledBalance(), aToken.scaledBalanceOf(address(router)));
    }

    function test_withdrawScaled_returns_yield() public {
        vm.startPrank(engine);
        router.depositScaled(tid, 1000e18);
        uint256 g0 = router.withdrawScaled(tid, 500e18);
        vm.stopPrank();
        assertGt(g0, 0);
        assertEq(router.principalOf(tid), 500e18);
    }

    function test_liquidity_index_growth_increases_value() public {
        vm.prank(engine);
        router.depositScaled(tid, 1000e18);
        pool.setLiquidityIndexRay(1_050_000_000_000_000_000_000_000_000); // 1.05e27
        uint256 v = router.currentValueOf(tid);
        assertGt(v, 1000e18);
    }

    function test_claimLmRewards_sends_to_engine() public {
        rewardTok.mint(address(rewards), 100e18);
        vm.prank(engine);
        router.depositScaled(tid, 100e18);
        vm.prank(engine);
        router.claimLmRewards(tid);
        assertEq(rewardTok.balanceOf(engine), 100e18);
    }

    function test_stata_path_deposit_withdraw() public {
        YieldRouterV2 r = new YieldRouterV2(
            address(stake), address(pool), address(aToken), address(0), address(stata), engine
        );
        vm.prank(r.owner());
        r.setTemplateYieldPath(tid, IYieldRouterV2.YieldPath.StataToken);

        stake.mint(engine, 500e18);
        vm.startPrank(engine);
        stake.approve(address(r), type(uint256).max);
        r.depositScaled(tid, 200e18);
        uint256 out = r.withdrawScaled(tid, 200e18);
        vm.stopPrank();
        assertEq(out, 200e18);
        assertEq(r.principalOf(tid), 0);
    }

    function test_reserve_frozen_reverts_deposit() public {
        pool.setReserveFlags(true, true, false);
        vm.prank(engine);
        vm.expectRevert(YieldRouterV2.ReserveNotHealthy.selector);
        router.depositScaled(tid, 100e18);
    }

    function test_withdraw_reverts_when_reserve_paused() public {
        vm.prank(engine);
        router.depositScaled(tid, 100e18);

        pool.setReserveFlags(true, false, true);
        vm.prank(engine);
        vm.expectRevert(YieldRouterV2.ReservePaused.selector);
        router.withdrawScaled(tid, 50e18);
    }

    function test_setTemplateYieldPath_reverts_when_balance_exists() public {
        vm.prank(engine);
        router.depositScaled(tid, 100e18);

        vm.prank(router.owner());
        vm.expectRevert(YieldRouterV2.CannotChangePath.selector);
        router.setTemplateYieldPath(tid, IYieldRouterV2.YieldPath.StataToken);
    }

    function test_pendingLmRewards_returns_rewards_tuple() public {
        rewardTok.mint(address(rewards), 50e18);
        vm.prank(engine);
        router.depositScaled(tid, 10e18);

        (address[] memory tokens, uint256[] memory amounts) = router.pendingLmRewards(tid);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(rewardTok));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], 50e18);
    }

    function test_rescueToken_reverts_for_aToken_and_transfers_other_token() public {
        vm.prank(router.owner());
        vm.expectRevert(YieldRouterV2.InvalidAddress.selector);
        router.rescueToken(address(aToken), address(this), 1);

        MockERC20 stray = new MockERC20();
        stray.mint(address(router), 123);
        vm.prank(router.owner());
        router.rescueToken(address(stray), address(this), 123);
        assertEq(stray.balanceOf(address(this)), 123);
    }

    function test_emergencyWithdraw_reverts_unauthorized_and_returns_zero_when_empty() public {
        vm.prank(address(0xABCD));
        vm.expectRevert(YieldRouterV2.Unauthorized.selector);
        router.emergencyWithdraw(tid);

        vm.prank(engine);
        assertEq(router.emergencyWithdraw(tid), 0);
    }

    function test_zero_rewards_controller_paths_return_empty() public {
        YieldRouterV2 r = new YieldRouterV2(address(stake), address(pool), address(aToken), address(0), address(0), engine);
        vm.prank(engine);
        (address[] memory tokens, uint256[] memory amounts) = r.claimLmRewards(tid);
        assertEq(tokens.length, 0);
        assertEq(amounts.length, 0);

        (tokens, amounts) = r.pendingLmRewards(tid);
        assertEq(tokens.length, 0);
        assertEq(amounts.length, 0);
    }

    function test_setTemplateYieldPath_reverts_when_stata_not_configured() public {
        vm.prank(router.owner());
        vm.expectRevert(YieldRouterV2.StataNotConfigured.selector);
        router.setTemplateYieldPath(tid, IYieldRouterV2.YieldPath.StataToken);
    }
}
