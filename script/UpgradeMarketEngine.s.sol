// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {IMarketEngine} from "../src/engine/IMarketEngine.sol";

/// @notice Deploy a new `MarketEngine` implementation and upgrade the UUPS proxy (caller must be `admin` on the proxy).
/// @dev Run with `--ffi`. Set `PROXY_ADDRESS` to the proxy users integrate with.
///   Optional: `NEW_CONTRACT` — defaults to `MarketEngineDispatcher.sol:MarketEngineDispatcher`.
///   Add `@custom:oz-upgrades-from MarketEngine` on a V2 contract when the implementation name changes.
contract UpgradeMarketEngine is Script {
    event UpgradeCompleted(address indexed proxy, address indexed implementation);

    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        require(expectedChainId != 0, "EXPECTED_CHAIN_ID=0");
        require(block.chainid == expectedChainId, "wrong chain");

        address proxy = vm.envAddress("PROXY_ADDRESS");
        // Change if the new implementation name differs; add @custom:oz-upgrades-from on V2 sources.
        string memory newContract = "MarketEngineDispatcher.sol:MarketEngineDispatcher";

        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        bool allowAmbientBroadcast = vm.envOr("ALLOW_AMBIENT_BROADCAST", false);
        if (pk == 0 && !allowAmbientBroadcast) revert("PRIVATE_KEY=0");

        IMarketEngine engineBefore = IMarketEngine(proxy);
        address stakeTokenBefore = address(engineBefore.stakeToken());
        address priceOracleBefore = address(engineBefore.priceOracle());
        address adminBefore = engineBefore.admin();
        address treasuryBefore = engineBefore.treasury();
        address workerBefore = engineBefore.workerAuthority();

        if (pk == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(pk);
        }

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
