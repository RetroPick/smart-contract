// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IYieldRouterV2} from "../interfaces/IYieldRouterV2.sol";
import {MarketTypes} from "../types/MarketTypes.sol";

/// @notice Unified external interface for MarketEngine dispatcher deployments.
interface IMarketEngine {
    struct UpsertTemplateParams {
        string slug;
        string assetSymbol;
        bytes32 oracleFeedId;
        MarketTypes.MarketType marketType;
        MarketTypes.Condition condition;
        MarketTypes.ThresholdRule thresholdRule;
        bool active;
        uint8 outcomeCount;
        int256 absoluteThresholdValueE8;
        int256[7] rangeBoundsE8;
        uint16 switchFeeBps;
        uint16 settlementFeeBps;
        bool allowMultiSidePositions;
        MarketTypes.ExecutionMode executionMode;
        uint64 rollingIntervalSeconds;
        uint64 rollingBufferSeconds;
        uint64 oracleMaxDelaySeconds;
        uint16 oracleMaxConfidenceBps;
    }

    event ConfigInitialized(address admin, address treasury, address workerAuthority);
    event TemplateUpserted(
        bytes32 indexed templateId,
        string slug,
        uint8 marketType,
        uint8 outcomeCount,
        uint64 oracleMaxDelaySeconds,
        uint16 oracleMaxConfidenceBps
    );
    event MarketInitialized(bytes32 indexed templateId);
    event EpochOpened(bytes32 indexed templateId, uint64 indexed epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt);
    event PositionDeposited(
        bytes32 indexed templateId,
        uint64 indexed epochId,
        address indexed user,
        uint8 outcome,
        uint256 amount
    );
    event UserEpochIndexed(bytes32 indexed templateId, uint64 indexed epochId, address indexed user);
    event SideSwitched(
        bytes32 indexed templateId,
        uint64 indexed epochId,
        address indexed user,
        uint8 fromOutcome,
        uint8 toOutcome,
        uint256 grossAmount,
        uint256 feeAmount,
        uint256 netAmount
    );
    event EpochLocked(
        bytes32 indexed templateId,
        uint64 indexed epochId,
        int256 checkpointAValueE8,
        uint64 publishTime
    );
    event EpochResolved(
        bytes32 indexed templateId,
        uint64 indexed epochId,
        uint256 winningMask,
        uint256 claimLiabilityTotal,
        uint256 settlementFeeTotal,
        bool refundMode
    );
    event EpochCancelled(bytes32 indexed templateId, uint64 indexed epochId, uint8 reason);
    event Claimed(bytes32 indexed templateId, uint64 indexed epochId, address indexed user, uint256 amount);
    event FeesWithdrawn(bytes32 indexed templateId, uint256 amount);

    /// @dev Single calldata struct keeps `forge coverage` (no `viaIR`) from stack-overflowing this initializer.
    struct InitConfig {
        IERC20 stakeToken;
        IPriceOracle priceOracle;
        address admin;
        address treasury;
        address worker;
        uint16 defaultSettlementFeeBps;
        uint16 maxSwitchFeeBps;
        uint8 maxOutcomes;
        MarketTypes.OracleKind oracleKind;
        uint64 oracleMaxDelaySeconds;
        uint16 oracleMaxConfidenceBps;
    }

    function initialize(InitConfig calldata config) external;

    function upsertTemplate(UpsertTemplateParams calldata p) external;
    function initializeMarket(bytes32 templateId) external;
    function pauseProgram(bool paused) external;
    function setYieldRouter(address router, uint16 feeBps) external;
    function setLmRewardsEnabled(bool enabled) external;
    function keeperClaimLmRewards(bytes32 templateId) external;
    function setDepositExecutor(address account, bool allowed) external;
    function setTreasury(address t) external;
    function setWorkerAuthority(address worker) external;
    function yieldEmergencyWithdraw(bytes32 templateId) external;
    function withdrawFees(bytes32 templateId, uint256 amount) external;

    function openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) external;
    function openEpochsBatch(
        bytes32[] calldata templateIds,
        uint64[] calldata epochIds,
        uint64[] calldata openAt,
        uint64[] calldata lockAt,
        uint64[] calldata resolveAt
    ) external;
    function lockEpoch(bytes32 templateId, uint64 epochId) external;
    function lockEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external;
    function resolveEpoch(bytes32 templateId, uint64 epochId) external;
    function resolveEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds) external;
    function cancelEpoch(bytes32 templateId, uint64 epochId, MarketTypes.CancelReason reason, bool voided) external;

    function genesisStartRolling(bytes32 templateId) external;
    function genesisLockRolling(bytes32 templateId) external;
    function executeRollingRound(bytes32 templateId) external;
    function executeRollingRoundBatch(bytes32[] calldata templateIds) external;
    function haltRollingMarket(bytes32 templateId) external;
    function resetRollingLifecycle(bytes32 templateId, uint64 nextRollingEpochId) external;
    function cancelRollingEpochWhileHalted(bytes32 templateId, uint64 epochId, MarketTypes.CancelReason reason, bool voided)
        external;

    function depositToSide(bytes32 templateId, uint64 epochId, uint8 outcomeIndex, uint256 amount) external;
    function depositToSideFor(address beneficiary, bytes32 templateId, uint64 epochId, uint8 outcomeIndex, uint256 amount)
        external;
    function switchSide(bytes32 templateId, uint64 epochId, uint8 fromOutcome, uint8 toOutcome, uint256 grossAmount)
        external;
    function claim(bytes32 templateId, uint64 epochId) external;
    function claimMany(bytes32 templateId, uint64[] calldata epochIds) external;

    function templateIdFromSlug(string memory slug) external pure returns (bytes32);
    function positionKey(bytes32 templateId, uint64 epochId) external pure returns (bytes32);

    function getUserEpochs(bytes32 templateId, address user, uint256 cursor, uint256 size)
        external
        view
        returns (uint64[] memory epochIds, uint256 nextCursor);
    function getVaultBalances(bytes32 templateId) external view returns (uint256 active, uint256 claims, uint256 fees);
    function getRollingLifecycle(bytes32 templateId)
        external
        view
        returns (
            MarketTypes.RollingPhase phase,
            MarketTypes.RollingHaltReason haltReason,
            uint64 haltedAtEpochId,
            uint64 rollingNextEpochId,
            uint64 activeEpochId,
            uint64 lastResolvedEpochId
        );
    function getEpoch(bytes32 templateId, uint64 epochId) external view returns (MarketTypes.Epoch memory);

    function configInitialized() external view returns (bool);
    function stakeToken() external view returns (IERC20);
    function priceOracle() external view returns (IPriceOracle);
    function admin() external view returns (address);
    function treasury() external view returns (address);
    function workerAuthority() external view returns (address);
    function globalPaused() external view returns (bool);
    function defaultSettlementFeeBps() external view returns (uint16);
    function maxSwitchFeeBps() external view returns (uint16);
    function maxOutcomes() external view returns (uint8);
    function oracleConfig() external view returns (MarketTypes.OracleConfig memory);
    function isDepositExecutor(address account) external view returns (bool);
    function yieldRouter() external view returns (IYieldRouterV2);
    function lmRewardsEnabled() external view returns (bool);
    function yieldFeeBps() external view returns (uint16);
    function lastOracleRoundIdByTemplate(bytes32 templateId) external view returns (uint80);

    function templates(bytes32 templateId) external view returns (MarketTypes.Template memory);
    function ledgers(bytes32 templateId) external view returns (MarketTypes.Ledger memory);
    function epochs(bytes32 templateId, uint64 epochId) external view returns (MarketTypes.Epoch memory);
}
