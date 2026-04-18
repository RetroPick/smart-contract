// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MarketTypes} from "../types/MarketTypes.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IYieldRouterV2} from "../interfaces/IYieldRouterV2.sol";
import {MarketMath} from "../math/MarketMath.sol";
import {SettlementLogic} from "../logic/SettlementLogic.sol";

/// @notice Canonical MarketEngine storage anchor used by dispatcher/modules.
/// @dev Keep this layout append-only for upgrade safety. Delegatecall modules must use this exact layout
/// (typically by inheriting this contract). The `marketEngineStorageCompatibility()` marker is not a proof of
/// layout correctness on-chain—only discipline, review, and the dispatcher bytecode allowlist mitigate storage clashes.
/// Trust / deployment: primitives (`admin`, `stakeToken`, `oracleConfig`, …) are set in
/// `MarketEngineDispatcher.initialize` on the UUPS proxy. Mappings default to empty. A proxy that
/// skips `initialize` is broken by design—operational risk, not an on-chain uninitialized read.
/// Stake token: user deposits require exact `balanceOf` delta (`NonStandardStakeToken`); yield routers
/// still assume ERC20 semantics for Aave/4626 integration.
// slither-disable-start uninitialized-state -- UUPS: dispatcher `initialize` sets primitives; mappings start empty
abstract contract MarketEngineState {
    bytes32 internal constant MODULE_STORAGE_COMPATIBILITY_ID = keccak256("retropick.marketengine.state.v1");
    uint256 public constant MAX_BATCH_SIZE = 100;
    uint256 internal constant MAX_USER_EPOCHS_PAGE_SIZE = 256;
    uint64 internal constant MIN_MANUAL_DEPOSIT_WINDOW = 10;
    uint64 internal constant MIN_MANUAL_LOCK_WINDOW = 10;
    uint64 internal constant MAX_MANUAL_EPOCH_DURATION = 30 days;
    uint64 internal constant MIN_ROLLING_INTERVAL_SECONDS = 10;
    uint64 internal constant MAX_ROLLING_INTERVAL_SECONDS = 7 days;

    IERC20 public stakeToken;
    IPriceOracle public priceOracle;
    IPriceOracle public rateOracle;
    IPriceOracle public smartDataOracle;
    IPriceOracle public macroOracle;
    IPriceOracle public equityOracle;

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
    mapping(bytes32 templateId => mapping(bytes32 feedId => bool)) internal oracleCursorUsesRoundId;

    IYieldRouterV2 public yieldRouter;
    uint16 public yieldFeeBps;
    bool public lmRewardsEnabled;
    bool public yieldRouterDisabled;
    uint8 public yieldRouterFailureCount;
    uint8 internal constant MAX_YIELD_ROUTER_FAILURES = 3;
    uint16 internal constant YIELD_BUFFER_BPS = 500;

    // --- dispatcher state (appended after legacy state) ---
    mapping(bytes4 selector => address module) internal selectorToModule;
    mapping(bytes4 selector => bool immutableSelector) internal selectorImmutable;

    uint256[41] private __gap;

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
    error OracleSampleNotMonotonic(
        uint80 newRoundId, uint80 lastRoundId, uint64 newPublishTime, uint64 lastPublishTime
    );
    error YieldWithdrawFailed();
    error YieldRouterBalanceInvariant();
    error ModuleNotSet(bytes4 selector);
    error InvalidModule();
    error IncompatibleModuleStorage(address module);
    error InvalidBatchSize(uint256 requested);
    error UnapprovedModule(address module);
    error ModuleCodeHashMismatch(address module, bytes32 expectedCodeHash, bytes32 actualCodeHash);
    error ModuleCodeHashNotAllowed(bytes32 codeHash);
    error SelectorImmutable(bytes4 selector);
    error OracleAdapterNotConfigured();
    error NotInitialized();
    error VaultInsufficientActive(bytes32 templateId, uint256 active, uint256 required);

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
    event YieldRouterFailureRecorded(uint8 failureCount, bool disabled);
    event YieldRouterDisabled();
    event YieldRouterFailureStateReset();
    event EpochYieldAccrued(
        bytes32 indexed templateId, uint64 indexed epochId, uint256 grossYield, uint256 yieldFee, uint256 netYield
    );
    event YieldRouterWithdrawFailed(bytes32 indexed templateId, uint64 indexed epochId, uint256 principal);
    event YieldRouterDepositFailed(bytes32 indexed templateId, uint256 attemptedAmount);
    event LMRewardReceived(bytes32 indexed templateId, address indexed token, uint256 amount);
    event LMRewardsEnabledUpdated(bool enabled);
    event EpochCancelled(bytes32 indexed templateId, uint64 indexed epochId, uint8 reason);
    event Claimed(bytes32 indexed templateId, uint64 indexed epochId, address indexed user, uint256 amount);
    event FeesWithdrawn(bytes32 indexed templateId, uint256 amount);
    event YieldEmergencyWithdrawn(bytes32 indexed templateId, uint256 grossAmount);
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
    event ModuleRegistered(address indexed module, bytes32 indexed codeHash);
    event ModuleCodeHashAllowed(bytes32 indexed codeHash);
    event ModuleCodeHashDisallowed(bytes32 indexed codeHash);
    event ModuleRevoked(address indexed module);
    event SelectorModuleSet(bytes4 indexed selector, address indexed module, bool immutableSelector);
    event RateOracleSet(address indexed previousOracle, address indexed newOracle);
    event SmartDataOracleSet(address indexed previousOracle, address indexed newOracle);
    event MacroOracleSet(address indexed previousOracle, address indexed newOracle);
    event EquityOracleSet(address indexed previousOracle, address indexed newOracle);
    event OracleCursorReset(bytes32 indexed templateId, bytes32 indexed feedId);

    modifier onlyAdmin() {
        if (!configInitialized) revert NotInitialized();
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /// @dev Modules use these instead of duplicating `onlyAdmin` / worker checks so uninitialized proxies reject cleanly.
    function _authAdmin() internal view {
        if (!configInitialized) revert NotInitialized();
        if (msg.sender != admin) revert Unauthorized();
    }

    function _authAdminOrWorker() internal view {
        if (!configInitialized) revert NotInitialized();
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
    }

    function _authTreasuryOrAdmin() internal view {
        if (!configInitialized) revert NotInitialized();
        if (msg.sender != treasury && msg.sender != admin) revert Unauthorized();
    }

    /// @notice Delegatecall module compatibility marker.
    /// @dev Dispatcher verifies this marker on registration and before delegatecall; it only proves the module
    /// implements this selector with the expected constant, not that bytecode matches `MarketEngineState` storage.
    function marketEngineStorageCompatibility() external pure returns (bytes32) {
        return MODULE_STORAGE_COMPATIBILITY_ID;
    }

    function _validateBatchSize(uint256 n) internal pure {
        if (n == 0 || n > MAX_BATCH_SIZE) revert InvalidBatchSize(n);
    }

    function templateIdFromSlug(string memory slug) public pure returns (bytes32) {
        return keccak256(bytes(slug));
    }

    /// @notice Canonical `marketId` for trusted-reporter / event oracles: `keccak256(abi.encodePacked(templateId, epochId))`.
    /// @dev Fixed-width `bytes32` + `uint64` packing is injective on pairs (no classic `encodePacked` ambiguity with dynamic types).
    function positionKey(bytes32 templateId, uint64 epochId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(templateId, epochId));
    }

    function _resolveOracleByClass(MarketTypes.OracleClass oracleClass) internal view returns (IPriceOracle) {
        if (oracleClass == MarketTypes.OracleClass.CHAINLINK_RATE) {
            if (address(rateOracle) == address(0)) revert OracleAdapterNotConfigured();
            return rateOracle;
        }
        if (oracleClass == MarketTypes.OracleClass.CHAINLINK_SMARTDATA) {
            if (address(smartDataOracle) == address(0)) revert OracleAdapterNotConfigured();
            return smartDataOracle;
        }
        if (oracleClass == MarketTypes.OracleClass.CHAINLINK_MACRO) {
            if (address(macroOracle) == address(0)) revert OracleAdapterNotConfigured();
            return macroOracle;
        }
        if (oracleClass == MarketTypes.OracleClass.CHAINLINK_EQUITY) {
            if (address(equityOracle) == address(0)) revert OracleAdapterNotConfigured();
            return equityOracle;
        }
        return priceOracle;
    }

    function _resolveOracle(bytes32 templateId) internal view returns (IPriceOracle) {
        return _resolveOracleByClass(_templates[templateId].oracleClass);
    }

    function _applyResolveAccounting(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.Ledger storage ledger,
        MarketTypes.Epoch storage e,
        SettlementLogic.Outputs memory outputs,
        uint64 nowTs
    ) internal {
        uint256 totalDeduction = outputs.claimLiabilityTotal + outputs.settlementFeeTotal;
        if (_vaults[templateId].active < totalDeduction) {
            revert VaultInsufficientActive(templateId, _vaults[templateId].active, totalDeduction);
        }
        if (outputs.claimLiabilityTotal > 0) {
            _vaults[templateId].active -= outputs.claimLiabilityTotal;
            _vaults[templateId].claims += outputs.claimLiabilityTotal;
            MarketMath.reserveClaimsFromActive(ledger, outputs.claimLiabilityTotal);
        }
        if (outputs.settlementFeeTotal > 0) {
            _vaults[templateId].active -= outputs.settlementFeeTotal;
            _vaults[templateId].fees += outputs.settlementFeeTotal;
            MarketMath.reserveFeesFromActive(ledger, outputs.settlementFeeTotal);
        }
        e.winningOutcomeMask = outputs.winningMask;
        e.claimLiabilityTotal = outputs.refundMode ? 0 : outputs.claimLiabilityTotal;
        e.totalRefundLiability = outputs.refundMode ? outputs.claimLiabilityTotal : 0;
        e.settlementFeeTotal = outputs.settlementFeeTotal;
        e.refundMode = outputs.refundMode;
        e.claimable = true;
        e.status = outputs.refundMode ? MarketTypes.EpochStatus.Voided : MarketTypes.EpochStatus.Resolved;
        e.resolvedAt = nowTs;
        ledger.lastResolvedEpochId = epochId;
        _setRemainingWinningStake(templateId, epochId, outputs.refundMode);
    }

    function _emitResolveEvents(
        bytes32 templateId,
        uint64 epochId,
        SettlementLogic.Outputs memory outputs,
        uint80 oracleRoundId
    ) internal {
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        emit EpochResolved(
            templateId,
            epochId,
            outputs.winningMask,
            outputs.claimLiabilityTotal,
            outputs.settlementFeeTotal,
            outputs.refundMode
        );
        emit EpochResolvedV2(templateId, epochId, oracleRoundId, e.checkpointB.valueE8, e.checkpointB.publishTime);
    }

    function _setRemainingWinningStake(bytes32 templateId, uint64 epochId, bool refundMode) internal {
        MarketTypes.Epoch storage e = _epochs[templateId][epochId];
        if (refundMode) {
            e.remainingWinningStake = 0;
            return;
        }
        uint256 sum = 0;
        uint8 n = e.outcomeCount;
        for (uint256 i = 0; i < uint256(n); i++) {
            if (((e.winningOutcomeMask >> i) & 1) != 0) sum += e.outcomePools[i];
        }
        e.remainingWinningStake = sum;
    }

    /// @dev Uses `stakeToken` balance delta after `withdrawScaled`; do not trust the router return value for accounting.
    function _balanceDeltaAfterWithdrawScaled(IYieldRouterV2 r, bytes32 templateId, uint256 principalAmount)
        internal
        returns (uint256 received)
    {
        uint256 b0 = stakeToken.balanceOf(address(this));
        r.withdrawScaled(templateId, principalAmount);
        uint256 b1 = stakeToken.balanceOf(address(this));
        if (b1 < b0) revert YieldRouterBalanceInvariant();
        unchecked {
            return b1 - b0;
        }
    }
}
// slither-disable-end uninitialized-state
