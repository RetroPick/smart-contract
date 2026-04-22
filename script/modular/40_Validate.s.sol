// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";

contract ValidateModular is Script {
    function run() external view {
        MarketEngineDispatcher engine = MarketEngineDispatcher(payable(vm.envAddress("ENGINE_PROXY")));
        console2.log("pauseProgram root-owned", engine.isRootOwnedSelector(IMarketEngine.pauseProgram.selector));
        (address pauseModule, bool pauseImmutable) = engine.getSelectorModule(IMarketEngine.pauseProgram.selector);
        console2.log("pauseProgram module (expected zero in V2)", pauseModule);
        console2.log("pauseProgram immutable (expected false in V2)", pauseImmutable);
        (address moduleView,) = engine.getSelectorModule(IMarketEngine.getVaultBalances.selector);
        console2.log("getVaultBalances module", moduleView);
        (address moduleUpsert,) = engine.getSelectorModule(IMarketEngine.upsertTemplate.selector);
        console2.log("upsertTemplate module", moduleUpsert);
        console2.log("admin", engine.admin());
        console2.log("treasury", engine.treasury());
        console2.log("workerAuthority", engine.workerAuthority());
    }
}
