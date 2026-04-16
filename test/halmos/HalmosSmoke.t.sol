// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/// @notice Minimal Halmos entrypoint: `halmos` only runs `check_*` / `invariant_*` tests by default.
/// Run: `halmos --contract HalmosSmokeTest` (or `halmos` once this contract is the only match).
contract HalmosSmokeTest is Test {
    /// @dev Trivial property so `halmos` has a discoverable symbolic test. Extend with real `check_*` specs as needed.
    /// forge-lint: disable-next-item(mixed-case-function) -- Halmos convention is `check_snake_case`
    function check_halmos_smoke() public pure {
        assert(true);
    }
}
