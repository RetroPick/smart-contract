// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";
import {MockPriceOracle} from "../../src/test/MockPriceOracle.sol";
import {TrustedReporterAdapter} from "../../src/oracle/TrustedReporterAdapter.sol";

/// @notice End-to-end manual lifecycle coverage for all 15 MarketType variants.
/// @dev Scenarios are aligned to Base upgrade docs feed families and use-cases.
contract MarketTypeAll15Test is MarketEngineBase {
    uint256 internal constant TRO_PK = 0xBEEF;
    address internal alice = address(0xA11CE1);
    address internal bob = address(0xB0B1);

    bytes32 internal constant FEED_B = keccak256("feed_b");
    bytes32 internal constant FEED_C = keccak256("feed_c");
    bytes32 internal constant FEED_D = keccak256("feed_d");
    bytes32 internal constant DOCS_PARITY_HASH = keccak256("basetypefeeds-v3");

    MockPriceOracle internal rateOracleMock;
    MockPriceOracle internal smartDataOracleMock;
    MockPriceOracle internal macroOracleMock;
    TrustedReporterAdapter internal tro;

    function setUp() public override {
        super.setUp();

        rateOracleMock = new MockPriceOracle();
        smartDataOracleMock = new MockPriceOracle();
        macroOracleMock = new MockPriceOracle();
        tro = new TrustedReporterAdapter(vm.addr(TRO_PK), admin, 3600);

        vm.startPrank(admin);
        engine.setRateOracle(address(rateOracleMock));
        engine.setSmartDataOracle(address(smartDataOracleMock));
        engine.setMacroOracle(address(macroOracleMock));
        vm.stopPrank();

        token.mint(alice, 1_000_000e18);
        token.mint(bob, 1_000_000e18);
        vm.prank(alice);
        token.approve(address(engine), type(uint256).max);
        vm.prank(bob);
        token.approve(address(engine), type(uint256).max);
    }

    function test_marketType_01_direction_btc_up() public {
        MarketEngine.UpsertTemplateParams memory p = _directionManualTemplate("mt-direction-btc");
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_PRICE, false
        );

        uint64 t0 = 1_000_000;
        _openAndSeedBinary(tid, t0, 200e18, 200e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 100e8, t0 + 200, 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 110e8, t0 + 300, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
        _claimAndAssertPositive(tid, 1, alice);
    }

    function test_marketType_02_threshold_eth_above() public {
        MarketEngine.UpsertTemplateParams memory p = _defaultThresholdTemplate("mt-threshold-eth");
        p.absoluteThresholdValueE8 = 2_500e8;
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_PRICE, false
        );

        uint64 t0 = 1_010_000;
        _openAndSeedBinary(tid, t0, 150e18, 150e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 2_700e8, t0 + 300, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
        _claimAndAssertPositive(tid, 1, alice);
    }

    function test_marketType_03_rangeClose_bucket() public {
        MarketEngine.UpsertTemplateParams memory p = _rangeCloseTemplate("mt-rangeclose-sol");
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_PRICE, false
        );

        uint64 t0 = 1_020_000;
        _openAndSeedThreeWay(tid, t0, 100e18, 120e18, 130e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 150e8, t0 + 300, 0); // [100,200)
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 1);
        _claimAndAssertPositive(tid, 1, bob);
    }

    function test_marketType_04_anchor_gold_vs_reference() public {
        MarketEngine.UpsertTemplateParams memory p = _anchorTemplate("mt-anchor-gold");
        p.anchorPriceE8 = 2_000e8;
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_PRICE, false
        );

        uint64 t0 = 1_030_000;
        _openAndSeedBinary(tid, t0, 90e18, 90e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 2_100e8, t0 + 300, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    function test_marketType_05_velocity_move_bucket() public {
        MarketEngine.UpsertTemplateParams memory p = _velocityTemplate("mt-velocity-btc");
        p.velocityBoundsE4[0] = 500; // 5%
        p.velocityBoundsE4[1] = 1500; // 15%
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_PRICE, false
        );

        uint64 t0 = 1_040_000;
        _openAndSeedThreeWay(tid, t0, 100e18, 100e18, 100e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 100e8, t0 + 200, 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 120e8, t0 + 300, 0); // +20% => highest bucket idx=2
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 2);
    }

    function test_marketType_06_ladder_weighted_level() public {
        MarketEngine.UpsertTemplateParams memory p = _ladderTemplate("mt-ladder-oil");
        p.ladderBoundsE8[0] = 70e8;
        p.ladderBoundsE8[1] = 80e8;
        p.ladderPayoutWeightsBps[0] = 8_000;
        p.ladderPayoutWeightsBps[1] = 9_000;
        p.ladderPayoutWeightsBps[2] = 10_000;
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_PRICE, false
        );

        uint64 t0 = 1_050_000;
        _openAndSeedThreeWay(tid, t0, 100e18, 100e18, 100e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 75e8, t0 + 300, 0); // winner idx=1
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 1);
    }

    function test_marketType_07_convergence_cbeth_wsteth() public {
        MarketEngine.UpsertTemplateParams memory p = _convergenceTemplate("mt-convergence-lst", FEED_B);
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_PRICE, false
        );

        uint64 t0 = 1_060_000;
        _openAndSeedBinary(tid, t0, 120e18, 120e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 1_060e8, t0 + 200, 0);
        oracle.set(FEED_B, 1_000e8, t0 + 200, 0); // open spread=60
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 1_050e8, t0 + 300, 0);
        oracle.set(FEED_B, 1_020e8, t0 + 300, 0); // close spread=30 => convergence
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    function test_marketType_08_composite_majority() public {
        MarketEngine.UpsertTemplateParams memory p = _compositeTemplate("mt-composite-macro", FEED_B, FEED_C);
        p.absoluteThresholdValueE8 = 100e8;
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_PRICE, false
        );

        uint64 t0 = 1_070_000;
        _openAndSeedBinary(tid, t0, 100e18, 100e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 99e8, t0 + 200, 0);
        oracle.set(FEED_B, 101e8, t0 + 200, 0);
        oracle.set(FEED_C, 102e8, t0 + 200, 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 110e8, t0 + 300, 0);
        oracle.set(FEED_B, 120e8, t0 + 300, 0);
        oracle.set(FEED_C, 90e8, t0 + 300, 0); // 2/3 true => YES
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    /// @dev Per-feed composite thresholds: legacy single threshold50e8 would fail feed C at 20e8; explicit100/30/15e8 passes all.
    function test_marketType_08b_composite_perFeedThresholds_majority() public {
        MarketEngine.UpsertTemplateParams memory p = _compositeTemplate("mt-composite-perfeed", FEED_B, FEED_C);
        p.absoluteThresholdValueE8 = 50e8;
        p.compositeAbsoluteThresholdsE8[0] = 100e8;
        p.compositeAbsoluteThresholdsE8[1] = 30e8;
        p.compositeAbsoluteThresholdsE8[2] = 15e8;
        bytes32 tid = _createAndInit(p);

        uint64 t0 = 1_075_000;
        _openAndSeedBinary(tid, t0, 100e18, 100e18);

        vm.warp(t0 + 200);
        oracle.set(feed, 99e8, t0 + 200, 0);
        oracle.set(FEED_B, 101e8, t0 + 200, 0);
        oracle.set(FEED_C, 102e8, t0 + 200, 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        oracle.set(feed, 110e8, t0 + 300, 0);
        oracle.set(FEED_B, 35e8, t0 + 300, 0);
        oracle.set(FEED_C, 20e8, t0 + 300, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    function test_marketType_09_corridor_stablecoin_with_tro_ohlc() public {
        MarketEngine.UpsertTemplateParams memory p = _corridorTemplate("mt-corridor-usdc", address(tro));
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.TrustedReporter, MarketTypes.OracleClass.CHAINLINK_PRICE, true
        );

        uint64 t0 = 1_080_000;
        _openAndSeedThreeWay(tid, t0, 80e18, 80e18, 80e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        _postTROResolveAndOhlc(
            tid,
            1,
            100_000_000, // close near peg
            100_300_000, // high < upper
            99_700_000 // low > lower
        );
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0); // in-corridor
    }

    function test_marketType_10_cascade_downward_support_breaks() public {
        MarketEngine.UpsertTemplateParams memory p = _cascadeTemplate("mt-cascade-oil", address(tro), true);
        // Downward cascade: bounds must be strictly decreasing (see template validation).
        p.rangeBoundsE8[0] = 80e8;
        p.rangeBoundsE8[1] = 78e8;
        p.rangeBoundsE8[2] = 75e8;
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.TrustedReporter, MarketTypes.OracleClass.CHAINLINK_PRICE, true
        );

        uint64 t0 = 1_090_000;
        _openAndSeedFourWay(tid, t0, 60e18, 60e18, 60e18, 60e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        _postTROResolveAndOhlc(
            tid,
            1,
            79e8, // close
            82e8, // high
            77e8 // low <=78 and <=80 => 2 levels
        );
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 2);
    }

    function test_marketType_11_volatility_band_rate_oracle() public {
        MarketEngine.UpsertTemplateParams memory p = _volatilityBandTemplate("mt-vol-band");
        p.absoluteThresholdValueE8 = 60e8;
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_RATE, false
        );

        uint64 t0 = 1_100_000;
        _openAndSeedBinary(tid, t0, 100e18, 100e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        rateOracleMock.set(feed, 70e8, t0 + 300, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    function test_marketType_12_staking_apr_rate_oracle() public {
        MarketEngine.UpsertTemplateParams memory p = _stakingAprTemplate("mt-staking-apr");
        p.absoluteThresholdValueE8 = 450_000_000; // 4.5%
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_RATE, false
        );

        uint64 t0 = 1_110_000;
        _openAndSeedBinary(tid, t0, 90e18, 90e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        rateOracleMock.set(feed, 500_000_000, t0 + 300, 0); // 5%
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    function test_marketType_13_bitcoin_irc_direction_mode() public {
        MarketEngine.UpsertTemplateParams memory p = _bitcoinIrcDirectionTemplate("mt-btc-irc");
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_RATE, false
        );

        uint64 t0 = 1_120_000;
        _openAndSeedBinary(tid, t0, 100e18, 100e18);

        vm.warp(t0 + 200);
        rateOracleMock.set(feed, 8e8, t0 + 200, 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        rateOracleMock.set(feed, 10e8, t0 + 300, 0); // up
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    function test_marketType_14_nav_threshold_smartdata_oracle() public {
        MarketEngine.UpsertTemplateParams memory p = _navThresholdTemplate("mt-nav-threshold");
        p.absoluteThresholdValueE8 = 100e8;
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_SMARTDATA, false
        );

        uint64 t0 = 1_130_000;
        _openAndSeedBinary(tid, t0, 130e18, 130e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        smartDataOracleMock.set(feed, 101e8, t0 + 300, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    function test_marketType_15_macro_event_macro_oracle() public {
        MarketEngine.UpsertTemplateParams memory p = _macroEventTemplate("mt-macro-event");
        p.absoluteThresholdValueE8 = 250_000_000; // 2.5%
        bytes32 tid = _createAndInit(p);
        _assertEpochOracleRouting(
            tid, 1, MarketTypes.OracleKind.Chainlink, MarketTypes.OracleClass.CHAINLINK_MACRO, false
        );

        uint64 t0 = 1_140_000;
        _openAndSeedBinary(tid, t0, 140e18, 140e18);

        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        macroOracleMock.set(feed, 310_000_000, t0 + 300, 0); // 3.1%
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        _assertMask(tid, 1, 1 << 0);
    }

    function _createAndInit(MarketEngine.UpsertTemplateParams memory p) internal returns (bytes32 tid) {
        vm.startPrank(admin);
        engine.upsertTemplate(p);
        tid = _tid(p.slug);
        engine.initializeMarket(tid);
        vm.stopPrank();
    }

    function _openAndSeedBinary(bytes32 tid, uint64 t0, uint256 a0, uint256 a1) internal {
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        vm.warp(t0 + 150);
        vm.prank(alice);
        engine.depositToSide(tid, 1, 0, a0);
        vm.prank(bob);
        engine.depositToSide(tid, 1, 1, a1);
    }

    function _openAndSeedThreeWay(bytes32 tid, uint64 t0, uint256 a0, uint256 a1, uint256 a2) internal {
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        vm.warp(t0 + 150);
        vm.prank(alice);
        engine.depositToSide(tid, 1, 0, a0);
        vm.prank(bob);
        engine.depositToSide(tid, 1, 1, a1);
        vm.prank(alice);
        engine.depositToSide(tid, 1, 2, a2);
    }

    function _openAndSeedFourWay(bytes32 tid, uint64 t0, uint256 a0, uint256 a1, uint256 a2, uint256 a3) internal {
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 100, t0 + 200, t0 + 300);

        vm.warp(t0 + 150);
        vm.prank(alice);
        engine.depositToSide(tid, 1, 0, a0);
        vm.prank(bob);
        engine.depositToSide(tid, 1, 1, a1);
        vm.prank(alice);
        engine.depositToSide(tid, 1, 2, a2);
        vm.prank(bob);
        engine.depositToSide(tid, 1, 3, a3);
    }

    function _assertMask(bytes32 tid, uint64 epochId, uint256 expectedMask) internal view {
        MarketTypes.Epoch memory e = engine.getEpoch(tid, epochId);
        assertEq(e.winningOutcomeMask, expectedMask);
        assertTrue(e.claimable);
    }

    function _assertEpochOracleRouting(
        bytes32 tid,
        uint64,
        MarketTypes.OracleKind expectedKind,
        MarketTypes.OracleClass expectedClass,
        bool expectsOhlcPath
    ) internal view {
        MarketTypes.Template memory t = engine.templates(tid);
        assertEq(uint8(t.templateOracleKind), uint8(expectedKind));
        assertEq(uint8(t.oracleClass), uint8(expectedClass));
        if (expectsOhlcPath) {
            assertEq(t.oracleFeedId, bytes32(0));
            assertTrue(t.eventOracle != address(0));
        } else {
            assertTrue(t.oracleFeedId != bytes32(0));
        }
    }

    function _claimAndAssertPositive(bytes32 tid, uint64 epochId, address user) internal {
        uint256 balBefore = token.balanceOf(user);
        vm.prank(user);
        engine.claim(tid, epochId);
        uint256 balAfter = token.balanceOf(user);
        assertGt(balAfter, balBefore);
    }

    /// @dev Corridor/Cascade need `getOhlcResult`; scalar resolve and OHLC are mutually exclusive on the adapter.
    function _postTROResolveAndOhlc(bytes32 templateId, uint64 epochId, int256 closeE8, int256 highE8, int256 lowE8)
        internal
    {
        bytes32 marketId = engine.positionKey(templateId, epochId);
        bytes32 ds = keccak256("markettype-e2e");
        uint64 observedAt = uint64(block.timestamp);
        _postTroOhlc(marketId, highE8, lowE8, closeE8, observedAt, ds);
    }

    function _postTroResolve(bytes32 marketId, int256 closeE8, uint64 observedAt, bytes32 ds) internal {
        bytes32 resolveDigest = tro.hashResolveClaim(marketId, closeE8, observedAt, ds);
        (uint8 rv, bytes32 rr, bytes32 rs) = vm.sign(TRO_PK, resolveDigest);
        tro.postResolveResult(marketId, closeE8, observedAt, ds, abi.encodePacked(rr, rs, rv));
    }

    function _postTroOhlc(bytes32 marketId, int256 highE8, int256 lowE8, int256 closeE8, uint64 observedAt, bytes32 ds)
        internal
    {
        bytes32 ohlcDigest = _hashOhlcClaim(marketId, highE8, lowE8, closeE8, observedAt, ds);
        (uint8 ov, bytes32 orr, bytes32 ors) = vm.sign(TRO_PK, ohlcDigest);
        tro.postOhlcResult(marketId, highE8, lowE8, closeE8, observedAt, ds, abi.encodePacked(orr, ors, ov));
    }

    function _hashOhlcClaim(
        bytes32 marketId,
        int256 highE8,
        int256 lowE8,
        int256 closeE8,
        uint64 observedAt,
        bytes32 dataSourceHash
    ) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("RetroPickTrustedReporter")),
                keccak256(bytes("1")),
                block.chainid,
                address(tro)
            )
        );
        bytes32 typeHash = keccak256(
            "OhlcClaim(bytes32 marketId,int256 highE8,int256 lowE8,int256 closeE8,uint64 observedAt,bytes32 dataSourceHash)"
        );
        bytes32 structHash = keccak256(
            abi.encode(typeHash, marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash)
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function test_docsParity_matrix_checksum_and_bitcoinIrc_threshold_mode() public {
        assertEq(DOCS_PARITY_HASH, keccak256("basetypefeeds-v3"));

        MarketEngine.UpsertTemplateParams memory p = _bitcoinIrcThresholdTemplate("mt-btc-irc-threshold");
        p.absoluteThresholdValueE8 = 9e8;
        bytes32 tid = _createAndInit(p);

        uint64 t0 = 1_150_000;
        _openAndSeedBinary(tid, t0, 100e18, 100e18);

        vm.warp(t0 + 200);
        rateOracleMock.set(feed, 10e8, t0 + 200, 0);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        vm.warp(t0 + 300);
        rateOracleMock.set(feed, 8e8, t0 + 300, 0);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        // Docs parity: BitcoinIRC can run threshold semantics in addition to direction semantics.
        _assertMask(tid, 1, 1 << 1);
    }
}
