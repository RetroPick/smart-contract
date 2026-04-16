// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Intentionally does not inherit `MarketEngineState` and lacks storage compatibility marker.
contract MockNonCompliantModule {
    function pauseProgram(bool) external pure {}
}
