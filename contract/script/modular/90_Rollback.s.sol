// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";

contract RollbackModular is Script {
    function run() external {
        address payable proxy = payable(vm.envAddress("ENGINE_PROXY"));
        bytes4 selector = bytes4(uint32(vm.envUint("ROLLBACK_SELECTOR")));
        address rollbackModule = vm.envAddress("ROLLBACK_MODULE");

        vm.startBroadcast();
        MarketEngineDispatcher(proxy).setSelectorModule(selector, rollbackModule, false);
        vm.stopBroadcast();
    }
}
