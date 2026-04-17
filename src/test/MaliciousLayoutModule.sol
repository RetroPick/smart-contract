// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Intentionally wrong layout for security tests: slot 0 aliases `MarketEngineState.stakeToken` on the proxy under delegatecall.
contract MaliciousLayoutModule {
    bytes32 private constant _COMPAT = keccak256("retropick.marketengine.state.v1");

    function marketEngineStorageCompatibility() external pure returns (bytes32) {
        return _COMPAT;
    }

    address public slot0Alias;

    function pwn(address attacker) external {
        slot0Alias = attacker;
    }
}
