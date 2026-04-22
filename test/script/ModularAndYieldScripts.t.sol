// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployCoreModular} from "../../script/modular/10_DeployCore.s.sol";
import {DeployModulesModular} from "../../script/modular/20_DeployModules.s.sol";
import {WireModulesModular} from "../../script/modular/30_WireModules.s.sol";
import {ValidateModular} from "../../script/modular/40_Validate.s.sol";
import {RollbackModular} from "../../script/modular/90_Rollback.s.sol";
import {PreflightModular} from "../../script/modular/00_Preflight.s.sol";
import {DeployYieldRouterV2} from "../../script/DeployYieldRouterV2.s.sol";
import {DeployYieldRouterAaveV3} from "../../script/DeployYieldRouterAaveV3.s.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";
import {MockERC20} from "../../src/test/MockERC20.sol";
import {MockAToken} from "../../src/test/MockAToken.sol";
import {MockAavePool} from "../../src/test/MockAavePool.sol";

/// forge-config: default.threads = 1
contract ModularAndYieldScriptsTest is Test {
    bytes32 private constant CORE_DEPLOYED_SIG = keccak256("CoreDeployed(address,address)");
    bytes32 private constant MODULES_DEPLOYED_SIG =
        keccak256("ModulesDeployed(address,address,address,address,address)");
    bytes32 private constant MODULES_WIRED_SIG = keccak256("ModulesWired(address)");
    bytes32 private constant SELECTOR_ROLLBACK_SIG = keccak256("SelectorRolledBack(address,bytes4,address)");
    bytes32 private constant YIELD_ROUTER_DEPLOYED_SIG = keccak256("YieldRouterDeployed(address)");

    function test_modular_pipeline_endToEnd() external {
        MockERC20 stake = new MockERC20();
        _setModularBaseEnv(address(stake));

        PreflightModular preflight = new PreflightModular();
        preflight.run();

        address proxy = _deployCoreAndGetProxy();
        vm.setEnv("ENGINE_PROXY", vm.toString(proxy));

        (
            address adminModule,
            address viewModule,
            address userOpsClaimsModule,
            address coreLifecycleModule,
            address rollingLifecycleModule
        ) = _deployAndExtractModules();
        vm.setEnv("MODULE_ADMIN", vm.toString(adminModule));
        vm.setEnv("MODULE_VIEW", vm.toString(viewModule));
        vm.setEnv("MODULE_USEROPS_CLAIMS", vm.toString(userOpsClaimsModule));
        vm.setEnv("MODULE_CORE_LIFECYCLE", vm.toString(coreLifecycleModule));
        vm.setEnv("MODULE_ROLLING_LIFECYCLE", vm.toString(rollingLifecycleModule));

        _wireModulesAndAssertProxy(proxy);

        ValidateModular validate = new ValidateModular();
        validate.run();

        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));
        (address vaultsModule,) = dispatcher.getSelectorModule(bytes4(keccak256("getVaultBalances(bytes32)")));
        assertEq(vaultsModule, viewModule);

        vm.setEnv("ROLLBACK_SELECTOR", vm.toString(uint256(uint32(bytes4(keccak256("getVaultBalances(bytes32)"))))));
        vm.setEnv("ROLLBACK_MODULE", vm.toString(adminModule));
        _rollbackSelectorAndAssert(proxy);
    }

    function test_deployCoreModular_reverts_onBounds() external {
        MockERC20 stake = new MockERC20();
        _setModularBaseEnv(address(stake));
        vm.setEnv("MAX_OUTCOMES", "9");

        DeployCoreModular script = new DeployCoreModular();
        vm.expectRevert("MAX_OUTCOMES>8");
        script.run();
    }

    function test_deployYieldRouterV2_success() external {
        MockERC20 stake = new MockERC20();
        MockAToken aToken = new MockAToken();
        MockAavePool pool = new MockAavePool(address(stake), address(aToken));

        vm.setEnv("STAKE_TOKEN", vm.toString(address(stake)));
        vm.setEnv("AAVE_POOL", vm.toString(address(pool)));
        vm.setEnv("A_TOKEN", vm.toString(address(aToken)));
        vm.setEnv("V2_ENGINE_PROXY", vm.toString(makeAddr("engine")));
        vm.setEnv("ENGINE_PROXY", vm.toString(makeAddr("engine")));
        vm.setEnv("REWARDS_CONTROLLER", vm.toString(address(0)));
        vm.setEnv("STATA_TOKEN", vm.toString(address(0)));
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));

        DeployYieldRouterV2 script = new DeployYieldRouterV2();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), YIELD_ROUTER_DEPLOYED_SIG);
        assertTrue(_topicAddress(log.topics[1]) != address(0));
    }

    function test_deployYieldRouterAaveV3_success() external {
        MockERC20 stake = new MockERC20();
        MockAToken aToken = new MockAToken();
        MockAavePool pool = new MockAavePool(address(stake), address(aToken));

        vm.setEnv("AAVE_STAKE_TOKEN", vm.toString(address(stake)));
        vm.setEnv("AAVE_POOL_ADDRESS", vm.toString(address(pool)));
        vm.setEnv("AAVE_A_TOKEN", vm.toString(address(aToken)));
        vm.setEnv("AAVE_ENGINE_PROXY", vm.toString(makeAddr("engine")));
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));

        DeployYieldRouterAaveV3 script = new DeployYieldRouterAaveV3();
        vm.recordLogs();
        script.run();

        Vm.Log memory log = _findLog(address(script), YIELD_ROUTER_DEPLOYED_SIG);
        assertTrue(_topicAddress(log.topics[1]) != address(0));
    }

    function test_deployYieldRouterV2_revertsOnZeroEngine() external {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("STAKE_TOKEN", vm.toString(makeAddr("stake")));
        vm.setEnv("AAVE_POOL", vm.toString(makeAddr("pool")));
        vm.setEnv("A_TOKEN", vm.toString(makeAddr("atoken")));
        vm.setEnv("V2_ENGINE_PROXY", vm.toString(address(0)));
        vm.setEnv("ENGINE_PROXY", vm.toString(address(0)));

        DeployYieldRouterV2 script = new DeployYieldRouterV2();
        vm.expectRevert();
        script.run();
    }

    function _setModularBaseEnv(address stakeToken) internal {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("OZ_UNSAFE_SKIP_ALL_CHECKS", "1");
        vm.setEnv("STAKE_TOKEN", vm.toString(stakeToken));
        vm.setEnv("PRICE_ORACLE", vm.toString(makeAddr("oracle")));
        // Script calls run through startBroadcast(), so use origin-style sender for admin in script e2e tests.
        vm.setEnv("ADMIN", vm.toString(tx.origin));
        vm.setEnv("TREASURY", vm.toString(makeAddr("treasury")));
        vm.setEnv("WORKER_AUTHORITY", vm.toString(makeAddr("worker")));
        vm.setEnv("DEFAULT_SETTLEMENT_FEE_BPS", "100");
        vm.setEnv("MAX_SWITCH_FEE_BPS", "300");
        vm.setEnv("MAX_OUTCOMES", "8");
        vm.setEnv("ORACLE_MAX_DELAY_SECONDS", "3600");
        vm.setEnv("ORACLE_MAX_CONFIDENCE_BPS", "500");
    }

    function _topicAddress(bytes32 topic) internal pure returns (address) {
        return address(uint160(uint256(topic)));
    }

    function _deployCoreAndGetProxy() internal returns (address proxy) {
        DeployCoreModular core = new DeployCoreModular();
        vm.recordLogs();
        core.run();
        Vm.Log memory coreLog = _findLog(address(core), CORE_DEPLOYED_SIG);
        return _topicAddress(coreLog.topics[1]);
    }

    function _deployAndExtractModules()
        internal
        returns (
            address adminModule,
            address viewModule,
            address userOpsClaimsModule,
            address coreLifecycleModule,
            address rollingLifecycleModule
        )
    {
        DeployModulesModular deployModules = new DeployModulesModular();
        vm.recordLogs();
        deployModules.run();
        Vm.Log memory modulesLog = _findLog(address(deployModules), MODULES_DEPLOYED_SIG);

        adminModule = _topicAddress(modulesLog.topics[1]);
        viewModule = _topicAddress(modulesLog.topics[2]);
        (userOpsClaimsModule, coreLifecycleModule, rollingLifecycleModule) =
            abi.decode(modulesLog.data, (address, address, address));
    }

    function _wireModulesAndAssertProxy(address proxy) internal {
        WireModulesModular wire = new WireModulesModular();
        vm.recordLogs();
        wire.run();
        Vm.Log memory wired = _findLog(address(wire), MODULES_WIRED_SIG);
        assertEq(_topicAddress(wired.topics[1]), proxy);
    }

    function _rollbackSelectorAndAssert(address proxy) internal {
        address rollbackModule = vm.envAddress("ROLLBACK_MODULE");
        RollbackModular rollback = new RollbackModular();
        vm.recordLogs();
        rollback.run();
        Vm.Log memory rollbackLog = _findLog(address(rollback), SELECTOR_ROLLBACK_SIG);
        assertEq(_topicAddress(rollbackLog.topics[1]), proxy);
        assertEq(address(uint160(uint256(rollbackLog.topics[3]))), rollbackModule);
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
