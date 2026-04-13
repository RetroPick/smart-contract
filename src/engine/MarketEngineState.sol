// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MarketTypes} from "../types/MarketTypes.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IYieldRouterV2} from "../interfaces/IYieldRouterV2.sol";

/// @notice Canonical MarketEngine storage anchor used by dispatcher/modules.
/// @dev Keep this layout append-only for upgrade safety.
/// Trust / deployment: primitives (`admin`, `stakeToken`, `oracleConfig`, …) are set in
/// `MarketEngineDispatcher.initialize` on the UUPS proxy. Mappings default to empty. A proxy that
/// skips `initialize` is broken by design—operational risk, not an on-chain uninitialized read.
/// Stake token: user deposits require exact `balanceOf` delta (`NonStandardStakeToken`); yield routers
/// still assume ERC20 semantics for Aave/4626 integration.
// slither-disable-start uninitialized-state -- UUPS: dispatcher `initialize` sets primitives; mappings start empty
abstract contract MarketEngineState {
    IERC20 public stakeToken;
    IPriceOracle public priceOracle;

    bool public configInitialized;
    address public admin;
    address public treasury;
    address public workerAuthority;
    bool public globalPaused;

    uint16 public defaultSettlementFeeBps;
    uint16 public maxSwitchFeeBps;
    uint8 public maxOutcomes;
    MarketTypes.OracleConfig public oracleConfig;

    mapping(bytes32 templateId => MarketTypes.Template) internal _templates;
    mapping(bytes32 templateId => MarketTypes.Ledger) internal _ledgers;
    mapping(bytes32 templateId => MarketTypes.VaultBalances) internal _vaults;
    mapping(bytes32 templateId => mapping(uint64 epochId => MarketTypes.Epoch)) internal _epochs;
    mapping(bytes32 positionKey => mapping(address user => MarketTypes.Position)) internal _positions;
    mapping(address account => bool) public isDepositExecutor;
    mapping(bytes32 templateId => mapping(address user => uint64[] epochIds)) internal _userEpochs;
    mapping(bytes32 templateId => uint80 lastOracleRoundId) internal lastOracleRoundIdByTemplate;

    struct OracleCursor {
        uint80 roundId;
        uint64 publishTime;
    }
    mapping(bytes32 templateId => mapping(bytes32 feedId => OracleCursor)) internal lastOracleCursorByTemplateFeed;

    IYieldRouterV2 public yieldRouter;
    uint16 public yieldFeeBps;
    bool public lmRewardsEnabled;
    uint16 internal constant YIELD_BUFFER_BPS = 500;

    // --- dispatcher state (appended after legacy state) ---
    mapping(bytes4 selector => address module) internal selectorToModule;
    mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

    uint256[45] private __gap;

    error Unauthorized();
    error InvalidAuthority();
    error ProtocolPaused();
    error InvalidTemplate();
    error TemplateInactive();
    error TooManyOutcomes();
    error InvalidFeeBps();
    error InvalidTiming();
    error InvalidEpochState();
    error BettingClosed();
    error TooEarlyToLock();
    error TooEarlyToResolve();
    error EpochAlreadyResolved();
    error EpochAlreadyExists();
    error PreviousEpochUnresolved();
    error EpochNotActive();
    error InvalidOracleFeed();
    error OracleStale();
    error OracleConfidenceTooWide();
    error InvalidOraclePrice();
    error InvalidOraclePublishTime();
    error CheckpointAlreadyWritten();
    error NoWinningOutcome();
    error InvalidOutcome();
    error SingleSideViolation();
    error PartialSwitchDisallowed();
    error AmountTooSmall();
    error ZeroStake();
    error InsufficientSourceStake();
    error NothingToClaim();
    error AlreadyClaimed();
    error ClaimNotAvailable();
    error MathOverflow();
    error ConfidenceOverflow();
    error RollingModeOnly();
    error ManualModeOnly();
    error RollingWrongPhase();
    error RollingInvalidParams();
    error RollingGenesisAlreadyStarted();
    error RollingHaltedUserOps();
    error InvalidRollingRecovery();
    error NotDepositExecutor();
    error OracleRoundIdNotMonotonic(uint80 newRoundId, uint80 lastRoundId);
    error NonStandardStakeToken();
    error OracleSampleNotMonotonic(uint80 newRoundId, uint80 lastRoundId, uint64 newPublishTime, uint64 lastPublishTime);
    error YieldWithdrawFailed();
    error ModuleNotSet(bytes4 selector);
    error InvalidModule();
    error SelectorImmutable(bytes4 selector);

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
    event EpochOpened(
        bytes32 indexed templateId, uint64 indexed epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt
    );
    event PositionDeposited(
        bytes32 indexed templateId, uint64 indexed epochId, address indexed user, uint8 outcome, uint256 amount
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
        bytes32 indexed templateId, uint64 indexed epochId, int256 checkpointAValueE8, uint64 publishTime
    );
    event EpochLockedV2(
        bytes32 indexed templateId,
        uint64 indexed epochId,
        int256 checkpointAValueE8,
        uint64 publishTime,
        uint80 oracleRoundId
    );
    event EpochResolved(
        bytes32 indexed templateId,
        uint64 indexed epochId,
        uint256 winningMask,
        uint256 claimLiabilityTotal,
        uint256 settlementFeeTotal,
        bool refundMode
    );
    event EpochResolvedV2(
        bytes32 indexed templateId,
        uint64 indexed epochId,
        uint80 oracleRoundId,
        int256 checkpointBValueE8,
        uint64 publishTime
    );
    event YieldRouterSet(address indexed oldRouter, address indexed newRouter, uint16 yieldFeeBps);
    event EpochYieldAccrued(
        bytes32 indexed templateId,
        uint64 indexed epochId,
        uint256 grossYield,
        uint256 yieldFee,
        uint256 netYield
    );
    event YieldRouterWithdrawFailed(bytes32 indexed templateId, uint64 indexed epochId, uint256 principal);
    event YieldRouterDepositFailed(bytes32 indexed templateId, uint256 attemptedAmount);
    event LMRewardReceived(bytes32 indexed templateId, address indexed token, uint256 amount);
    event LMRewardsEnabledUpdated(bool enabled);
    event EpochCancelled(bytes32 indexed templateId, uint64 indexed epochId, uint8 reason);
    event Claimed(bytes32 indexed templateId, uint64 indexed epochId, address indexed user, uint256 amount);
    event FeesWithdrawn(bytes32 indexed templateId, uint256 amount);
    event RollingGenesisStarted(bytes32 indexed templateId, uint64 epochId, uint64 lockAt, uint64 resolveAt);
    event RollingGenesisLocked(bytes32 indexed templateId, uint64 lockedEpochId, uint64 newOpenEpochId);
    event RollingRoundExecuted(
        bytes32 indexed templateId, uint64 resolvedEpochId, uint64 lockedEpochId, uint64 newOpenEpochId
    );
    event RollingHalted(bytes32 indexed templateId, uint8 reason, uint64 haltedAtEpochId);
    event RollingLifecycleReset(bytes32 indexed templateId, uint64 nextRollingEpochId);
    event DepositExecutorSet(address indexed account, bool allowed);
    event WorkerAuthorityUpdated(address indexed previousWorker, address indexed newWorker);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event SelectorModuleSet(bytes4 indexed selector, address indexed module, bool immutableSelector);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    function templateIdFromSlug(string memory slug) public pure returns (bytes32) {
        return keccak256(bytes(slug));
    }

    function positionKey(bytes32 templateId, uint64 epochId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(templateId, epochId));
    }
}
// slither-disable-end uninitialized-state
