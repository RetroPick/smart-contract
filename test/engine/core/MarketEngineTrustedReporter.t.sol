// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {TrustedReporterAdapter} from "../../../src/oracle/TrustedReporterAdapter.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";

contract MarketEngineTrustedReporterTest is MarketEngineBase {
    uint256 internal constant TRO_PK = 0xC0FFEE;
    TrustedReporterAdapter internal tro;

    function setUp() public override {
        super.setUp();
        address troReporter = vm.addr(TRO_PK);
        tro = new TrustedReporterAdapter(troReporter, admin, 3600);
    }

    function _troThresholdTemplate(string memory slug)
        internal
        view
        returns (MarketEngine.UpsertTemplateParams memory p)
    {
        p = _defaultThresholdTemplate(slug);
        p.oracleFeedId = bytes32(0);
        p.templateOracleKind = MarketTypes.OracleKind.TrustedReporter;
        p.eventOracle = address(tro);
    }

    function _postResolve(bytes32 templateId, uint64 epochId, int256 valueE8) internal {
        bytes32 marketId = engine.positionKey(templateId, epochId);
        bytes32 ds = keccak256("test-source");
        uint64 t = uint64(block.timestamp);
        bytes32 digest = tro.hashResolveClaim(marketId, valueE8, t, ds);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TRO_PK, digest);
        tro.postResolveResult(marketId, valueE8, t, ds, abi.encodePacked(r, s, v));
    }

    function test_tro_threshold_manual_resolve() public {
        MarketEngine.UpsertTemplateParams memory p = _troThresholdTemplate("tro-th");
        bytes32 tidT = _tid("tro-th");
        uint64 t0 = 1_000_000;
        vm.startPrank(admin);
        engine.upsertTemplate(p);
        engine.initializeMarket(tidT);
        vm.stopPrank();

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tidT, 1, t0, t0 + 100, t0 + 200);

        vm.warp(t0 + 1);
        address user = address(0x111);
        token.mint(user, 1000e18);
        vm.startPrank(user);
        token.approve(address(engine), 500e18);
        engine.depositToSide(tidT, 1, 0, 500e18);
        vm.stopPrank();

        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.lockEpoch(tidT, 1);

        vm.warp(t0 + 200);
        _postResolve(tidT, 1, 150e8);

        vm.prank(worker);
        engine.resolveEpoch(tidT, 1);

        MarketTypes.Epoch memory e = engine.epochs(tidT, 1);
        assertEq(uint8(e.status), uint8(MarketTypes.EpochStatus.Resolved));
        assertEq(e.checkpointB.valueE8, 150e8);
    }

    function test_tro_rangeClose_manual_resolve() public {
        MarketEngine.UpsertTemplateParams memory p = _rangeCloseTemplate("tro-rc");
        p.oracleFeedId = bytes32(0);
        p.templateOracleKind = MarketTypes.OracleKind.TrustedReporter;
        p.eventOracle = address(tro);

        bytes32 tidR = _tid("tro-rc");
        uint64 t0 = 2_000_000;
        vm.startPrank(admin);
        engine.upsertTemplate(p);
        engine.initializeMarket(tidR);
        vm.stopPrank();

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tidR, 1, t0, t0 + 100, t0 + 200);

        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.lockEpoch(tidR, 1);

        vm.warp(t0 + 200);
        _postResolve(tidR, 1, 150e8);

        vm.prank(worker);
        engine.resolveEpoch(tidR, 1);

        MarketTypes.Epoch memory e = engine.epochs(tidR, 1);
        assertEq(uint8(e.status), uint8(MarketTypes.EpochStatus.Resolved));
        assertEq(e.winningOutcomeMask, uint256(1) << 1);
    }

    function test_RevertWhen_resolveWithoutPost() public {
        MarketEngine.UpsertTemplateParams memory p = _troThresholdTemplate("tro-x");
        bytes32 tidX = _tid("tro-x");
        uint64 t0 = 3_000_000;
        vm.startPrank(admin);
        engine.upsertTemplate(p);
        engine.initializeMarket(tidX);
        vm.stopPrank();

        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tidX, 1, t0, t0 + 100, t0 + 200);

        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.lockEpoch(tidX, 1);

        vm.warp(t0 + 200);
        vm.expectRevert(bytes4(keccak256("InvalidOracleFeed()")));
        vm.prank(worker);
        engine.resolveEpoch(tidX, 1);
    }

    function test_RevertWhen_directionWithTro() public {
        MarketEngine.UpsertTemplateParams memory p = _directionManualTemplate("tro-dir");
        p.oracleFeedId = bytes32(0);
        p.templateOracleKind = MarketTypes.OracleKind.TrustedReporter;
        p.eventOracle = address(tro);

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("InvalidTemplate()")));
        engine.upsertTemplate(p);
    }

    function test_RevertWhen_rollingWithTro() public {
        MarketEngine.UpsertTemplateParams memory p = _thresholdRollingTemplate("tro-roll", 100, 10);
        p.oracleFeedId = bytes32(0);
        p.templateOracleKind = MarketTypes.OracleKind.TrustedReporter;
        p.eventOracle = address(tro);

        vm.prank(admin);
        vm.expectRevert(bytes4(keccak256("RollingInvalidParams()")));
        engine.upsertTemplate(p);
    }
}
