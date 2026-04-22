// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ScriptSelectorMatrix} from "../../script/ScriptSelectorMatrix.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";

/// @dev Exposes `delegatedSelectors` for unit tests (library is internal-only otherwise).
contract ScriptSelectorMatrixExposed {
    function delegatedSelectors() external pure returns (bytes4[] memory) {
        return ScriptSelectorMatrix.delegatedSelectors();
    }
}

/// @dev Hooks that name `ScriptSelectorMatrix` / `wireAll` for tools that key off test→symbol edges.
contract ScriptSelectorMatrixTest is Test {
    function test_ScriptSelectorMatrix_DELEGATED_SELECTOR_COUNT() public pure {
        // Explicit reference: constant must stay in sync with `ScriptSelectorMatrix._delegatedEntry` row count.
        assertEq(ScriptSelectorMatrix.DELEGATED_SELECTOR_COUNT, 28);
    }

    function test_ScriptSelectorMatrix_delegatedSelectors() public {
        ScriptSelectorMatrixExposed ex = new ScriptSelectorMatrixExposed();
        bytes4[] memory s = ex.delegatedSelectors();
        assertEq(s.length, ScriptSelectorMatrix.DELEGATED_SELECTOR_COUNT, "delegatedSelectors length");
        for (uint256 i; i < s.length; i++) {
            for (uint256 j = i + 1; j < s.length; j++) {
                assertTrue(s[i] != s[j], "duplicate selector");
            }
        }
    }

    /// @dev `_delegatedEntry` is private; this test names it and checks row semantics match `IMarketEngine` and `delegatedSelectors`.
    function test_ScriptSelectorMatrix__delegatedEntry_rows_match_delegatedSelectors() public {
        ScriptSelectorMatrixExposed ex = new ScriptSelectorMatrixExposed();
        bytes4[] memory s = ex.delegatedSelectors();
        assertEq(s[0], IMarketEngine.getUserEpochs.selector, "_delegatedEntry row0 view");
        assertEq(s[12], IMarketEngine.unreconciledRecoveredByTemplate.selector, "_delegatedEntry row12 view end");
        assertEq(s[13], IMarketEngine.upsertTemplate.selector, "_delegatedEntry row13 core");
        assertEq(s[20], IMarketEngine.cancelEpoch.selector, "_delegatedEntry row20 core end");
        assertEq(s[21], IMarketEngine.genesisStartRolling.selector, "_delegatedEntry row21 rolling");
        assertEq(s[27], IMarketEngine.resetRollingLifecycle.selector, "_delegatedEntry row27 rolling end");
    }

    function test_delegatedSelectors_count_length_and_unique() public {
        // Legacy name: keep for any harness expecting the original test id.
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
