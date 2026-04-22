// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ScriptSelectorMatrix} from "../../script/ScriptSelectorMatrix.sol";

/// @dev Exposes `delegatedSelectors` for unit tests (library is internal-only otherwise).
contract ScriptSelectorMatrixExposed {
    function delegatedSelectors() external pure returns (bytes4[] memory) {
        return ScriptSelectorMatrix.delegatedSelectors();
    }
}

contract ScriptSelectorMatrixTest is Test {
    function test_delegatedSelectors_count_length_and_unique() public {
        ScriptSelectorMatrixExposed ex = new ScriptSelectorMatrixExposed();
        bytes4[] memory s = ex.delegatedSelectors();
        assertEq(s.length, ScriptSelectorMatrix.DELEGATED_SELECTOR_COUNT, "length");
        for (uint256 i; i < s.length; i++) {
            for (uint256 j = i + 1; j < s.length; j++) {
                assertTrue(s[i] != s[j], "duplicate selector");
            }
        }
    }
}
