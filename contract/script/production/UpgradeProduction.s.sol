// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

/// @notice Production upgrade script for the `MarketEngine` UUPS proxy.
/// @dev Run with `--ffi` so OpenZeppelin upgrades validations can run.
/// @dev Caller must be `admin` on the proxy (use a multisig flow in production).
///
/// Required env:
/// - PROXY_ADDRESS
///
/// Optional env:
/// - NEW_CONTRACT (defaults to "engine/MarketEngineDispatcher.sol:MarketEngineDispatcher")
///
/// Post-upgrade: re-run modular wiring if new selectors were added (`script/modular/30_WireModules.s.sol`).
/// Yield + LM: [`script/UpgradeMarketEngine_YieldRouting.s.sol`](../UpgradeMarketEngine_YieldRouting.s.sol).
contract UpgradeProduction is Script {
    function run() external {
        address proxy = vm.envAddress("PROXY_ADDRESS");
        string memory newContract =
            vm.envOr("NEW_CONTRACT", string("engine/MarketEngineDispatcher.sol:MarketEngineDispatcher"));

        vm.startBroadcast();

        Options memory opts;
        Upgrades.upgradeProxy(proxy, newContract, "", opts);

        console2.log("Upgraded proxy", proxy);
        console2.log("New implementation", Upgrades.getImplementationAddress(proxy));

        vm.stopBroadcast();
    }
}

