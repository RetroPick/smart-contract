// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";

/// @notice Testnet upgrade script for the `MarketEngine` UUPS proxy.
/// @dev Run with `--ffi` so OpenZeppelin upgrades validations can run.
///
/// Required env:
/// - PROXY_ADDRESS
///
/// Optional env:
/// - NEW_CONTRACT (defaults to "MarketEngineDispatcher.sol:MarketEngineDispatcher")
///
/// After upgrading, wire any new admin selectors (e.g. `setLmRewardsEnabled`, `keeperClaimLmRewards`)
/// by re-running [`script/modular/30_WireModules.s.sol`](./modular/30_WireModules.s.sol) with the same `MODULE_*` env vars.
/// Optional yield + LM post-config: [`script/UpgradeMarketEngine_YieldRouting.s.sol`](../UpgradeMarketEngine_YieldRouting.s.sol) (`LM_REWARDS_ENABLED=1`).
contract UpgradeTestnet is Script {
    event UpgradeCompleted(address indexed proxy, address indexed implementation);

    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        require(expectedChainId != 0, "EXPECTED_CHAIN_ID=0");
        require(block.chainid == expectedChainId, "wrong chain");

        address proxy = vm.envAddress("PROXY_ADDRESS");
        string memory newContract =
            vm.envOr("NEW_CONTRACT", string("MarketEngineDispatcher.sol:MarketEngineDispatcher"));

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

