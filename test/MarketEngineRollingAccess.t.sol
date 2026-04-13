// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "./MarketEngineBase.t.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";

/// @notice Access control and manual API gating on rolling templates.
contract MarketEngineRollingAccessTest is MarketEngineBase {
    uint64 internal constant INTER = 100;
    address internal stranger = address(0xBEEF);

    function test_attack_non_worker_reverts_genesis() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("nw", INTER, 10));
        bytes32 tid = _tid("nw");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.prank(stranger);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.genesisStartRolling(tid);
    }

    function test_rolling_lock_epoch_reverts_manual_mode_only() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("lock_m", INTER, 10));
        bytes32 tid = _tid("lock_m");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.warp(500_000);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.warp(500_000 + INTER);
        oracle.set(feed, 100e8, 500_000 + INTER, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ManualModeOnly()")));
        engine.lockEpoch(tid, 2);
    }

    function test_rolling_resolve_epoch_reverts_manual_mode_only() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("res_m", INTER, 10));
        bytes32 tid = _tid("res_m");
        engine.initializeMarket(tid);
        vm.stopPrank();

        _rollingGenesisToLive(tid, 510_000, INTER);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ManualModeOnly()")));
        engine.resolveEpoch(tid, 1);
    }

    function test_rolling_cancel_epoch_live_reverts_manual_mode_only() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("can_m", INTER, 10));
        bytes32 tid = _tid("can_m");
        engine.initializeMarket(tid);
        vm.stopPrank();

        _rollingGenesisToLive(tid, 520_000, INTER);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ManualModeOnly()")));
        engine.cancelEpoch(tid, 2, MarketTypes.CancelReason.ManualAdminCancel, false);
    }

    function test_worker_ops_blocked_when_paused() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("pause", INTER, 10));
        bytes32 tid = _tid("pause");
        engine.initializeMarket(tid);
        engine.pauseProgram(true);
        vm.stopPrank();

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ProtocolPaused()")));
        engine.genesisStartRolling(tid);
    }

    function test_attack_non_admin_halt_reverts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("halt", INTER, 10));
        bytes32 tid = _tid("halt");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.warp(530_000);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        vm.prank(stranger);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.haltRollingMarket(tid);
    }
}
