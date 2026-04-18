// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockBrokenYieldRouter} from "../../helpers/MockBrokenYieldRouter.sol";

/// @notice Exploit PoC tests for lifecycle security vulnerabilities:
///   H10 — cancelEpoch permanently blocked when yield router fails
///   H15 — cancelRollingEpochWhileHalted doesn't withdraw yield router principal
contract MarketEngineLifecycleSecurity is MarketEngineBase {
    MockBrokenYieldRouter internal brokenRouter;

    function setUp() public override {
        super.setUp();
        brokenRouter = new MockBrokenYieldRouter();
    }

    // ─── H10: cancelEpoch blocked by broken yield router ──────────────────────

    /// @notice Serious-TVL posture: cancelEpoch must revert when routed principal cannot be recovered.
    function test_cancelEpoch_revertsWhenYieldRouterFails() public {
        bytes32 tid = _tid("eth-cancel");
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("eth-cancel"));
        engine.initializeMarket(tid);
        engine.setYieldRouter(address(brokenRouter), 0);
        vm.stopPrank();

        uint64 t0 = 1_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 100, t0 + 200);

        address alice = address(0xA11CE1);
        token.mint(alice, 1000e18);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000e18);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(MockBrokenYieldRouter.WithdrawAlwaysFails.selector);
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);
    }

    /// @notice cancelEpoch with no yield router must still work correctly.
    function test_cancelEpoch_noYieldRouter_works() public {
        bytes32 tid = _tid("eth-norouter");
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("eth-norouter"));
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 2_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 100, t0 + 200);

        address alice = address(0xA11CE2);
        token.mint(alice, 500e18);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 500e18);
        vm.stopPrank();

        vm.prank(admin);
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

        vm.prank(alice);
        engine.claim(tid, 1);
        assertGt(token.balanceOf(alice), 0, "Alice should receive refund");
    }

    // ─── H15: cancelRollingEpochWhileHalted missing yield withdrawal ──────────

    /// @notice Serious-TVL posture: rolling cancel must also revert if routed principal cannot be recovered.
    function test_cancelRollingWhileHalted_reverts_withBrokenYieldRouter() public {
        bytes32 tid = _tid("eth-roll-cancel");
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("eth-roll-cancel", 100, 10));
        engine.initializeMarket(tid);
        engine.setYieldRouter(address(brokenRouter), 0);
        vm.stopPrank();

        uint64 t0 = 3_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        address alice = address(0xA11CE3);
        token.mint(alice, 500e18);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 500e18);
        vm.stopPrank();

        vm.startPrank(admin);
        engine.haltRollingMarket(tid);
        engine.pauseProgram(true);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(MockBrokenYieldRouter.WithdrawAlwaysFails.selector);
        engine.cancelRollingEpochWhileHalted(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);
    }

    /// @notice Rolling cancel with no yield router works correctly.
    function test_cancelRollingWhileHalted_noYieldRouter_works() public {
        bytes32 tid = _tid("eth-roll-simple");
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("eth-roll-simple", 100, 10));
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 4_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        address alice = address(0xA11CE4);
        token.mint(alice, 300e18);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 300e18);
        vm.stopPrank();

        vm.startPrank(admin);
        engine.haltRollingMarket(tid);
        engine.pauseProgram(true);
        vm.stopPrank();

        vm.prank(admin);
        engine.cancelRollingEpochWhileHalted(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

        vm.prank(alice);
        engine.claim(tid, 1);
        assertGt(token.balanceOf(alice), 0, "Alice should receive refund");
    }
}
