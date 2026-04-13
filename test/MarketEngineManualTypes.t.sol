// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "./MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../src/engine/IMarketEngine.sol";
import {MarketEngineDispatcher} from "../src/engine/MarketEngineDispatcher.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/// @notice Manual lifecycle per market type (rolling is Direction-only; these use open/lock/resolve).
contract MarketEngineManualTypesTest is MarketEngineBase {
    function test_initialize_reverts_on_zero_addresses() public {
        MarketEngineDispatcher impl = new MarketEngineDispatcher();

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        MarketEngine(UnsafeUpgrades.deployUUPSProxy(address(impl), abi.encodeCall(
            MarketEngineDispatcher.initialize,
            (MarketEngine.InitConfig({
                stakeToken: IERC20(address(0)),
                priceOracle: oracle,
                admin: admin,
                treasury: treasury,
                worker: worker,
                defaultSettlementFeeBps: 100,
                maxSwitchFeeBps: 500,
                maxOutcomes: 8,
                oracleKind: MarketTypes.OracleKind.Chainlink,
                oracleMaxDelaySeconds: 3600,
                oracleMaxConfidenceBps: 10_000
            }))
        )));

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        MarketEngine(UnsafeUpgrades.deployUUPSProxy(address(impl), abi.encodeCall(
            MarketEngineDispatcher.initialize,
            (MarketEngine.InitConfig({
                stakeToken: IERC20(address(token)),
                priceOracle: IPriceOracle(address(0)),
                admin: admin,
                treasury: treasury,
                worker: worker,
                defaultSettlementFeeBps: 100,
                maxSwitchFeeBps: 500,
                maxOutcomes: 8,
                oracleKind: MarketTypes.OracleKind.Chainlink,
                oracleMaxDelaySeconds: 3600,
                oracleMaxConfidenceBps: 10_000
            }))
        )));
    }

    function test_direction_lock_reverts_on_int256_min_oracle_price() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionManualTemplate("dir_min"));
        bytes32 tid = _tid("dir_min");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 930_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 500e18);

        vm.warp(t0 + 200);
        oracle.set(feed, type(int256).min, uint64(t0 + 200), 0);
        vm.prank(worker);
        vm.expectRevert(bytes4(keccak256("InvalidOraclePrice()")));
        engine.lockEpoch(tid, 1);
    }

    function test_manual_direction_full_lifecycle_claim() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionManualTemplate("dir_m"));
        bytes32 tid = _tid("dir_m");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 900_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 500e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 100e8, uint64(t0 + 200), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 110e8, uint64(t0 + 300), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        uint256 beforeBal = token.balanceOf(address(this));
        engine.claim(tid, 1);
        assertGt(token.balanceOf(address(this)), beforeBal);
    }

    function test_manual_direction_allows_chainlink_style_publishTime_before_lock_and_resolve() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionManualTemplate("dir_m2"));
        bytes32 tid = _tid("dir_m2");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 920_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 500e18);

        // Chainlink-style: feed's updatedAt can be slightly before the on-chain lock time,
        // but still within maxDelaySeconds (global default in test setup is 3600s).
        vm.warp(t0 + 200);
        oracle.set(feed, 100e8, uint64(t0 + 190), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        // Same at resolve: updatedAt can be before resolveAt, but must be fresh and monotonic vs checkpoint A.
        vm.warp(t0 + 300);
        oracle.set(feed, 110e8, uint64(t0 + 290), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        uint256 beforeBal = token.balanceOf(address(this));
        engine.claim(tid, 1);
        assertGt(token.balanceOf(address(this)), beforeBal);
    }

    function test_manual_range_close_full_lifecycle_claim() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_rangeCloseTemplate("range_m"));
        bytes32 tid = _tid("range_m");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 910_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 1, 800e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 150e8, uint64(t0 + 300), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        uint256 beforeBal = token.balanceOf(address(this));
        engine.claim(tid, 1);
        assertGt(token.balanceOf(address(this)), beforeBal);
    }
}
