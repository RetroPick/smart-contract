// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";
import {ChainlinkAdapter} from "../../src/adapters/ChainlinkAdapter.sol";
import {RateAdapter} from "../../src/oracle/RateAdapter.sol";
import {SmartDataAdapter} from "../../src/oracle/SmartDataAdapter.sol";
import {MacroAdapter} from "../../src/oracle/MacroAdapter.sol";

contract MarketTypeBaseForkParityTest is MarketEngineBase {
    address internal constant BASE_SEQUENCER = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
    address internal constant BASE_ETH_USD = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address internal constant BASE_BTC_USD = 0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F;
    address internal constant BASE_USDC_USD = 0x7E860098f58bbFc8648a4311b374B1d669a2BC9B;

    bool internal forkEnabled;

    RateAdapter internal rateAdapter;
    SmartDataAdapter internal smartDataAdapter;
    MacroAdapter internal macroAdapter;

    function setUp() public override {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("BASE_RPC", string(""));
        }
        if (bytes(rpc).length != 0) {
            vm.createSelectFork(rpc);
            forkEnabled = true;
        }

        super.setUp();

        if (!forkEnabled) return;

        rateAdapter = new RateAdapter(BASE_SEQUENCER);
        smartDataAdapter = new SmartDataAdapter(BASE_SEQUENCER);
        macroAdapter = new MacroAdapter(BASE_SEQUENCER);

        vm.startPrank(admin);
        engine.setRateOracle(address(rateAdapter));
        engine.setSmartDataOracle(address(smartDataAdapter));
        engine.setMacroOracle(address(macroAdapter));
        vm.stopPrank();
    }

    function testFork_chainlinkAdapter_reads_live_base_feed() public {
        if (!forkEnabled) return;
        ChainlinkAdapter adapter = new ChainlinkAdapter(BASE_SEQUENCER);
        (int256 priceE8, uint64 publishTime,) = adapter.getNormalizedPrice(_toFeedId(BASE_ETH_USD), 7200, 0);
        assertGt(priceE8, 0);
        assertGt(publishTime, 0);
    }

    function testFork_rateOracleClass_threshold_path_live_feed() public {
        if (!forkEnabled) return;

        MarketEngine.UpsertTemplateParams memory p = _volatilityBandTemplate("fork-rate-path");
        p.oracleFeedId = _toFeedId(BASE_BTC_USD);
        p.absoluteThresholdValueE8 = 1;
        p.oracleMaxDelaySeconds = 7200;
        bytes32 tid = _createAndInit(p);
        _openAndResolveBinaryYes(tid);
    }

    function testFork_smartDataOracleClass_threshold_path_live_feed() public {
        if (!forkEnabled) return;

        MarketEngine.UpsertTemplateParams memory p = _navThresholdTemplate("fork-smartdata-path");
        p.oracleFeedId = _toFeedId(BASE_USDC_USD);
        p.absoluteThresholdValueE8 = 50_000_000;
        p.oracleMaxDelaySeconds = 172800;
        bytes32 tid = _createAndInit(p);
        _openAndResolveBinaryYes(tid);
    }

    function testFork_macroOracleClass_threshold_path_live_feed() public {
        if (!forkEnabled) return;

        MarketEngine.UpsertTemplateParams memory p = _macroEventTemplate("fork-macro-path");
        p.oracleFeedId = _toFeedId(BASE_ETH_USD);
        p.absoluteThresholdValueE8 = 1;
        p.oracleMaxDelaySeconds = 7200;
        bytes32 tid = _createAndInit(p);
        _openAndResolveBinaryYes(tid);
    }

    function _createAndInit(MarketEngine.UpsertTemplateParams memory p) internal returns (bytes32 tid) {
        vm.startPrank(admin);
        engine.upsertTemplate(p);
        tid = _tid(p.slug);
        engine.initializeMarket(tid);
        vm.stopPrank();
    }

    function _openAndResolveBinaryYes(bytes32 tid) internal {
        uint64 t0 = uint64(block.timestamp) + 10;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 10, t0 + 20, t0 + 30);

        token.mint(address(0xA11CE1), 100e18);
        vm.startPrank(address(0xA11CE1));
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 15);
        engine.depositToSide(tid, 1, 0, 100e18);
        vm.stopPrank();

        vm.warp(t0 + 21);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 31);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        MarketTypes.Epoch memory e = engine.getEpoch(tid, 1);
        assertEq(e.winningOutcomeMask, 1 << 0);
        assertTrue(e.claimable);
    }

    function _toFeedId(address feedAddress) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(feedAddress)));
    }
}
