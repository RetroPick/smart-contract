// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {MarketEngineBase} from "../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MockERC20} from "../../src/test/MockERC20.sol";
import {MockPriceOracle} from "../../src/test/MockPriceOracle.sol";
import {MockPartialYieldRouter} from "../helpers/MockPartialYieldRouter.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";

interface IRecoveryTotalsView {
    function totalUnreconciledRecovered() external view returns (uint256);
}

contract MarketEngineRoutedRecoveryHandler is Test {
    MarketEngine internal engine;
    MockERC20 internal token;
    MockPriceOracle internal oracle;
    MockPartialYieldRouter internal router;

    address internal admin;
    address internal treasury;
    address internal worker;
    bytes32 internal feed;
    bytes32[2] internal tids;
    uint64[2] public currentEpochIds;

    address[] internal users;

    constructor(
        MarketEngine engine_,
        MockERC20 token_,
        MockPriceOracle oracle_,
        MockPartialYieldRouter router_,
        address admin_,
        address treasury_,
        address worker_,
        bytes32 feed_,
        bytes32[2] memory tids_
    ) {
        engine = engine_;
        token = token_;
        oracle = oracle_;
        router = router_;
        admin = admin_;
        treasury = treasury_;
        worker = worker_;
        feed = feed_;
        tids = tids_;

        users.push(address(0xA11CE));
        users.push(address(0xB0B));
        users.push(address(0xCAFE));
        users.push(address(0xD00D));
    }

    function bootstrap() external {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultThresholdTemplate("inv-routed-a"));
        engine.initializeMarket(tids[0]);
        engine.upsertTemplate(_defaultThresholdTemplate("inv-routed-b"));
        engine.initializeMarket(tids[1]);
        engine.setYieldRouter(address(router), 0);
        vm.stopPrank();

        currentEpochIds[0] = 1;
        currentEpochIds[1] = 1;
        _openEpoch(0, currentEpochIds[0], 1_000_000);
        _openEpoch(1, currentEpochIds[1], 1_000_100);
    }

    function deposit(uint256 templateSeed, uint256 userSeed, uint256 outcomeSeed, uint256 amountSeed) external {
        uint256 idx = templateSeed % 2;
        MarketTypes.Epoch memory e = engine.epochs(tids[idx], currentEpochIds[idx]);
        if (e.status != MarketTypes.EpochStatus.Open) return;
        if (block.timestamp >= e.timing.lockAt) return;
        if (engine.globalPaused()) return;

        address user = users[userSeed % users.length];
        uint8 outcome = uint8(outcomeSeed % e.outcomeCount);
        uint256 amount = bound(amountSeed, 1 ether, 50 ether);

        token.mint(user, amount);
        vm.startPrank(user);
        token.approve(address(engine), type(uint256).max);
        try engine.depositToSide(tids[idx], currentEpochIds[idx], outcome, amount) {} catch {}
        vm.stopPrank();
    }

    function switchSide(uint256 templateSeed, uint256 userSeed, uint256 directionSeed, uint256 amountSeed) external {
        uint256 idx = templateSeed % 2;
        MarketTypes.Epoch memory e = engine.epochs(tids[idx], currentEpochIds[idx]);
        if (e.status != MarketTypes.EpochStatus.Open) return;
        if (block.timestamp >= e.timing.lockAt) return;
        if (e.outcomeCount < 2) return;
        if (engine.globalPaused()) return;

        address user = users[userSeed % users.length];
        uint8 fromOutcome = uint8(directionSeed % 2);
        uint8 toOutcome = fromOutcome == 0 ? 1 : 0;
        uint256 grossAmount = bound(amountSeed, 1 ether, 20 ether);

        vm.prank(user);
        try engine.switchSide(tids[idx], currentEpochIds[idx], fromOutcome, toOutcome, grossAmount) {} catch {}
    }

    function lockCurrent(uint256 templateSeed) external {
        uint256 idx = templateSeed % 2;
        MarketTypes.Epoch memory e = engine.epochs(tids[idx], currentEpochIds[idx]);
        if (e.status != MarketTypes.EpochStatus.Open) return;
        if (engine.globalPaused()) return;

        vm.warp(e.timing.lockAt + 1);
        oracle.set(feed, 100e8, uint64(block.timestamp), 0);
        vm.prank(worker);
        try engine.lockEpoch(tids[idx], currentEpochIds[idx]) {} catch {}
    }

    function resolveCurrent(uint256 templateSeed, uint256 priceSeed) external {
        uint256 idx = templateSeed % 2;
        MarketTypes.Epoch memory e = engine.epochs(tids[idx], currentEpochIds[idx]);
        if (e.status != MarketTypes.EpochStatus.Locked) return;

        vm.warp(e.timing.resolveAt + 1);
        int256 price = priceSeed % 2 == 0 ? int256(200e8) : int256(50e8);
        oracle.set(feed, price, uint64(block.timestamp), 0);
        vm.prank(worker);
        try engine.resolveEpoch(tids[idx], currentEpochIds[idx]) {} catch {}
    }

    function cancelCurrent(uint256 templateSeed, uint256 voidedSeed) external {
        uint256 idx = templateSeed % 2;
        MarketTypes.Epoch memory e = engine.epochs(tids[idx], currentEpochIds[idx]);
        if (e.status != MarketTypes.EpochStatus.Open && e.status != MarketTypes.EpochStatus.Locked) return;

        vm.prank(worker);
        try engine.cancelEpoch(
            tids[idx], currentEpochIds[idx], MarketTypes.CancelReason.ManualAdminCancel, voidedSeed % 2 == 0
        ) {} catch {}
    }

    function claim(uint256 templateSeed, uint256 userSeed, uint256 epochSeed) external {
        uint256 idx = templateSeed % 2;
        uint64 maxEpoch = currentEpochIds[idx];
        if (maxEpoch == 0) return;

        address user = users[userSeed % users.length];
        uint64 epochId = uint64(bound(epochSeed, 1, maxEpoch));

        vm.prank(user);
        try engine.claim(tids[idx], epochId) {} catch {}
    }

    function openNextEpoch(uint256 templateSeed) external {
        uint256 idx = templateSeed % 2;
        MarketTypes.Epoch memory e = engine.epochs(tids[idx], currentEpochIds[idx]);
        if (
            e.status != MarketTypes.EpochStatus.Resolved && e.status != MarketTypes.EpochStatus.Cancelled
                && e.status != MarketTypes.EpochStatus.Voided
        ) return;
        if (engine.globalPaused()) return;

        uint64 nextEpochId = currentEpochIds[idx] + 1;
        uint64 start = uint64(block.timestamp + 100);
        vm.startPrank(worker);
        try engine.openEpoch(tids[idx], nextEpochId, start, start + 10, start + 20) {
            currentEpochIds[idx] = nextEpochId;
            vm.warp(start);
        } catch {}
        vm.stopPrank();
    }

    function setRouterBehavior(uint256 bpsSeed, uint256 revertSeed) external {
        uint16 bps = uint16(bound(bpsSeed, 0, 10_000));
        router.setWithdrawReturnBps(bps);
        router.setRevertOnWithdraw(revertSeed % 2 == 0);
    }

    function pauseProgram(uint256 pausedSeed) external {
        vm.prank(admin);
        try engine.pauseProgram(pausedSeed % 2 == 0) {} catch {}
    }

    function emergencyWithdraw(uint256 templateSeed) external {
        uint256 idx = templateSeed % 2;
        vm.prank(admin);
        try engine.yieldEmergencyWithdraw(tids[idx]) {} catch {}
    }

    function reconcile(uint256 templateSeed, uint256 epochSeed, uint256 amountSeed) external {
        uint256 idx = templateSeed % 2;
        uint64 maxEpoch = currentEpochIds[idx];
        if (maxEpoch == 0) return;
        uint64 epochId = uint64(bound(epochSeed, 1, maxEpoch));
        MarketTypes.Epoch memory e = engine.epochs(tids[idx], epochId);
        if (!e.exists || e.routedPrincipal == 0) return;

        uint256 amount = bound(amountSeed, 1, e.routedPrincipal);
        vm.prank(admin);
        try engine.reconcileEpochRoutedPrincipal(tids[idx], epochId, amount) {} catch {}
    }

    function finalizeRecoveredYield(uint256 templateSeed) external {
        uint256 idx = templateSeed % 2;
        vm.prank(admin);
        try engine.finalizeRecoveredYield(tids[idx]) {} catch {}
    }

    function reassignRecoveredBalance(uint256 directionSeed, uint256 amountSeed) external {
        bytes32 fromTemplateId = tids[directionSeed % 2];
        bytes32 toTemplateId = tids[(directionSeed % 2) ^ 1];
        uint256 available = engine.unreconciledRecoveredByTemplate(fromTemplateId);
        if (available == 0) return;

        uint256 amount = bound(amountSeed, 1, available);
        vm.prank(admin);
        try engine.reassignRecoveredBalance(fromTemplateId, toTemplateId, amount) {} catch {}
    }

    function resetYieldRouterFailures() external {
        vm.prank(admin);
        try engine.resetYieldRouterFailures() {} catch {}
    }

    function _openEpoch(uint256 idx, uint64 epochId, uint64 start) internal {
        vm.warp(start);
        vm.prank(worker);
        engine.openEpoch(tids[idx], epochId, start, start + 10, start + 20);
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
}

contract MarketEngineRoutedRecoveryInvariants is StdInvariant, MarketEngineBase {
    MarketEngineRoutedRecoveryHandler internal handler;
    MockPartialYieldRouter internal router;
    bytes32[2] internal tids;
    IRecoveryTotalsView internal recoveryView;

    function setUp() public override {
        super.setUp();

        tids[0] = _tid("inv-routed-a");
        tids[1] = _tid("inv-routed-b");

        router = new MockPartialYieldRouter(token, 10_000);
        handler = new MarketEngineRoutedRecoveryHandler(
            engine, token, oracle, router, admin, treasury, worker, feed, tids
        );
        recoveryView = IRecoveryTotalsView(address(engine));
        handler.bootstrap();

        targetContract(address(handler));
    }

    function invariant_totalRoutedPrincipal_matches_sum_of_epoch_routed_principal() public view {
        uint256 summed;
        for (uint256 t; t < tids.length; ++t) {
            for (uint64 i = 1; i <= handler.currentEpochIds(t); ++i) {
                MarketTypes.Epoch memory e = engine.epochs(tids[t], i);
                if (!e.exists) continue;
                summed += e.routedPrincipal;
            }
        }
        assertEq(engine.totalRoutedPrincipal(), summed, "global routed principal mismatch");
    }

    function invariant_totalUnreconciled_matches_sum_of_template_buckets() public view {
        uint256 summed;
        for (uint256 t; t < tids.length; ++t) {
            summed += engine.unreconciledRecoveredByTemplate(tids[t]);
        }
        assertEq(recoveryView.totalUnreconciledRecovered(), summed, "global unreconciled mismatch");
    }

    function invariant_terminal_epochs_never_retain_routed_principal() public view {
        for (uint256 t; t < tids.length; ++t) {
            for (uint64 i = 1; i <= handler.currentEpochIds(t); ++i) {
                MarketTypes.Epoch memory e = engine.epochs(tids[t], i);
                if (!e.exists) continue;
                if (
                    e.status == MarketTypes.EpochStatus.Resolved || e.status == MarketTypes.EpochStatus.Cancelled
                        || e.status == MarketTypes.EpochStatus.Voided
                ) {
                    assertEq(e.routedPrincipal, 0, "terminal epoch retained routed principal");
                }
            }
        }
    }

    function invariant_unpaused_state_has_no_pending_recovery_or_disabled_router() public view {
        if (!engine.globalPaused()) {
            assertEq(recoveryView.totalUnreconciledRecovered(), 0, "unpaused with pending recovery");
            assertFalse(engine.yieldRouterDisabled(), "unpaused with disabled router");
        }
    }

    function invariant_router_empty_once_no_routed_principal_remains() public view {
        if (engine.totalRoutedPrincipal() == 0) {
            assertEq(token.balanceOf(address(router)), 0, "router retains balance with no routed principal");
        }
    }
}
