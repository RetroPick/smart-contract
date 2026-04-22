// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployCoreModular} from "../../script/modular/10_DeployCore.s.sol";
import {DeployModulesModular} from "../../script/modular/20_DeployModules.s.sol";

/// @dev Shared deploy + env helpers for `script/modular` pipeline tests. Keeps one copy so
/// `test/script/ScriptSelectorMatrix.t.sol` can run integration coverage for `ScriptSelectorMatrix.wireAll`
/// without duplicating a second `ModularAndYieldScriptsTest` suite (and without splitting symbols across files for static "test gap" tools).
abstract contract ModularEnvTestBase is Test {
    bytes32 internal constant CORE_DEPLOYED_SIG = keccak256("CoreDeployed(address,address)");
    bytes32 internal constant MODULES_DEPLOYED_SIG =
        keccak256("ModulesDeployed(address,address,address,address,address)");

    /// @dev Forge keeps `vm.setEnv` across contracts in one process; reset hot keys so suite order is deterministic.
    function setUp() public virtual {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("MAX_OUTCOMES", "8");
    }

    function _setModularBaseEnv(address stakeToken) internal {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("OZ_UNSAFE_SKIP_ALL_CHECKS", "1");
        vm.setEnv("STAKE_TOKEN", vm.toString(stakeToken));
        vm.setEnv("PRICE_ORACLE", vm.toString(makeAddr("oracle")));
        // Script calls use `startBroadcast()`; origin-style admin matches modular script e2e tests.
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
