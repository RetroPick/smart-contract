// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
        _wireModules(
            dispatcher, adminModule, viewModule, userOpsClaimsModule, coreLifecycleModule, rollingLifecycleModule
        );
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

    function _defaultThresholdTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
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
        p.templateOracleKind = MarketTypes.OracleKind.Chainlink;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_PRICE;
    }

    function _directionManualTemplate(string memory slug)
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
        p.executionMode = MarketTypes.ExecutionMode.Manual;
        p.rollingIntervalSeconds = 0;
        p.rollingBufferSeconds = 0;
        p.oracleMaxDelaySeconds = 0;
        p.oracleMaxConfidenceBps = 0;
        p.templateOracleKind = MarketTypes.OracleKind.Chainlink;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_PRICE;
    }

    /// @dev RangeClose: three buckets; bounds strictly increasing (see `_validateTemplate`).
    function _rangeCloseTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
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
        p.templateOracleKind = MarketTypes.OracleKind.Chainlink;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_PRICE;
    }

    function _anchorTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Threshold;
        p.absoluteThresholdValueE8 = 0;
        p.anchorPriceE8 = 100e8;
    }

    function _velocityTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Velocity;
        p.thresholdRule = MarketTypes.ThresholdRule.None;
        p.outcomeCount = 3;
        p.rangeBoundsE8[0] = 100e8;
        p.rangeBoundsE8[1] = 200e8;
        p.absoluteThresholdValueE8 = 0;
        p.velocityBoundsE4[0] = 500;
        p.velocityBoundsE4[1] = 1500;
    }

    function _ladderTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Ladder;
        p.thresholdRule = MarketTypes.ThresholdRule.None;
        p.outcomeCount = 3;
        p.rangeBoundsE8[0] = 100e8;
        p.rangeBoundsE8[1] = 200e8;
        p.absoluteThresholdValueE8 = 0;
        p.ladderBoundsE8[0] = 100e8;
        p.ladderBoundsE8[1] = 200e8;
        p.ladderPayoutWeightsBps[0] = 8_000;
        p.ladderPayoutWeightsBps[1] = 9_000;
        p.ladderPayoutWeightsBps[2] = 10_000;
    }

    function _convergenceTemplate(string memory slug, bytes32 feedB)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Convergence;
        p.thresholdRule = MarketTypes.ThresholdRule.Absolute;
        p.oracleFeedIdB = feedB;
        p.spreadToleranceBps = 50;
    }

    function _compositeTemplate(string memory slug, bytes32 feedB, bytes32 feedC)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Composite;
        p.thresholdRule = MarketTypes.ThresholdRule.Absolute;
        p.compositeFeedCount = 3;
        p.compositeFeedIds[0] = feed;
        p.compositeFeedIds[1] = feedB;
        p.compositeFeedIds[2] = feedC;
        p.compositeConditions[0] = MarketTypes.Condition.AtOrAbove;
        p.compositeConditions[1] = MarketTypes.Condition.AtOrAbove;
        p.compositeConditions[2] = MarketTypes.Condition.AtOrAbove;
        p.compositeLogic = MarketTypes.CompositeLogic.Majority;
    }

    function _corridorTemplate(string memory slug, address eventOracle)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _rangeCloseTemplate(slug);
        p.marketType = MarketTypes.MarketType.Corridor;
        p.templateOracleKind = MarketTypes.OracleKind.TrustedReporter;
        p.eventOracle = eventOracle;
        p.oracleFeedId = bytes32(0);
        p.outcomeCount = 3;
        p.rangeBoundsE8[0] = 99_500_000;
        p.rangeBoundsE8[1] = 100_500_000;
    }

    function _cascadeTemplate(string memory slug, address eventOracle, bool downward)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _rangeCloseTemplate(slug);
        p.marketType = MarketTypes.MarketType.Cascade;
        p.templateOracleKind = MarketTypes.OracleKind.TrustedReporter;
        p.eventOracle = eventOracle;
        p.oracleFeedId = bytes32(0);
        p.outcomeCount = 4;
        p.cascadeDownward = downward;
    }

    function _volatilityBandTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Threshold;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
    }

    function _stakingAprTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Threshold;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
    }

    function _bitcoinIrcDirectionTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _directionManualTemplate(slug);
        p.marketType = MarketTypes.MarketType.Direction;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
    }

    function _bitcoinIrcThresholdTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Threshold;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_RATE;
    }

    function _navThresholdTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Threshold;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_SMARTDATA;
    }

    function _macroEventTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.marketType = MarketTypes.MarketType.Threshold;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_MACRO;
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
        dispatcher.registerModule(adminModule, keccak256(adminModule.code));
        dispatcher.registerModule(viewModule, keccak256(viewModule.code));
        dispatcher.registerModule(userOpsClaimsModule, keccak256(userOpsClaimsModule.code));
        dispatcher.registerModule(coreLifecycleModule, keccak256(coreLifecycleModule.code));
        dispatcher.registerModule(rollingLifecycleModule, keccak256(rollingLifecycleModule.code));

        dispatcher.setSelectorModule(bytes4(keccak256("pauseProgram(bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setTreasury(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setWorkerAuthority(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setDepositExecutor(address,bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setYieldRouter(address,uint16)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("resetYieldRouterFailures()")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setRateOracle(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setSmartDataOracle(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setMacroOracle(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setEquityOracle(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setLmRewardsEnabled(bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("keeperClaimLmRewards(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("yieldEmergencyWithdraw(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("initializeMarket(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("withdrawFees(bytes32,uint256)")), adminModule, false);

        dispatcher.setSelectorModule(
            bytes4(keccak256("getUserEpochs(bytes32,address,uint256,uint256)")), viewModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("getVaultBalances(bytes32)")), viewModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("getRollingLifecycle(bytes32)")), viewModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("getEpoch(bytes32,uint64)")), viewModule, false);

        dispatcher.setSelectorModule(
            bytes4(keccak256("depositToSide(bytes32,uint64,uint8,uint256)")), userOpsClaimsModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("depositToSideFor(address,bytes32,uint64,uint8,uint256)")), userOpsClaimsModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("switchSide(bytes32,uint64,uint8,uint8,uint256)")), userOpsClaimsModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("claim(bytes32,uint64)")), userOpsClaimsModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("claimMany(bytes32,uint64[])")), userOpsClaimsModule, false);

        dispatcher.setSelectorModule(MarketEngine.upsertTemplate.selector, coreLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("openEpoch(bytes32,uint64,uint64,uint64,uint64)")), coreLifecycleModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("openEpochsBatch(bytes32[],uint64[],uint64[],uint64[],uint64[])")),
            coreLifecycleModule,
            false
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
