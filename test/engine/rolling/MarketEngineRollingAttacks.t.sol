// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";

/// @notice Abuse-resistant behavior: double keeper ticks, halted user ops.
contract MarketEngineRollingAttacksTest is MarketEngineBase {
    uint64 internal constant INTER = 100;

    function test_attack_double_execute_same_timestamp_reverts() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("dbl", INTER, 10));
        bytes32 tid = _tid("dbl");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 700_000;
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

        uint64 execTs = t0 + 2 * INTER;
        vm.warp(execTs);
        oracle.set(feed, 110e8, execTs, 0);
        vm.startPrank(worker);
        engine.executeRollingRound(tid);
        vm.expectRevert(bytes4(keccak256("TooEarlyToResolve()")));
        engine.executeRollingRound(tid);
        vm.stopPrank();
    }

    function test_attack_deposit_reverts_when_halted() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("halt_d", INTER, 10));
        bytes32 tid = _tid("halt_d");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 710_000;
        _rollingGenesisToLive(tid, t0, INTER);

        vm.prank(admin);
        engine.haltRollingMarket(tid);

        token.mint(address(this), 1e18);
        token.approve(address(engine), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("RollingHaltedUserOps()")));
        engine.depositToSide(tid, 2, 0, 1);
    }

    function test_attack_switch_side_reverts_when_halted() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("halt_sw", INTER, 10));
        bytes32 tid = _tid("halt_sw");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 720_000;
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

        vm.prank(admin);
        engine.haltRollingMarket(tid);

        vm.expectRevert(bytes4(keccak256("RollingHaltedUserOps()")));
        engine.switchSide(tid, 2, 0, 1, 100e18);
    }
}
