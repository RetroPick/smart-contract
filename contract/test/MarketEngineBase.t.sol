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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract MarketEngineBase is Test {
    MarketEngine internal engine;
    MockERC20 internal token;
    MockPriceOracle internal oracle;

    address internal admin = address(0xA11CE);
    address internal treasury = address(0xFEE);
    address internal worker = address(0xB0B);
    bytes32 internal feed = keccak256("feed");

    function setUp() public virtual {
        token = new MockERC20();
        oracle = new MockPriceOracle();

        MarketEngineDispatcher impl = new MarketEngineDispatcher();
        bytes memory initData = abi.encodeCall(
            MarketEngineDispatcher.initialize,
            (MarketEngine.InitConfig({
                stakeToken: IERC20(address(token)),
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

    function _tid(string memory slug) internal view returns (bytes32) {
        return engine.templateIdFromSlug(slug);
    }

    /// @dev Default Threshold market (legacy name kept for existing tests).
    function _defaultTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
        return _defaultThresholdTemplate(slug);
    }

    function _defaultThresholdTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
        p.slug = slug;
        p.assetSymbol = "ETH";
        p.oracleFeedId = feed;
        p.marketType = MarketTypes.MarketType.Threshold;
        p.condition = MarketTypes.Condition.AtOrAbove;
        p.thresholdRule = MarketTypes.ThresholdRule.Absolute;
        p.active = true;
        p.outcomeCount = 2;
        p.absoluteThresholdValueE8 = 100e8;
        p.switchFeeBps = 100;
        p.settlementFeeBps = 100;
        p.allowMultiSidePositions = true;
        p.executionMode = MarketTypes.ExecutionMode.Manual;
        p.rollingIntervalSeconds = 0;
        p.rollingBufferSeconds = 0;
        p.oracleMaxDelaySeconds = 0;
        p.oracleMaxConfidenceBps = 0;
    }

    function _directionManualTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
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

    /// @dev RangeClose: three buckets; bounds strictly increasing (see `_validateTemplate`).
    function _rangeCloseTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
        p.slug = slug;
        p.assetSymbol = "ETH";
        p.oracleFeedId = feed;
        p.marketType = MarketTypes.MarketType.RangeClose;
        p.condition = MarketTypes.Condition.AtOrAbove;
        p.thresholdRule = MarketTypes.ThresholdRule.None;
        p.active = true;
        p.outcomeCount = 3;
        p.rangeBoundsE8[0] = 100e8;
        p.rangeBoundsE8[1] = 200e8;
        p.switchFeeBps = 100;
        p.settlementFeeBps = 100;
        p.allowMultiSidePositions = true;
        p.executionMode = MarketTypes.ExecutionMode.Manual;
        p.rollingIntervalSeconds = 0;
        p.rollingBufferSeconds = 0;
        p.oracleMaxDelaySeconds = 0;
        p.oracleMaxConfidenceBps = 0;
    }

    function _directionRollingTemplate(string memory slug, uint64 intervalSec, uint64 bufferSec)
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
        p.absoluteThresholdValueE8 = 0;
        p.switchFeeBps = 100;
        p.settlementFeeBps = 100;
        p.allowMultiSidePositions = true;
        p.executionMode = MarketTypes.ExecutionMode.Rolling;
        p.rollingIntervalSeconds = intervalSec;
        p.rollingBufferSeconds = bufferSec;
        p.oracleMaxDelaySeconds = 0;
        p.oracleMaxConfidenceBps = 0;
    }

    function _thresholdRollingTemplate(string memory slug, uint64 intervalSec, uint64 bufferSec)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.executionMode = MarketTypes.ExecutionMode.Rolling;
        p.rollingIntervalSeconds = intervalSec;
        p.rollingBufferSeconds = bufferSec;
    }

    function _rangeCloseRollingTemplate(string memory slug, uint64 intervalSec, uint64 bufferSec)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _rangeCloseTemplate(slug);
        p.executionMode = MarketTypes.ExecutionMode.Rolling;
        p.rollingIntervalSeconds = intervalSec;
        p.rollingBufferSeconds = bufferSec;
    }

    /// @dev Genesis open then lock at `t0+interval` with oracle price at lock time (enters `Live`).
    function _rollingGenesisToLive(bytes32 templateId, uint64 t0, uint64 interval) internal {
        _rollingGenesisToLiveWithFeed(templateId, feed, t0, interval);
    }

    /// @dev Same as `_rollingGenesisToLive` but uses the template's oracle feed id (multi-asset tests).
    function _rollingGenesisToLiveWithFeed(bytes32 templateId, bytes32 oracleFeedId, uint64 t0, uint64 interval)
        internal
    {
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(templateId);

        vm.warp(t0 + interval);
        oracle.set(oracleFeedId, 100e8, t0 + interval, 0);
        vm.prank(worker);
        engine.genesisLockRolling(templateId);
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
