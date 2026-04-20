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

interface IRecoveryTotalsViewRolling {
    function totalUnreconciledRecovered() external view returns (uint256);
}

contract MarketEngineRollingRecoveryHandler is Test {
    uint64 internal constant INTERVAL = 100;
    uint64 internal constant BUFFER = 10;

    MarketEngine internal engine;
    MockERC20 internal token;
    MockPriceOracle internal oracle;
    MockPartialYieldRouter internal router;

    address internal admin;
    address internal worker;
    bytes32 internal feed;
    bytes32 internal tid;

    address[] internal users;

    constructor(
        MarketEngine engine_,
        MockERC20 token_,
        MockPriceOracle oracle_,
        MockPartialYieldRouter router_,
        address admin_,
        address worker_,
        bytes32 feed_,
        bytes32 tid_
    ) {
        engine = engine_;
        token = token_;
        oracle = oracle_;
        router = router_;
        admin = admin_;
        worker = worker_;
        feed = feed_;
        tid = tid_;

        users.push(address(0xA11CE));
        users.push(address(0xB0B));
        users.push(address(0xCAFE));
        users.push(address(0xD00D));
    }

    function bootstrap() external {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("inv-roll", INTERVAL, BUFFER));
        engine.initializeMarket(tid);
        engine.setYieldRouter(address(router), 0);
        vm.stopPrank();

        vm.warp(1_000_000);
        vm.prank(worker);
        engine.genesisStartRolling(tid);
    }

    function deposit(uint256 userSeed, uint256 outcomeSeed, uint256 amountSeed) external {
        (, MarketTypes.RollingPhase phase,,,, uint64 activeEpochId,) = _rollingState();
        if (phase == MarketTypes.RollingPhase.Uninitialized || phase == MarketTypes.RollingPhase.Halted) return;
        if (activeEpochId == 0) return;

        MarketTypes.Epoch memory e = engine.epochs(tid, activeEpochId);
        if (e.status != MarketTypes.EpochStatus.Open) return;
        if (block.timestamp >= e.timing.lockAt) return;
        if (engine.globalPaused()) return;

        address user = users[userSeed % users.length];
        uint8 outcome = uint8(outcomeSeed % e.outcomeCount);
        uint256 amount = bound(amountSeed, 1 ether, 50 ether);

        token.mint(user, amount);
        vm.startPrank(user);
        token.approve(address(engine), type(uint256).max);
        try engine.depositToSide(tid, activeEpochId, outcome, amount) {} catch {}
        vm.stopPrank();
    }

    function switchSide(uint256 userSeed, uint256 directionSeed, uint256 amountSeed) external {
        (, MarketTypes.RollingPhase phase,,,, uint64 activeEpochId,) = _rollingState();
        if (phase == MarketTypes.RollingPhase.Uninitialized || phase == MarketTypes.RollingPhase.Halted) return;
        if (activeEpochId == 0) return;

        MarketTypes.Epoch memory e = engine.epochs(tid, activeEpochId);
        if (e.status != MarketTypes.EpochStatus.Open) return;
        if (block.timestamp >= e.timing.lockAt) return;
        if (e.outcomeCount < 2) return;
        if (engine.globalPaused()) return;

        address user = users[userSeed % users.length];
        uint8 fromOutcome = uint8(directionSeed % 2);
        uint8 toOutcome = fromOutcome == 0 ? 1 : 0;
        uint256 grossAmount = bound(amountSeed, 1 ether, 20 ether);

        vm.prank(user);
        try engine.switchSide(tid, activeEpochId, fromOutcome, toOutcome, grossAmount) {} catch {}
    }

    function genesisLock() external {
        (, MarketTypes.RollingPhase phase,,,, uint64 activeEpochId,) = _rollingState();
        if (phase != MarketTypes.RollingPhase.GenesisOpen || activeEpochId == 0) return;

        MarketTypes.Epoch memory e = engine.epochs(tid, activeEpochId);
        vm.warp(e.timing.lockAt);
        oracle.set(feed, 100e8, uint64(block.timestamp), 0);
        vm.prank(worker);
        try engine.genesisLockRolling(tid) {} catch {}
    }

    function executeRound(uint256 priceSeed) external {
        (, MarketTypes.RollingPhase phase,,,, uint64 activeEpochId,) = _rollingState();
        if (phase != MarketTypes.RollingPhase.Live || activeEpochId < 2) return;

        MarketTypes.Epoch memory prev = engine.epochs(tid, activeEpochId - 1);
        vm.warp(prev.timing.resolveAt);
        int256 price = priceSeed % 2 == 0 ? int256(200e8) : int256(50e8);
        oracle.set(feed, price, uint64(block.timestamp), 0);
        vm.prank(worker);
        try engine.executeRollingRound(tid) {} catch {}
    }

    function haltRolling() external {
        (, MarketTypes.RollingPhase phase,,,,,) = _rollingState();
        if (phase != MarketTypes.RollingPhase.GenesisOpen && phase != MarketTypes.RollingPhase.Live) return;

        vm.prank(admin);
        try engine.haltRollingMarket(tid) {} catch {}
    }

    function pauseProgram(uint256 pausedSeed) external {
        vm.prank(admin);
        try engine.pauseProgram(pausedSeed % 2 == 0) {} catch {}
    }

    function cancelWhileHalted(uint256 epochSeed, uint256 voidedSeed) external {
        (, MarketTypes.RollingPhase phase,,, uint64 haltedAtEpochId, uint64 activeEpochId,) = _rollingState();
        if (phase != MarketTypes.RollingPhase.Halted) return;
        if (!engine.globalPaused()) return;
        uint64 hi = activeEpochId > haltedAtEpochId ? activeEpochId : haltedAtEpochId;
        if (hi == 0) return;

        uint64 epochId = uint64(bound(epochSeed, 1, hi));
        vm.prank(admin);
        try engine.cancelRollingEpochWhileHalted(
            tid, epochId, MarketTypes.CancelReason.EmergencyPaused, voidedSeed % 2 == 0
        ) {} catch {}
    }

    function emergencyWithdraw() external {
        vm.prank(admin);
        try engine.yieldEmergencyWithdraw(tid) {} catch {}
    }

    function reconcile(uint256 epochSeed, uint256 amountSeed) external {
        uint64 hi = _maxEpochSeen();
        if (hi == 0) return;
        uint64 epochId = uint64(bound(epochSeed, 1, hi));
        MarketTypes.Epoch memory e = engine.epochs(tid, epochId);
        if (!e.exists || e.routedPrincipal == 0) return;

        uint256 amount = bound(amountSeed, 1, e.routedPrincipal);
        vm.prank(admin);
        try engine.reconcileEpochRoutedPrincipal(tid, epochId, amount) {} catch {}
    }

    function finalizeRecoveredYield() external {
        vm.prank(admin);
        try engine.finalizeRecoveredYield(tid) {} catch {}
    }

    function resetFailures() external {
        vm.prank(admin);
        try engine.resetYieldRouterFailures() {} catch {}
    }

    function resetRollingLifecycle(uint256 nextSeed) external {
        (, MarketTypes.RollingPhase phase,,,,, uint64 lastResolvedEpochId) = _rollingState();
        if (phase != MarketTypes.RollingPhase.Halted) return;
        if (!engine.globalPaused()) return;
        uint64 nextEpochId = uint64(bound(nextSeed, lastResolvedEpochId + 1, lastResolvedEpochId + 20));
        vm.prank(admin);
        try engine.resetRollingLifecycle(tid, nextEpochId) {} catch {}
    }

    function restartGenesis() external {
        (, MarketTypes.RollingPhase phase,,,,,) = _rollingState();
        if (phase != MarketTypes.RollingPhase.Uninitialized) return;
        if (engine.globalPaused()) return;

        vm.prank(worker);
        try engine.genesisStartRolling(tid) {} catch {}
    }

    function setRouterBehavior(uint256 bpsSeed, uint256 revertSeed) external {
        uint16 bps = uint16(bound(bpsSeed, 0, 10_000));
        router.setWithdrawReturnBps(bps);
        router.setRevertOnWithdraw(revertSeed % 2 == 0);
    }

    function _rollingState()
        internal
        view
        returns (
            bytes32 templateId,
            MarketTypes.RollingPhase phase,
            MarketTypes.RollingHaltReason haltReason,
            uint64 haltedAtEpochId,
            uint64 rollingNextEpochId,
            uint64 activeEpochId,
            uint64 lastResolvedEpochId
        )
    {
        templateId = tid;
        (phase, haltReason, haltedAtEpochId, rollingNextEpochId, activeEpochId, lastResolvedEpochId) =
            engine.getRollingLifecycle(tid);
    }

    function _maxEpochSeen() internal view returns (uint64) {
        (,,,, uint64 rollingNextEpochId, uint64 activeEpochId, uint64 lastResolvedEpochId) = _rollingState();
        uint64 hi = lastResolvedEpochId;
        if (activeEpochId > hi) hi = activeEpochId;
        if (rollingNextEpochId > 0 && rollingNextEpochId - 1 > hi) hi = rollingNextEpochId - 1;
        return hi;
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
}

contract MarketEngineRollingRecoveryInvariants is StdInvariant, MarketEngineBase {
    MarketEngineRollingRecoveryHandler internal handler;
    MockPartialYieldRouter internal router;
    bytes32 internal tid;
    IRecoveryTotalsViewRolling internal recoveryView;

    function setUp() public override {
        super.setUp();

        tid = _tid("inv-roll");
        router = new MockPartialYieldRouter(token, 10_000);
        handler = new MarketEngineRollingRecoveryHandler(
            engine, token, oracle, router, admin, worker, feed, tid
        );
        recoveryView = IRecoveryTotalsViewRolling(address(engine));
        handler.bootstrap();

        targetContract(address(handler));
    }

    function invariant_unpaused_state_has_no_pending_recovery_or_disabled_router() public view {
        if (!engine.globalPaused()) {
            assertEq(recoveryView.totalUnreconciledRecovered(), 0, "unpaused with pending recovery");
            assertFalse(engine.yieldRouterDisabled(), "unpaused with disabled router");
        }
    }

    function invariant_rolling_uninitialized_has_zero_active_epoch() public view {
        (MarketTypes.RollingPhase phase,, uint64 haltedAtEpochId, uint64 nextEpochId, uint64 activeEpochId,) =
            engine.getRollingLifecycle(tid);
        if (phase == MarketTypes.RollingPhase.Uninitialized) {
            assertEq(activeEpochId, 0, "uninitialized phase retained active epoch");
            assertEq(haltedAtEpochId, 0, "uninitialized phase retained haltedAtEpochId");
            assertGt(nextEpochId, 0, "uninitialized phase lost next epoch pointer");
        }
    }

    function invariant_halted_phase_marks_valid_halt_epoch() public view {
        (MarketTypes.RollingPhase phase,, uint64 haltedAtEpochId,, uint64 activeEpochId,) = engine.getRollingLifecycle(tid);
        if (phase == MarketTypes.RollingPhase.Halted) {
            assertGt(haltedAtEpochId, 0, "halted phase missing halted epoch");
            assertGe(activeEpochId, haltedAtEpochId, "active epoch moved behind halted epoch");
        }
    }

    function invariant_no_terminal_epoch_retains_routed_principal() public view {
        (, , , uint64 nextEpochId, uint64 activeEpochId, uint64 lastResolvedEpochId) = engine.getRollingLifecycle(tid);
        uint64 hi = lastResolvedEpochId;
        if (activeEpochId > hi) hi = activeEpochId;
        if (nextEpochId > 0 && nextEpochId - 1 > hi) hi = nextEpochId - 1;

        for (uint64 i = 1; i <= hi; ++i) {
            MarketTypes.Epoch memory e = engine.epochs(tid, i);
            if (!e.exists) continue;
            if (
                e.status == MarketTypes.EpochStatus.Resolved || e.status == MarketTypes.EpochStatus.Cancelled
                    || e.status == MarketTypes.EpochStatus.Voided
            ) {
                assertEq(e.routedPrincipal, 0, "terminal rolling epoch retained routed principal");
            }
        }
    }

    function invariant_router_empty_when_no_routed_principal_remains() public view {
        if (engine.totalRoutedPrincipal() == 0) {
            assertEq(token.balanceOf(address(router)), 0, "router retains balance with no routed principal");
        }
    }
}
