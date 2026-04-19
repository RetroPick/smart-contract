// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketEngineState} from "../../../src/engine/MarketEngineState.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockPriceOracle} from "../../../src/test/MockPriceOracle.sol";
import {MockPriceOracleWithRoundId} from "../../../src/test/MockPriceOracleWithRoundId.sol";

contract MarketEngineCoreMarketUpgradeTest is MarketEngineBase {
    function test_admin_can_set_all_oracle_family_adapters() public {
        MockPriceOracle rate = new MockPriceOracle();
        MockPriceOracle smart = new MockPriceOracle();
        MockPriceOracle macroOracleMock = new MockPriceOracle();
        MockPriceOracle equity = new MockPriceOracle();

        vm.startPrank(admin);
        engine.setRateOracle(address(rate));
        engine.setSmartDataOracle(address(smart));
        engine.setMacroOracle(address(macroOracleMock));
        engine.setEquityOracle(address(equity));
        vm.stopPrank();

        assertEq(address(engine.rateOracle()), address(rate));
        assertEq(address(engine.smartDataOracle()), address(smart));
        assertEq(address(engine.macroOracle()), address(macroOracleMock));
        assertEq(address(engine.equityOracle()), address(equity));
    }

    function test_threshold_routes_to_rate_oracle_for_apr_style_market() public {
        MockPriceOracle rate = new MockPriceOracle();

        vm.startPrank(admin);
        engine.setRateOracle(address(rate));
        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("staking-apr-weekly");
        p.marketType = MarketTypes.MarketType.Threshold;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
        p.absoluteThresholdValueE8 = 50e8;
        engine.upsertTemplate(p);
        bytes32 tid = _tid("staking-apr-weekly");
        engine.initializeMarket(tid);
        vm.stopPrank();

        token.mint(address(this), 1_000e18);
        token.approve(address(engine), type(uint256).max);

        uint64 t0 = 10_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 400e18);
        vm.prank(address(0xBEEF));
        token.mint(address(0xBEEF), 400e18);
        vm.prank(address(0xBEEF));
        token.approve(address(engine), type(uint256).max);
        vm.prank(address(0xBEEF));
        engine.depositToSide(tid, 1, 1, 400e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        // Price oracle and rate oracle intentionally diverge; resolver must use rate adapter.
        oracle.set(feed, 10e8, t0 + 300, 0);
        rate.set(feed, 80e8, t0 + 300, 0);
        vm.warp(t0 + 300);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        MarketTypes.Epoch memory e = engine.getEpoch(tid, 1);
        assertEq(e.winningOutcomeMask, 1 << 0);
    }

    function test_manual_epoch_uses_snapshotted_oracle_class_after_template_update() public {
        MockPriceOracle rate = new MockPriceOracle();

        vm.startPrank(admin);
        engine.setRateOracle(address(rate));

        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("oracle-snapshot");
        engine.upsertTemplate(p);
        bytes32 tid = _tid("oracle-snapshot");
        engine.initializeMarket(tid);
        vm.stopPrank();

        token.mint(address(this), 1_000e18);
        token.approve(address(engine), type(uint256).max);

        uint64 t0 = 20_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 1, 400e18); // NO side for threshold >= 100

        // Update template oracle routing after epoch open. Epoch-1 should keep original routing snapshot.
        vm.startPrank(admin);
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
        engine.upsertTemplate(p);
        vm.stopPrank();

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        // Diverge adapters intentionally:
        // - global price oracle says 80 (NO wins)
        // - rate oracle says 120 (YES would win if live template routing is used)
        oracle.set(feed, 80e8, t0 + 300, 0);
        rate.set(feed, 120e8, t0 + 300, 0);
        vm.warp(t0 + 300);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        MarketTypes.Epoch memory e = engine.getEpoch(tid, 1);
        assertEq(e.winningOutcomeMask, 1 << 1);
    }

    function test_threshold_rejects_none_rule() public {
        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("threshold-none-invalid");
        p.marketType = MarketTypes.MarketType.Threshold;
        p.thresholdRule = MarketTypes.ThresholdRule.None;
        p.absoluteThresholdValueE8 = 1e8;

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidTemplate()")));
        engine.upsertTemplate(p);
    }

    function test_threshold_allows_absolute_rule_with_zero_threshold() public {
        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("threshold-abs-zero");
        p.marketType = MarketTypes.MarketType.Threshold;
        p.thresholdRule = MarketTypes.ThresholdRule.Absolute;
        p.absoluteThresholdValueE8 = 0;

        vm.prank(admin);
        engine.upsertTemplate(p);
    }

    function test_admin_can_reset_oracle_cursor_after_adapter_swap() public {
        MockPriceOracleWithRoundId rateA = new MockPriceOracleWithRoundId();
        MockPriceOracleWithRoundId rateB = new MockPriceOracleWithRoundId();

        vm.startPrank(admin);
        engine.setRateOracle(address(rateA));
        engine.upsertTemplate(_bitcoinIrcDirectionTemplate("rate-cursor-reset"));
        bytes32 tid = _tid("rate-cursor-reset");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 30_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 10, t0 + 100, t0 + 200);

        rateA.set(feed, 100, 100e8, t0 + 100, 0);
        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.prank(admin);
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

        vm.startPrank(admin);
        engine.pauseProgram(true);
        engine.setRateOracle(address(rateB));
        engine.resetOracleCursor(tid, feed);
        engine.pauseProgram(false);
        vm.stopPrank();

        uint64 t1 = 31_000;
        vm.warp(t1);
        vm.prank(worker);
        engine.openEpoch(tid, 2, t1 + 10, t1 + 100, t1 + 200);

        rateB.set(feed, 1, 120e8, t1 + 100, 0);
        vm.warp(t1 + 100);
        vm.prank(worker);
        engine.lockEpoch(tid, 2);

        MarketTypes.Epoch memory e = engine.getEpoch(tid, 2);
        assertTrue(e.checkpointA.written);
        assertEq(e.checkpointA.valueE8, 120e8);
    }

    function test_rate_oracle_replacement_reverts_while_live_epoch_is_open() public {
        MockPriceOracle rateA = new MockPriceOracle();
        MockPriceOracle rateB = new MockPriceOracle();

        vm.startPrank(admin);
        engine.setRateOracle(address(rateA));
        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("rate-live-replace");
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
        p.absoluteThresholdValueE8 = 100e8;
        engine.upsertTemplate(p);
        bytes32 tid = _tid("rate-live-replace");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 33_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 10, t0 + 100, t0 + 200);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(MarketEngineState.OracleAdapterChangeRequiresPause.selector, address(rateA), address(rateB))
        );
        engine.setRateOracle(address(rateB));
    }

    function test_paused_rate_oracle_replacement_between_epochs_is_allowed() public {
        MockPriceOracleWithRoundId rateA = new MockPriceOracleWithRoundId();
        MockPriceOracleWithRoundId rateB = new MockPriceOracleWithRoundId();

        vm.startPrank(admin);
        engine.setRateOracle(address(rateA));
        engine.upsertTemplate(_bitcoinIrcDirectionTemplate("rate-paused-replace"));
        bytes32 tid = _tid("rate-paused-replace");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 34_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 10, t0 + 100, t0 + 200);

        rateA.set(feed, 100, 100e8, t0 + 100, 0);
        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.prank(admin);
        engine.cancelEpoch(tid, 1, MarketTypes.CancelReason.ManualAdminCancel, false);

        vm.startPrank(admin);
        engine.pauseProgram(true);
        engine.setRateOracle(address(rateB));
        engine.resetOracleCursor(tid, feed);
        engine.pauseProgram(false);
        vm.stopPrank();
    }

    function test_paused_rate_oracle_replacement_does_not_change_active_epoch_source() public {
        MockPriceOracle rateA = new MockPriceOracle();
        MockPriceOracle rateB = new MockPriceOracle();

        vm.startPrank(admin);
        engine.setRateOracle(address(rateA));
        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("rate-source-snapshot");
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
        p.absoluteThresholdValueE8 = 100e8;
        engine.upsertTemplate(p);
        bytes32 tid = _tid("rate-source-snapshot");
        engine.initializeMarket(tid);
        vm.stopPrank();

        token.mint(address(this), 1_000e18);
        token.approve(address(engine), type(uint256).max);

        uint64 t0 = 35_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 1, 400e18);

        vm.startPrank(admin);
        engine.pauseProgram(true);
        engine.setRateOracle(address(rateB));
        engine.pauseProgram(false);
        vm.stopPrank();

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        rateA.set(feed, 80e8, t0 + 300, 0);
        rateB.set(feed, 120e8, t0 + 300, 0);
        vm.warp(t0 + 300);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        MarketTypes.Epoch memory e = engine.getEpoch(tid, 1);
        assertEq(e.winningOutcomeMask, 1 << 1);
    }

    function test_reset_oracle_cursor_reverts_while_manual_epoch_locked() public {
        MockPriceOracleWithRoundId rate = new MockPriceOracleWithRoundId();

        vm.startPrank(admin);
        engine.setRateOracle(address(rate));
        engine.upsertTemplate(_bitcoinIrcDirectionTemplate("rate-cursor-live-reset"));
        bytes32 tid = _tid("rate-cursor-live-reset");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 32_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 10, t0 + 100, t0 + 200);

        rate.set(feed, 100, 100e8, t0 + 100, 0);
        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketEngineState.OracleCursorResetWhileEpochActive.selector,
                tid,
                uint64(1),
                uint8(MarketTypes.EpochStatus.Locked)
            )
        );
        engine.resetOracleCursor(tid, feed);
    }
}
