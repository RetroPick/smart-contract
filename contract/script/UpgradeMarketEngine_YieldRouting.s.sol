// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {IMarketEngine} from "../src/engine/IMarketEngine.sol";

/// @notice Upgrade the `MarketEngine` UUPS proxy, then configure yield routing.
/// @dev Run with `--ffi` so OpenZeppelin upgrades validations can run.
///   Required env:
///   - PROXY_ADDRESS
///   Optional env (to enable yield routing post-upgrade):
///   - YIELD_ROUTER (address)  (set to 0x0 to disable)
///   - YIELD_FEE_BPS (uint)    (0..10000)
contract UpgradeMarketEngine_YieldRouting is Script {
    function run() external {
        address proxy = vm.envAddress("PROXY_ADDRESS");
        require(proxy != address(0), "PROXY_ADDRESS=0");

        vm.startBroadcast();

        Options memory opts;
        Upgrades.upgradeProxy(proxy, "engine/MarketEngineDispatcher.sol:MarketEngineDispatcher", "", opts);

        console2.log("Upgraded proxy", proxy);
        console2.log("New implementation", Upgrades.getImplementationAddress(proxy));

        // Post-upgrade configuration (optional).
        address router = vm.envOr("YIELD_ROUTER", address(0));
        uint256 feeRaw = vm.envOr("YIELD_FEE_BPS", uint256(0));
        require(feeRaw <= 10_000, "YIELD_FEE_BPS>10000");
        require(feeRaw <= type(uint16).max, "YIELD_FEE_BPS_UINT16_OVERFLOW");
        // forge-lint: disable-next-line(unsafe-typecast)
        uint16 feeBps = uint16(feeRaw);

        if (router != address(0) || feeRaw != 0) {
            IMarketEngine(proxy).setYieldRouter(router, feeBps);
            console2.log("YieldRouter set", router);
            console2.log("YieldFeeBps set", feeRaw);
        }

        bool lm = vm.envOr("LM_REWARDS_ENABLED", false);
        if (lm) {
            IMarketEngine(proxy).setLmRewardsEnabled(true);
            console2.log("LM rewards enabled");
        }

        vm.stopBroadcast();
    }
}

