// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";

/// @notice Rolling equal A/B price => void refund claim.
contract MarketEngineRollingEconomicVoidTest is MarketEngineBase {
    uint64 internal constant INTER = 100;

    function test_rolling_equal_price_void_refund_claim() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("void", INTER, 10));
        bytes32 tid = _tid("void");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 800_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 1000e18);

        vm.warp(t0 + INTER);
        int256 px = 100e8;
        oracle.set(feed, px, t0 + INTER, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 2 * INTER);
        oracle.set(feed, px, t0 + 2 * INTER, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        (,,,,, uint64 lr) = engine.getRollingLifecycle(tid);
        assertEq(lr, 1);

        uint256 balBefore = token.balanceOf(address(this));
        engine.claim(tid, 1);
        assertGt(token.balanceOf(address(this)), balBefore);
    }
}
