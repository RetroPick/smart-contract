// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
        // Admin / config selectors
        dispatcher.setSelectorModule(IMarketEngine.pauseProgram.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setTreasury.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setWorkerAuthority.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setDepositExecutor.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setYieldRouter.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setRateOracle.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setSmartDataOracle.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setMacroOracle.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setEquityOracle.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.setLmRewardsEnabled.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.keeperClaimLmRewards.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.yieldEmergencyWithdraw.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.initializeMarket.selector, m.admin, false);
        dispatcher.setSelectorModule(IMarketEngine.withdrawFees.selector, m.admin, false);

        // View selectors
        dispatcher.setSelectorModule(IMarketEngine.getUserEpochs.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getVaultBalances.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getRollingLifecycle.selector, m.viewModule, false);
        dispatcher.setSelectorModule(IMarketEngine.getEpoch.selector, m.viewModule, false);

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
}
