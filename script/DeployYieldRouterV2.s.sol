// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {YieldRouterV2} from "../src/yield/YieldRouterV2.sol";

/// @notice Deploy `YieldRouterV2` (scaled aToken accounting + optional Stata + LM rewards).
/// @dev Dry-run by default. Add `--broadcast` when ready.
///   Required env:
///   - STAKE_TOKEN
///   - AAVE_POOL
///   - A_TOKEN
///   - ENGINE_PROXY
///   Optional env (use address(0) to disable):
///   - REWARDS_CONTROLLER
///   - STATA_TOKEN
contract DeployYieldRouterV2 is Script {
    event YieldRouterDeployed(address indexed router);

    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        require(expectedChainId != 0, "EXPECTED_CHAIN_ID=0");
        require(block.chainid == expectedChainId, "wrong chain");

        address stakeToken = vm.envAddress("STAKE_TOKEN");
        address aavePool = vm.envAddress("AAVE_POOL");
        address aToken = vm.envAddress("A_TOKEN");
        address engineProxy = vm.envOr("V2_ENGINE_PROXY", vm.envOr("ENGINE_PROXY", address(0)));
        address rewards = vm.envOr("REWARDS_CONTROLLER", address(0));
        address stata = vm.envOr("STATA_TOKEN", address(0));

        require(stakeToken != address(0), "STAKE_TOKEN=0");
        require(aavePool != address(0), "AAVE_POOL=0");
        require(aToken != address(0), "A_TOKEN=0");
        require(engineProxy != address(0), "ENGINE_PROXY=0");

        vm.startBroadcast();
        YieldRouterV2 router = new YieldRouterV2(stakeToken, aavePool, aToken, rewards, stata, engineProxy);
        vm.stopBroadcast();

        console2.log("YieldRouterV2", address(router));
        console2.log("stakeToken", stakeToken);
        console2.log("aavePool", aavePool);
        console2.log("aToken", aToken);
        console2.log("rewardsController", rewards);
        console2.log("stataToken", stata);
        console2.log("engineProxy", engineProxy);
        emit YieldRouterDeployed(address(router));
    }
}
