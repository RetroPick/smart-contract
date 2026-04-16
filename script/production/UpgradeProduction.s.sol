// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";

/// @notice Production upgrade script for the `MarketEngine` UUPS proxy.
/// @dev Run with `--ffi` so OpenZeppelin upgrades validations can run.
/// @dev Caller must be `admin` on the proxy (use a multisig flow in production).
///
/// Required env:
/// - PROXY_ADDRESS
///
/// Optional env:
/// - NEW_CONTRACT (defaults to "MarketEngineDispatcher.sol:MarketEngineDispatcher")
///
/// Post-upgrade: re-run modular wiring if new selectors were added (`script/modular/30_WireModules.s.sol`).
/// Yield + LM: [`script/UpgradeMarketEngine_YieldRouting.s.sol`](../UpgradeMarketEngine_YieldRouting.s.sol).
contract UpgradeProduction is Script {
    string internal constant CANONICAL_CONTRACT = "MarketEngineDispatcher.sol:MarketEngineDispatcher";
    event UpgradeCompleted(address indexed proxy, address indexed implementation);

    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        require(expectedChainId != 0, "EXPECTED_CHAIN_ID=0");
        require(block.chainid == expectedChainId, "wrong chain");

        address proxy = vm.envAddress("PROXY_ADDRESS");
        string memory newContract = CANONICAL_CONTRACT;

        IMarketEngine engineBefore = IMarketEngine(proxy);
        address stakeTokenBefore = address(engineBefore.stakeToken());
        address priceOracleBefore = address(engineBefore.priceOracle());
        address adminBefore = engineBefore.admin();
        address treasuryBefore = engineBefore.treasury();
        address workerBefore = engineBefore.workerAuthority();

        vm.startBroadcast();

        Options memory opts;
        opts.unsafeSkipAllChecks = vm.envOr("OZ_UNSAFE_SKIP_ALL_CHECKS", false);
        Upgrades.upgradeProxy(proxy, newContract, "", opts);

        IMarketEngine engineAfter = IMarketEngine(proxy);
        require(engineAfter.configInitialized(), "configInitialized=false");
        require(address(engineAfter.stakeToken()) == stakeTokenBefore, "stakeToken changed");
        require(address(engineAfter.priceOracle()) == priceOracleBefore, "priceOracle changed");
        require(engineAfter.admin() == adminBefore, "admin changed");
        require(engineAfter.treasury() == treasuryBefore, "treasury changed");
        require(engineAfter.workerAuthority() == workerBefore, "worker changed");

        console2.log("Upgraded proxy", proxy);
        address implementation = Upgrades.getImplementationAddress(proxy);
        console2.log("New implementation", implementation);
        emit UpgradeCompleted(proxy, implementation);

        vm.stopBroadcast();
    }
}

