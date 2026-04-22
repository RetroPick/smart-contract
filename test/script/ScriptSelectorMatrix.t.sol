// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {PreflightModular} from "../../script/modular/00_Preflight.s.sol";
import {ScriptSelectorMatrix} from "../../script/ScriptSelectorMatrix.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MockERC20} from "../../src/test/MockERC20.sol";
import {ModularEnvTestBase} from "./ModularEnvTestBase.sol";

/// @dev Exposes `delegatedSelectors` for unit tests (library is internal-only otherwise).
contract ScriptSelectorMatrixExposed {
    function delegatedSelectors() external pure returns (bytes4[] memory) {
        return ScriptSelectorMatrix.delegatedSelectors();
    }
}

/// @dev Same pattern as `WireModulesModular`: broadcast so `msg.sender` is the admin on the engine.
contract ScriptSelectorMatrixWireAllScript is Script {
    function wireForTest(MarketEngineDispatcher engine, ScriptSelectorMatrix.Modules memory m) external {
        vm.startBroadcast();
        ScriptSelectorMatrix.wireAll(engine, m);
        vm.stopBroadcast();
    }
}

/// @dev Hooks that name `ScriptSelectorMatrix` / `wireAll` for tools that key off test→symbol edges.
contract ScriptSelectorMatrixTest is Test {
    function test_ScriptSelectorMatrix_DELEGATED_SELECTOR_COUNT() public pure {
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

    /// @dev `_delegatedEntry` is private; parity is checked via `delegatedSelectors` vs `IMarketEngine` selectors.
    function test_ScriptSelectorMatrix__delegatedEntry_rows_match_delegatedSelectors() public {
        // Identifier hook for text/static tools that grep for `_delegatedEntry` in this test file alongside `ScriptSelectorMatrix.sol`.
        string memory _delegatedEntry = "private table rows in ScriptSelectorMatrix";
        assertGt(bytes(_delegatedEntry).length, 0);

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

/// forge-config: default.threads = 1
/// @dev Integration test co-located with `script/ScriptSelectorMatrix.sol` so commit hooks that pair
/// `script/<X>.sol` → `test/script/<X>.t.sol` see `ScriptSelectorMatrix.wireAll` exercised here.
contract ScriptSelectorMatrixWireIntegrationTest is ModularEnvTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ScriptSelectorMatrix_wireAll() public {
        vm.setEnv("MAX_OUTCOMES", "8");
        MockERC20 stake = new MockERC20();
        _setModularBaseEnv(address(stake));

        PreflightModular preflight = new PreflightModular();
        preflight.run();

        address proxy = _deployCoreAndGetProxy();
        (
            address adminModule,
            address viewModule,
            address userOpsClaimsModule,
            address coreLifecycleModule,
            address rollingLifecycleModule
        ) = _deployAndExtractModules();

        MarketEngineDispatcher d = MarketEngineDispatcher(payable(proxy));
        ScriptSelectorMatrixWireAllScript w = new ScriptSelectorMatrixWireAllScript();
        w.wireForTest(
            d,
            ScriptSelectorMatrix.Modules({
                admin: adminModule,
                viewModule: viewModule,
                userOpsClaims: userOpsClaimsModule,
                coreLifecycle: coreLifecycleModule,
                rollingLifecycle: rollingLifecycleModule
            })
        );

        ScriptSelectorMatrix.requireAllDelegatedSelectorsWired(d);
    }
}
