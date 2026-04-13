// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "./MarketEngineBase.t.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";

/// @notice Bounded fuzz: steady-state rolling keeps `rollingNextEpochId == activeEpochId + 1`.
contract MarketEngineRollingFuzzTest is MarketEngineBase {
    function testFuzz_rolling_next_cursor_invariant(uint256 tickCountRaw) public {
        uint256 tickCount = bound(tickCountRaw, 1, 6);

        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("fuzz_roll", 100, 10));
        bytes32 tid = engine.templateIdFromSlug("fuzz_roll");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 100_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e30);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 10e18);

        vm.warp(t0 + 100);
        oracle.set(feed, 100e8, t0 + 100, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        for (uint256 i = 0; i < tickCount; ++i) {
            (,,, uint64 nextBefore, uint64 activeBefore,) = engine.getRollingLifecycle(tid);
            assertEq(nextBefore, activeBefore + 1);

            // tickCount <= 6: offset fits uint64 for test constants.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint64 execTs = uint64(uint256(t0) + 200 + i * 100);
            uint256 step1 = i + 1;
            uint256 step2 = i + 2;
            // forge-lint: disable-next-line(unsafe-typecast)
            int256 priceAtLock = int256(100e8) + int256(step1) * 1e8;
            // forge-lint: disable-next-line(unsafe-typecast)
            int256 priceAtExec = int256(100e8) + int256(step2) * 1e8;
            // Deposit must happen strictly before `lockAt` (which equals `execTs` on the open epoch).
            vm.warp(execTs - 1);
            oracle.set(feed, priceAtLock, execTs - 1, 0);
            // Stake the “up” side so monotonically rising prices always yield a non-zero winning pool.
            engine.depositToSide(tid, activeBefore, 0, 5e18);

            vm.warp(execTs);
            oracle.set(feed, priceAtExec, execTs, 0);
            vm.prank(worker);
            engine.executeRollingRound(tid);

            (MarketTypes.RollingPhase phase,,,, uint64 activeAfter,) = engine.getRollingLifecycle(tid);
            assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Live));
            assertEq(activeAfter, activeBefore + 1);

            (,,, uint64 nextAfter,,) = engine.getRollingLifecycle(tid);
            assertEq(nextAfter, activeAfter + 1);
        }
    }
}
