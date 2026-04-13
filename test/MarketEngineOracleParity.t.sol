// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MarketEngineBase} from "./MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../src/engine/IMarketEngine.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";

/// @notice Colosseum parity: per-epoch oracle policy snapshot + rolling `min(prev, cur)` effective delay.
contract MarketEngineOracleParityTest is MarketEngineBase {
    uint64 internal constant INTER = 100;

    function test_lock_uses_epoch_oracle_snapshot_after_template_changes() public {
        vm.startPrank(admin);
        MarketEngine.UpsertTemplateParams memory p = _directionManualTemplate("snap");
        p.oracleMaxDelaySeconds = 100;
        engine.upsertTemplate(p);
        bytes32 tid = _tid("snap");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 openAt = 10_000;
        uint64 lockAt = 11_000;
        uint64 resolveAt = 12_000;
        vm.warp(openAt);
        vm.prank(worker);
        engine.openEpoch(tid, 1, openAt, lockAt, resolveAt);

        vm.startPrank(admin);
        MarketEngine.UpsertTemplateParams memory p2 = _directionManualTemplate("snap");
        p2.oracleMaxDelaySeconds = 9_000;
        engine.upsertTemplate(p2);
        vm.stopPrank();

        oracle.set(feed, 100e8, lockAt, 1e8);

        vm.warp(lockAt);
        vm.expectCall(
            address(oracle),
            abi.encodeWithSelector(IPriceOracle.getNormalizedPrice.selector, feed, uint64(100), uint64(lockAt))
        );
        vm.prank(worker);
        engine.lockEpoch(tid, 1);
    }

    function test_executeRollingRound_uses_min_effective_delay_between_epochs() public {
        uint64 t0 = 100_000;

        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("rollmin", INTER, 10));
        bytes32 tid = _tid("rollmin");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        IERC20(address(token)).approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1e18);

        vm.startPrank(admin);
        MarketEngine.UpsertTemplateParams memory p2 = _directionRollingTemplate("rollmin", INTER, 10);
        p2.oracleMaxDelaySeconds = 60;
        engine.upsertTemplate(p2);
        vm.stopPrank();

        uint64 lock1 = t0 + INTER;
        vm.warp(lock1);
        oracle.set(feed, 100e8, lock1, 1e8);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        uint64 tickTs = t0 + 2 * INTER;
        vm.warp(tickTs);
        oracle.set(feed, 101e8, tickTs, 1e8);

        vm.expectCall(
            address(oracle),
            abi.encodeWithSelector(IPriceOracle.getNormalizedPrice.selector, feed, uint64(60), uint64(tickTs))
        );
        vm.prank(worker);
        engine.executeRollingRound(tid);
    }

    function test_executeRollingRound_threshold_uses_prev_effective_delay_only() public {
        uint64 t0 = 200_000;

        vm.startPrank(admin);
        engine.upsertTemplate(_thresholdRollingTemplate("thr_min", INTER, 10));
        bytes32 tid = _tid("thr_min");
        engine.initializeMarket(tid);
        vm.stopPrank();

        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        IERC20(address(token)).approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 1e18);

        // Change template before genesis lock so epoch 2 snapshots this stricter delay.
        vm.startPrank(admin);
        MarketEngine.UpsertTemplateParams memory p2 = _thresholdRollingTemplate("thr_min", INTER, 10);
        p2.oracleMaxDelaySeconds = 60;
        engine.upsertTemplate(p2);
        vm.stopPrank();

        uint64 lock1 = t0 + INTER;
        vm.warp(lock1);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        // Tick resolves epoch 1 (prev) and locks epoch 2 (no checkpoint A); oracle call should use prev delay (global 3600).
        uint64 tickTs = t0 + 2 * INTER;
        vm.warp(tickTs);
        oracle.set(feed, 101e8, tickTs, 1e8);

        vm.expectCall(
            address(oracle),
            abi.encodeWithSelector(IPriceOracle.getNormalizedPrice.selector, feed, uint64(3600), uint64(tickTs))
        );
        vm.prank(worker);
        engine.executeRollingRound(tid);
    }
}
