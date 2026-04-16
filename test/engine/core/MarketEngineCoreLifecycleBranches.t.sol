// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";

contract MarketEngineCoreLifecycleBranchesTest is MarketEngineBase {
    uint256 private constant OVERSIZED_BATCH = 101;

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

    function test_openEpochsBatch_reverts_on_oversized_batch() public {
        bytes32[] memory ids = new bytes32[](OVERSIZED_BATCH);
        uint64[] memory epochIds = new uint64[](OVERSIZED_BATCH);
        uint64[] memory opens = new uint64[](OVERSIZED_BATCH);
        uint64[] memory locks = new uint64[](OVERSIZED_BATCH);
        uint64[] memory resolves = new uint64[](OVERSIZED_BATCH);

        vm.prank(worker);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidBatchSize(uint256)")), OVERSIZED_BATCH));
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

    function test_lockEpochsBatch_reverts_on_oversized_batch() public {
        bytes32[] memory ids = new bytes32[](OVERSIZED_BATCH);
        uint64[] memory epochIds = new uint64[](OVERSIZED_BATCH);

        vm.prank(worker);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidBatchSize(uint256)")), OVERSIZED_BATCH));
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

    function test_resolveEpochsBatch_reverts_on_oversized_batch() public {
        bytes32[] memory ids = new bytes32[](OVERSIZED_BATCH);
        uint64[] memory epochIds = new uint64[](OVERSIZED_BATCH);

        vm.prank(worker);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidBatchSize(uint256)")), OVERSIZED_BATCH));
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

    function test_open_lock_resolve_batch_revert_when_paused() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("paused-batch"));
        bytes32 tid = _tid("paused-batch");
        engine.initializeMarket(tid);
        engine.pauseProgram(true);
        vm.stopPrank();

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = tid;
        uint64[] memory epochIds = new uint64[](1);
        epochIds[0] = 1;
        uint64[] memory opens = new uint64[](1);
        opens[0] = 100;
        uint64[] memory locks = new uint64[](1);
        locks[0] = 200;
        uint64[] memory resolves = new uint64[](1);
        resolves[0] = 300;

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ProtocolPaused()")));
        engine.openEpochsBatch(ids, epochIds, opens, locks, resolves);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ProtocolPaused()")));
        engine.lockEpochsBatch(ids, epochIds);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("ProtocolPaused()")));
        engine.resolveEpochsBatch(ids, epochIds);
    }

    function test_cancelEpoch_reverts_when_epoch_already_resolved() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("cancel-resolved"));
        bytes32 tid = _tid("cancel-resolved");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 90_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 10, t0 + 20);

        vm.warp(t0 + 11);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 21);
        oracle.set(feed, 120e8, t0 + 21, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidEpochState()")));
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);
    }

    function test_openEpoch_reverts_when_lock_time_is_not_in_future() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("timing-past-lock"));
        bytes32 tid = _tid("timing-past-lock");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 100_000;
        vm.warp(t0);
        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidTiming()")));
        engine.openEpoch(tid, 1, t0 - 20, t0, t0 + 10);
    }

    function test_openEpoch_reverts_when_deposit_window_too_short() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("timing-short-deposit"));
        bytes32 tid = _tid("timing-short-deposit");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 100_100;
        vm.warp(t0);
        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidTiming()")));
        engine.openEpoch(tid, 1, t0 + 1, t0 + 9, t0 + 30);
    }

    function test_openEpoch_reverts_when_lock_window_too_short() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("timing-short-lock"));
        bytes32 tid = _tid("timing-short-lock");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 100_200;
        vm.warp(t0);
        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidTiming()")));
        engine.openEpoch(tid, 1, t0 + 10, t0 + 20, t0 + 29);
    }

    function test_openEpoch_reverts_when_epoch_duration_too_long() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("timing-too-long"));
        bytes32 tid = _tid("timing-too-long");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 100_300;
        vm.warp(t0);
        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidTiming()")));
        engine.openEpoch(tid, 1, t0 + 10, t0 + 20, t0 + uint64(31 days));
    }
}
