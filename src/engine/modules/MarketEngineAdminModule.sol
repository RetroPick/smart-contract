// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineState} from "../MarketEngineState.sol";
import {IYieldRouterV2} from "../../interfaces/IYieldRouterV2.sol";
import {IPriceOracle} from "../../interfaces/IPriceOracle.sol";
import {MarketTypes} from "../../types/MarketTypes.sol";
import {MarketMath} from "../../math/MarketMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Admin/config module extracted from monolithic MarketEngine.
/// @dev Runs via delegatecall from `MarketEngineDispatcher`.
contract MarketEngineAdminModule is MarketEngineState {
    using SafeERC20 for IERC20;

    function pauseProgram(bool paused) external {
        _authAdmin();
        globalPaused = paused;
    }

    function setWorkerAuthority(address worker) external {
        _authAdmin();
        if (worker == address(0)) revert InvalidAuthority();
        address prev = workerAuthority;
        workerAuthority = worker;
        emit WorkerAuthorityUpdated(prev, worker);
    }

    function setTreasury(address t) external {
        _authAdmin();
        if (t == address(0)) revert InvalidAuthority();
        address prev = treasury;
        treasury = t;
        emit TreasuryUpdated(prev, t);
    }

    function setDepositExecutor(address account, bool allowed) external {
        _authAdmin();
        isDepositExecutor[account] = allowed;
        emit DepositExecutorSet(account, allowed);
    }

    function setYieldRouter(address router, uint16 feeBps) external {
        _authAdmin();
        if (feeBps > 10_000) revert InvalidFeeBps();
        address old = address(yieldRouter);
        yieldRouter = IYieldRouterV2(router);
        yieldFeeBps = router == address(0) ? 0 : feeBps;
        yieldRouterFailureCount = 0;
        yieldRouterDisabled = false;
        if (router == address(0)) {
            lmRewardsEnabled = false;
        }
        emit YieldRouterSet(old, router, yieldFeeBps);
        emit YieldRouterFailureStateReset();
    }

    function setRateOracle(address oracle) external {
        _authAdmin();
        if (oracle == address(0)) revert InvalidOracleFeed();
        address old = address(rateOracle);
        rateOracle = IPriceOracle(oracle);
        emit RateOracleSet(old, oracle);
    }

    function setSmartDataOracle(address oracle) external {
        _authAdmin();
        if (oracle == address(0)) revert InvalidOracleFeed();
        address old = address(smartDataOracle);
        smartDataOracle = IPriceOracle(oracle);
        emit SmartDataOracleSet(old, oracle);
    }

    function setMacroOracle(address oracle) external {
        _authAdmin();
        if (oracle == address(0)) revert InvalidOracleFeed();
        address old = address(macroOracle);
        macroOracle = IPriceOracle(oracle);
        emit MacroOracleSet(old, oracle);
    }

    function setEquityOracle(address oracle) external {
        _authAdmin();
        if (oracle == address(0)) revert InvalidOracleFeed();
        address old = address(equityOracle);
        equityOracle = IPriceOracle(oracle);
        emit EquityOracleSet(old, oracle);
    }

    function setLmRewardsEnabled(bool enabled) external {
        _authAdmin();
        if (enabled && address(yieldRouter) == address(0)) revert Unauthorized();
        lmRewardsEnabled = enabled;
        emit LMRewardsEnabledUpdated(enabled);
    }

    function keeperClaimLmRewards(bytes32 templateId) external {
        _authAdminOrWorker();
        IYieldRouterV2 r = yieldRouter;
        if (address(r) == address(0)) revert Unauthorized();
        if (!lmRewardsEnabled) return;
        (address[] memory tokens, uint256[] memory amounts) = r.claimLmRewards(templateId);
        uint256 n = tokens.length;
        for (uint256 i; i < n; ++i) {
            if (amounts[i] > 0) {
                emit LMRewardReceived(templateId, tokens[i], amounts[i]);
            }
        }
    }

    function yieldEmergencyWithdraw(bytes32 templateId) external {
        _authAdmin();
        IYieldRouterV2 r = yieldRouter;
        if (address(r) == address(0)) revert Unauthorized();
        // slither-disable-next-line unused-return -- gross underlying is transferred to engine by router; no local use.
        r.emergencyWithdraw(templateId);
    }

    function resetYieldRouterFailures() external {
        _authAdmin();
        yieldRouterFailureCount = 0;
        yieldRouterDisabled = false;
        emit YieldRouterFailureStateReset();
    }

    function initializeMarket(bytes32 templateId) external {
        _authAdmin();
        MarketTypes.Template storage t = _templates[templateId];
        if (t.version == 0) revert InvalidTemplate();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (ledger.initialized) revert EpochAlreadyExists();

        ledger.version = MarketTypes.VERSION;
        ledger.initialized = true;
        ledger.rollingPhase = MarketTypes.RollingPhase.Uninitialized;
        ledger.rollingHaltReason = MarketTypes.RollingHaltReason.NoneReason;
        ledger.rollingNextEpochId = 1;

        emit MarketInitialized(templateId);
    }

    function withdrawFees(bytes32 templateId, uint256 amount) external {
        _authTreasuryOrAdmin();
        if (amount == 0) revert NothingToClaim();
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.feeReserveTotal < amount) revert NothingToClaim();

        stakeToken.safeTransfer(treasury, amount);
        MarketMath.releaseFeeOnWithdraw(ledger, amount);
        _vaults[templateId].fees -= amount;
        emit FeesWithdrawn(templateId, amount);
    }
}
