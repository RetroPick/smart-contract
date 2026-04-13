// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

/// @notice Deploy a new `MarketEngine` implementation and upgrade the UUPS proxy (caller must be `admin` on the proxy).
/// @dev Run with `--ffi`. Set `PROXY_ADDRESS` to the proxy users integrate with.
///   Optional: `NEW_CONTRACT` — defaults to `engine/MarketEngineDispatcher.sol:MarketEngineDispatcher`.
///   Add `@custom:oz-upgrades-from MarketEngine` on a V2 contract when the implementation name changes.
contract UpgradeMarketEngine is Script {
    function run() external {
        address proxy = vm.envAddress("PROXY_ADDRESS");
        // Change if the new implementation name differs; add @custom:oz-upgrades-from on V2 sources.
        string memory newContract = "engine/MarketEngineDispatcher.sol:MarketEngineDispatcher";

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        Options memory opts;
        Upgrades.upgradeProxy(proxy, newContract, "", opts);

        console2.log("Upgraded proxy", proxy);
        console2.log("New implementation", Upgrades.getImplementationAddress(proxy));

        vm.stopBroadcast();
    }
}
