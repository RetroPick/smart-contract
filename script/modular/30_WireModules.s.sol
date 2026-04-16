// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";
import {ScriptSelectorMatrix} from "../ScriptSelectorMatrix.sol";

contract WireModulesModular is Script {
    event ModulesWired(address indexed proxy);

    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        require(expectedChainId != 0, "EXPECTED_CHAIN_ID=0");
        require(block.chainid == expectedChainId, "wrong chain");

        address payable proxy = payable(vm.envAddress("ENGINE_PROXY"));
        address adminModule = vm.envAddress("MODULE_ADMIN");
        address viewModule = vm.envAddress("MODULE_VIEW");
        address userOpsClaimsModule = vm.envAddress("MODULE_USEROPS_CLAIMS");
        address coreLifecycleModule = vm.envAddress("MODULE_CORE_LIFECYCLE");
        address rollingLifecycleModule = vm.envAddress("MODULE_ROLLING_LIFECYCLE");

        vm.startBroadcast();
        MarketEngineDispatcher engine = MarketEngineDispatcher(proxy);
        ScriptSelectorMatrix.wireAll(
            engine,
            ScriptSelectorMatrix.Modules({
                admin: adminModule,
                viewModule: viewModule,
                userOpsClaims: userOpsClaimsModule,
                coreLifecycle: coreLifecycleModule,
                rollingLifecycle: rollingLifecycleModule
            })
        );
        emit ModulesWired(proxy);
        vm.stopBroadcast();
    }
}
