// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MarketEngineAdminModule} from "../../src/engine/modules/MarketEngineAdminModule.sol";
import {MarketEngineViewModule} from "../../src/engine/modules/MarketEngineViewModule.sol";
import {MarketEngineUserOpsClaimsModule} from "../../src/engine/modules/MarketEngineUserOpsClaimsModule.sol";
import {MarketEngineCoreLifecycleModule} from "../../src/engine/modules/MarketEngineCoreLifecycleModule.sol";
import {MarketEngineRollingLifecycleModule} from "../../src/engine/modules/MarketEngineRollingLifecycleModule.sol";

contract DeployModulesModular is Script {
    function run() external {
        vm.startBroadcast();
        address adminModule = address(new MarketEngineAdminModule());
        address viewModule = address(new MarketEngineViewModule());
        address userOpsClaimsModule = address(new MarketEngineUserOpsClaimsModule());
        address coreLifecycleModule = address(new MarketEngineCoreLifecycleModule());
        address rollingLifecycleModule = address(new MarketEngineRollingLifecycleModule());
        vm.stopBroadcast();
        console2.log("MODULE_ADMIN", adminModule);
        console2.log("MODULE_VIEW", viewModule);
        console2.log("MODULE_USEROPS_CLAIMS", userOpsClaimsModule);
        console2.log("MODULE_CORE_LIFECYCLE", coreLifecycleModule);
        console2.log("MODULE_ROLLING_LIFECYCLE", rollingLifecycleModule);
    }
}
