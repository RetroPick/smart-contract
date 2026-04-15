// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployProduction} from "../../script/production/DeployProduction.s.sol";
import {DeployTestnet} from "../../script/test/DeployTestnet.s.sol";
import {DeployLocal} from "../../script/DeployLocal.s.sol";
import {UpgradeProduction} from "../../script/production/UpgradeProduction.s.sol";
import {UpgradeTestnet} from "../../script/test/UpgradeTestnet.s.sol";
import {UpgradeMarketEngine} from "../../script/UpgradeMarketEngine.s.sol";
import {UpgradeMarketEngine_YieldRouting} from "../../script/UpgradeMarketEngine_YieldRouting.s.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";
import {MockERC20} from "../../src/test/MockERC20.sol";
import {ScriptSelectorMatrix} from "../../script/ScriptSelectorMatrix.sol";

/// forge-config: default.threads = 1
contract DeploymentScriptExecutionTest is Test {
    bytes32 private constant DEPLOYMENT_COMPLETED_SIG = keccak256("DeploymentCompleted(address,address)");
    bytes32 private constant UPGRADE_COMPLETED_SIG = keccak256("UpgradeCompleted(address,address)");

    function test_deployProduction_success_configAndSelectors() external {
        MockERC20 stake = new MockERC20();
        _setBaseDeployEnv(address(stake));

        DeployProduction script = new DeployProduction();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), DEPLOYMENT_COMPLETED_SIG);
        address proxy = _topicAddress(log.topics[1]);
        address adapter = _topicAddress(log.topics[2]);

        assertTrue(proxy != address(0));
        assertTrue(adapter != address(0));

        IMarketEngine engine = IMarketEngine(proxy);
        assertEq(address(engine.stakeToken()), address(stake));
        assertEq(address(engine.priceOracle()), adapter);
        assertEq(engine.admin(), tx.origin);
        assertEq(engine.treasury(), makeAddr("treasury"));
        assertEq(engine.workerAuthority(), makeAddr("worker"));

        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));
        (address pauseModule,) = dispatcher.getSelectorModule(bytes4(keccak256("pauseProgram(bool)")));
        (address depositModule,) =
            dispatcher.getSelectorModule(bytes4(keccak256("depositToSide(bytes32,uint64,uint8,uint256)")));
        (address rollingModule,) = dispatcher.getSelectorModule(bytes4(keccak256("executeRollingRound(bytes32)")));
        assertTrue(pauseModule != address(0));
        assertTrue(depositModule != address(0));
        assertTrue(rollingModule != address(0));

        ScriptSelectorMatrix.requireAllDelegatedSelectorsWired(dispatcher);
    }

    function test_deployTestnet_success_withoutFaucet() external {
        MockERC20 stake = new MockERC20();
        _setBaseDeployEnv(address(stake));
        vm.setEnv("DEPLOY_FAUCET", "0");

        DeployTestnet script = new DeployTestnet();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), DEPLOYMENT_COMPLETED_SIG);
        address proxy = _topicAddress(log.topics[1]);
        IMarketEngine engine = IMarketEngine(proxy);
        assertEq(address(engine.stakeToken()), address(stake));
    }

    function test_deployTestnet_success_withFaucet() external {
        _setBaseDeployEnv(address(0));
        vm.setEnv("DEPLOY_FAUCET", "1");
        vm.setEnv("MAINNET_CHAIN_ID", "1");

        DeployTestnet script = new DeployTestnet();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), DEPLOYMENT_COMPLETED_SIG);
        address proxy = _topicAddress(log.topics[1]);
        assertTrue(address(IMarketEngine(proxy).stakeToken()) != address(0));
    }

    function test_deployLocal_success_emitsDeployment() external {
        vm.setEnv("PRIVATE_KEY", vm.toString(uint256(0xA11CE)));

        DeployLocal script = new DeployLocal();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), DEPLOYMENT_COMPLETED_SIG);
        assertTrue(_topicAddress(log.topics[1]) != address(0));
        assertTrue(_topicAddress(log.topics[2]) != address(0));
    }

    function test_upgradeProduction_success() external {
        address proxy = _deployProductionFixture();
        vm.setEnv("PROXY_ADDRESS", vm.toString(proxy));
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));

        UpgradeProduction script = new UpgradeProduction();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), UPGRADE_COMPLETED_SIG);
        assertEq(_topicAddress(log.topics[1]), proxy);
    }

    function test_upgradeTestnet_success() external {
        address proxy = _deployProductionFixture();
        vm.setEnv("PROXY_ADDRESS", vm.toString(proxy));
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));

        UpgradeTestnet script = new UpgradeTestnet();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), UPGRADE_COMPLETED_SIG);
        assertEq(_topicAddress(log.topics[1]), proxy);
    }

    function test_upgradeMarketEngine_success() external {
        address proxy = _deployProductionFixture();
        vm.setEnv("PROXY_ADDRESS", vm.toString(proxy));
        vm.setEnv("PRIVATE_KEY", "0");
        vm.setEnv("ALLOW_AMBIENT_BROADCAST", "true");

        UpgradeMarketEngine script = new UpgradeMarketEngine();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), UPGRADE_COMPLETED_SIG);
        assertEq(_topicAddress(log.topics[1]), proxy);
    }

    function test_upgradeYieldRouting_success_withLmToggle() external {
        address proxy = _deployProductionFixture();
        vm.setEnv("PROXY_ADDRESS", vm.toString(proxy));
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("YIELD_ROUTER", vm.toString(makeAddr("yieldRouter")));
        vm.setEnv("YIELD_FEE_BPS", "100");
        vm.setEnv("LM_REWARDS_ENABLED", "true");

        UpgradeMarketEngine_YieldRouting script = new UpgradeMarketEngine_YieldRouting();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), UPGRADE_COMPLETED_SIG);
        assertEq(_topicAddress(log.topics[1]), proxy);
        assertEq(IMarketEngine(proxy).lmRewardsEnabled(), true);
    }

    function _deployProductionFixture() internal returns (address proxy) {
        return _deployProductionFixtureWithAdmin(tx.origin);
    }

    function _deployProductionFixtureWithAdmin(address admin) internal returns (address proxy) {
        MockERC20 stake = new MockERC20();
        _setBaseDeployEnv(address(stake), admin);
        DeployProduction script = new DeployProduction();
        vm.recordLogs();
        script.run();
        Vm.Log memory log = _findLog(address(script), DEPLOYMENT_COMPLETED_SIG);
        proxy = _topicAddress(log.topics[1]);
    }

    function _setBaseDeployEnv(address stakeToken) internal {
        _setBaseDeployEnv(stakeToken, tx.origin);
    }

    function _setBaseDeployEnv(address stakeToken, address admin) internal {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("OZ_UNSAFE_SKIP_ALL_CHECKS", "1");
        vm.setEnv("SEQUENCER_FEED", vm.toString(address(0)));
        vm.setEnv("ADMIN", vm.toString(admin));
        vm.setEnv("TREASURY", vm.toString(makeAddr("treasury")));
        vm.setEnv("WORKER", vm.toString(makeAddr("worker")));
        vm.setEnv("DEFAULT_SETTLEMENT_FEE_BPS", "100");
        vm.setEnv("MAX_SWITCH_FEE_BPS", "200");
        vm.setEnv("MAX_OUTCOMES", "8");
        vm.setEnv("ORACLE_MAX_DELAY_SECONDS", "3600");
        vm.setEnv("ORACLE_MAX_CONFIDENCE_BPS", "500");
        if (stakeToken != address(0)) {
            vm.setEnv("STAKE_TOKEN", vm.toString(stakeToken));
        }
    }

    function _topicAddress(bytes32 topic) internal pure returns (address) {
        return address(uint160(uint256(topic)));
    }

    function _findLog(address emitter, bytes32 sig) internal view returns (Vm.Log memory out) {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].emitter == emitter && entries[i].topics.length > 0 && entries[i].topics[0] == sig) {
                return entries[i];
            }
        }
        revert("event not found");
    }
}
