// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";

contract RollbackModular is Script {
    event SelectorRolledBack(address indexed proxy, bytes4 indexed selector, address indexed rollbackModule);

    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        require(expectedChainId != 0, "EXPECTED_CHAIN_ID=0");
        require(block.chainid == expectedChainId, "wrong chain");

        address payable proxy = payable(vm.envAddress("ENGINE_PROXY"));
        uint256 selectorRaw = vm.envUint("ROLLBACK_SELECTOR");
        require(selectorRaw <= type(uint32).max, "ROLLBACK_SELECTOR>uint32");
        bytes4 selector = bytes4(uint32(selectorRaw));
        address rollbackModule = vm.envAddress("ROLLBACK_MODULE");

        vm.startBroadcast();
        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(proxy);
        dispatcher.allowModuleCodeHash(keccak256(rollbackModule.code));
        dispatcher.registerModule(rollbackModule, keccak256(rollbackModule.code));
        dispatcher.setSelectorModule(selector, rollbackModule, false);
        emit SelectorRolledBack(proxy, selector, rollbackModule);
        vm.stopBroadcast();
    }
}
