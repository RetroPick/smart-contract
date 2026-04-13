// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IMarketEngine as MarketEngine} from "../src/engine/IMarketEngine.sol";
import {MarketEngineDispatcher} from "../src/engine/MarketEngineDispatcher.sol";
import {MarketEngineAdminModule} from "../src/engine/modules/MarketEngineAdminModule.sol";
import {MarketEngineCoreLifecycleModule} from "../src/engine/modules/MarketEngineCoreLifecycleModule.sol";
import {MarketEngineUserOpsClaimsModule} from "../src/engine/modules/MarketEngineUserOpsClaimsModule.sol";
import {MarketEngineRollingLifecycleModule} from "../src/engine/modules/MarketEngineRollingLifecycleModule.sol";
import {MarketEngineViewModule} from "../src/engine/modules/MarketEngineViewModule.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";
import {MockERC20} from "../src/test/MockERC20.sol";
import {MockPriceOracle} from "../src/test/MockPriceOracle.sol";
import {MockPriceOracleWithRoundId} from "../src/test/MockPriceOracleWithRoundId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";

contract MarketEngineUXIntegrationsTest is Test {
    address internal admin = address(0xA11CE);
    address internal treasury = address(0xFEE);
    address internal worker = address(0xB0B);
    bytes32 internal feed = keccak256("feed");

    function _deployEngine(IERC20 token, IPriceOracle oracle_) internal returns (MarketEngine engine) {
        MarketEngineDispatcher impl = new MarketEngineDispatcher();
        bytes memory initData = abi.encodeCall(
            MarketEngineDispatcher.initialize,
            (MarketEngine.InitConfig({
                stakeToken: token,
                priceOracle: oracle_,
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
        );
        address proxy = UnsafeUpgrades.deployUUPSProxy(address(impl), initData);
        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));

        address adminModule = address(new MarketEngineAdminModule());
        address viewModule = address(new MarketEngineViewModule());
        address userOpsClaimsModule = address(new MarketEngineUserOpsClaimsModule());
        address coreLifecycleModule = address(new MarketEngineCoreLifecycleModule());
        address rollingLifecycleModule = address(new MarketEngineRollingLifecycleModule());

        vm.startPrank(admin);
        _wireModules(dispatcher, adminModule, viewModule, userOpsClaimsModule, coreLifecycleModule, rollingLifecycleModule);
        vm.stopPrank();

        engine = MarketEngine(proxy);
    }

    function _directionManualTemplate(MarketEngine engine, string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p.slug = slug;
        p.assetSymbol = "ETH";
        p.oracleFeedId = feed;
        p.marketType = MarketTypes.MarketType.Direction;
        p.condition = MarketTypes.Condition.AtOrAbove;
        p.thresholdRule = MarketTypes.ThresholdRule.None;
        p.active = true;
        p.outcomeCount = 2;
        p.switchFeeBps = 100;
        p.settlementFeeBps = 100;
        p.allowMultiSidePositions = true;
        p.executionMode = MarketTypes.ExecutionMode.Manual;
        p.oracleMaxDelaySeconds = 0;
        p.oracleMaxConfidenceBps = 0;
        // other fields default
        engine; // silence unused warning (solc may warn in some profiles)
    }

    function test_claimMany_matches_two_single_claims() public {
        MockERC20 tokenA = new MockERC20();
        MockPriceOracle oracleA = new MockPriceOracle();
        MarketEngine engineMany = _deployEngine(IERC20(address(tokenA)), oracleA);

        MockERC20 tokenB = new MockERC20();
        MockPriceOracle oracleB = new MockPriceOracle();
        MarketEngine engineSingles = _deployEngine(IERC20(address(tokenB)), oracleB);

        address user = address(0xCAFE);
        address other = address(0xBEEF);

        vm.startPrank(admin);
        engineMany.upsertTemplate(_directionManualTemplate(engineMany, "dir"));
        bytes32 tidMany = engineMany.templateIdFromSlug("dir");
        engineMany.initializeMarket(tidMany);
        vm.stopPrank();

        vm.startPrank(admin);
        engineSingles.upsertTemplate(_directionManualTemplate(engineSingles, "dir"));
        bytes32 tidSingles = engineSingles.templateIdFromSlug("dir");
        engineSingles.initializeMarket(tidSingles);
        vm.stopPrank();

        uint64 t0 = 1_000_000;

        // Epoch 1
        vm.warp(t0);
        vm.prank(worker);
        engineMany.openEpoch(tidMany, 1, t0 + 100, t0 + 200, t0 + 300);
        vm.prank(worker);
        engineSingles.openEpoch(tidSingles, 1, t0 + 100, t0 + 200, t0 + 300);

        tokenA.mint(user, 1e24);
        tokenA.mint(other, 1e24);
        tokenB.mint(user, 1e24);
        tokenB.mint(other, 1e24);

        vm.startPrank(user);
        tokenA.approve(address(engineMany), type(uint256).max);
        tokenB.approve(address(engineSingles), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(other);
        tokenA.approve(address(engineMany), type(uint256).max);
        tokenB.approve(address(engineSingles), type(uint256).max);
        vm.stopPrank();

        vm.warp(t0 + 150);
        vm.prank(user);
        engineMany.depositToSide(tidMany, 1, 0, 500e18);
        vm.prank(other);
        engineMany.depositToSide(tidMany, 1, 1, 300e18);

        vm.prank(user);
        engineSingles.depositToSide(tidSingles, 1, 0, 500e18);
        vm.prank(other);
        engineSingles.depositToSide(tidSingles, 1, 1, 300e18);

        vm.warp(t0 + 200);
        oracleA.set(feed, 100e8, uint64(t0 + 200), 0);
        oracleB.set(feed, 100e8, uint64(t0 + 200), 0);
        vm.prank(worker);
        engineMany.lockEpoch(tidMany, 1);
        vm.prank(worker);
        engineSingles.lockEpoch(tidSingles, 1);

        vm.warp(t0 + 300);
        // Bull wins
        oracleA.set(feed, 110e8, uint64(t0 + 300), 0);
        oracleB.set(feed, 110e8, uint64(t0 + 300), 0);
        vm.prank(worker);
        engineMany.resolveEpoch(tidMany, 1);
        vm.prank(worker);
        engineSingles.resolveEpoch(tidSingles, 1);

        // Epoch 2 (must open after epoch 1 resolved)
        vm.warp(t0 + 310);
        vm.prank(worker);
        engineMany.openEpoch(tidMany, 2, t0 + 320, t0 + 420, t0 + 520);
        vm.prank(worker);
        engineSingles.openEpoch(tidSingles, 2, t0 + 320, t0 + 420, t0 + 520);

        vm.warp(t0 + 350);
        vm.prank(user);
        engineMany.depositToSide(tidMany, 2, 0, 200e18);
        vm.prank(other);
        engineMany.depositToSide(tidMany, 2, 1, 400e18);

        vm.prank(user);
        engineSingles.depositToSide(tidSingles, 2, 0, 200e18);
        vm.prank(other);
        engineSingles.depositToSide(tidSingles, 2, 1, 400e18);

        vm.warp(t0 + 420);
        oracleA.set(feed, 200e8, uint64(t0 + 420), 0);
        oracleB.set(feed, 200e8, uint64(t0 + 420), 0);
        vm.prank(worker);
        engineMany.lockEpoch(tidMany, 2);
        vm.prank(worker);
        engineSingles.lockEpoch(tidSingles, 2);

        vm.warp(t0 + 520);
        // Bull wins again (so both epochs are claimable for `user`)
        oracleA.set(feed, 210e8, uint64(t0 + 520), 0);
        oracleB.set(feed, 210e8, uint64(t0 + 520), 0);
        vm.prank(worker);
        engineMany.resolveEpoch(tidMany, 2);
        vm.prank(worker);
        engineSingles.resolveEpoch(tidSingles, 2);

        uint256 beforeMany = tokenA.balanceOf(user);
        uint256 beforeSingles = tokenB.balanceOf(user);

        uint64[] memory epochs = new uint64[](2);
        epochs[0] = 1;
        epochs[1] = 2;
        vm.prank(user);
        engineMany.claimMany(tidMany, epochs);

        vm.prank(user);
        engineSingles.claim(tidSingles, 1);
        vm.prank(user);
        engineSingles.claim(tidSingles, 2);

        uint256 gotMany = tokenA.balanceOf(user) - beforeMany;
        uint256 gotSingles = tokenB.balanceOf(user) - beforeSingles;
        assertEq(gotMany, gotSingles);
    }

    function test_userEpochs_indexes_once_and_supports_pagination() public {
        MockERC20 token = new MockERC20();
        MockPriceOracle oracle = new MockPriceOracle();
        MarketEngine engine = _deployEngine(IERC20(address(token)), oracle);

        vm.startPrank(admin);
        engine.upsertTemplate(_directionManualTemplate(engine, "dir"));
        bytes32 tid = engine.templateIdFromSlug("dir");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 2_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        address user = address(0xCAFE);
        token.mint(user, 1e24);
        vm.startPrank(user);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 100e18);
        // second deposit same epoch should not duplicate indexing
        engine.depositToSide(tid, 1, 0, 50e18);
        vm.stopPrank();

        (uint64[] memory first, uint256 next) = engine.getUserEpochs(tid, user, 0, 1);
        assertEq(first.length, 1);
        assertEq(first[0], 1);
        assertEq(next, 1);

        (uint64[] memory empty, uint256 next2) = engine.getUserEpochs(tid, user, 1, 10);
        assertEq(empty.length, 0);
        assertEq(next2, 1);
    }

    function test_depositToSideFor_indexes_beneficiary() public {
        MockERC20 token = new MockERC20();
        MockPriceOracle oracle = new MockPriceOracle();
        MarketEngine engine = _deployEngine(IERC20(address(token)), oracle);

        vm.startPrank(admin);
        engine.upsertTemplate(_directionManualTemplate(engine, "dir"));
        bytes32 tid = engine.templateIdFromSlug("dir");
        engine.initializeMarket(tid);
        engine.setDepositExecutor(address(0xD00D), true);
        vm.stopPrank();

        uint64 t0 = 3_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        address executor = address(0xD00D);
        address beneficiary = address(0xB0B0);

        token.mint(executor, 1e24);
        vm.startPrank(executor);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSideFor(beneficiary, tid, 1, 0, 123e18);
        vm.stopPrank();

        (uint64[] memory epochs, uint256 next) = engine.getUserEpochs(tid, beneficiary, 0, 10);
        assertEq(epochs.length, 1);
        assertEq(epochs[0], 1);
        assertEq(next, 1);
    }

    function test_oracleRoundId_monotonicity_reverts_on_decrease() public {
        MockERC20 token = new MockERC20();
        MockPriceOracleWithRoundId oracle = new MockPriceOracleWithRoundId();
        MarketEngine engine = _deployEngine(IERC20(address(token)), IPriceOracle(address(oracle)));

        vm.startPrank(admin);
        engine.upsertTemplate(_directionManualTemplate(engine, "dir"));
        bytes32 tid = engine.templateIdFromSlug("dir");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 4_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 100e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 10, 100e8, uint64(t0 + 200), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        // roundId goes backwards: should revert
        oracle.set(feed, 9, 110e8, uint64(t0 + 300), 0);
        vm.prank(worker);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OracleSampleNotMonotonic(uint80,uint80,uint64,uint64)")),
                uint80(9),
                uint80(10),
                uint64(t0 + 300),
                uint64(t0 + 200)
            )
        );
        engine.resolveEpoch(tid, 1);
    }

    function test_oracleRoundId_allows_same_roundId_between_lock_and_resolve_when_publishTime_monotonic() public {
        MockERC20 token = new MockERC20();
        MockPriceOracleWithRoundId oracle = new MockPriceOracleWithRoundId();
        MarketEngine engine = _deployEngine(IERC20(address(token)), IPriceOracle(address(oracle)));

        vm.startPrank(admin);
        engine.upsertTemplate(_directionManualTemplate(engine, "dir_eq"));
        bytes32 tid = engine.templateIdFromSlug("dir_eq");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 4_100_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 150);
        engine.depositToSide(tid, 1, 0, 100e18);

        // Lock A
        vm.warp(t0 + 200);
        oracle.set(feed, 10, 100e8, uint64(t0 + 200), 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        // Resolve B (same roundId and publishTime is allowed, as long as it doesn't go backwards)
        vm.warp(t0 + 300);
        oracle.set(feed, 10, 110e8, uint64(t0 + 200), 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);
    }

    function _wireModules(
        MarketEngineDispatcher dispatcher,
        address adminModule,
        address viewModule,
        address userOpsClaimsModule,
        address coreLifecycleModule,
        address rollingLifecycleModule
    ) internal {
        dispatcher.setSelectorModule(bytes4(keccak256("pauseProgram(bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setTreasury(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setWorkerAuthority(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setDepositExecutor(address,bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setYieldRouter(address,uint16)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setLmRewardsEnabled(bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("keeperClaimLmRewards(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("yieldEmergencyWithdraw(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("initializeMarket(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("withdrawFees(bytes32,uint256)")), adminModule, false);

        dispatcher.setSelectorModule(bytes4(keccak256("getUserEpochs(bytes32,address,uint256,uint256)")), viewModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("getVaultBalances(bytes32)")), viewModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("getRollingLifecycle(bytes32)")), viewModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("getEpoch(bytes32,uint64)")), viewModule, false);

        dispatcher.setSelectorModule(bytes4(keccak256("depositToSide(bytes32,uint64,uint8,uint256)")), userOpsClaimsModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("depositToSideFor(address,bytes32,uint64,uint8,uint256)")), userOpsClaimsModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("switchSide(bytes32,uint64,uint8,uint8,uint256)")), userOpsClaimsModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("claim(bytes32,uint64)")), userOpsClaimsModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("claimMany(bytes32,uint64[])")), userOpsClaimsModule, false);

        dispatcher.setSelectorModule(
            bytes4(
                keccak256(
                    "upsertTemplate((string,string,bytes32,uint8,uint8,uint8,bool,uint8,int256,int256[7],uint16,uint16,bool,uint8,uint64,uint64,uint64,uint16))"
                )
            ),
            coreLifecycleModule,
            false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("openEpoch(bytes32,uint64,uint64,uint64,uint64)")), coreLifecycleModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("openEpochsBatch(bytes32[],uint64[],uint64[],uint64[],uint64[])")), coreLifecycleModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("lockEpoch(bytes32,uint64)")), coreLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("lockEpochsBatch(bytes32[],uint64[])")), coreLifecycleModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("resolveEpoch(bytes32,uint64)")), coreLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("resolveEpochsBatch(bytes32[],uint64[])")), coreLifecycleModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("cancelEpoch(bytes32,uint64,uint8,bool)")), coreLifecycleModule, false
        );

        dispatcher.setSelectorModule(bytes4(keccak256("genesisStartRolling(bytes32)")), rollingLifecycleModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("genesisLockRolling(bytes32)")), rollingLifecycleModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("executeRollingRound(bytes32)")), rollingLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("executeRollingRoundBatch(bytes32[])")), rollingLifecycleModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("haltRollingMarket(bytes32)")), rollingLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("cancelRollingEpochWhileHalted(bytes32,uint64,uint8,bool)")), rollingLifecycleModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("resetRollingLifecycle(bytes32,uint64)")), rollingLifecycleModule, false
        );
    }
}

