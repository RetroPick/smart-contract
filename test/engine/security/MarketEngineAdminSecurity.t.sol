// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketEngineDispatcher} from "../../../src/engine/MarketEngineDispatcher.sol";
import {MarketEngineAdminModule} from "../../../src/engine/modules/MarketEngineAdminModule.sol";
import {MarketEngineCoreLifecycleModule} from "../../../src/engine/modules/MarketEngineCoreLifecycleModule.sol";
import {MarketEngineUserOpsClaimsModule} from "../../../src/engine/modules/MarketEngineUserOpsClaimsModule.sol";
import {MarketEngineRollingLifecycleModule} from "../../../src/engine/modules/MarketEngineRollingLifecycleModule.sol";
import {MarketEngineViewModule} from "../../../src/engine/modules/MarketEngineViewModule.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockPriceOracle} from "../../../src/test/MockPriceOracle.sol";
import {MockCallbackERC20} from "../../helpers/MockCallbackERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Treasury that re-enters withdrawFees when it receives tokens via MockCallbackERC20 hook.
contract ReentrantTreasury {
    MarketEngine public engine;
    bytes32 public targetTid;

    constructor(address engine_) {
        engine = MarketEngine(engine_);
    }

    function setTarget(bytes32 tid) external {
        targetTid = tid;
    }

    fallback() external {
        // Try to re-enter; state should already be updated (CEI fix), so this should revert silently
        (,, uint256 fees) = engine.getVaultBalances(targetTid);
        if (fees > 0) {
            try engine.withdrawFees(targetTid, fees) {} catch {}
        }
    }
}

/// @notice Exploit PoC tests for admin module vulnerabilities:
///   H7 — withdrawFees CEI violation: reentrancy double-withdrawal
contract MarketEngineAdminSecurity is Test {
    MarketEngine internal engine;
    MockCallbackERC20 internal callbackToken;
    MockPriceOracle internal oracle;
    ReentrantTreasury internal reentrantTreasury;

    address internal admin = address(0xA11CE);
    address internal worker = address(0xB0B);
    // Initial treasury; replaced with reentrantTreasury in setUp
    address internal initialTreasury = address(0xFEE1);
    bytes32 internal feed = keccak256("feed");

    function setUp() public {
        callbackToken = new MockCallbackERC20();
        oracle = new MockPriceOracle();

        MarketEngineDispatcher impl = new MarketEngineDispatcher();
        bytes memory initData = abi.encodeCall(
            MarketEngineDispatcher.initialize,
            (
                MarketEngine.InitConfig({
                    stakeToken: IERC20(address(callbackToken)),
                    priceOracle: oracle,
                    admin: admin,
                    treasury: initialTreasury,
                    worker: worker,
                    defaultSettlementFeeBps: 100,
                    maxSwitchFeeBps: 500,
                    maxOutcomes: 8,
                    oracleKind: MarketTypes.OracleKind.Chainlink,
                    oracleMaxDelaySeconds: 3600,
                    oracleMaxConfidenceBps: 10_000
                })
            )
        );
        address proxy = UnsafeUpgrades.deployUUPSProxy(address(impl), initData);
        engine = MarketEngine(proxy);

        // Now deploy the reentrant treasury pointing at the engine
        reentrantTreasury = new ReentrantTreasury(proxy);

        // Wire modules
        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));
        _wireModules(dispatcher);

        // Switch treasury to the reentrant one
        vm.prank(admin);
        engine.setTreasury(address(reentrantTreasury));
    }

    function _wireModules(MarketEngineDispatcher d) internal {
        address adminMod = address(new MarketEngineAdminModule());
        address viewMod = address(new MarketEngineViewModule());
        address userOpsMod = address(new MarketEngineUserOpsClaimsModule());
        address coreMod = address(new MarketEngineCoreLifecycleModule());
        address rollingMod = address(new MarketEngineRollingLifecycleModule());

        vm.startPrank(admin);
        d.allowModuleCodeHash(keccak256(adminMod.code));
        d.allowModuleCodeHash(keccak256(viewMod.code));
        d.allowModuleCodeHash(keccak256(userOpsMod.code));
        d.allowModuleCodeHash(keccak256(coreMod.code));
        d.allowModuleCodeHash(keccak256(rollingMod.code));

        d.registerModule(adminMod, keccak256(adminMod.code));
        d.registerModule(viewMod, keccak256(viewMod.code));
        d.registerModule(userOpsMod, keccak256(userOpsMod.code));
        d.registerModule(coreMod, keccak256(coreMod.code));
        d.registerModule(rollingMod, keccak256(rollingMod.code));

        d.setSelectorModule(bytes4(keccak256("pauseProgram(bool)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setTreasury(address)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setWorkerAuthority(address)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setDepositExecutor(address,bool)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setYieldRouter(address,uint16)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("resetYieldRouterFailures()")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setRateOracle(address)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setSmartDataOracle(address)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setMacroOracle(address)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setEquityOracle(address)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("setLmRewardsEnabled(bool)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("keeperClaimLmRewards(bytes32)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("yieldEmergencyWithdraw(bytes32)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("initializeMarket(bytes32)")), adminMod, false);
        d.setSelectorModule(bytes4(keccak256("withdrawFees(bytes32,uint256)")), adminMod, false);

        d.setSelectorModule(bytes4(keccak256("getUserEpochs(bytes32,address,uint256,uint256)")), viewMod, false);
        d.setSelectorModule(bytes4(keccak256("getVaultBalances(bytes32)")), viewMod, false);
        d.setSelectorModule(bytes4(keccak256("getRollingLifecycle(bytes32)")), viewMod, false);
        d.setSelectorModule(bytes4(keccak256("getEpoch(bytes32,uint64)")), viewMod, false);

        d.setSelectorModule(bytes4(keccak256("depositToSide(bytes32,uint64,uint8,uint256)")), userOpsMod, false);
        d.setSelectorModule(
            bytes4(keccak256("depositToSideFor(address,bytes32,uint64,uint8,uint256)")), userOpsMod, false
        );
        d.setSelectorModule(bytes4(keccak256("switchSide(bytes32,uint64,uint8,uint8,uint256)")), userOpsMod, false);
        d.setSelectorModule(bytes4(keccak256("claim(bytes32,uint64)")), userOpsMod, false);
        d.setSelectorModule(bytes4(keccak256("claimMany(bytes32,uint64[])")), userOpsMod, false);

        d.setSelectorModule(MarketEngine.upsertTemplate.selector, coreMod, false);
        d.setSelectorModule(bytes4(keccak256("openEpoch(bytes32,uint64,uint64,uint64,uint64)")), coreMod, false);
        d.setSelectorModule(bytes4(keccak256("lockEpoch(bytes32,uint64)")), coreMod, false);
        d.setSelectorModule(bytes4(keccak256("resolveEpoch(bytes32,uint64)")), coreMod, false);
        d.setSelectorModule(bytes4(keccak256("cancelEpoch(bytes32,uint64,uint8,bool)")), coreMod, false);

        d.setSelectorModule(bytes4(keccak256("genesisStartRolling(bytes32)")), rollingMod, false);
        d.setSelectorModule(bytes4(keccak256("genesisLockRolling(bytes32)")), rollingMod, false);
        d.setSelectorModule(bytes4(keccak256("executeRollingRound(bytes32)")), rollingMod, false);
        d.setSelectorModule(bytes4(keccak256("haltRollingMarket(bytes32)")), rollingMod, false);
        d.setSelectorModule(bytes4(keccak256("resetRollingLifecycle(bytes32,uint64)")), rollingMod, false);
        d.setSelectorModule(
            bytes4(keccak256("cancelRollingEpochWhileHalted(bytes32,uint64,uint8,bool)")), rollingMod, false
        );
        d.setSelectorModule(bytes4(keccak256("templateIdFromSlug(string)")), viewMod, false);
        vm.stopPrank();
    }

    function _setupTemplateWithFees() internal returns (bytes32 tid) {
        string memory slug = "fee-test";
        tid = engine.templateIdFromSlug(slug);

        MarketEngine.UpsertTemplateParams memory p;
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
        p.settlementFeeBps = 500;
        p.allowMultiSidePositions = true;
        p.executionMode = MarketTypes.ExecutionMode.Manual;
        p.templateOracleKind = MarketTypes.OracleKind.Chainlink;
        p.oracleClass = MarketTypes.OracleClass.CHAINLINK_PRICE;

        vm.startPrank(admin);
        engine.upsertTemplate(p);
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 1_000_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0, t0 + 100, t0 + 200);

        address alice = address(0xA11CE1);
        address bob = address(0xB0B01);
        callbackToken.mint(alice, 2000e18);
        callbackToken.mint(bob, 2000e18);

        vm.startPrank(alice);
        callbackToken.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 0, 2000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        callbackToken.approve(address(engine), type(uint256).max);
        engine.depositToSide(tid, 1, 1, 2000e18);
        vm.stopPrank();

        vm.warp(t0 + 100);
        vm.prank(worker);
        engine.lockEpoch(tid, 1);

        oracle.set(feed, 200e8, uint64(block.timestamp), 0);
        vm.warp(t0 + 200);
        vm.prank(worker);
        engine.resolveEpoch(tid, 1);

        (,, uint256 fees) = engine.getVaultBalances(tid);
        require(fees > 0, "Setup: no fees generated");
    }

    // ─── H7: CEI fix on withdrawFees ─────────────────────────────────────────

    /// @notice After CEI fix: reentrancy via ERC-777-style callback cannot double-withdraw.
    ///         The state (feeReserveTotal, vault.fees) is decremented BEFORE the transfer,
    ///         so the reentrant call sees 0 fees and reverts silently — only one withdrawal happens.
    function test_withdrawFees_reentrantCallReverts() public {
        bytes32 tid = _setupTemplateWithFees();
        (,, uint256 feesBefore) = engine.getVaultBalances(tid);

        reentrantTreasury.setTarget(tid);

        // Hook fires when treasury receives tokens, trying to withdrawFees again
        bytes memory hookData = abi.encodeCall(engine.withdrawFees, (tid, feesBefore));
        callbackToken.setTransferHook(address(reentrantTreasury), hookData);

        vm.prank(admin);
        engine.withdrawFees(tid, feesBefore);

        // CEI: vault fees already zeroed before transfer → reentrant call fails → only one withdrawal
        (,, uint256 feesAfter) = engine.getVaultBalances(tid);
        assertEq(feesAfter, 0, "CEI fix: fees must be 0 after single withdrawal");
        // No double-spend: treasury balance equals exactly feesBefore
        assertEq(callbackToken.balanceOf(address(reentrantTreasury)), feesBefore, "Exactly one withdrawal occurred");
    }

    /// @notice withdrawFees correctly zeroes vault state and sends exact amount.
    function test_withdrawFees_stateConsistency() public {
        bytes32 tid = _setupTemplateWithFees();
        (,, uint256 feesBefore) = engine.getVaultBalances(tid);

        vm.prank(admin);
        engine.withdrawFees(tid, feesBefore);

        (,, uint256 feesAfter) = engine.getVaultBalances(tid);
        assertEq(feesAfter, 0, "Vault fees should be zero after full withdrawal");
        assertEq(callbackToken.balanceOf(address(reentrantTreasury)), feesBefore, "Treasury received wrong amount");
    }
}
