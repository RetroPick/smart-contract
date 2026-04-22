// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketEngineDispatcher} from "../../../src/engine/MarketEngineDispatcher.sol";
import {MarketEngineCoreLifecycleModule} from "../../../src/engine/modules/MarketEngineCoreLifecycleModule.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockFeeOnTransferERC20} from "../../../src/test/MockFeeOnTransferERC20.sol";
import {MockPriceOracle} from "../../../src/test/MockPriceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MarketEngineStakeTokenCompatibilityTest is Test {
    MarketEngine internal engine;
    MockFeeOnTransferERC20 internal token;
    MockPriceOracle internal oracle;

    address internal admin = address(0xA11CE);
    address internal worker = address(0xB0B);
    address internal treasury = address(0xFEE);
    bytes32 internal feed = keccak256("fee-token-feed");
    bytes32 internal tid;

    function setUp() public {
        token = new MockFeeOnTransferERC20(1_000);
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

        vm.startPrank(admin);
        _wireModules(dispatcher, address(new MarketEngineCoreLifecycleModule()));
        vm.stopPrank();

        engine = MarketEngine(proxy);

        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("fee-token-market"));
        tid = _tid("fee-token-market");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 1_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 100, t0 + 200);
    }

    function test_depositToSide_reverts_for_fee_on_transfer_stake_token() public {
        token.mint(address(this), 1_000e18);
        token.approve(address(engine), type(uint256).max);

        vm.expectRevert(bytes4(keccak256("NonStandardStakeToken()")));
        engine.depositToSide(tid, 1, 0, 100e18);
    }

    function test_depositToSideFor_reverts_for_fee_on_transfer_stake_token() public {
        address executor = address(0xE1);
        address beneficiary = address(0xBEEF);

        vm.prank(admin);
        engine.setDepositExecutor(executor, true);

        token.mint(executor, 1_000e18);
        vm.startPrank(executor);
        token.approve(address(engine), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NonStandardStakeToken()")));
        engine.depositToSideFor(beneficiary, tid, 1, 0, 100e18);
        vm.stopPrank();
    }

    function _tid(string memory slug) internal view returns (bytes32) {
        return engine.templateIdFromSlug(slug);
    }

    function _defaultTemplate(string memory slug) internal view returns (MarketEngine.UpsertTemplateParams memory p) {
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

    function _wireModules(MarketEngineDispatcher dispatcher, address coreLifecycleModule) internal {
        _allowAndRegister(dispatcher, coreLifecycleModule);
        dispatcher.setSelectorModule(MarketEngine.upsertTemplate.selector, coreLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("openEpoch(bytes32,uint64,uint64,uint64,uint64)")), coreLifecycleModule, false
        );
    }

    function _allowAndRegister(MarketEngineDispatcher dispatcher, address module) internal {
        bytes32 codeHash = keccak256(module.code);
        dispatcher.allowModuleCodeHash(codeHash);
        dispatcher.registerModule(module, codeHash);
    }
}
