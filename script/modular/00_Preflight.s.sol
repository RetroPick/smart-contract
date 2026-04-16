// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

contract PreflightModular is Script {
    function run() external view {
        uint256 chainId = block.chainid;
        address admin = vm.envAddress("ADMIN");
        address treasury = vm.envAddress("TREASURY");
        address worker = vm.envOr("WORKER_AUTHORITY", vm.envOr("WORKER", address(0)));
        address stakeToken = vm.envAddress("STAKE_TOKEN");
        address priceOracle = vm.envAddress("PRICE_ORACLE");

        require(admin != address(0), "ADMIN=0");
        require(treasury != address(0), "TREASURY=0");
        require(worker != address(0), "WORKER_AUTHORITY=0");
        require(stakeToken != address(0), "STAKE_TOKEN=0");
        require(priceOracle != address(0), "PRICE_ORACLE=0");

        console2.log("chainId", chainId);
        console2.log("admin", admin);
        console2.log("treasury", treasury);
        console2.log("worker", worker);
        console2.log("stakeToken", stakeToken);
        console2.log("priceOracle", priceOracle);
    }
}
