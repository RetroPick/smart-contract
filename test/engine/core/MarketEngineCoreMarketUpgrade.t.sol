// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockPriceOracle} from "../../../src/test/MockPriceOracle.sol";

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
}
