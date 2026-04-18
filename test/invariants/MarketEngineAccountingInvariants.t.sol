// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {MarketEngineBase} from "../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MockERC20} from "../../src/test/MockERC20.sol";
import {MockPriceOracle} from "../../src/test/MockPriceOracle.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";

contract MarketEngineInvariantHandler is Test {
    MarketEngine internal engine;
    MockERC20 internal token;
    MockPriceOracle internal oracle;

    address internal admin;
    address internal treasury;
    address internal worker;
    bytes32 internal feed;
    bytes32 internal tid;

    uint64 public currentEpochId;

    address[] internal users;

    constructor(
        MarketEngine engine_,
        MockERC20 token_,
        MockPriceOracle oracle_,
        address admin_,
        address treasury_,
        address worker_,
        bytes32 feed_,
        bytes32 tid_
    ) {
        engine = engine_;
        token = token_;
        oracle = oracle_;
        admin = admin_;
        treasury = treasury_;
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
        engine.upsertTemplate(_defaultThresholdTemplate("inv"));
        engine.initializeMarket(tid);
        vm.stopPrank();

        currentEpochId = 1;
        _openEpoch(currentEpochId, 1_000_000);
    }

    function deposit(uint256 userSeed, uint256 outcomeSeed, uint256 amountSeed) external {
        MarketTypes.Epoch memory e = engine.epochs(tid, currentEpochId);
        if (e.status != MarketTypes.EpochStatus.Open) return;
        if (block.timestamp >= e.timing.lockAt) return;

        address user = users[userSeed % users.length];
        uint8 outcome = uint8(outcomeSeed % e.outcomeCount);
        uint256 amount = bound(amountSeed, 1 ether, 50 ether);

        token.mint(user, amount);
        vm.startPrank(user);
        token.approve(address(engine), type(uint256).max);
        try engine.depositToSide(tid, currentEpochId, outcome, amount) {} catch {}
        vm.stopPrank();
    }

    function switchSide(uint256 userSeed, uint256 directionSeed, uint256 amountSeed) external {
        MarketTypes.Epoch memory e = engine.epochs(tid, currentEpochId);
        if (e.status != MarketTypes.EpochStatus.Open) return;
        if (block.timestamp >= e.timing.lockAt) return;
        if (e.outcomeCount < 2) return;

        address user = users[userSeed % users.length];
        uint8 fromOutcome = uint8(directionSeed % 2);
        uint8 toOutcome = fromOutcome == 0 ? 1 : 0;
        uint256 grossAmount = bound(amountSeed, 1 ether, 20 ether);

        vm.prank(user);
        try engine.switchSide(tid, currentEpochId, fromOutcome, toOutcome, grossAmount) {} catch {}
    }

    function lockCurrent() external {
        MarketTypes.Epoch memory e = engine.epochs(tid, currentEpochId);
        if (e.status != MarketTypes.EpochStatus.Open) return;

        vm.warp(e.timing.lockAt + 1);
        oracle.set(feed, 100e8, uint64(block.timestamp), 0);
        vm.prank(worker);
        try engine.lockEpoch(tid, currentEpochId) {} catch {}
    }

    function resolveCurrent(uint256 priceSeed) external {
        MarketTypes.Epoch memory e = engine.epochs(tid, currentEpochId);
        if (e.status != MarketTypes.EpochStatus.Locked) return;

        vm.warp(e.timing.resolveAt + 1);
        int256 price = priceSeed % 2 == 0 ? int256(200e8) : int256(50e8);
        oracle.set(feed, price, uint64(block.timestamp), 0);
        vm.prank(worker);
        try engine.resolveEpoch(tid, currentEpochId) {} catch {}
    }

    function cancelCurrent(uint256 voidedSeed) external {
        MarketTypes.Epoch memory e = engine.epochs(tid, currentEpochId);
        if (e.status != MarketTypes.EpochStatus.Open && e.status != MarketTypes.EpochStatus.Locked) return;

        vm.prank(worker);
        try engine.cancelEpoch(
            tid, currentEpochId, MarketTypes.CancelReason.ManualAdminCancel, voidedSeed % 2 == 0
        ) {} catch {}
    }

    function claim(uint256 userSeed, uint256 epochSeed) external {
        if (currentEpochId == 0) return;
        address user = users[userSeed % users.length];
        uint64 epochId = uint64(bound(epochSeed, 1, currentEpochId));

        vm.prank(user);
        try engine.claim(tid, epochId) {} catch {}
    }

    function withdrawFees(uint256 amountSeed) external {
        MarketTypes.Ledger memory ledger = engine.ledgers(tid);
        if (ledger.feeReserveTotal == 0) return;
        uint256 amount = bound(amountSeed, 1, ledger.feeReserveTotal);
        vm.prank(treasury);
        try engine.withdrawFees(tid, amount) {} catch {}
    }

    function openNextEpoch() external {
        MarketTypes.Epoch memory e = engine.epochs(tid, currentEpochId);
        if (
            e.status != MarketTypes.EpochStatus.Resolved && e.status != MarketTypes.EpochStatus.Cancelled
                && e.status != MarketTypes.EpochStatus.Voided
        ) return;

        uint64 nextEpochId = currentEpochId + 1;
        uint64 start = uint64(block.timestamp + 100);
        vm.startPrank(worker);
        try engine.openEpoch(tid, nextEpochId, start, start + 10, start + 20) {
            currentEpochId = nextEpochId;
            vm.warp(start);
        } catch {}
        vm.stopPrank();
    }

    function _openEpoch(uint64 epochId, uint64 start) internal {
        vm.warp(start);
        vm.prank(worker);
        engine.openEpoch(tid, epochId, start, start + 10, start + 20);
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

contract MarketEngineAccountingInvariants is StdInvariant, MarketEngineBase {
    MarketEngineInvariantHandler internal handler;
    bytes32 internal tid;

    function setUp() public override {
        super.setUp();

        tid = _tid("inv");
        handler = new MarketEngineInvariantHandler(engine, token, oracle, admin, treasury, worker, feed, tid);
        handler.bootstrap();

        targetContract(address(handler));
    }

    function invariant_vaults_match_ledger_reserves() public view {
        (uint256 active, uint256 claims, uint256 fees) = engine.getVaultBalances(tid);
        MarketTypes.Ledger memory ledger = engine.ledgers(tid);

        assertEq(active, ledger.activeCollateralTotal, "active vault / ledger mismatch");
        assertEq(claims, ledger.claimsReserveTotal, "claims vault / ledger mismatch");
        assertEq(fees, ledger.feeReserveTotal, "fee vault / ledger mismatch");
    }

    function invariant_engine_token_balance_matches_internal_vaults_without_router() public view {
        (uint256 active, uint256 claims, uint256 fees) = engine.getVaultBalances(tid);
        assertEq(token.balanceOf(address(engine)), active + claims + fees, "engine balance != internal vault sum");
    }

    function invariant_claimed_never_exceeds_epoch_liability() public view {
        uint64 maxEpoch = handler.currentEpochId();
        for (uint64 i = 1; i <= maxEpoch; ++i) {
            MarketTypes.Epoch memory e = engine.epochs(tid, i);
            if (!e.exists) continue;

            uint256 liability = e.refundMode ? e.totalRefundLiability : e.claimLiabilityTotal;
            assertLe(e.claimedTotal, liability, "claimed exceeds reserved liability");
        }
    }
}
