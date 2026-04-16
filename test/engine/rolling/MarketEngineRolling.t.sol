// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {IPriceOracle} from "../../../src/interfaces/IPriceOracle.sol";

contract MarketEngineRollingTest is MarketEngineBase {
    function test_rolling_threshold_genesis_execute_claim() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_thresholdRollingTemplate("thr_roll", 100, 10));
        bytes32 tid = _tid("thr_roll");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 80_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + 50);
        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000e18); // YES

        // Non-Direction: genesis lock should not require oracle.
        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        // Tick at resolve boundary for epoch 1; price >= 100e8 => YES wins.
        vm.warp(t0 + 200);
        oracle.set(feed, 150e8, t0 + 200, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        MarketTypes.Epoch memory e2 = engine.getEpoch(tid, 2);
        assertEq(uint8(e2.status), uint8(MarketTypes.EpochStatus.Locked));
        assertEq(e2.checkpointA.written, false);

        engine.claim(tid, 1);
    }

    function test_rolling_rangeClose_genesis_execute_claim() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_rangeCloseRollingTemplate("rng_roll", 100, 10));
        bytes32 tid = _tid("rng_roll");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 90_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + 50);
        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 1, 1000e18); // bucket 1: [100,200)

        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 200);
        oracle.set(feed, 150e8, t0 + 200, 0); // should select idx=1
        vm.prank(worker);
        engine.executeRollingRound(tid);

        MarketTypes.Epoch memory e1 = engine.getEpoch(tid, 1);
        assertEq(uint8(e1.status), uint8(MarketTypes.EpochStatus.Resolved));
        assertEq(e1.winningOutcomeMask, (uint256(1) << 1));

        MarketTypes.Epoch memory e2 = engine.getEpoch(tid, 2);
        assertEq(uint8(e2.status), uint8(MarketTypes.EpochStatus.Locked));
        assertEq(e2.checkpointA.written, false);

        engine.claim(tid, 1);
    }

    function test_rolling_genesis_execute_claim() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("roll", 100, 10));
        bytes32 tid = _tid("roll");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 10_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + 50);
        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000e18);

        vm.warp(t0 + 100);
        oracle.set(feed, 100e8, t0 + 100, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 2, 0, 500e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 150e8, t0 + 200, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        engine.claim(tid, 1);
    }

    function test_revert_manual_openEpoch_on_rolling_template() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("r2", 100, 10));
        bytes32 tid = _tid("r2");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ManualModeOnly()")));
        engine.openEpoch(tid, 1, 100, 200, 300);
    }

    function test_rolling_buffer_exceeded_halts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("r3", 100, 10));
        bytes32 tid = _tid("r3");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 20_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + 100);
        oracle.set(feed, 100e8, t0 + 100, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 250);
        oracle.set(feed, 150e8, t0 + 200, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.BufferMissOnResolve));
    }

    function test_rolling_halt_oracle_failure_execute() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("r_oracle", 100, 10));
        bytes32 tid = _tid("r_oracle");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 40_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(t0 + 100);
        oracle.set(feed, 100e8, t0 + 100, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        uint64 execTs = t0 + 200;
        vm.warp(execTs);
        vm.mockCallRevert(
            address(oracle),
            abi.encodeWithSelector(IPriceOracle.getNormalizedPrice.selector, feed, uint64(3600), uint64(execTs)),
            hex""
        );
        vm.prank(worker);
        engine.executeRollingRound(tid);
        vm.clearMockedCalls();

        (MarketTypes.RollingPhase phase, MarketTypes.RollingHaltReason reason,,,,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.Halted));
        assertEq(uint8(reason), uint8(MarketTypes.RollingHaltReason.OracleFailure));
    }

    function test_rolling_recovery_rebootstrap() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("r_rec", 100, 10));
        bytes32 tid = _tid("r_rec");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 50_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 100e18);

        vm.warp(t0 + 100);
        oracle.set(feed, 100e8, t0 + 100, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 2, 1, 100e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 120e8, t0 + 200, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        vm.prank(admin);
        engine.haltRollingMarket(tid);

        vm.startPrank(admin);
        engine.pauseProgram(true);
        engine.cancelRollingEpochWhileHalted(tid, 2, MarketTypes.CancelReason.EmergencyPaused, false);
        engine.cancelRollingEpochWhileHalted(tid, 3, MarketTypes.CancelReason.EmergencyPaused, false);
        engine.resetRollingLifecycle(tid, 4);
        engine.pauseProgram(false);
        vm.stopPrank();

        vm.warp(t0 + 300);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        (MarketTypes.RollingPhase phase,,, uint64 nextId, uint64 active,) = engine.getRollingLifecycle(tid);
        assertEq(uint8(phase), uint8(MarketTypes.RollingPhase.GenesisOpen));
        assertEq(active, 4);
        assertEq(nextId, 5);
    }

    function test_revert_deposit_when_rolling_halted() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("r_dep", 100, 10));
        bytes32 tid = _tid("r_dep");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 60_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.prank(admin);
        engine.haltRollingMarket(tid);

        token.mint(address(this), 1e18);
        token.approve(address(engine), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("RollingHaltedUserOps()")));
        engine.depositToSide(tid, 1, 0, 1);
    }

    /// @dev Gas for `genesisStartRolling` only (cold open via rolling cursor). See `.gas-snapshot`.
    function test_gas_genesis_start_rolling() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("g_gstart", 100, 10));
        bytes32 tid = _tid("g_gstart");
        engine.initializeMarket(tid);
        vm.stopPrank();
        vm.warp(70_000);
        vm.resumeGasMetering();
        vm.prank(worker);
        engine.genesisStartRolling(tid);
    }

    /// @dev Gas for `genesisLockRolling` (oracle + lock + open next). See `.gas-snapshot`.
    function test_gas_genesis_lock_rolling() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("g_glock", 100, 10));
        bytes32 tid = _tid("g_glock");
        engine.initializeMarket(tid);
        vm.stopPrank();
        uint64 t0 = 71_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);
        vm.warp(t0 + 100);
        oracle.set(feed, 100e8, t0 + 100, 0);
        vm.resumeGasMetering();
        vm.prank(worker);
        engine.genesisLockRolling(tid);
    }

    function test_gas_rolling_execute_one_tick() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rgas", 100, 10));
        bytes32 tid = _tid("rgas");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 30_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e18);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 1);

        vm.warp(t0 + 100);
        oracle.set(feed, 100e8, t0 + 100, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 2, 0, 1);

        vm.warp(t0 + 200);
        oracle.set(feed, 150e8, t0 + 200, 0);
        vm.resumeGasMetering();
        vm.prank(worker);
        engine.executeRollingRound(tid);
    }

    function test_rolling_upsert_threshold_allowed() public {
        vm.startPrank(admin);
        MarketEngine.UpsertTemplateParams memory p = _defaultTemplate("ok-roll");
        p.executionMode = MarketTypes.ExecutionMode.Rolling;
        p.rollingIntervalSeconds = 100;
        p.rollingBufferSeconds = 10;
        engine.upsertTemplate(p);
        vm.stopPrank();
    }
}
