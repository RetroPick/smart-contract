// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineDispatcher} from "../src/engine/MarketEngineDispatcher.sol";
import {IMarketEngine} from "../src/engine/IMarketEngine.sol";

library ScriptSelectorMatrix {
    /// @dev Count of delegate-routed selectors wired by `wireAll` (view + core + rolling modules).
    uint256 public constant DELEGATED_SELECTOR_COUNT = 28;

    /// @dev moduleKind: 0 = viewModule, 1 = coreLifecycle, 2 = rollingLifecycle. Single source of truth for `wireAll` and `delegatedSelectors`.
    function _delegatedEntry(uint256 index) private pure returns (bytes4 sel, uint8 moduleKind) {
        if (index == 0) return (IMarketEngine.getUserEpochs.selector, 0);
        if (index == 1) return (IMarketEngine.getVaultBalances.selector, 0);
        if (index == 2) return (IMarketEngine.getRollingLifecycle.selector, 0);
        if (index == 3) return (IMarketEngine.getEpoch.selector, 0);
        if (index == 4) return (IMarketEngine.getMarketView.selector, 0);
        if (index == 5) return (IMarketEngine.getEpochView.selector, 0);
        if (index == 6) return (IMarketEngine.getActiveEpochView.selector, 0);
        if (index == 7) return (IMarketEngine.getOutcomeViews.selector, 0);
        if (index == 8) return (IMarketEngine.getPositionView.selector, 0);
        if (index == 9) return (IMarketEngine.getTemplateYieldView.selector, 0);
        if (index == 10) return (IMarketEngine.getOperatorTemplateView.selector, 0);
        if (index == 11) return (IMarketEngine.getOperatorGlobalView.selector, 0);
        if (index == 12) return (IMarketEngine.unreconciledRecoveredByTemplate.selector, 0);
        if (index == 13) return (IMarketEngine.upsertTemplate.selector, 1);
        if (index == 14) return (IMarketEngine.openEpoch.selector, 1);
        if (index == 15) return (IMarketEngine.openEpochsBatch.selector, 1);
        if (index == 16) return (IMarketEngine.lockEpoch.selector, 1);
        if (index == 17) return (IMarketEngine.lockEpochsBatch.selector, 1);
        if (index == 18) return (IMarketEngine.resolveEpoch.selector, 1);
        if (index == 19) return (IMarketEngine.resolveEpochsBatch.selector, 1);
        if (index == 20) return (IMarketEngine.cancelEpoch.selector, 1);
        if (index == 21) return (IMarketEngine.genesisStartRolling.selector, 2);
        if (index == 22) return (IMarketEngine.genesisLockRolling.selector, 2);
        if (index == 23) return (IMarketEngine.executeRollingRound.selector, 2);
        if (index == 24) return (IMarketEngine.executeRollingRoundBatch.selector, 2);
        if (index == 25) return (IMarketEngine.haltRollingMarket.selector, 2);
        if (index == 26) return (IMarketEngine.cancelRollingEpochWhileHalted.selector, 2);
        if (index == 27) return (IMarketEngine.resetRollingLifecycle.selector, 2);
        revert("delegated entry OOB");
    }

    struct Modules {
        // Kept for backwards-compatible script inputs; V2 runtime no longer delegate-routes these surfaces.
        address admin;
        address viewModule;
        address userOpsClaims;
        address coreLifecycle;
        address rollingLifecycle;
    }

    function wireAll(MarketEngineDispatcher dispatcher, Modules memory m) internal {
        dispatcher.allowModuleCodeHash(keccak256(m.viewModule.code));
        dispatcher.allowModuleCodeHash(keccak256(m.coreLifecycle.code));
        dispatcher.allowModuleCodeHash(keccak256(m.rollingLifecycle.code));

        dispatcher.registerModule(m.viewModule, keccak256(m.viewModule.code));
        dispatcher.registerModule(m.coreLifecycle, keccak256(m.coreLifecycle.code));
        dispatcher.registerModule(m.rollingLifecycle, keccak256(m.rollingLifecycle.code));

        for (uint256 i; i < DELEGATED_SELECTOR_COUNT; ++i) {
            (bytes4 sel, uint8 k) = _delegatedEntry(i);
            address mod = k == 0 ? m.viewModule : k == 1 ? m.coreLifecycle : m.rollingLifecycle;
            dispatcher.setSelectorModule(sel, mod, false);
        }
    }

    /// @notice Every delegated selector registered in `wireAll` — direct V2 admin/userops selectors are root-owned.
    function delegatedSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](DELEGATED_SELECTOR_COUNT);
        for (uint256 i; i < DELEGATED_SELECTOR_COUNT; ++i) {
            (bytes4 sel,) = _delegatedEntry(i);
            s[i] = sel;
        }
    }

    /// @dev Reverts with `selector not wired` if any delegated selector maps to `address(0)`.
    function requireAllDelegatedSelectorsWired(MarketEngineDispatcher dispatcher) internal view {
        bytes4[] memory sel = delegatedSelectors();
        for (uint256 k = 0; k < sel.length; k++) {
            (address modAddr,) = dispatcher.getSelectorModule(sel[k]);
            require(modAddr != address(0), "selector not wired");
        }
    }
}
