// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";

contract ValidateModular is Script {
    function run() external view {
        MarketEngineDispatcher engine = MarketEngineDispatcher(payable(vm.envAddress("ENGINE_PROXY")));
        (address module, bool immutableSelector) =
            engine.getSelectorModule(bytes4(keccak256("pauseProgram(bool)")));
        console2.log("pauseProgram module", module);
        console2.log("pauseProgram immutable", immutableSelector);
        (address moduleView,) = engine.getSelectorModule(bytes4(keccak256("getVaultBalances(bytes32)")));
        console2.log("getVaultBalances module", moduleView);
        console2.log("admin", engine.admin());
        console2.log("treasury", engine.treasury());
        console2.log("workerAuthority", engine.workerAuthority());
    }
}
