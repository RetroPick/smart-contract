// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ModularEnvTestBase} from "./ModularEnvTestBase.sol";

/// @dev Pairs with `ModularEnvTestBase.sol` so file-stem test gaps see `setUp` and base env in the co-located test.
contract ModularEnvTestBaseSetUpTest is ModularEnvTestBase {
    function test_ModularEnvTestBase_setUp_expectedChain_and_maxOutcomes() public {
        assertEq(vm.envUint("EXPECTED_CHAIN_ID"), block.chainid, "setUp");
        assertEq(vm.envUint("MAX_OUTCOMES"), 8, "setUp");
    }
}
