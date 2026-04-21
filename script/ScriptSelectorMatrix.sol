// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineDispatcher} from "../src/engine/MarketEngineDispatcher.sol";
import {IMarketEngine} from "../src/engine/IMarketEngine.sol";

library ScriptSelectorMatrix {
    struct Modules {
        address admin;
        address viewModule;
        address userOpsClaims;
        address coreLifecycle;
        address rollingLifecycle;
    }

    function wireAll(MarketEngineDispatcher dispatcher, Modules memory m) internal {
        dispatcher.allowModuleCodeHash(keccak256(m.admin.code));
        dispatcher.allowModuleCodeHash(keccak256(m.viewModule.code));
        dispatcher.allowModuleCodeHash(keccak256(m.userOpsClaims.code));
        dispatcher.allowModuleCodeHash(keccak256(m.coreLifecycle.code));
        dispatcher.allowModuleCodeHash(keccak256(m.rollingLifecycle.code));

        dispatcher.registerModule(m.admin, keccak256(m.admin.code));
        dispatcher.registerModule(m.viewModule, keccak256(m.viewModule.code));
        dispatcher.registerModule(m.userOpsClaims, keccak256(m.userOpsClaims.code));
        dispatcher.registerModule(m.coreLifecycle, keccak256(m.coreLifecycle.code));
        dispatcher.registerModule(m.rollingLifecycle, keccak256(m.rollingLifecycle.code));

        // Admin / config selectors
        dispatcher.setSelectorModule(IMarketEngine.pauseProgram.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setTreasury.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setWorkerAuthority.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setDepositExecutor.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setYieldRouter.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.resetYieldRouterFailures.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setRateOracle.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setSmartDataOracle.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setMacroOracle.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setEquityOracle.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setLmRewardsEnabled.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.keeperClaimLmRewards.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.yieldEmergencyWithdraw.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.recoverRoutedSettledClaims.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.initializeMarket.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.withdrawFees.selector, m.admin, false);

        // View selectors
        dispatcher.setSelectorModule(IMarketEngine.getUserEpochs.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getVaultBalances.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getRollingLifecycle.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getEpoch.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getMarketView.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getEpochView.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getActiveEpochView.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getOutcomeViews.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getPositionView.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getTemplateYieldView.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getOperatorTemplateView.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getOperatorGlobalView.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.unreconciledRecoveredByTemplate.selector, m.viewModule, false);

        // User operations + claims selectors
        dispatcher.setSelectorModule(IMarketEngine.depositToSide.selector, m.userOpsClaims, false);
        dispatcher.setSelectorModule(IMarketEngine.depositToSideFor.selector, m.userOpsClaims, false);
        dispatcher.setSelectorModule(IMarketEngine.switchSide.selector, m.userOpsClaims, false);
        dispatcher.setSelectorModule(IMarketEngine.claim.selector, m.userOpsClaims, false);
        dispatcher.setSelectorModule(IMarketEngine.claimMany.selector, m.userOpsClaims, false);

        // Core lifecycle selectors
        dispatcher.setSelectorModule(IMarketEngine.upsertTemplate.selector, m.coreLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.openEpoch.selector, m.coreLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.openEpochsBatch.selector, m.coreLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.lockEpoch.selector, m.coreLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.lockEpochsBatch.selector, m.coreLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.resolveEpoch.selector, m.coreLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.resolveEpochsBatch.selector, m.coreLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.cancelEpoch.selector, m.coreLifecycle, false);

        // Rolling lifecycle selectors
        dispatcher.setSelectorModule(IMarketEngine.genesisStartRolling.selector, m.rollingLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.genesisLockRolling.selector, m.rollingLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.executeRollingRound.selector, m.rollingLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.executeRollingRoundBatch.selector, m.rollingLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.haltRollingMarket.selector, m.rollingLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.cancelRollingEpochWhileHalted.selector, m.rollingLifecycle, false);
        dispatcher.setSelectorModule(IMarketEngine.resetRollingLifecycle.selector, m.rollingLifecycle, false);
    }

    /// @notice Every selector registered in `wireAll` — use in tests to detect wiring drift.
    function delegatedSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](48);
        uint256 i;
        s[i++] = IMarketEngine.pauseProgram.selector;
        s[i++] = IMarketEngine.setTreasury.selector;
        s[i++] = IMarketEngine.setWorkerAuthority.selector;
        s[i++] = IMarketEngine.setDepositExecutor.selector;
        s[i++] = IMarketEngine.setYieldRouter.selector;
        s[i++] = IMarketEngine.resetYieldRouterFailures.selector;
        s[i++] = IMarketEngine.setRateOracle.selector;
        s[i++] = IMarketEngine.setSmartDataOracle.selector;
        s[i++] = IMarketEngine.setMacroOracle.selector;
        s[i++] = IMarketEngine.setEquityOracle.selector;
        s[i++] = IMarketEngine.setLmRewardsEnabled.selector;
        s[i++] = IMarketEngine.keeperClaimLmRewards.selector;
        s[i++] = IMarketEngine.yieldEmergencyWithdraw.selector;
        s[i++] = IMarketEngine.recoverRoutedSettledClaims.selector;
        s[i++] = IMarketEngine.initializeMarket.selector;
        s[i++] = IMarketEngine.withdrawFees.selector;
        s[i++] = IMarketEngine.getUserEpochs.selector;
        s[i++] = IMarketEngine.getVaultBalances.selector;
        s[i++] = IMarketEngine.getRollingLifecycle.selector;
        s[i++] = IMarketEngine.getEpoch.selector;
        s[i++] = IMarketEngine.getMarketView.selector;
        s[i++] = IMarketEngine.getEpochView.selector;
        s[i++] = IMarketEngine.getActiveEpochView.selector;
        s[i++] = IMarketEngine.getOutcomeViews.selector;
        s[i++] = IMarketEngine.getPositionView.selector;
        s[i++] = IMarketEngine.getTemplateYieldView.selector;
        s[i++] = IMarketEngine.getOperatorTemplateView.selector;
        s[i++] = IMarketEngine.getOperatorGlobalView.selector;
        s[i++] = IMarketEngine.depositToSide.selector;
        s[i++] = IMarketEngine.depositToSideFor.selector;
        s[i++] = IMarketEngine.switchSide.selector;
        s[i++] = IMarketEngine.claim.selector;
        s[i++] = IMarketEngine.claimMany.selector;
        s[i++] = IMarketEngine.upsertTemplate.selector;
        s[i++] = IMarketEngine.openEpoch.selector;
        s[i++] = IMarketEngine.openEpochsBatch.selector;
        s[i++] = IMarketEngine.lockEpoch.selector;
        s[i++] = IMarketEngine.lockEpochsBatch.selector;
        s[i++] = IMarketEngine.resolveEpoch.selector;
        s[i++] = IMarketEngine.resolveEpochsBatch.selector;
        s[i++] = IMarketEngine.cancelEpoch.selector;
        s[i++] = IMarketEngine.genesisStartRolling.selector;
        s[i++] = IMarketEngine.genesisLockRolling.selector;
        s[i++] = IMarketEngine.executeRollingRound.selector;
        s[i++] = IMarketEngine.executeRollingRoundBatch.selector;
        s[i++] = IMarketEngine.haltRollingMarket.selector;
        s[i++] = IMarketEngine.cancelRollingEpochWhileHalted.selector;
        s[i++] = IMarketEngine.resetRollingLifecycle.selector;
        require(i == 48, "delegatedSelectors length");
    }

    /// @dev Reverts with `selector not wired` if any delegated selector maps to `address(0)`.
    function requireAllDelegatedSelectorsWired(MarketEngineDispatcher dispatcher) internal view {
        bytes4[] memory sel = delegatedSelectors();
        for (uint256 k = 0; k < sel.length; k++) {
            (address m,) = dispatcher.getSelectorModule(sel[k]);
            require(m != address(0), "selector not wired");
        }
    }
}
