// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {MarketEngineState} from "../../../src/engine/MarketEngineState.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockYieldRouterReentrant} from "../../../src/test/MockYieldRouterReentrant.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/// @notice Reentrancy regression tests: malicious yield router reenters user ops via `depositToSideFor` (deposit executor).
contract MarketEngineReentrancyTest is MarketEngineBase {
    MockYieldRouterReentrant internal badRouter;
    address internal alice = address(0xA11);

    function setUp() public override {
        super.setUp();
        badRouter = new MockYieldRouterReentrant(address(engine));
        vm.startPrank(admin);
        engine.setYieldRouter(address(badRouter), 0);
        engine.setDepositExecutor(address(badRouter), true);
        vm.stopPrank();

        token.mint(address(badRouter), 100 ether);
        vm.prank(address(badRouter));
        token.approve(address(engine), type(uint256).max);
    }

    function _openManualEpoch(bytes32 tid, uint64 t0) internal {
        vm.prank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("re"));
        vm.prank(admin);
        engine.initializeMarket(tid);
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, uint64(t0), uint64(t0 + 100), uint64(t0 + 200));
    }

    /// @dev `switchSide` calls `withdrawScaled` without try/catch; nested `depositToSideFor` must revert.
    function test_switchSide_revertsOnYieldRouterReentrancy() public {
        bytes32 tid = _tid("re");
        uint64 t0 = 5_000_000;
        _openManualEpoch(tid, t0);

        // Credit `routedPrincipal` so `_withdrawSwitchFeePrincipal` calls `withdrawScaled` (mock returned 0 attribution before).
        badRouter.setDepositScaledReturn(1);

        token.mint(alice, 10_000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        badRouter.setReenterDepositForParams(alice, tid, 1, 0, 1 wei);
        badRouter.setReenterWithdraw(true);

        vm.prank(alice);
        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        engine.switchSide(tid, 1, 0, 1, 500 ether);
    }

    /// @dev `depositToSide` wraps `depositScaled` in try/catch; reentrancy revert surfaces as `YieldRouterDepositFailed`.
    function test_depositToSide_emitsYieldRouterDepositFailedOnReentrantRouter() public {
        bytes32 tid = _tid("re");
        uint64 t0 = 6_000_000;
        _openManualEpoch(tid, t0);

        badRouter.setReenterDepositForParams(alice, tid, 1, 0, 1 wei);
        badRouter.setReenterDeposit(true);

        uint256 routeAmount = (1000 ether * 9500) / 10_000;

        token.mint(alice, 10_000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit MarketEngineState.YieldRouterDepositFailed(tid, routeAmount);

        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        MarketTypes.Epoch memory e = engine.epochs(tid, 1);
        assertEq(e.totalPool, 1000 ether);
    }

    /// @dev Manual `resolveEpoch` now hard-reverts on yield-router withdrawal failure, including router-driven reentrancy.
    function test_resolveEpoch_revertsOnYieldRouterReentrancy() public {
        bytes32 tid = _tid("re-resolve");
        uint64 t0 = 7_000_000;
        vm.prank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("re-resolve"));
        vm.prank(admin);
        engine.initializeMarket(tid);

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, uint64(t0), uint64(t0 + 100), uint64(t0 + 200));

        badRouter.setDepositScaledReturn(1);
        token.mint(alice, 10_000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        vm.warp(t0 + 110);
        oracle.set(feed, 100e8, uint64(t0 + 110), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        badRouter.setReenterDepositForParams(alice, tid, 1, 0, 1 wei);
        badRouter.setReenterWithdraw(true);

        vm.warp(t0 + 210);
        oracle.set(feed, 200e8, uint64(t0 + 210), 0);

        vm.prank(worker);
        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        engine.resolveEpoch(tid, 1);

        assertEq(engine.yieldRouterFailureCount(), 0);
        MarketTypes.Epoch memory e = engine.getEpoch(tid, 1);
        assertFalse(e.claimable);
    }
}
