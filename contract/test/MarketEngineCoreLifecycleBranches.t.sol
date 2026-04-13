// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "./MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";

contract MarketEngineCoreLifecycleBranchesTest is MarketEngineBase {
    function test_upsertTemplate_revertsForEmptyAndTooLongFields() public {
        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("ok");
        p.slug = "";
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidTemplate()")));
        engine.upsertTemplate(p);

        p = _defaultThresholdTemplate("ok2");
        p.assetSymbol = "";
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidTemplate()")));
        engine.upsertTemplate(p);
    }

    function test_upsertTemplate_revertsForRollingInvalidParams() public {
        MarketEngine.UpsertTemplateParams memory p = _directionRollingTemplate("roll-invalid", 0, 0);
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("RollingInvalidParams()")));
        engine.upsertTemplate(p);

        p = _directionRollingTemplate("roll-invalid-2", 10, 10);
        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("RollingInvalidParams()")));
        engine.upsertTemplate(p);
    }

    function test_openEpochsBatch_revertsOnLengthMismatch() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("b-open"));
        bytes32 tid = _tid("b-open");
        engine.initializeMarket(tid);
        vm.stopPrank();

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = tid;
        uint64[] memory epochIds = new uint64[](2);
        epochIds[0] = 1;
        epochIds[1] = 2;
        uint64[] memory opens = new uint64[](1);
        opens[0] = 100;
        uint64[] memory locks = new uint64[](1);
        locks[0] = 200;
        uint64[] memory resolves = new uint64[](1);
        resolves[0] = 300;

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidTemplate()")));
        engine.openEpochsBatch(ids, epochIds, opens, locks, resolves);
    }

    function test_lockEpochsBatch_revertsOnLengthMismatch() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("b-lock"));
        bytes32 tid = _tid("b-lock");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 1000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 10, t0 + 20);

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = tid;
        uint64[] memory epochIds = new uint64[](2);
        epochIds[0] = 1;
        epochIds[1] = 2;

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidTemplate()")));
        engine.lockEpochsBatch(ids, epochIds);
    }

    function test_resolveEpochsBatch_revertsOnLengthMismatch() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("b-resolve"));
        bytes32 tid = _tid("b-resolve");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 10_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 10, t0 + 20);
        vm.warp(t0 + 11);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = tid;
        uint64[] memory epochIds = new uint64[](2);
        epochIds[0] = 1;
        epochIds[1] = 2;

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidTemplate()")));
        engine.resolveEpochsBatch(ids, epochIds);
    }

    function test_cancelEpoch_revertsForNoneReason() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("cancel-none"));
        bytes32 tid = _tid("cancel-none");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 20_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 10, t0 + 20);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidEpochState()")));
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.NoneReason, false);
    }

    function test_cancelEpoch_revertsForRollingLiveMarket() public {
        vm.prank(admin);
        engine.upsertTemplate(_directionRollingTemplate("roll-cancel", 60, 5));
        bytes32 tid = _tid("roll-cancel");
        vm.prank(admin);
        engine.initializeMarket(tid);

        _rollingGenesisToLive(tid, 30_000, 60);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ManualModeOnly()")));
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);
    }
}
