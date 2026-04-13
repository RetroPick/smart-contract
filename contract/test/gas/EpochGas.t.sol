// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";

/// @notice Gas reference for keeper paths. Run `forge snapshot --match-contract EpochGasTest`.
contract EpochGasTest is MarketEngineBase {
    function _directionTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
        p.slug = slug;
        p.assetSymbol = "ETH";
        p.oracleFeedId = feed;
        p.marketType = MarketTypes.MarketType.Direction;
        p.condition = MarketTypes.Condition.AtOrAbove;
        p.thresholdRule = MarketTypes.ThresholdRule.None;
        p.active = true;
        p.outcomeCount = 2;
        p.absoluteThresholdValueE8 = 0;
        p.switchFeeBps = 100;
        p.settlementFeeBps = 100;
        p.allowMultiSidePositions = true;
        p.executionMode = MarketTypes.ExecutionMode.Manual;
        p.rollingIntervalSeconds = 0;
        p.rollingBufferSeconds = 0;
        p.oracleMaxDelaySeconds = 0;
        p.oracleMaxConfidenceBps = 0;
    }

    function test_gas_openEpoch_cold() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("g-open"));
        bytes32 tid = _tid("g-open");
        engine.initializeMarket(tid);
        vm.stopPrank();
        vm.warp(10_000);
        vm.resumeGasMetering();
        vm.prank(worker);
        engine.openEpoch(tid, 1, 10_100, 10_200, 10_300);
    }

    function test_gas_lockEpoch_threshold() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("g-lock"));
        bytes32 tid = _tid("g-lock");
        engine.initializeMarket(tid);
        vm.stopPrank();
        uint64 t0 = 20_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);
        vm.warp(t0 + 150);
        token.mint(address(this), 1e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1); // winning-side liquidity for later resolve
        vm.warp(t0 + 250);
        oracle.set(feed, 150e8, uint64(t0 + 250), 0);
        vm.resumeGasMetering();
        vm.prank(worker);
        engine.lockEpoch(tid, 1);
    }

    /// @dev Direction writes checkpoint A at lock (oracle read); higher gas than threshold lock.
    function test_gas_lockEpoch_direction() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_directionTemplate("g-lock-dir"));
        bytes32 tid = _tid("g-lock-dir");
        engine.initializeMarket(tid);
        vm.stopPrank();
        uint64 t0 = 21_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);
        vm.warp(t0 + 150);
        token.mint(address(this), 1e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1);
        vm.warp(t0 + 250);
        oracle.set(feed, 100e8, uint64(t0 + 250), 0);
        vm.resumeGasMetering();
        vm.prank(worker);
        engine.lockEpoch(tid, 1);
    }

    function test_gas_resolveEpoch_threshold() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("g-res"));
        bytes32 tid = _tid("g-res");
        engine.initializeMarket(tid);
        vm.stopPrank();
        uint64 t0 = 30_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);
        vm.warp(t0 + 150);
        token.mint(address(this), 1e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1);
        vm.warp(t0 + 250);
        oracle.set(feed, 150e8, uint64(t0 + 250), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);
        vm.warp(t0 + 350);
        oracle.set(feed, 150e8, uint64(t0 + 350), 0);
        vm.resumeGasMetering();
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);
    }

    function test_gas_resolveEpoch_direction() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_directionTemplate("g-res-dir"));
        bytes32 tid = _tid("g-res-dir");
        engine.initializeMarket(tid);
        vm.stopPrank();
        uint64 t0 = 31_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);
        vm.warp(t0 + 150);
        token.mint(address(this), 1e18);
        token.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1);
        vm.warp(t0 + 250);
        oracle.set(feed, 100e8, uint64(t0 + 250), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);
        vm.warp(t0 + 350);
        oracle.set(feed, 150e8, uint64(t0 + 350), 0);
        vm.resumeGasMetering();
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);
    }

    function test_gas_claim_afterResolve() public {
        vm.pauseGasMetering();
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("g-cl"));
        bytes32 tid = _tid("g-cl");
        engine.initializeMarket(tid);
        vm.stopPrank();
        uint64 t0 = 40_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);
        vm.warp(t0 + 150);
        token.mint(address(this), 1e24);
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
        vm.resumeGasMetering();
        engine.claim(tid, 1);
    }
}
