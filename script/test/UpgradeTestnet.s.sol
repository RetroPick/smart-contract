// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

/// @notice Testnet upgrade script for the `MarketEngine` UUPS proxy.
/// @dev Run with `--ffi` so OpenZeppelin upgrades validations can run.
///
/// Required env:
/// - PROXY_ADDRESS
///
/// Optional env:
/// - NEW_CONTRACT (defaults to "engine/MarketEngineDispatcher.sol:MarketEngineDispatcher")
///
/// After upgrading, wire any new admin selectors (e.g. `setLmRewardsEnabled`, `keeperClaimLmRewards`)
/// by re-running [`script/modular/30_WireModules.s.sol`](./modular/30_WireModules.s.sol) with the same `MODULE_*` env vars.
/// Optional yield + LM post-config: [`script/UpgradeMarketEngine_YieldRouting.s.sol`](../UpgradeMarketEngine_YieldRouting.s.sol) (`LM_REWARDS_ENABLED=1`).
contract UpgradeTestnet is Script {
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

