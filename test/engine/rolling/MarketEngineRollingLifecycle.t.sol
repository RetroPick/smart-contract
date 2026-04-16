// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";

/// @notice Rolling steady-state: multi-tick progression and resolved cursor.
contract MarketEngineRollingLifecycleTest is MarketEngineBase {
    uint64 internal constant INTER = 100;

    function test_rolling_multi_tick_lastResolved_increments() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("life", INTER, 10));
        bytes32 tid = _tid("life");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 300_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 100e18);

        vm.warp(t0 + INTER);
        oracle.set(feed, 100e8, t0 + INTER, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        assertEq(_lastResolved(tid), 0);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 2, 0, 100e18);

        vm.warp(t0 + 2 * INTER);
        oracle.set(feed, 110e8, t0 + 2 * INTER, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        assertEq(_lastResolved(tid), 1);
        (,,,, uint64 active,) = engine.getRollingLifecycle(tid);
        assertEq(active, 3);
        (,,, uint64 next,,) = engine.getRollingLifecycle(tid);
        assertEq(next, active + 1);

        vm.warp(t0 + 250);
        engine.depositToSide(tid, 3, 0, 50e18);

        vm.warp(t0 + 3 * INTER);
        oracle.set(feed, 120e8, t0 + 3 * INTER, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        assertEq(_lastResolved(tid), 2);
        (,,,, active,) = engine.getRollingLifecycle(tid);
        assertEq(active, 4);
    }

    function _lastResolved(bytes32 templateId) internal view returns (uint64) {
        (,,,,, uint64 lr) = engine.getRollingLifecycle(templateId);
        return lr;
    }
}
