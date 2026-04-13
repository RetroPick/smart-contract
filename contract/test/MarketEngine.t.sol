// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "./MarketEngineBase.t.sol";

contract MarketEngineTest is MarketEngineBase {
    function test_fullLifecycle_threshold() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("eth-up"));
        bytes32 tid = _tid("eth-up");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 1_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        vm.warp(t0 + 150);
        token.mint(address(this), 1_000_000e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000e18);

        vm.warp(t0 + 250);
        oracle.set(feed, 150e8, uint64(t0 + 250), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 350);
        oracle.set(feed, 150e8, uint64(t0 + 350), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        uint256 beforeBal = token.balanceOf(address(this));
        engine.claim(tid, 1);
        assertGt(token.balanceOf(address(this)), beforeBal);
    }

    function test_vaultsMatchBalance() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("m"));
        bytes32 tid = _tid("m");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.warp(150);
        vm.prank(worker);
        engine.openEpoch(tid, 1, 100, 200, 300);

        vm.warp(150);
        token.mint(address(this), 5000e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 2000e18);

        (uint256 a, uint256 c, uint256 f) = engine.getVaultBalances(tid);
        assertEq(a + c + f, 2000e18);
        assertEq(token.balanceOf(address(engine)), 2000e18);
    }

    function test_openEpochsBatch_twoTemplates() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("b1"));
        engine.upsertTemplate(_defaultTemplate("b2"));
        bytes32 t1 = _tid("b1");
        bytes32 t2 = _tid("b2");
        engine.initializeMarket(t1);
        engine.initializeMarket(t2);
        vm.stopPrank();

        vm.warp(500);
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = t1;
        ids[1] = t2;
        uint64[] memory eid = new uint64[](2);
        eid[0] = 1;
        eid[1] = 1;
        uint64[] memory o = new uint64[](2);
        o[0] = 600;
        o[1] = 600;
        uint64[] memory l = new uint64[](2);
        l[0] = 700;
        l[1] = 700;
        uint64[] memory r = new uint64[](2);
        r[0] = 800;
        r[1] = 800;
        vm.prank(worker);
        engine.openEpochsBatch(ids, eid, o, l, r);

        vm.warp(650);
        token.mint(address(this), 10e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(t1, 1, 0, 1e18);
        engine.depositToSide(t2, 1, 0, 1e18);
        (uint256 a1,,) = engine.getVaultBalances(t1);
        (uint256 a2,,) = engine.getVaultBalances(t2);
        assertEq(a1, 1e18);
        assertEq(a2, 1e18);
    }

    function test_switchMovesFeeToFeeVault() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("sw"));
        bytes32 tid = _tid("sw");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.warp(200);
        vm.prank(worker);
        engine.openEpoch(tid, 1, 100, 500, 600);

        vm.warp(200);
        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 10_000e18);
        engine.switchSide(tid, 1, 0, 1, 10_000e18);

        (,, uint256 fees) = engine.getVaultBalances(tid);
        assertEq(fees, 100e18);
    }
}
