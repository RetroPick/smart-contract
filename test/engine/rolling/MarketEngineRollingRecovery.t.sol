// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {IPriceOracle} from "../../../src/interfaces/IPriceOracle.sol";

/// @notice Pause, reset, and invalid recovery parameters.
contract MarketEngineRollingRecoveryTest is MarketEngineBase {
    uint64 internal constant INTER = 100;

    function test_recovery_reset_reverts_when_not_paused() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rst_np", INTER, 10));
        bytes32 tid = _tid("rst_np");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 600_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 50e18);

        vm.warp(t0 + INTER);
        oracle.set(feed, 100e8, t0 + INTER, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + 2 * INTER);
        oracle.set(feed, 110e8, t0 + 2 * INTER, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        vm.prank(admin);
        engine.haltRollingMarket(tid);

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("ProtocolPaused()")));
        engine.resetRollingLifecycle(tid, 10);
    }

    function test_recovery_reset_reverts_when_not_halted() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rst_ph", INTER, 10));
        bytes32 tid = _tid("rst_ph");
        engine.initializeMarket(tid);
        engine.pauseProgram(true);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("RollingWrongPhase()")));
        engine.resetRollingLifecycle(tid, 5);
    }

    function test_recovery_reset_reverts_next_id_too_low() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rst_low", INTER, 10));
        bytes32 tid = _tid("rst_low");
        engine.initializeMarket(tid);
        vm.stopPrank();

        _rollingGenesisToLive(tid, 610_000, INTER);

        vm.startPrank(admin);
        engine.pauseProgram(true);
        engine.haltRollingMarket(tid);
        vm.expectRevert(bytes4(keccak256("InvalidRollingRecovery()")));
        engine.resetRollingLifecycle(tid, 1);
        vm.stopPrank();
    }

    function test_recovery_cancel_while_halted_reverts_when_not_paused() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("can_np", INTER, 10));
        bytes32 tid = _tid("can_np");
        engine.initializeMarket(tid);
        vm.stopPrank();

        _rollingGenesisToLive(tid, 620_000, INTER);
        vm.prank(admin);
        engine.haltRollingMarket(tid);

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("ProtocolPaused()")));
        engine.cancelRollingEpochWhileHalted(tid, 1, MarketTypes.CancelReason.EmergencyPaused, false);
    }

    function test_recovery_reset_reverts_when_halted_epoch_not_cleared() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rst_uncleared", INTER, 10));
        bytes32 tid = _tid("rst_uncleared");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 630_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 50e18);

        vm.startPrank(admin);
        engine.haltRollingMarket(tid);
        engine.pauseProgram(true);
        vm.expectRevert(bytes4(keccak256("InvalidRollingRecovery()")));
        engine.resetRollingLifecycle(tid, 2);
        vm.stopPrank();
    }

    function test_recovery_reset_reverts_when_previous_locked_epoch_still_uncleared() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rst_prev_locked", INTER, 10));
        bytes32 tid = _tid("rst_prev_locked");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 640_000;
        _rollingGenesisToLive(tid, t0, INTER);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 2, 0, 50e18);

        uint64 execTs = t0 + 2 * INTER;
        vm.warp(execTs);
        vm.mockCallRevert(
            address(oracle),
            abi.encodeWithSelector(IPriceOracle.getNormalizedPrice.selector, feed, uint64(3600), uint64(execTs)),
            hex""
        );
        vm.prank(worker);
        engine.executeRollingRound(tid);
        vm.clearMockedCalls();

        vm.startPrank(admin);
        engine.pauseProgram(true);
        engine.cancelRollingEpochWhileHalted(tid, 2, MarketTypes.CancelReason.EmergencyPaused, false);
        vm.expectRevert(bytes4(keccak256("InvalidRollingRecovery()")));
        engine.resetRollingLifecycle(tid, 4);
        vm.stopPrank();
    }
}
