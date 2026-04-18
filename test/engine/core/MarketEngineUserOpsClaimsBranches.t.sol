// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";

contract MarketEngineUserOpsClaimsBranchesTest is MarketEngineBase {
    function test_claimMany_revertsOnEmptyEpochIds() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("claim-many-empty"));
        bytes32 tid = _tid("claim-many-empty");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64[] memory epochIds = new uint64[](0);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidBatchSize(uint256)")), uint256(0)));
        engine.claimMany(tid, epochIds);
    }

    function test_claimMany_revertsOnOversizedBatch() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("claim-many-oversized"));
        bytes32 tid = _tid("claim-many-oversized");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64[] memory epochIds = new uint64[](101);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidBatchSize(uint256)")), uint256(101)));
        engine.claimMany(tid, epochIds);
    }

    function test_claimMany_skips_epochs_that_become_already_claimed_mid_batch() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("claim-many-soft-skip"));
        bytes32 tid = _tid("claim-many-soft-skip");
        engine.initializeMarket(tid);
        vm.stopPrank();

        address loser = address(0xB0B);
        uint64 t0 = 8_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 100, t0 + 200);

        token.mint(address(this), 1000e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000e18);

        token.mint(loser, 1000e18);
        vm.startPrank(loser);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 1, 1000e18);
        vm.stopPrank();

        vm.warp(t0 + 201);
        oracle.set(feed, 200e8, uint64(t0 + 201), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 202);
        oracle.set(feed, 200e8, uint64(t0 + 202), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        uint64[] memory epochIds = new uint64[](2);
        epochIds[0] = 1;
        epochIds[1] = 1;

        uint256 balBefore = token.balanceOf(address(this));
        engine.claimMany(tid, epochIds);
        uint256 claimed = token.balanceOf(address(this)) - balBefore;

        assertGt(claimed, 1000e18);
        assertEq(engine.getEpoch(tid, 1).claimedTotal, claimed);
    }

    function test_switchSide_revertsPartialSwitchWhenSingleSideOnly() public {
        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("single-side-switch");
        p.allowMultiSidePositions = false;
        vm.startPrank(admin);
        engine.upsertTemplate(p);
        bytes32 tid = _tid("single-side-switch");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 7_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 100, t0 + 200);

        token.mint(address(this), 1000e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000e18);

        vm.expectRevert(bytes4(keccak256("PartialSwitchDisallowed()")));
        engine.switchSide(tid, 1, 0, 1, 500e18);
    }

    function test_switchSide_reverts_when_outcome_index_exceeds_max_outcomes() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("invalid-outcome"));
        bytes32 tid = _tid("invalid-outcome");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 7_100_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 20, t0 + 200, t0 + 300);

        token.mint(address(this), 1000e18);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 30);
        engine.depositToSide(tid, 1, 0, 1000e18);

        vm.expectRevert(bytes4(keccak256("InvalidOutcome()")));
        engine.switchSide(tid, 1, 8, 1, 100e18);
    }
}
