// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {YieldRouterAaveV3} from "../src/yield/YieldRouterAaveV3.sol";

/// @notice Deploy `YieldRouterAaveV3` (chain-agnostic; provide Aave v3 addresses via env).
/// @dev Dry-run by default. Add `--broadcast` when ready.
///   Required env:
///   - STAKE_TOKEN (e.g. USDT)
///   - AAVE_POOL (Aave v3 Pool proxy on target chain)
///   - A_TOKEN (aToken for STAKE_TOKEN on target chain)
///   - ENGINE_PROXY (MarketEngine proxy address)
contract DeployYieldRouterAaveV3 is Script {
    function run() external {
        address stakeToken = vm.envAddress("STAKE_TOKEN");
        address aavePool = vm.envAddress("AAVE_POOL");
        address aToken = vm.envAddress("A_TOKEN");
        address engineProxy = vm.envAddress("ENGINE_PROXY");

        require(stakeToken != address(0), "STAKE_TOKEN=0");
        require(aavePool != address(0), "AAVE_POOL=0");
        require(aToken != address(0), "A_TOKEN=0");
        require(engineProxy != address(0), "ENGINE_PROXY=0");

        vm.startBroadcast();
        YieldRouterAaveV3 router = new YieldRouterAaveV3(stakeToken, aavePool, aToken, engineProxy);
        vm.stopBroadcast();

        console2.log("YieldRouterAaveV3", address(router));
        console2.log("stakeToken", stakeToken);
        console2.log("aavePool", aavePool);
        console2.log("aToken", aToken);
        console2.log("engineProxy", engineProxy);
    }
}

