// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketEngineState} from "../../../src/engine/MarketEngineState.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {IPriceOracle} from "../../../src/interfaces/IPriceOracle.sol";
import {MockAavePool} from "../../../src/test/MockAavePool.sol";
import {MockAToken} from "../../../src/test/MockAToken.sol";
import {MockPriceOracle} from "../../../src/test/MockPriceOracle.sol";
import {YieldRouterAaveV3} from "../../../src/yield/YieldRouterAaveV3.sol";

/// @notice Rolling oracle and timing: buffers, confidence, early calls, batch.
contract MarketEngineRollingOracleTest is MarketEngineBase {
    uint64 internal constant INTER = 100;
    uint256 internal constant OVERSIZED_BATCH = 101;

    function test_rolling_allows_chainlink_style_publishTime_before_lock_and_resolve() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("cl_pt", INTER, 10));
        bytes32 tid = _tid("cl_pt");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 395_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 10);
        engine.depositToSide(tid, 1, 0, 20e18);

        // Genesis lock: oracle publishTime can be slightly before lockAt.
        uint64 lockTs = t0 + INTER;
        vm.warp(lockTs);
        oracle.set(feed, 100e8, lockTs - 5, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        // Execute tick: oracle publishTime can be slightly before resolveAt/lockAt boundary.
        uint64 execTs = t0 + 2 * INTER;
        vm.warp(execTs);
        oracle.set(feed, 110e8, execTs - 5, 0); // winner = outcome 0 (up)
        vm.prank(worker);
        engine.executeRollingRound(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Live));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.NoneReason));
    }

    function test_rolling_genesis_lock_buffer_miss_halts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("buf_lock", INTER, 10));
        bytes32 tid = _tid("buf_lock");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 400_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + INTER + 11);
        oracle.set(feed, 100e8, t0 + INTER + 11, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.BufferMissOnLock));
    }

    /// @dev Late tick misses the resolve buffer first (`ePrev.resolveAt` equals `eCur.lockAt` in steady state).
    function test_rolling_execute_late_halts_buffer_miss_resolve() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("buf_ex_res", INTER, 10));
        bytes32 tid = _tid("buf_ex_res");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 410_000;
        _rollingGenesisToLive(tid, t0, INTER);

        vm.warp(t0 + 2 * INTER + 11);
        oracle.set(feed, 110e8, t0 + 2 * INTER + 11, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.BufferMissOnResolve));
    }

    function test_rolling_genesis_lock_confidence_wide_halts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("conf_g", INTER, 10));
        bytes32 tid = _tid("conf_g");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 420_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + INTER);
        oracle.set(feed, 100e8, t0 + INTER, 200e8);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.OracleConfidenceWide));
    }

    function test_rolling_small_price_confidence_floor_does_not_halt() public {
        vm.startPrank(admin);
        MarketEngine.UpsertTemplateParams memory p = _directionRollingTemplate("conf_small_ok", INTER, 10);
        p.oracleMaxConfidenceBps = 500; // 5%
        engine.upsertTemplate(p);
        bytes32 tid = _tid("conf_small_ok");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 425_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + INTER);
        // Small price (100) with confidence (10): old logic halted since 10 > 5.
        oracle.set(feed, 100, t0 + INTER, 10);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Live));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.NoneReason));
    }

    function test_rolling_execute_confidence_wide_halts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("conf_x", INTER, 10));
        bytes32 tid = _tid("conf_x");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 430_000;
        _rollingGenesisToLive(tid, t0, INTER);

        vm.warp(t0 + 2 * INTER);
        oracle.set(feed, 100e8, t0 + 2 * INTER, 200e8);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.OracleConfidenceWide));
    }

    function test_rolling_genesis_lock_oracle_failure_halts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("ora_g", INTER, 10));
        bytes32 tid = _tid("ora_g");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 440_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        uint64 lockTs = t0 + INTER;
        vm.warp(lockTs);
        vm.mockCallRevert(
            address(oracle),
            abi.encodeWithSelector(IPriceOracle.getNormalizedPrice.selector, feed, uint64(3600), uint64(lockTs)),
            hex""
        );
        vm.prank(worker);
        engine.genesisLockRolling(tid);
        vm.clearMockedCalls();

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.OracleFailure));
    }

    function test_rolling_execute_too_early_reverts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("early", INTER, 10));
        bytes32 tid = _tid("early");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 450_000;
        _rollingGenesisToLive(tid, t0, INTER);

        vm.warp(t0 + 2 * INTER - 1);
        oracle.set(feed, 100e8, t0 + 2 * INTER - 1, 0);
        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("TooEarlyToResolve()")));
        engine.executeRollingRound(tid);
    }

    function test_rolling_genesis_lock_too_early_reverts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("early_gl", INTER, 10));
        bytes32 tid = _tid("early_gl");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 460_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + INTER - 1);
        oracle.set(feed, 100e8, t0 + INTER - 1, 0);
        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("TooEarlyToLock()")));
        engine.genesisLockRolling(tid);
    }

    function test_reset_oracle_cursor_reverts_while_rolling_epoch_open() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rolling_cursor_live_reset", INTER, 10));
        bytes32 tid = _tid("rolling_cursor_live_reset");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 461_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketEngineState.OracleCursorResetWhileEpochActive.selector,
                tid,
                uint64(1),
                uint8(MarketTypes.EpochStatus.Open)
            )
        );
        engine.resetOracleCursor(tid, feed);
    }

    function test_rolling_halts_when_prev_and_cur_epoch_oracle_snapshots_differ() public {
        MockPriceOracle rateA = new MockPriceOracle();
        MockPriceOracle rateB = new MockPriceOracle();

        vm.startPrank(admin);
        engine.setRateOracle(address(rateA));
        MarketEngine.UpsertTemplateParams memory p = _directionRollingTemplate("rolling_oracle_snapshot_mismatch", INTER, 10);
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
        engine.upsertTemplate(p);
        bytes32 tid = _tid("rolling_oracle_snapshot_mismatch");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 462_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 10);
        engine.depositToSide(tid, 1, 0, 20e18);

        vm.startPrank(admin);
        engine.pauseProgram(true);
        engine.setRateOracle(address(rateB));
        engine.pauseProgram(false);
        vm.stopPrank();

        uint64 lockTs = t0 + INTER;
        vm.warp(lockTs);
        rateA.set(feed, 100e8, lockTs, 0);
        rateB.set(feed, 100e8, lockTs, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        uint64 execTs = t0 + 2 * INTER;
        vm.warp(execTs);
        rateA.set(feed, 110e8, execTs, 0);
        rateB.set(feed, 110e8, execTs, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.OracleFailure));
    }

    /// @dev Batch loops templates: oracle failure on one feed does not stop the other template in the same tx.
    function test_rolling_execute_round_batch_one_halts_one_ok() public {
        bytes32 feedB = keccak256("feed_b");
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("batch_a", INTER, 10));
        MarketEngine.UpsertTemplateParams memory pb = _directionRollingTemplate("batch_b", INTER, 10);
        pb.oracleFeedId = feedB;
        engine.upsertTemplate(pb);
        bytes32 tidA = _tid("batch_a");
        bytes32 tidB = _tid("batch_b");
        engine.initializeMarket(tidA);
        engine.initializeMarket(tidB);
        vm.stopPrank();

        uint64 t0 = 470_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tidA);
        vm.prank(worker);
        engine.genesisStartRolling(tidB);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tidA, 1, 0, 20e18);
        engine.depositToSide(tidB, 1, 0, 20e18);

        vm.warp(t0 + INTER);
        oracle.set(feed, 100e8, t0 + INTER, 0);
        oracle.set(feedB, 100e8, t0 + INTER, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tidA);
        vm.prank(worker);
        engine.genesisLockRolling(tidB);

        uint64 execTs = t0 + 2 * INTER;
        vm.warp(execTs);
        vm.mockCallRevert(
            address(oracle),
            abi.encodeWithSelector(IPriceOracle.getNormalizedPrice.selector, feed, uint64(3600), uint64(execTs)),
            hex""
        );
        oracle.set(feedB, 110e8, execTs, 0);

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = tidA;
        ids[1] = tidB;
        vm.prank(worker);
        engine.executeRollingRoundBatch(ids);
        vm.clearMockedCalls();

        (MarketTypes.RollingPhase pA, MarketTypes.RollingHaltReason rA,,,,) = engine.getRollingLifecycle(tidA);
        (MarketTypes.RollingPhase pB,,,, uint64 activeB, uint64 lrB) = engine.getRollingLifecycle(tidB);
        assertEq(uint8(pA), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(rA), uint8(MarketTypes.RollingHaltReason.OracleFailure));
        assertEq(uint8(pB), uint8(MarketTypes.RollingPhase.Live));
        assertEq(activeB, 3);
        assertEq(lrB, 1);
    }

    function test_rolling_execute_round_batch_reverts_on_oversized_batch() public {
        bytes32[] memory ids = new bytes32[](OVERSIZED_BATCH);
        vm.prank(worker);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidBatchSize(uint256)")), OVERSIZED_BATCH));
        engine.executeRollingRoundBatch(ids);
    }

    function test_rolling_execute_halts_when_yield_withdraw_fails() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("roll_withdraw_fail", INTER, 10));
        bytes32 tid = _tid("roll_withdraw_fail");
        engine.initializeMarket(tid);
        vm.stopPrank();

        MockAToken aToken = new MockAToken();
        MockAavePool pool = new MockAavePool(address(token), address(aToken));
        YieldRouterAaveV3 router =
            new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);

        uint64 t0 = 480_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 20e18);

        vm.warp(t0 + INTER);
        oracle.set(feed, 100e8, t0 + INTER, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 2, 0, 20e18);

        pool.setRevertWithdraw(true);
        vm.warp(t0 + 2 * INTER);
        oracle.set(feed, 120e8, t0 + 2 * INTER, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.OracleFailure));
    }

    function test_disabledRouter_blocks_new_routing_on_deposit() public {
        MockAToken aToken = new MockAToken();
        MockAavePool pool = new MockAavePool(address(token), address(aToken));
        YieldRouterAaveV3 router =
            new YieldRouterAaveV3(address(token), address(pool), address(aToken), address(engine));

        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);

        uint64[3] memory starts = [uint64(500_000), uint64(501_000), uint64(502_000)];
        string[3] memory slugs = ["disable_a", "disable_b", "disable_c"];

        for (uint256 i = 0; i < 3; ++i) {
            vm.startPrank(admin);
            engine.upsertTemplate(_directionRollingTemplate(slugs[i], INTER, 10));
            engine.initializeMarket(_tid(slugs[i]));
            vm.stopPrank();

            bytes32 tid = _tid(slugs[i]);
            uint64 t0 = starts[i];

            vm.warp(t0);
            vm.prank(worker);
            engine.genesisStartRolling(tid);

            vm.warp(t0 + 50);
            engine.depositToSide(tid, 1, 0, 20e18);

            vm.warp(t0 + INTER);
            oracle.set(feed, 100e8, t0 + INTER, 0);
            vm.prank(worker);
            engine.genesisLockRolling(tid);

            vm.warp(t0 + 150);
            engine.depositToSide(tid, 2, 0, 20e18);

            pool.setRevertWithdraw(true);
            vm.warp(t0 + 2 * INTER);
            oracle.set(feed, 120e8, t0 + 2 * INTER, 0);
            vm.prank(worker);
            engine.executeRollingRound(tid);
        }

        assertEq(engine.yieldRouterFailureCount(), 3);
        assertTrue(engine.yieldRouterDisabled());

        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("disabled-manual"));
        bytes32 manualTid = _tid("disabled-manual");
        engine.initializeMarket(manualTid);
        vm.stopPrank();

        uint64 t0Manual = 503_000;
        vm.warp(t0Manual);
        vm.prank(worker);
        engine.openEpoch(manualTid, 1, t0Manual, t0Manual + 10, t0Manual + 20);

        uint256 routeAmount = (1000 ether * 9500) / 10_000;
        vm.expectEmit(true, true, true, true);
        emit MarketEngineState.YieldRouterDepositFailed(manualTid, routeAmount);
        engine.depositToSide(manualTid, 1, 0, 1000 ether);

        assertEq(engine.epochs(manualTid, 1).routedPrincipal, 0);
    }

    function test_rolling_genesis_reverts_when_interval_too_small() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("roll-small-inter", 5, 1));
        bytes32 tid = _tid("roll-small-inter");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("RollingInvalidParams()")));
        engine.genesisStartRolling(tid);
    }
}
