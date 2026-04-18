// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {MarketEngineState} from "../../../src/engine/MarketEngineState.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockPartialYieldRouter} from "../../helpers/MockPartialYieldRouter.sol";
import {MockLyingEmergencyYieldRouter} from "../../helpers/MockLyingEmergencyYieldRouter.sol";

/// @notice Recovery tests for serious-TVL router failure semantics.
contract MarketEngineEmergencyRecoveryTest is MarketEngineBase {
    MockPartialYieldRouter internal router;
    address internal alice = address(0xA11CE);

    function setUp() public override {
        super.setUp();
        router = new MockPartialYieldRouter(token, 10_000);
        vm.prank(admin);
        engine.setYieldRouter(address(router), 0);
    }

    function _initManualThresholdMarket(bytes32 tid, uint64 t0, string memory slug) internal {
        vm.prank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate(slug));
        vm.prank(admin);
        engine.initializeMarket(tid);

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, uint64(t0), uint64(t0 + 10), uint64(t0 + 20));
    }

    function test_cancelEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile() public {
        bytes32 tid = _tid("recover-cancel");
        uint64 t0 = 9_000_000;
        _initManualThresholdMarket(tid, t0, "recover-cancel");

        token.mint(alice, 1000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        uint256 routed = engine.epochs(tid, 1).routedPrincipal;
        router.setRevertOnWithdraw(true);

        vm.prank(worker);
        vm.expectRevert();
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketEngineState.UnreconciledRecoveryInsufficient.selector, tid, uint256(0), routed
            )
        );
        engine.reconcileEpochRoutedPrincipal(tid, 1, routed);

        vm.startPrank(admin);
        router.setRevertOnWithdraw(false);
        engine.yieldEmergencyWithdraw(tid);
        assertEq(engine.unreconciledRecoveredByTemplate(tid), 950 ether);
        engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
        vm.stopPrank();

        assertEq(engine.unreconciledRecoveredByTemplate(tid), 0);

        vm.prank(worker);
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

        vm.prank(alice);
        engine.claim(tid, 1);
        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function test_resolveEpoch_routerRevert_requires_emergencyWithdraw_and_reconcile() public {
        bytes32 tid = _tid("recover-resolve");
        uint64 t0 = 9_100_000;
        _initManualThresholdMarket(tid, t0, "recover-resolve");

        token.mint(alice, 1000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        vm.warp(t0 + 11);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        uint256 routed = engine.epochs(tid, 1).routedPrincipal;
        router.setRevertOnWithdraw(true);

        vm.warp(t0 + 21);
        oracle.set(feed, 200e8, uint64(t0 + 21), 0);
        vm.prank(worker);
        vm.expectRevert();
        engine.resolveEpoch(tid, 1);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketEngineState.UnreconciledRecoveryInsufficient.selector, tid, uint256(0), routed
            )
        );
        engine.reconcileEpochRoutedPrincipal(tid, 1, routed);

        vm.startPrank(admin);
        router.setRevertOnWithdraw(false);
        engine.yieldEmergencyWithdraw(tid);
        assertEq(engine.unreconciledRecoveredByTemplate(tid), 950 ether);
        engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
        vm.stopPrank();

        assertEq(engine.unreconciledRecoveredByTemplate(tid), 0);

        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        vm.prank(alice);
        engine.claim(tid, 1);
        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function test_emergencyWithdraw_doesNotCredit_recovery_bucket_on_lying_router() public {
        bytes32 tid = _tid("recover-lie");
        uint64 t0 = 9_200_000;
        _initManualThresholdMarket(tid, t0, "recover-lie");

        MockLyingEmergencyYieldRouter liar = new MockLyingEmergencyYieldRouter(950 ether);
        vm.prank(admin);
        engine.setYieldRouter(address(liar), 0);

        token.mint(alice, 1000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        uint256 routed = engine.epochs(tid, 1).routedPrincipal;
        assertEq(routed, 950 ether);

        vm.prank(admin);
        engine.yieldEmergencyWithdraw(tid);

        assertEq(engine.unreconciledRecoveredByTemplate(tid), 0);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketEngineState.UnreconciledRecoveryInsufficient.selector, tid, uint256(0), routed
            )
        );
        engine.reconcileEpochRoutedPrincipal(tid, 1, routed);
    }

    function test_emergencyWithdraw_books_excess_recovered_yield_to_fees_after_full_reconcile() public {
        bytes32 tid = _tid("recover-yield");
        uint64 t0 = 9_300_000;
        _initManualThresholdMarket(tid, t0, "recover-yield");

        token.mint(alice, 1000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        uint256 routed = engine.epochs(tid, 1).routedPrincipal;
        assertEq(routed, 950 ether);

        // Simulate accrued yield sitting in the router before emergency unwind.
        token.mint(address(router), 50 ether);

        vm.prank(admin);
        engine.yieldEmergencyWithdraw(tid);

        assertEq(engine.unreconciledRecoveredByTemplate(tid), 1000 ether);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit MarketEngineState.EmergencyRecoveredYieldBooked(tid, 50 ether);
        engine.reconcileEpochRoutedPrincipal(tid, 1, routed);

        (uint256 active, uint256 claims, uint256 fees) = engine.getVaultBalances(tid);
        assertEq(active, 1000 ether);
        assertEq(claims, 0);
        assertEq(fees, 50 ether);
        assertEq(engine.ledgers(tid).feeReserveTotal, 50 ether);
        assertEq(engine.unreconciledRecoveredByTemplate(tid), 0);
        assertEq(token.balanceOf(address(engine)), active + claims + fees);
    }
}
