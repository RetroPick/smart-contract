// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {MarketEngineState} from "../../../src/engine/MarketEngineState.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockPartialYieldRouter} from "../../helpers/MockPartialYieldRouter.sol";

/// @notice Adversarial tests for principal shortfall at the yield-router boundary.
contract MarketEngineYieldRouterShortfallTest is MarketEngineBase {
    MockPartialYieldRouter internal partialRouter;
    address internal alice = address(0xA11CE);

    function setUp() public override {
        super.setUp();
        partialRouter = new MockPartialYieldRouter(token, 5_000);
        vm.prank(admin);
        engine.setYieldRouter(address(partialRouter), 0);
    }

    function _initManualThresholdMarket(bytes32 tid, uint64 t0) internal {
        vm.prank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("shortfall"));
        vm.prank(admin);
        engine.initializeMarket(tid);

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, uint64(t0), uint64(t0 + 10), uint64(t0 + 20));
    }

    function test_cancelEpoch_reverts_onPartialRouterPrincipalReturn() public {
        bytes32 tid = _tid("shortfall");
        uint64 t0 = 8_000_000;
        _initManualThresholdMarket(tid, t0);

        token.mint(alice, 1000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        uint256 routed = engine.epochs(tid, 1).routedPrincipal;
        uint256 expectedRecovered = routed / 2;
        vm.prank(worker);
        vm.expectRevert(abi.encodeWithSelector(MarketEngineState.YieldRouterShortfall.selector, routed, expectedRecovered));
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

        MarketTypes.Epoch memory e = engine.epochs(tid, 1);
        assertEq(uint256(e.status), uint256(MarketTypes.EpochStatus.Open), "epoch should remain open after revert");
        assertEq(e.routedPrincipal, routed, "routed principal should remain unchanged after revert");
    }

    function test_resolveEpoch_reverts_onPartialRouterPrincipalReturn() public {
        bytes32 tid = _tid("shortfall");
        uint64 t0 = 8_100_000;
        _initManualThresholdMarket(tid, t0);

        token.mint(alice, 1000 ether);
        vm.startPrank(alice);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1000 ether);
        vm.stopPrank();

        vm.warp(t0 + 11);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        uint256 routed = engine.epochs(tid, 1).routedPrincipal;
        uint256 expectedRecovered = routed / 2;
        vm.warp(t0 + 21);
        oracle.set(feed, 200e8, uint64(t0 + 21), 0);

        vm.prank(worker);
        vm.expectRevert(abi.encodeWithSelector(MarketEngineState.YieldRouterShortfall.selector, routed, expectedRecovered));
        engine.resolveEpoch(tid, 1);

        MarketTypes.Epoch memory e = engine.epochs(tid, 1);
        assertEq(uint256(e.status), uint256(MarketTypes.EpochStatus.Locked), "epoch should remain locked after revert");
        assertEq(e.routedPrincipal, routed, "routed principal should remain unchanged after revert");
        assertFalse(e.claimable, "epoch must not become claimable after shortfall revert");
    }
}
