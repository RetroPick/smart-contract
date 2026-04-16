// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {MarketEngineDispatcher} from "../../../src/engine/MarketEngineDispatcher.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/// @notice UUPS: only `admin` may upgrade the implementation.
contract MarketEngineUpgradeTest is MarketEngineBase {
    function test_upgrade_preserves_config_and_storage() public {
        address stakeBefore = address(engine.stakeToken());
        address adm = engine.admin();

        MarketEngineDispatcher newImpl = new MarketEngineDispatcher();
        UnsafeUpgrades.upgradeProxy(address(engine), address(newImpl), "", adm);

        assertEq(address(engine.stakeToken()), stakeBefore);
        assertEq(engine.admin(), adm);
    }

    function test_non_admin_cannot_upgrade() public {
        MarketEngineDispatcher newImpl = new MarketEngineDispatcher();
        address attacker = address(0xBEEF);

        vm.prank(attacker);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        MarketEngineDispatcher(payable(address(engine))).upgradeToAndCall(address(newImpl), "");
    }
}
