// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {MarketTypes} from "./types/MarketTypes.sol";
import {MarketMath} from "./math/MarketMath.sol";
import {Resolvers} from "./logic/Resolvers.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IPriceOracleWithRoundId} from "./interfaces/IPriceOracleWithRoundId.sol";
import {IYieldRouter} from "./interfaces/IYieldRouter.sol";

/// @title MarketEngine
/// @notice RetroPick rolling-rounds prediction market engine (monolithic per-protocol contract).
/// @dev
/// NOTES: Core model (Template -> Ledger -> Epoch -> Position)
/// RetroPick runs many markets inside one engine. A market is identified by a template id (`templateId`)
/// and has a per-template ledger plus a sequence of epochs (a.k.a. rounds).
///
/// - Template (`templates[templateId]`): market definition (type, oracle feed id, fees, execution mode).
/// - Ledger (`ledgers[templateId]`): per-template cursor + reserves + rolling lifecycle state.
/// - Epoch (`epochs[templateId][epochId]`): one round lifecycle: open -> lock -> resolve -> claim.
/// - Position (`positions[positionKey(templateId,epochId)][user]`): user stake per outcome in an epoch.
///
/// Epoch ids are `uint64`. Manual-mode epochs must be sequential and fully resolved before the next open.
/// Rolling-mode epochs use an independent cursor (`rollingNextEpochId`) and can be reset upward after halts.
///
/// NOTES: Execution modes
/// - Manual (`ExecutionMode.Manual`): keeper calls `openEpoch` -> `lockEpoch` -> `resolveEpoch`.
/// - Rolling (`ExecutionMode.Rolling`): pipeline that advances in one keeper tx per interval:
///   - `genesisStartRolling` opens epoch k (k starts at 1).
///   - `genesisLockRolling` locks k (writes checkpoint A only for Direction) and opens k+1, entering steady state.
///   - `executeRollingRound` steady-state: resolves (k-1), locks (k), opens (k+1).
///
/// INVARIANT: Rolling steady-state (Direction)
/// Let `k = ledger.activeEpochId` when rolling is `Live`:
/// - epoch k is Open (accepting bets)
/// - epoch k-1 is Locked
/// - epoch k-2 is already Resolved (or voided/cancelled and claimable)
///
/// `executeRollingRound` uses a single oracle sample and applies it to both:
/// - checkpoint B for epoch (k-1) resolve, and
/// - checkpoint A for epoch k lock.
///
/// NOTES: Oracle model (push oracles like Chainlink)
/// The oracle adapter returns `(priceE8, publishTime, confidenceE8)`. `publishTime` is the oracle’s own
/// update timestamp (e.g. Chainlink `updatedAt`), which may be earlier than `lockAt/resolveAt`.
/// The engine therefore validates freshness vs now and monotonicity rather than requiring
/// `publishTime >= lockAt/resolveAt`.
///
/// NOTES: Oracle sample monotonicity cursor (anti time-travel + feed migration safety)
/// The engine tracks an `OracleCursor` per (templateId, feedId) in `lastOracleCursorByTemplateFeed`.
/// Samples must be monotonic:
/// - `oracleRoundId` must not decrease
/// - if `oracleRoundId` is unchanged (e.g. adapters without round ids use 0), `publishTime` must not decrease
///
/// Example:
/// - lock: (round=120, publishTime=10:00)
/// - resolve: (round=121, publishTime=10:05) ✅
/// - resolve attempt: (round=119, publishTime=09:55) ❌ 
///
/// NOTES: Funds and accounting
/// One ERC20 `stakeToken` is used for staking, fees, and payouts. Per-template vault accounting splits totals into:
/// - `active`: collateral backing open/locked epochs
/// - `claims`: reserved for winners/refunds in claimable epochs
/// - `fees`: reserved protocol fees (withdrawable by `treasury`)
///
/// Resolve moves amounts from active→claims and active→fees based on settlement math (`MarketMath`).
/// Claim moves amounts from claims→user and decrements ledger reserves.
///
/// IMPORTANT: Last-claimer remainder rule (per-epoch)
/// On the last winning claimant for an epoch, payout equals the remaining claim pool for that epoch:
/// `remainingClaimsForEpoch = epoch.claimLiabilityTotal - epoch.claimedTotal` (not the global claims reserve).
///
/// NOTES: Roles
/// - `admin`: governance; templates, pause, config, executor allowlist, and UUPS upgrades.
/// - `workerAuthority`: keeper/operator; epoch lifecycle ops (manual or rolling).
/// - `treasury`: fee receiver; can withdraw accumulated fees.
///
/// NOTES: Upgradeability (UUPS)
/// Deploy `MarketEngine` implementation + ERC1967 proxy (`initialize` via proxy creation calldata).
/// Upgrades are `admin`-only via `_authorizeUpgrade`. Storage layout is append-only; `__gap` must remain.
contract MarketEngine is Initializable, ReentrancyGuardTransient, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using MarketTypes for MarketTypes.Epoch;
    using MarketMath for MarketTypes.Ledger;

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

    mapping(bytes32 templateId => MarketTypes.Template) public templates;
    mapping(bytes32 templateId => MarketTypes.Ledger) public ledgers;
    mapping(bytes32 templateId => MarketTypes.VaultBalances) internal vaults;
    mapping(bytes32 templateId => mapping(uint64 epochId => MarketTypes.Epoch)) public epochs;
    mapping(bytes32 positionKey => mapping(address user => MarketTypes.Position)) internal positions;

    /// @dev Contracts allowed to call `depositToSideFor` (e.g. swap routers). Governed by `admin`.
    mapping(address account => bool) public isDepositExecutor;

    /// @dev onchain user participation index for UI pagination.
    mapping(bytes32 templateId => mapping(address user => uint64[] epochIds)) internal userEpochs;

    /// @dev Chainlink oracle monotonicity per template (roundId must strictly increase).
    mapping(bytes32 templateId => uint80 lastOracleRoundId) internal lastOracleRoundIdByTemplate;

    /// @dev Oracle sample cursor keyed by template + feed to avoid feed-migration bricking.
    struct OracleCursor {
        uint80 roundId;
        uint64 publishTime;
    }
    mapping(bytes32 templateId => mapping(bytes32 feedId => OracleCursor)) internal lastOracleCursorByTemplateFeed;

    /// @notice Optional yield router. When set, a portion of deposits is routed into a yield backend.
    IYieldRouter public yieldRouter;

    /// @notice Fee on gross yield in basis points (0..10_000).
    uint16 public yieldFeeBps;

    /// @dev Portion of each deposit retained in-engine as raw liquidity buffer (BPS).
    uint16 internal constant YIELD_BUFFER_BPS = 500; // 5%

    /// @dev Reserved for future storage variables; do not remove or move (UUPS upgrade safety).
    // slither-disable-next-line unused-state,naming-convention -- UUPS storage gap; OZ reserved name
    uint256[47] private __gap;

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
    // NOTE: rolling is supported for all market types; Direction additionally writes checkpoint A at lock.
    error RollingInvalidParams();
    error RollingGenesisAlreadyStarted();
    error RollingHaltedUserOps();
    error InvalidRollingRecovery();
    error NotDepositExecutor();
    error OracleRoundIdNotMonotonic(uint80 newRoundId, uint80 lastRoundId);
    error NonStandardStakeToken();
    error OracleSampleNotMonotonic(uint80 newRoundId, uint80 lastRoundId, uint64 newPublishTime, uint64 lastPublishTime);
    error YieldWithdrawFailed();

    // slither-disable-next-line unindexed-event-address -- stable init event; indexing would change ABI
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

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier onlyWorkerOrAdmin() {
        if (msg.sender != admin && msg.sender != workerAuthority) revert Unauthorized();
        _;
    }

    modifier onlyTreasuryOrAdmin() {
        if (msg.sender != treasury && msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier notPausedUserOps() {
        if (globalPaused) revert ProtocolPaused();
        _;
    }

    modifier notPausedWorkerOps() {
        if (globalPaused) revert ProtocolPaused();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @dev Implementation constructor disables initializers to prevent implementation takeover.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the engine behind a UUPS proxy.
    /// @dev
    /// - Must be called exactly once (protected by `initializer` + `onlyProxy`).
    /// - Rejects non-Chainlink oracle kinds in the current implementation.
    /// - `maxOutcomes_` is capped by `MarketTypes.MAX_OUTCOMES` (8) to bound outcome arrays in `Epoch/Position`.
    /// - Fees are basis points: 0..10_000.
    /// @param stakeToken_ ERC20 used for staking, fees, and payouts.
    /// @param priceOracle_ Oracle adapter implementing `IPriceOracle` (optionally `IPriceOracleWithRoundId`).
    /// @param admin_ Governance authority (also authorizes UUPS upgrades).
    /// @param treasury_ Fee receiver.
    /// @param worker_ Keeper/operator authority.
    /// @param defaultSettlementFeeBps_ Default settlement fee basis points.
    /// @param maxSwitchFeeBps_ Global cap on per-template switch fee basis points.
    /// @param maxOutcomes_ Global cap on per-template outcomes.
    /// @param oracleKind_ Global oracle kind (currently Chainlink only).
    /// @param oracleMaxDelaySeconds_ Global staleness window for oracle `publishTime` freshness validation.
    /// @param oracleMaxConfidenceBps_ Global confidence cap in basis points relative to \(|price|\).
    function initialize(
        IERC20 stakeToken_,
        IPriceOracle priceOracle_,
        address admin_,
        address treasury_,
        address worker_,
        uint16 defaultSettlementFeeBps_,
        uint16 maxSwitchFeeBps_,
        uint8 maxOutcomes_,
        MarketTypes.OracleKind oracleKind_,
        uint64 oracleMaxDelaySeconds_,
        uint16 oracleMaxConfidenceBps_
    ) external initializer onlyProxy {
        if (configInitialized) revert Unauthorized();
        if (address(stakeToken_) == address(0) || address(priceOracle_) == address(0)) revert Unauthorized();
        if (admin_ == address(0) || treasury_ == address(0) || worker_ == address(0)) revert Unauthorized();
        if (defaultSettlementFeeBps_ > 10_000 || maxSwitchFeeBps_ > 10_000) revert InvalidFeeBps();
        if (maxOutcomes_ > MarketTypes.MAX_OUTCOMES) revert TooManyOutcomes();
        if (oracleKind_ != MarketTypes.OracleKind.Chainlink) revert InvalidOracleFeed();

        stakeToken = stakeToken_;
        priceOracle = priceOracle_;
        admin = admin_;
        treasury = treasury_;
        workerAuthority = worker_;
        defaultSettlementFeeBps = defaultSettlementFeeBps_;
        maxSwitchFeeBps = maxSwitchFeeBps_;
        maxOutcomes = maxOutcomes_;
        oracleConfig = MarketTypes.OracleConfig({
            oracleKind: oracleKind_, maxDelaySeconds: oracleMaxDelaySeconds_, maxConfidenceBps: oracleMaxConfidenceBps_
        });

        configInitialized = true;
        emit ConfigInitialized(admin_, treasury_, worker_);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Configure (or disable) yield routing.
    /// @dev Pass `router=address(0)` to disable. Fee is applied only when router is enabled.
    function setYieldRouter(address router, uint16 feeBps) external onlyAdmin {
        if (feeBps > 10_000) revert InvalidFeeBps();
        address old = address(yieldRouter);
        yieldRouter = IYieldRouter(router);
        yieldFeeBps = router == address(0) ? 0 : feeBps;
        emit YieldRouterSet(old, router, yieldFeeBps);
    }

    /// @notice Emergency: withdraw all yield-bearing assets for a template back to the engine.
    function yieldEmergencyWithdraw(bytes32 templateId) external onlyAdmin nonReentrant {
        IYieldRouter r = yieldRouter;
        if (address(r) == address(0)) revert Unauthorized();
        r.emergencyWithdraw(templateId);
    }

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

    /// @notice Create or update a template (market definition) keyed by `templateIdFromSlug(p.slug)`.
    /// @dev
    /// Template invariants are validated by `_validateTemplate`. Important rules:
    /// - Direction: binary outcomes (2), `ThresholdRule.None`, and `equalPriceVoids=true`.
    /// - Threshold: binary outcomes (2) and `ThresholdRule.Absolute`.
    /// - RangeClose: `outcomeCount >= 2` and `rangeBoundsE8` strictly increasing for the used prefix.
    /// - Rolling: requires `rollingIntervalSeconds > 0` and `rollingBufferSeconds < rollingIntervalSeconds`.
    ///
    /// Integration note:
    /// - Epochs snapshot template fields at open. Updating a template does not retroactively change existing epochs.
    function upsertTemplate(UpsertTemplateParams calldata p) external onlyAdmin {
        if (bytes(p.slug).length == 0 || bytes(p.slug).length > MarketTypes.SLUG_MAX_LEN) revert InvalidTemplate();
        if (bytes(p.assetSymbol).length == 0 || bytes(p.assetSymbol).length > MarketTypes.ASSET_SYMBOL_MAX_LEN) {
            revert InvalidTemplate();
        }
        if (p.switchFeeBps > maxSwitchFeeBps) revert InvalidFeeBps();
        if (p.outcomeCount == 0 || p.outcomeCount > maxOutcomes) revert TooManyOutcomes();
        if (p.oracleFeedId == bytes32(0)) revert InvalidOracleFeed();

        bytes32 tid = templateIdFromSlug(p.slug);
        MarketTypes.Template storage t = templates[tid];

        if (t.version != 0) {
            if (keccak256(bytes(t.slug)) != keccak256(bytes(p.slug))) revert InvalidTemplate();
        } else {
            t.version = MarketTypes.VERSION;
        }

        t.slug = p.slug;
        t.assetSymbol = p.assetSymbol;
        t.oracleFeedId = p.oracleFeedId;
        t.marketType = p.marketType;
        t.condition = p.condition;
        t.thresholdRule = p.thresholdRule;
        t.active = p.active;
        t.outcomeCount = p.outcomeCount;
        t.absoluteThresholdValueE8 = p.absoluteThresholdValueE8;
        t.rangeBoundsE8 = p.rangeBoundsE8;
        t.switchFeeBps = p.switchFeeBps;
        t.settlementFeeBps = p.settlementFeeBps;
        t.equalPriceVoids = true;
        t.feeOnLosingPool = true;
        t.allowMultiSidePositions = p.allowMultiSidePositions;
        t.executionMode = p.executionMode;
        t.rollingIntervalSeconds = p.rollingIntervalSeconds;
        t.rollingBufferSeconds = p.rollingBufferSeconds;
        t.oracleMaxDelaySeconds = p.oracleMaxDelaySeconds;
        t.oracleMaxConfidenceBps = p.oracleMaxConfidenceBps;

        if (p.executionMode == MarketTypes.ExecutionMode.Rolling) {
            if (p.rollingIntervalSeconds == 0) revert RollingInvalidParams();
            if (!(p.rollingBufferSeconds < p.rollingIntervalSeconds)) revert RollingInvalidParams();
        }

        _validateTemplate(t);
        emit TemplateUpserted(
            tid, p.slug, uint8(uint256(p.marketType)), p.outcomeCount, p.oracleMaxDelaySeconds, p.oracleMaxConfidenceBps
        );
    }

    /// @notice Initialize per-template ledger storage (one-time) so epochs can be opened.
    /// @dev Initializes cursors and reserves to zero and sets rolling lifecycle to `Uninitialized`.
    function initializeMarket(bytes32 templateId) external onlyAdmin {
        MarketTypes.Template storage t = templates[templateId];
        if (t.version == 0) revert InvalidTemplate();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (ledger.initialized) revert EpochAlreadyExists();

        ledger.version = MarketTypes.VERSION;
        ledger.initialized = true;
        ledger.activeEpochId = 0;
        ledger.lastResolvedEpochId = 0;
        ledger.activeCollateralTotal = 0;
        ledger.claimsReserveTotal = 0;
        ledger.feeReserveTotal = 0;
        ledger.insuranceReserveTotal = 0;
        ledger.rollingPhase = MarketTypes.RollingPhase.Uninitialized;
        ledger.rollingHaltReason = MarketTypes.RollingHaltReason.NoneReason;
        ledger.rollingNextEpochId = 1;
        ledger.haltedAtEpochId = 0;

        emit MarketInitialized(templateId);
    }

    /// @notice Start a rolling market by opening the genesis epoch (bootstrap step 1/2).
    /// @dev
    /// Rolling uses fixed interval timing:
    /// - openAt = now
    /// - lockAt = now + rollingIntervalSeconds
    /// - resolveAt = now + 2*rollingIntervalSeconds
    ///
    /// After this call:
    /// - `ledger.activeEpochId` becomes the opened epoch id (starting at `ledger.rollingNextEpochId`, initially 1).
    /// - `ledger.rollingPhase` becomes `GenesisOpen`.
    ///
    /// Keepers must follow with `genesisLockRolling` after `lockAt` (within the template buffer window).
    function genesisStartRolling(bytes32 templateId) external onlyWorkerOrAdmin notPausedWorkerOps {
        if (!configInitialized) revert Unauthorized();
        MarketTypes.Template storage t = templates[templateId];
        if (t.version == 0) revert InvalidTemplate();
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.Uninitialized) revert RollingGenesisAlreadyStarted();

        uint64 ts = uint64(block.timestamp);
        uint64 opened = _openRollingEpoch(templateId, ts, t);
        ledger.rollingPhase = MarketTypes.RollingPhase.GenesisOpen;
        emit RollingGenesisStarted(
            templateId, opened, uint64(ts + t.rollingIntervalSeconds), uint64(ts + 2 * t.rollingIntervalSeconds)
        );
    }

    /// @notice Lock the genesis epoch and open the next; enter steady-state rolling (bootstrap step 2/2).
    /// @dev
    /// Performs:
    /// - lock epoch k = `ledger.activeEpochId` (writes checkpoint A only for Direction)
    /// - open epoch k+1
    /// - sets `ledger.rollingPhase = Live`
    ///
    /// Liveness-first behavior: buffer misses, oracle failures, or wide confidence halt rolling instead of reverting.
    ///
    /// Buffer rule: must be called in `[lockAt, lockAt + rollingBufferSeconds]`.
    function genesisLockRolling(bytes32 templateId) external onlyWorkerOrAdmin notPausedWorkerOps nonReentrant {
        if (!configInitialized) revert Unauthorized();
        MarketTypes.Template storage t = templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.GenesisOpen) revert RollingWrongPhase();

        uint64 k = ledger.activeEpochId;
        _requireActiveEpoch(ledger, k);
        MarketTypes.Epoch storage e1 = epochs[templateId][k];
        uint64 nowTs = uint64(block.timestamp);
        if (nowTs < e1.timing.lockAt) revert TooEarlyToLock();
        if (nowTs > e1.timing.lockAt + t.rollingBufferSeconds) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnLock, k);
            return;
        }

        if (MarketTypes.requiresCheckpointAOnLock(e1)) {
            uint64 maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(e1, oracleConfig.maxDelaySeconds);
            uint16 maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(e1, oracleConfig.maxConfidenceBps);
            (bool ok, int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId) =
                _tryReadOracle(templateId, t.oracleFeedId, maxDelay, nowTs);
            if (!ok) {
                _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleFailure, k);
                return;
            }
            if (!_confidenceWithinBand(priceE8, confidenceE8, maxConf)) {
                _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleConfidenceWide, k);
                return;
            }
            _applyLock(templateId, k, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelay, maxConf, nowTs);
        } else {
            _applyLock(templateId, k, 0, 0, 0, 0, 0, 0, nowTs);
        }

        uint64 newOpen = _openRollingEpoch(templateId, nowTs, t);
        ledger.rollingPhase = MarketTypes.RollingPhase.Live;
        emit RollingGenesisLocked(templateId, k, newOpen);
    }

    /// @notice Rolling tick: resolve (k-1), lock (k), open (k+1) in one keeper transaction.
    /// @dev
    /// Uses a single oracle sample for:
    /// - checkpoint B for epoch (k-1) resolve, and
    /// - checkpoint A for epoch k lock.
    ///
    /// This is the primary keeper entrypoint in rolling steady state.
    function executeRollingRound(bytes32 templateId) external onlyWorkerOrAdmin notPausedWorkerOps nonReentrant {
        _executeRollingRoundCore(templateId);
    }

    function _executeRollingRoundCore(bytes32 templateId) internal {
        if (!configInitialized) revert Unauthorized();
        MarketTypes.Template storage t = templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.Live) revert RollingWrongPhase();

        uint64 k = ledger.activeEpochId;
        if (k < 2) revert InvalidEpochState();
        uint64 prev = k - 1;

        MarketTypes.Epoch storage ePrev = epochs[templateId][prev];
        MarketTypes.Epoch storage eCur = epochs[templateId][k];
        uint64 nowTs = uint64(block.timestamp);

        if (nowTs < ePrev.timing.resolveAt) revert TooEarlyToResolve();
        if (nowTs > ePrev.timing.resolveAt + t.rollingBufferSeconds) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnResolve, prev);
            return;
        }
        if (nowTs < eCur.timing.lockAt) revert TooEarlyToLock();
        if (nowTs > eCur.timing.lockAt + t.rollingBufferSeconds) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.BufferMissOnLock, k);
            return;
        }

        uint64 maxDelay;
        uint16 maxConf;
        if (MarketTypes.requiresCheckpointAOnLock(eCur)) {
            uint64 dPrev = MarketTypes.effectiveOracleMaxDelaySeconds(ePrev, oracleConfig.maxDelaySeconds);
            uint64 dCur = MarketTypes.effectiveOracleMaxDelaySeconds(eCur, oracleConfig.maxDelaySeconds);
            maxDelay = dPrev < dCur ? dPrev : dCur;
            uint16 cPrev = MarketTypes.effectiveOracleMaxConfidenceBps(ePrev, oracleConfig.maxConfidenceBps);
            uint16 cCur = MarketTypes.effectiveOracleMaxConfidenceBps(eCur, oracleConfig.maxConfidenceBps);
            maxConf = cPrev < cCur ? cPrev : cCur;
        } else {
            maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(ePrev, oracleConfig.maxDelaySeconds);
            maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(ePrev, oracleConfig.maxConfidenceBps);
        }

        (bool ok, int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId) =
            _tryReadOracle(templateId, t.oracleFeedId, maxDelay, nowTs);
        if (!ok) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleFailure, k);
            return;
        }
        if (!_confidenceWithinBand(priceE8, confidenceE8, maxConf)) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleConfidenceWide, k);
            return;
        }

        _finishResolveEpochRolling(templateId, prev, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelay);
        if (MarketTypes.requiresCheckpointAOnLock(eCur)) {
            _applyLock(templateId, k, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelay, maxConf, nowTs);
        } else {
            _applyLock(templateId, k, 0, 0, 0, 0, 0, 0, nowTs);
        }
        uint64 newOpen = _openRollingEpoch(templateId, nowTs, t);

        emit RollingRoundExecuted(templateId, prev, k, newOpen);
    }

    /// @notice Amortize calldata for multi-template rolling keepers.
    function executeRollingRoundBatch(bytes32[] calldata templateIds)
        external
        onlyWorkerOrAdmin
        notPausedWorkerOps
        nonReentrant
    {
        uint256 n = templateIds.length;
        for (uint256 i = 0; i < n; i++) {
            _executeRollingRoundCore(templateIds[i]);
        }
    }

    function pauseProgram(bool paused) external onlyAdmin {
        globalPaused = paused;
    }

    /// @notice Emergency: stop rolling keeper progression (users can still claim; use recovery flow to re-bootstrap).
    function haltRollingMarket(bytes32 templateId) external onlyAdmin {
        MarketTypes.Template storage t = templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (
            ledger.rollingPhase != MarketTypes.RollingPhase.GenesisOpen
                && ledger.rollingPhase != MarketTypes.RollingPhase.Live
        ) revert RollingWrongPhase();
        _haltRolling(
            templateId, ledger, MarketTypes.RollingHaltReason.ManualAdmin, ledger.activeEpochId
        );
    }

    /// @dev After halt: pause, cancel stuck Open/Locked epochs via `cancelRollingEpochWhileHalted`, then reset cursors and re-run genesis.
    function resetRollingLifecycle(bytes32 templateId, uint64 nextRollingEpochId) external onlyAdmin {
        if (!globalPaused) revert ProtocolPaused();
        MarketTypes.Template storage t = templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.Halted) revert RollingWrongPhase();
        uint64 hi = ledger.lastResolvedEpochId;
        if (ledger.activeEpochId > hi) hi = ledger.activeEpochId;
        if (nextRollingEpochId == 0 || nextRollingEpochId <= hi) revert InvalidRollingRecovery();

        ledger.rollingPhase = MarketTypes.RollingPhase.Uninitialized;
        ledger.rollingHaltReason = MarketTypes.RollingHaltReason.NoneReason;
        ledger.haltedAtEpochId = 0;
        ledger.rollingNextEpochId = nextRollingEpochId;
        ledger.activeEpochId = 0;
        emit RollingLifecycleReset(templateId, nextRollingEpochId);
    }

    /// @dev Cancel an Open or Locked rolling epoch while halted (unlocks the locked predecessor the active-epoch-only `cancelEpoch` cannot reach).
    function cancelRollingEpochWhileHalted(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.CancelReason reason,
        bool voided
    ) external onlyAdmin nonReentrant {
        if (!globalPaused) revert ProtocolPaused();
        if (reason == MarketTypes.CancelReason.NoneReason) revert InvalidEpochState();
        MarketTypes.Template storage t = templates[templateId];
        if (t.executionMode != MarketTypes.ExecutionMode.Rolling) revert RollingModeOnly();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.rollingPhase != MarketTypes.RollingPhase.Halted) revert RollingWrongPhase();

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (!e.exists) revert InvalidEpochState();
        if (!(e.status == MarketTypes.EpochStatus.Open || e.status == MarketTypes.EpochStatus.Locked)) {
            revert InvalidEpochState();
        }

        uint256 refundLiability = e.totalPool;
        if (refundLiability > 0) {
            vaults[templateId].active -= refundLiability;
            vaults[templateId].claims += refundLiability;
            MarketMath.reserveClaimsFromActive(ledger, refundLiability);
        }

        e.claimLiabilityTotal = 0;
        e.totalRefundLiability = refundLiability;
        e.settlementFeeTotal = 0;
        e.winningOutcomeMask = 0;
        e.remainingWinningStake = 0;
        e.cancelReason = reason;
        e.refundMode = true;
        e.claimable = true;
        e.status = voided ? MarketTypes.EpochStatus.Voided : MarketTypes.EpochStatus.Cancelled;
        e.resolvedAt = uint64(block.timestamp);
        if (epochId > ledger.lastResolvedEpochId) {
            ledger.lastResolvedEpochId = epochId;
        }

        emit EpochCancelled(templateId, epochId, uint8(reason));
    }

    function setWorkerAuthority(address worker) external onlyAdmin {
        if (worker == address(0)) revert InvalidAuthority();
        address prev = workerAuthority;
        workerAuthority = worker;
        emit WorkerAuthorityUpdated(prev, worker);
    }

    function setTreasury(address t) external onlyAdmin {
        if (t == address(0)) revert InvalidAuthority();
        address prev = treasury;
        treasury = t;
        emit TreasuryUpdated(prev, t);
    }

    function openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt)
        external
        onlyWorkerOrAdmin
        notPausedWorkerOps
    {
        _openEpoch(templateId, epochId, openAt, lockAt, resolveAt);
    }

    /// @notice Manual mode: batch open epochs across templates (amortizes base gas/calldata).
    /// @dev Arrays must be the same length. Each epoch must satisfy manual sequential-open invariants per template.
    function openEpochsBatch(
        bytes32[] calldata templateIds,
        uint64[] calldata epochIds,
        uint64[] calldata openAt,
        uint64[] calldata lockAt,
        uint64[] calldata resolveAt
    ) external onlyWorkerOrAdmin notPausedWorkerOps {
        uint256 n = templateIds.length;
        if (!(n == epochIds.length && n == openAt.length && n == lockAt.length && n == resolveAt.length)) {
            revert InvalidTemplate();
        }
        for (uint256 i = 0; i < n; i++) {
            _openEpoch(templateIds[i], epochIds[i], openAt[i], lockAt[i], resolveAt[i]);
        }
    }

    /// @dev Manual open implementation. Snapshots template parameters into the epoch storage.
    function _openEpoch(bytes32 templateId, uint64 epochId, uint64 openAt, uint64 lockAt, uint64 resolveAt) internal {
        if (templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
        if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();
        MarketTypes.Template storage t = templates[templateId];
        if (t.version == 0) revert InvalidTemplate();
        if (!t.active) revert TemplateInactive();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        _requireCanOpenNextEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (e.exists) revert EpochAlreadyExists();

        uint64 nowTs = uint64(block.timestamp);
        e.version = MarketTypes.VERSION;
        e.status = MarketTypes.EpochStatus.Open;
        e.cancelReason = MarketTypes.CancelReason.NoneReason;
        e.outcomeCount = t.outcomeCount;
        e.marketType = t.marketType;
        e.condition = t.condition;
        e.switchFeeBps = t.switchFeeBps;
        e.settlementFeeBps = t.settlementFeeBps;
        e.equalPriceVoids = t.equalPriceVoids;
        e.feeOnLosingPool = t.feeOnLosingPool;
        e.allowMultiSidePositions = t.allowMultiSidePositions;
        e.refundMode = false;
        e.claimable = false;
        e.exists = true;
        e.epochId = epochId;
        e.totalPositions = 0;
        e.timing = MarketTypes.MarketTiming({openAt: openAt, lockAt: lockAt, resolveAt: resolveAt});
        e.createdAt = nowTs;
        e.lockedAt = 0;
        e.resolvedAt = 0;
        e.oracleMaxDelaySeconds = t.oracleMaxDelaySeconds;
        e.oracleMaxConfidenceBps = t.oracleMaxConfidenceBps;
        e.checkpointA = MarketTypes.OracleCheckpoint({valueE8: 0, publishTime: 0, confidenceE8: 0, written: false});
        e.checkpointB = MarketTypes.OracleCheckpoint({valueE8: 0, publishTime: 0, confidenceE8: 0, written: false});
        e.oracleFeedId = t.oracleFeedId;
        e.absoluteThresholdValueE8 = t.absoluteThresholdValueE8;
        e.rangeBoundsE8 = t.rangeBoundsE8;
        e.winningOutcomeMask = 0;
        e.totalPool = 0;
        e.switchFeeTotal = 0;
        e.settlementFeeTotal = 0;
        e.claimLiabilityTotal = 0;
        e.totalRefundLiability = 0;
        e.claimedTotal = 0;
        e.remainingWinningStake = 0;
        for (uint256 i = 0; i < MarketTypes.MAX_OUTCOMES; i++) {
            e.outcomePools[i] = 0;
        }

        ledger.activeEpochId = epochId;
        emit EpochOpened(templateId, epochId, openAt, lockAt, resolveAt);
    }

    /// @dev
    /// Rolling-only open implementation.
    /// - Uses `ledger.rollingNextEpochId` then advances it.
    /// - Does not enforce manual sequential-open guard; rolling can restart at a higher epoch id after a halt.
    function _openRollingEpoch(bytes32 templateId, uint64 startTs, MarketTypes.Template storage t)
        internal
        returns (uint64 openedEpochId)
    {
        if (t.version == 0) revert InvalidTemplate();
        if (!t.active) revert TemplateInactive();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();

        uint64 epochId = ledger.rollingNextEpochId;
        if (epochId == 0) revert InvalidEpochState();

        uint64 inter = t.rollingIntervalSeconds;
        uint64 openAt = startTs;
        uint64 lockAt = startTs + inter;
        uint64 resolveAt = startTs + 2 * inter;
        if (!(openAt < lockAt && lockAt < resolveAt)) revert InvalidTiming();

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (e.exists) revert EpochAlreadyExists();

        uint64 nowTs = uint64(block.timestamp);
        e.version = MarketTypes.VERSION;
        e.status = MarketTypes.EpochStatus.Open;
        e.cancelReason = MarketTypes.CancelReason.NoneReason;
        e.outcomeCount = t.outcomeCount;
        e.marketType = t.marketType;
        e.condition = t.condition;
        e.switchFeeBps = t.switchFeeBps;
        e.settlementFeeBps = t.settlementFeeBps;
        e.equalPriceVoids = t.equalPriceVoids;
        e.feeOnLosingPool = t.feeOnLosingPool;
        e.allowMultiSidePositions = t.allowMultiSidePositions;
        e.refundMode = false;
        e.claimable = false;
        e.exists = true;
        e.epochId = epochId;
        e.totalPositions = 0;
        e.timing = MarketTypes.MarketTiming({openAt: openAt, lockAt: lockAt, resolveAt: resolveAt});
        e.createdAt = nowTs;
        e.lockedAt = 0;
        e.resolvedAt = 0;
        e.oracleMaxDelaySeconds = t.oracleMaxDelaySeconds;
        e.oracleMaxConfidenceBps = t.oracleMaxConfidenceBps;
        e.checkpointA = MarketTypes.OracleCheckpoint({valueE8: 0, publishTime: 0, confidenceE8: 0, written: false});
        e.checkpointB = MarketTypes.OracleCheckpoint({valueE8: 0, publishTime: 0, confidenceE8: 0, written: false});
        e.oracleFeedId = t.oracleFeedId;
        e.absoluteThresholdValueE8 = t.absoluteThresholdValueE8;
        e.rangeBoundsE8 = t.rangeBoundsE8;
        e.winningOutcomeMask = 0;
        e.totalPool = 0;
        e.switchFeeTotal = 0;
        e.settlementFeeTotal = 0;
        e.claimLiabilityTotal = 0;
        e.totalRefundLiability = 0;
        e.claimedTotal = 0;
        e.remainingWinningStake = 0;
        for (uint256 i = 0; i < MarketTypes.MAX_OUTCOMES; i++) {
            e.outcomePools[i] = 0;
        }

        ledger.activeEpochId = epochId;
        ledger.rollingNextEpochId = epochId + 1;
        openedEpochId = epochId;
        emit EpochOpened(templateId, epochId, openAt, lockAt, resolveAt);
    }

    /// @dev Enter `RollingPhase.Halted` with a reason and emit `RollingHalted`.
    /// Rolling halts are used instead of reverts for keeper liveness when conditions are unsafe (buffer miss/oracle issues).
    function _haltRolling(
        bytes32 templateId,
        MarketTypes.Ledger storage ledger,
        MarketTypes.RollingHaltReason reason,
        uint64 atEpoch
    ) internal {
        ledger.rollingPhase = MarketTypes.RollingPhase.Halted;
        ledger.rollingHaltReason = reason;
        ledger.haltedAtEpochId = atEpoch;
        emit RollingHalted(templateId, uint8(reason), atEpoch);
    }

    /// @notice Allowlist contracts that may call `depositToSideFor` (routers / intent settlers).
    /// @dev Allows UX flows where a router swaps and then deposits into a position owned by the end user.
    function setDepositExecutor(address account, bool allowed) external onlyAdmin {
        isDepositExecutor[account] = allowed;
        emit DepositExecutorSet(account, allowed);
    }

    /// @notice Deposit stake into an outcome for the active epoch (position owned by caller).
    /// @dev
    /// - Only valid for the current `ledger.activeEpochId` for the template.
    /// - Reverts for fee-on-transfer / deflationary tokens by enforcing `received == amount`.
    /// - Enforces single-side participation if the epoch disallows multi-side positions.
    function depositToSide(bytes32 templateId, uint64 epochId, uint8 outcomeIndex, uint256 amount)
        external
        nonReentrant
        notPausedUserOps
    {
        _depositToSide(msg.sender, msg.sender, templateId, epochId, outcomeIndex, amount);
    }

    /// @notice Deposit stake into an outcome for the active epoch, crediting `beneficiary`.
    /// @dev
    /// - Pulls stake token from `msg.sender` (must be allowlisted via `isDepositExecutor`).
    /// - Credits the position to `beneficiary` (end user), enabling router-based UX.
    /// - Indexes `beneficiary` in `userEpochs` on first participation in this epoch.
    function depositToSideFor(
        address beneficiary,
        bytes32 templateId,
        uint64 epochId,
        uint8 outcomeIndex,
        uint256 amount
    ) external nonReentrant notPausedUserOps {
        if (!isDepositExecutor[msg.sender]) revert NotDepositExecutor();
        if (beneficiary == address(0)) revert Unauthorized();
        _depositToSide(msg.sender, beneficiary, templateId, epochId, outcomeIndex, amount);
    }

    /// @dev Internal deposit implementation shared by `depositToSide` and `depositToSideFor`.
    /// Indexing rule: on first position initialization for `(templateId, beneficiary, epochId)`, append `epochId`
    /// to `userEpochs[templateId][beneficiary]` and emit `UserEpochIndexed` (no duplicates per epoch).
    function _depositToSide(
        address payer,
        address beneficiary,
        bytes32 templateId,
        uint64 epochId,
        uint8 outcomeIndex,
        uint256 amount
    ) internal {
        if (!configInitialized) revert Unauthorized();
        if (amount == 0) revert ZeroStake();
        MarketTypes.Template storage t = templates[templateId];
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (t.executionMode == MarketTypes.ExecutionMode.Rolling && ledger.rollingPhase == MarketTypes.RollingPhase.Halted)
        {
            revert RollingHaltedUserOps();
        }
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (!(uint256(outcomeIndex) < uint256(e.outcomeCount))) revert InvalidOutcome();

        uint64 nowTs = uint64(block.timestamp);
        if (!e.isEpochOpen(nowTs)) revert BettingClosed();

        uint256 balBefore = stakeToken.balanceOf(address(this));
        stakeToken.safeTransferFrom(payer, address(this), amount);
        uint256 received = stakeToken.balanceOf(address(this)) - balBefore;
        if (received != amount) revert NonStandardStakeToken();

        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = positions[pk][beneficiary];
        if (!pos.initialized) {
            pos.version = MarketTypes.VERSION;
            pos.initialized = true;
            for (uint256 i = 0; i < MarketTypes.MAX_OUTCOMES; i++) {
                pos.stakes[i] = 0;
            }
            pos.totalStake = 0;
            pos.switchFeesPaid = 0;
            pos.entryFeesPaid = 0;
            pos.claimedAmount = 0;
            pos.claimed = false;
            e.totalPositions += 1;
            userEpochs[templateId][beneficiary].push(epochId);
            emit UserEpochIndexed(templateId, epochId, beneficiary);
        }

        if (!_canDepositToOutcome(pos, outcomeIndex, e.outcomeCount, e.allowMultiSidePositions)) {
            revert SingleSideViolation();
        }

        pos.stakes[outcomeIndex] += amount;
        pos.totalStake += amount;
        e.outcomePools[outcomeIndex] += amount;
        e.totalPool += amount;
        ledger.increaseActiveCollateral(amount);
        vaults[templateId].active += amount;

        // Optional yield routing: move a portion of the just-deposited collateral into the yield backend.
        // Keep a fixed buffer in-engine for operational liquidity.
        IYieldRouter r = yieldRouter;
        if (address(r) != address(0)) {
            uint256 routeAmount = (amount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
            if (routeAmount > 0) {
                // USDT-safe approval pattern: `forceApprove` handles tokens that require allowance reset to 0.
                stakeToken.forceApprove(address(r), routeAmount);
                r.deposit(templateId, routeAmount);
            }
        }

        emit PositionDeposited(templateId, epochId, beneficiary, outcomeIndex, amount);
    }

    /// @notice onchain user participation index for UI pagination.
    function getUserEpochs(bytes32 templateId, address user, uint256 cursor, uint256 size)
        external
        view
        returns (uint64[] memory epochIds, uint256 nextCursor)
    {
        uint64[] storage src = userEpochs[templateId][user];
        uint256 n = src.length;
        if (cursor >= n) return (new uint64[](0), cursor);
        uint256 end = cursor + size;
        if (end > n) end = n;
        uint256 outLen = end - cursor;
        epochIds = new uint64[](outLen);
        for (uint256 i = 0; i < outLen; i++) {
            epochIds[i] = src[cursor + i];
        }
        nextCursor = end;
    }

    /// @notice Move stake from one outcome to another within the active open epoch, charging a switch fee.
    /// @dev
    /// Fee math is implemented in `MarketMath.computeSwitch`:
    /// - `feeAmount = ceil(grossAmount * switchFeeBps / 10_000)`
    /// - `netAmount = grossAmount - feeAmount`
    ///
    /// Accounting:
    /// - `feeAmount` is removed from the epoch pool totals and moved from active→fees reserve immediately.
    ///
    /// Single-side epochs (`allowMultiSidePositions=false`):
    /// - user must be fully single-sided on `fromOutcome`, and
    /// - partial switches are disallowed (must switch the entire stake from that outcome).
    function switchSide(bytes32 templateId, uint64 epochId, uint8 fromOutcome, uint8 toOutcome, uint256 grossAmount)
        external
        nonReentrant
        notPausedUserOps
    {
        if (!configInitialized) revert Unauthorized();
        if (grossAmount == 0) revert ZeroStake();
        if (fromOutcome == toOutcome) revert InvalidOutcome();
        MarketTypes.Template storage t = templates[templateId];
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (t.executionMode == MarketTypes.ExecutionMode.Rolling && ledger.rollingPhase == MarketTypes.RollingPhase.Halted)
        {
            revert RollingHaltedUserOps();
        }
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (!(uint256(fromOutcome) < uint256(e.outcomeCount) && uint256(toOutcome) < uint256(e.outcomeCount))) {
            revert InvalidOutcome();
        }

        uint64 nowTs = uint64(block.timestamp);
        if (!e.isEpochOpen(nowTs)) revert BettingClosed();

        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = positions[pk][msg.sender];
        if (pos.stakes[fromOutcome] < grossAmount) revert InsufficientSourceStake();

        (uint256 netAmount, uint256 feeAmount) = MarketMath.computeSwitch(grossAmount, e.switchFeeBps);
        if (netAmount == 0) revert AmountTooSmall();

        if (!e.allowMultiSidePositions) {
            if (!_isSingleSidedOn(pos, fromOutcome, e.outcomeCount)) revert SingleSideViolation();
            if (grossAmount != pos.stakes[fromOutcome]) revert PartialSwitchDisallowed();
        }

        pos.stakes[fromOutcome] -= grossAmount;
        pos.stakes[toOutcome] += netAmount;
        pos.totalStake -= feeAmount;
        pos.switchFeesPaid += feeAmount;

        e.outcomePools[fromOutcome] -= grossAmount;
        e.outcomePools[toOutcome] += netAmount;
        e.totalPool -= feeAmount;
        e.switchFeeTotal += feeAmount;

        if (feeAmount > 0) {
            vaults[templateId].active -= feeAmount;
            vaults[templateId].fees += feeAmount;
            MarketMath.reserveFeesFromActive(ledger, feeAmount);
        }

        // Optional yield routing: ensure reserved switch fees are liquid in-engine by withdrawing the routed portion.
        // The buffered portion (YIELD_BUFFER_BPS) is already held in-engine.
        IYieldRouter r = yieldRouter;
        if (feeAmount > 0 && address(r) != address(0)) {
            uint256 principalToWithdraw = (feeAmount * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
            if (principalToWithdraw > 0) {
                uint256 grossReturned = r.withdraw(templateId, principalToWithdraw);
                if (grossReturned > principalToWithdraw) {
                    uint256 grossYield = grossReturned - principalToWithdraw;
                    // Yield earned on protocol fees is treated as protocol revenue immediately.
                    vaults[templateId].fees += grossYield;
                    ledger.feeReserveTotal += grossYield;
                }
            }
        }

        emit SideSwitched(templateId, epochId, msg.sender, fromOutcome, toOutcome, grossAmount, feeAmount, netAmount);
    }

    /// @notice Manual mode: lock the active epoch.
    /// @dev For Direction epochs, writes oracle checkpoint A. For other market types, simply transitions to Locked.
    function lockEpoch(bytes32 templateId, uint64 epochId) external onlyWorkerOrAdmin notPausedWorkerOps {
        _lockEpoch(templateId, epochId);
    }

    /// @notice Manual mode: batch lock epochs across templates.
    function lockEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds)
        external
        onlyWorkerOrAdmin
        notPausedWorkerOps
    {
        uint256 n = templateIds.length;
        if (n != epochIds.length) revert InvalidTemplate();
        for (uint256 i = 0; i < n; i++) {
            _lockEpoch(templateIds[i], epochIds[i]);
        }
    }

    /// @dev Internal manual lock implementation. Enforces timing; for Direction reads oracle and validates confidence/freshness.
    function _lockEpoch(bytes32 templateId, uint64 epochId) internal {
        if (!configInitialized) revert Unauthorized();
        if (templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        uint64 nowTs = uint64(block.timestamp);
        if (!e.isLockable(nowTs)) revert TooEarlyToLock();

        if (MarketTypes.requiresCheckpointAOnLock(e)) {
            uint64 maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(e, oracleConfig.maxDelaySeconds);
            uint16 maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(e, oracleConfig.maxConfidenceBps);
            (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId) =
                _readOracleOrRevert(templateId, e.oracleFeedId, maxDelay, nowTs);
            _applyLock(templateId, epochId, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelay, maxConf, nowTs);
        } else {
            _applyLock(templateId, epochId, 0, 0, 0, 0, 0, 0, nowTs);
        }
    }

    /// @dev
    /// Shared lock transition.
    /// - For Direction, writes checkpoint A using the supplied oracle sample (manual: read per lock; rolling: shared read).
    /// - For other market types, checkpoint A is not written.
    ///
    /// Publish-time rule is “push-oracle compatible”: freshness vs now/maxDelaySeconds (does not require publishTime >= lockAt).
    function _applyLock(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
        uint80 oracleRoundId,
        uint64 maxDelaySeconds,
        uint16 maxConfBps,
        uint64 nowTs
    ) internal {
        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (!e.isLockable(nowTs)) revert TooEarlyToLock();

        if (MarketTypes.requiresCheckpointAOnLock(e)) {
            if (e.checkpointA.written) revert CheckpointAlreadyWritten();
            _enforceConfidence(priceE8, confidenceE8, maxConfBps);
            if (!e.validateCheckpointAPublishTime(publishTime, nowTs, maxDelaySeconds)) revert InvalidOraclePublishTime();
            e.checkpointA = MarketTypes.OracleCheckpoint({
                valueE8: priceE8, publishTime: publishTime, confidenceE8: _toConf128(confidenceE8), written: true
            });
        }

        e.status = MarketTypes.EpochStatus.Locked;
        e.lockedAt = nowTs;
        emit EpochLocked(templateId, epochId, e.checkpointA.valueE8, e.checkpointA.publishTime);
        if (MarketTypes.requiresCheckpointAOnLock(e)) {
            emit EpochLockedV2(templateId, epochId, e.checkpointA.valueE8, e.checkpointA.publishTime, oracleRoundId);
        }
    }

    /// @notice Manual mode: resolve the active locked epoch and make it claimable.
    /// @dev
    /// Writes checkpoint B (oracle sample at resolve), computes settlement outputs (winning mask or refund-mode),
    /// moves funds from active→claims/fees reserves, and marks the epoch `claimable=true`.
    function resolveEpoch(bytes32 templateId, uint64 epochId)
        external
        onlyWorkerOrAdmin
        notPausedWorkerOps
        nonReentrant
    {
        _resolveEpoch(templateId, epochId);
    }

    /// @notice Manual mode: batch resolve active epochs across templates.
    function resolveEpochsBatch(bytes32[] calldata templateIds, uint64[] calldata epochIds)
        external
        onlyWorkerOrAdmin
        notPausedWorkerOps
        nonReentrant
    {
        uint256 n = templateIds.length;
        if (n != epochIds.length) revert InvalidTemplate();
        for (uint256 i = 0; i < n; i++) {
            _resolveEpoch(templateIds[i], epochIds[i]);
        }
    }

    /// @dev Internal manual resolve implementation. Enforces oracle freshness/confidence before settlement.
    function _resolveEpoch(bytes32 templateId, uint64 epochId) internal {
        if (!configInitialized) revert Unauthorized();
        if (templates[templateId].executionMode == MarketTypes.ExecutionMode.Rolling) revert ManualModeOnly();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        uint64 nowTs = uint64(block.timestamp);
        if (!e.isResolvable(nowTs)) revert TooEarlyToResolve();
        if (e.checkpointB.written) revert CheckpointAlreadyWritten();

        uint64 maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(e, oracleConfig.maxDelaySeconds);
        uint16 maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(e, oracleConfig.maxConfidenceBps);
        (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId) =
            _readOracleOrRevert(templateId, e.oracleFeedId, maxDelay, nowTs);
        _enforceConfidence(priceE8, confidenceE8, maxConf);
        _finishResolveEpoch(templateId, epochId, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelay, false, nowTs);
    }

    /// @dev Rolling-only resolve hook invoked by rolling tick with the shared oracle sample.
    function _finishResolveEpochRolling(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
        uint80 oracleRoundId,
        uint64 maxDelaySeconds
    ) internal {
        uint64 nowTs = uint64(block.timestamp);
        _finishResolveEpoch(
            templateId, epochId, priceE8, publishTime, confidenceE8, oracleRoundId, maxDelaySeconds, true, nowTs
        );
    }

    /// @dev Finalize resolve for an epoch in either manual or rolling linkage.
    /// @param rollingLink Whether resolve is invoked via rolling linkage.
    /// - false: manual resolve of `epochId == ledger.activeEpochId`
    /// - true: rolling resolve where `epochId + 1 == ledger.activeEpochId` (epoch is the locked predecessor)
    function _finishResolveEpoch(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
        uint80 oracleRoundId,
        uint64 maxDelaySeconds,
        bool rollingLink,
        uint64 nowTs
    ) internal {
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (rollingLink) {
            if (epochId + 1 != ledger.activeEpochId) revert InvalidEpochState();
        } else {
            if (epochId != ledger.activeEpochId) revert EpochNotActive();
        }

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (!e.isResolvable(nowTs)) revert TooEarlyToResolve();
        if (e.checkpointB.written) revert CheckpointAlreadyWritten();
        if (!e.validateCheckpointBPublishTime(publishTime, nowTs, maxDelaySeconds)) revert InvalidOraclePublishTime();

        e.checkpointB = MarketTypes.OracleCheckpoint({
            valueE8: priceE8, publishTime: publishTime, confidenceE8: _toConf128(confidenceE8), written: true
        });

        // Pull routed principal (and any accrued yield) back from the yield backend before marking the epoch claimable.
        uint256 grossYield = 0;
        IYieldRouter r = yieldRouter;
        if (address(r) != address(0) && e.totalPool > 0) {
            uint256 routedPrincipal = (e.totalPool * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
            if (routedPrincipal > 0) {
                if (rollingLink) {
                    // Rolling mode prefers liveness: halt instead of reverting the keeper tx if yield backend withdraw fails.
                    try r.withdraw(templateId, routedPrincipal) returns (uint256 grossReturned) {
                        if (grossReturned > routedPrincipal) grossYield = grossReturned - routedPrincipal;
                    } catch {
                        _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleFailure, ledger.activeEpochId);
                        emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
                        return;
                    }
                } else {
                    try r.withdraw(templateId, routedPrincipal) returns (uint256 grossReturned) {
                        if (grossReturned > routedPrincipal) grossYield = grossReturned - routedPrincipal;
                    } catch {
                        emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
                        revert YieldWithdrawFailed();
                    }
                }
            }
        }

        // Account new yield as active collateral, then split protocol yield fee and include net yield in settlement.
        uint256 yieldFee = 0;
        uint256 netYield = 0;
        if (grossYield > 0) {
            vaults[templateId].active += grossYield;
            ledger.increaseActiveCollateral(grossYield);

            // In refund-mode epochs there are no winners; treat all yield as protocol fees.
            // Otherwise, apply `yieldFeeBps` and distribute net yield via settlement (winners-only).
            yieldFee = (grossYield * uint256(yieldFeeBps)) / 10_000;
            netYield = grossYield - yieldFee;
            if (yieldFee > 0) {
                vaults[templateId].active -= yieldFee;
                vaults[templateId].fees += yieldFee;
                MarketMath.reserveFeesFromActive(ledger, yieldFee);
            }
        }

        (bool refundMode, uint256 winningMask, uint256 claimLiabilityTotal, uint256 settlementFeeTotal) =
            _computeSettlementOutputsWithEffectivePool(e, netYield);
        _applyResolveAccounting(
            templateId, epochId, ledger, e, refundMode, winningMask, claimLiabilityTotal, settlementFeeTotal, nowTs
        );
        _emitResolveEvents(templateId, epochId, refundMode, winningMask, claimLiabilityTotal, settlementFeeTotal, oracleRoundId);

        if (grossYield > 0) {
            if (refundMode) {
                // Move net yield into fees in refund-mode to avoid stranded balances and preserve "winners-only" semantics.
                vaults[templateId].active -= netYield;
                vaults[templateId].fees += netYield;
                MarketMath.reserveFeesFromActive(ledger, netYield);
                netYield = 0;
            }
            emit EpochYieldAccrued(templateId, epochId, grossYield, yieldFee, netYield);
        }
    }

    /// @dev Apply vault + ledger reserve accounting at resolve by moving computed liabilities out of active collateral.
    function _applyResolveAccounting(
        bytes32 templateId,
        uint64 epochId,
        MarketTypes.Ledger storage ledger,
        MarketTypes.Epoch storage e,
        bool refundMode,
        uint256 winningMask,
        uint256 claimLiabilityTotal,
        uint256 settlementFeeTotal,
        uint64 nowTs
    ) internal {
        if (claimLiabilityTotal > 0) {
            vaults[templateId].active -= claimLiabilityTotal;
            vaults[templateId].claims += claimLiabilityTotal;
            MarketMath.reserveClaimsFromActive(ledger, claimLiabilityTotal);
        }
        if (settlementFeeTotal > 0) {
            vaults[templateId].active -= settlementFeeTotal;
            vaults[templateId].fees += settlementFeeTotal;
            MarketMath.reserveFeesFromActive(ledger, settlementFeeTotal);
        }

        e.winningOutcomeMask = winningMask;
        e.claimLiabilityTotal = refundMode ? 0 : claimLiabilityTotal;
        e.totalRefundLiability = refundMode ? claimLiabilityTotal : 0;
        e.settlementFeeTotal = settlementFeeTotal;
        e.refundMode = refundMode;
        e.claimable = true;
        e.status = refundMode ? MarketTypes.EpochStatus.Voided : MarketTypes.EpochStatus.Resolved;
        e.resolvedAt = nowTs;
        ledger.lastResolvedEpochId = epochId;
        _setRemainingWinningStake(templateId, epochId, refundMode);
        epochId; // silence unused warning in some compile profiles
    }

    /// @dev Set `epoch.remainingWinningStake`, used to detect the final winning claimant for remainder payout.
    function _setRemainingWinningStake(bytes32 templateId, uint64 epochId, bool refundMode) internal {
        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (refundMode) {
            e.remainingWinningStake = 0;
            return;
        }
        uint256 sum = 0;
        uint8 n = e.outcomeCount;
        for (uint256 i = 0; i < uint256(n); i++) {
            if (((e.winningOutcomeMask >> i) & 1) == 1) {
                sum += e.outcomePools[i];
            }
        }
        e.remainingWinningStake = sum;
    }

    /// @dev Emit resolve events, including V2 event carrying oracle round id (0 when unavailable).
    function _emitResolveEvents(
        bytes32 templateId,
        uint64 epochId,
        bool refundMode,
        uint256 winningMask,
        uint256 claimLiabilityTotal,
        uint256 settlementFeeTotal,
        uint80 oracleRoundId
    ) internal {
        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        emit EpochResolved(templateId, epochId, winningMask, claimLiabilityTotal, settlementFeeTotal, refundMode);
        emit EpochResolvedV2(templateId, epochId, oracleRoundId, e.checkpointB.valueE8, e.checkpointB.publishTime);
    }

    function _computeSettlementOutputs(MarketTypes.Epoch storage e)
        internal
        returns (bool refundMode, uint256 winningMask, uint256 claimLiabilityTotal, uint256 settlementFeeTotal)
    {
        return _computeSettlementOutputsWithEffectivePool(e, 0);
    }

    function _computeSettlementOutputsWithEffectivePool(MarketTypes.Epoch storage e, uint256 netYield)
        internal
        returns (bool refundMode, uint256 winningMask, uint256 claimLiabilityTotal, uint256 settlementFeeTotal)
    {
        // slither-disable-next-line incorrect-equality -- enum branch for resolve math
        if (e.marketType == MarketTypes.MarketType.Direction) {
            (bool voided, uint256 mask) = Resolvers.resolveDirection(e.checkpointA, e.checkpointB, e.equalPriceVoids);
            if (voided) {
                refundMode = true;
                winningMask = 0;
                claimLiabilityTotal = e.totalPool;
                settlementFeeTotal = 0;
                return (refundMode, winningMask, claimLiabilityTotal, settlementFeeTotal);
            }
            refundMode = false;
            winningMask = mask;
            e.winningOutcomeMask = mask;
        // slither-disable-next-line incorrect-equality -- enum branch for resolve math
        } else if (e.marketType == MarketTypes.MarketType.Threshold) {
            refundMode = false;
            winningMask = Resolvers.resolveThreshold(e.condition, e.absoluteThresholdValueE8, e.checkpointB);
            e.winningOutcomeMask = winningMask;
        } else {
            refundMode = false;
            winningMask = Resolvers.resolveRangeClose(e.checkpointB, e.outcomeCount, e.rangeBoundsE8);
            e.winningOutcomeMask = winningMask;
        }

        uint256 effectiveTotalPool = e.totalPool + netYield;
        uint256 winningPool = 0;
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if (((winningMask >> i) & 1) == 1) {
                winningPool += e.outcomePools[i];
            }
        }

        // slither-disable-next-line unused-return -- third value is distributable losing pool; vault split uses claim + fee only
        (claimLiabilityTotal, settlementFeeTotal,) = MarketMath.computeClaimLiabilityComponents(
            effectiveTotalPool, winningPool, e.settlementFeeBps, e.feeOnLosingPool
        );
    }

    /// @notice Cancel an Open/Locked epoch and make user funds claimable as refunds.
    /// @dev
    /// Pause semantics:
    /// - When paused, only `admin` may cancel (worker is blocked).
    ///
    /// Rolling restriction:
    /// - Disallowed while a rolling template is `Live`; use rolling recovery (`cancelRollingEpochWhileHalted`) instead.
    ///
    /// Accounting:
    /// - Moves `e.totalPool` from active→claims reserve and sets `refundMode=true` and `claimable=true`.
    /// @param reason Cancel reason (must not be None).
    /// @param voided If true, sets status `Voided` else `Cancelled` (both are refund-mode).
    function cancelEpoch(bytes32 templateId, uint64 epochId, MarketTypes.CancelReason reason, bool voided)
        external
        onlyWorkerOrAdmin
        nonReentrant
    {
        // Pause semantics: allow admin emergency actions while paused, but block worker ops.
        if (globalPaused && msg.sender != admin) revert ProtocolPaused();
        if (!configInitialized) revert Unauthorized();
        if (reason == MarketTypes.CancelReason.NoneReason) revert InvalidEpochState();
        MarketTypes.Template storage t = templates[templateId];
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (
            t.executionMode == MarketTypes.ExecutionMode.Rolling && ledger.rollingPhase == MarketTypes.RollingPhase.Live
        ) {
            revert ManualModeOnly();
        }
        if (!ledger.initialized) revert InvalidTemplate();
        _requireActiveEpoch(ledger, epochId);

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (!(e.status == MarketTypes.EpochStatus.Open || e.status == MarketTypes.EpochStatus.Locked)) {
            revert InvalidEpochState();
        }

        // Ensure routed collateral is available for refunds.
        IYieldRouter r = yieldRouter;
        if (address(r) != address(0) && e.totalPool > 0) {
            uint256 routedPrincipal = (e.totalPool * uint256(10_000 - YIELD_BUFFER_BPS)) / 10_000;
            if (routedPrincipal > 0) {
                try r.withdraw(templateId, routedPrincipal) returns (uint256 grossReturned) {
                    if (grossReturned > routedPrincipal) {
                        uint256 grossYield = grossReturned - routedPrincipal;
                        // Yield earned on cancelled epochs is treated as protocol fees.
                        vaults[templateId].fees += grossYield;
                        ledger.feeReserveTotal += grossYield;
                    }
                } catch {
                    emit YieldRouterWithdrawFailed(templateId, epochId, routedPrincipal);
                    revert YieldWithdrawFailed();
                }
            }
        }

        uint256 refundLiability = e.totalPool;
        if (refundLiability > 0) {
            vaults[templateId].active -= refundLiability;
            vaults[templateId].claims += refundLiability;
            MarketMath.reserveClaimsFromActive(ledger, refundLiability);
        }

        e.claimLiabilityTotal = 0;
        e.totalRefundLiability = refundLiability;
        e.settlementFeeTotal = 0;
        e.winningOutcomeMask = 0;
        e.remainingWinningStake = 0;
        e.cancelReason = reason;
        e.refundMode = true;
        e.claimable = true;
        e.status = voided ? MarketTypes.EpochStatus.Voided : MarketTypes.EpochStatus.Cancelled;
        e.resolvedAt = uint64(block.timestamp);
        ledger.lastResolvedEpochId = epochId;

        emit EpochCancelled(templateId, epochId, uint8(reason));
    }

    /// @notice Claim payout/refund for a single epoch.
    /// @dev Transfers stakeToken once for this epoch.
    function claim(bytes32 templateId, uint64 epochId) external nonReentrant {
        uint256 amount = _claimOne(templateId, epochId, msg.sender);
        stakeToken.safeTransfer(msg.sender, amount);
        emit Claimed(templateId, epochId, msg.sender, amount);
    }

    /// @notice Claim multiple epochs in a single token transfer (gas-optimized UX).
    /// @dev Emits `Claimed` per epoch and transfers only once for the sum.
    function claimMany(bytes32 templateId, uint64[] calldata epochIds) external nonReentrant {
        uint256 total = 0;
        for (uint256 i = 0; i < epochIds.length; i++) {
            uint256 amt = _claimOne(templateId, epochIds[i], msg.sender);
            total += amt;
            emit Claimed(templateId, epochIds[i], msg.sender, amt);
        }
        if (total == 0) revert NothingToClaim();
        stakeToken.safeTransfer(msg.sender, total);
    }

    /// @dev Compute and record a single-epoch claim amount (does not transfer tokens).
    /// Implements the per-epoch “last-claimer remainder” rule by passing:
    /// `remainingClaimsForEpoch = e.claimLiabilityTotal - e.claimedTotal` into `MarketMath.computeClaimPayoutStorage`.
    function _claimOne(bytes32 templateId, uint64 epochId, address user) internal returns (uint256 amount) {
        if (!configInitialized) revert Unauthorized();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (!e.claimable) revert ClaimNotAvailable();

        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = positions[pk][user];
        if (pos.claimed) revert AlreadyClaimed();

        uint256 winningStake;
        if (e.refundMode) {
            amount = MarketMath.computeRefundTotal(pos.totalStake);
            winningStake = 0;
        } else {
            // Must match `MarketTypes.MAX_OUTCOMES` (8).
            uint256[8] memory stakes = pos.stakes;
            uint256 remainingClaims = e.claimLiabilityTotal - e.claimedTotal;
            (amount, winningStake) = MarketMath.computeClaimPayoutStorage(e, stakes, remainingClaims);
        }

        if (amount == 0) revert NothingToClaim();
        pos.claimedAmount = amount;
        pos.claimed = true;
        e.claimedTotal += amount;
        if (!e.refundMode) {
            e.remainingWinningStake -= winningStake;
        }
        MarketMath.releaseClaimOnWithdraw(ledger, amount);
        vaults[templateId].claims -= amount;
    }

    /// @notice Withdraw accumulated protocol fees for a template to `treasury`.
    /// @dev Decrements ledger fee reserve and per-template fees vault.
    function withdrawFees(bytes32 templateId, uint256 amount) external onlyTreasuryOrAdmin nonReentrant {
        if (!configInitialized) revert Unauthorized();
        if (amount == 0) revert NothingToClaim();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();
        if (ledger.feeReserveTotal < amount) revert NothingToClaim();

        stakeToken.safeTransfer(treasury, amount);
        MarketMath.releaseFeeOnWithdraw(ledger, amount);
        vaults[templateId].fees -= amount;

        emit FeesWithdrawn(templateId, amount);
    }

    /// @notice Derive template id from a human-readable slug.
    function templateIdFromSlug(string memory slug) public pure returns (bytes32) {
        return keccak256(bytes(slug));
    }

    /// @notice Derive position key for `(templateId,epochId)` used to index `positions`.
    function positionKey(bytes32 templateId, uint64 epochId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(templateId, epochId));
    }

    /// @notice Read per-template vault balances (active/claims/fees).
    /// @dev These are internal accounting totals; the ERC20 balance is shared across templates.
    function getVaultBalances(bytes32 templateId) external view returns (uint256 active, uint256 claims, uint256 fees) {
        MarketTypes.VaultBalances storage v = vaults[templateId];
        return (v.active, v.claims, v.fees);
    }

    /// @notice Rolling cursor + phase for keepers and UIs (avoids unpacking the full public `ledgers` tuple).
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
        )
    {
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        return (
            ledger.rollingPhase,
            ledger.rollingHaltReason,
            ledger.haltedAtEpochId,
            ledger.rollingNextEpochId,
            ledger.activeEpochId,
            ledger.lastResolvedEpochId
        );
    }

    /// @notice Fetch a full epoch snapshot for offchain consumers and tests.
    /// @dev Public mapping getters return tuples; this helper returns the struct directly.
    function getEpoch(bytes32 templateId, uint64 epochId) external view returns (MarketTypes.Epoch memory) {
        return epochs[templateId][epochId];
    }

    /// @dev Downcast oracle confidence to uint128 for packed checkpoint storage.
    function _toConf128(uint256 confidenceE8) internal pure returns (uint128) {
        if (confidenceE8 > type(uint128).max) revert ConfidenceOverflow();
        // forge-lint: disable-next-line(unsafe-typecast) -- guarded by revert above
        return uint128(confidenceE8);
    }

    /// @dev Check `confidenceE8 <= |priceE8| * maxConfidenceBps / 10_000`.
    /// Uses wrapping abs via assembly to avoid `type(int256).min` negation overflow.
    function _confidenceWithinBand(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps)
        internal
        pure
        returns (bool)
    {
        uint256 abs;
        assembly {
            // abs = priceE8 >= 0 ? uint(priceE8) : uint(-priceE8)
            // Using EVM wrapping arithmetic avoids `int256` negation overflow panics on `type(int256).min`.
            abs := priceE8
            if slt(priceE8, 0) { abs := sub(0, priceE8) }
        }
        // `type(int256).min` would map to abs = 2**255, which cannot be represented as positive int256.
        if (abs == (1 << 255)) revert InvalidOraclePrice();
        uint256 limit = (abs * uint256(maxConfidenceBps)) / 10_000;
        return confidenceE8 <= limit;
    }

    /// @dev Enforce confidence within band, else revert.
    function _enforceConfidence(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps) internal pure {
        if (!_confidenceWithinBand(priceE8, confidenceE8, maxConfidenceBps)) revert OracleConfidenceTooWide();
    }

    /// @dev Manual sequential-open guard: cannot open next epoch until previous is resolved/cancelled/voided.
    function _requireCanOpenNextEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (ledger.activeEpochId != ledger.lastResolvedEpochId) revert PreviousEpochUnresolved();
        if (epochId != ledger.activeEpochId + 1) revert EpochAlreadyExists();
    }

    /// @dev Active epoch guard used for user ops and manual keeper ops.
    function _requireActiveEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (epochId != ledger.activeEpochId) revert EpochNotActive();
    }

    /// @dev Enforce oracle sample monotonicity and update per-(template,feed) cursor.
    /// See file header for rationale and examples.
    function _enforceAndUpdateOracleCursor(bytes32 templateId, bytes32 feedId, uint80 oracleRoundId, uint64 publishTime)
        internal
    {
        OracleCursor storage c = lastOracleCursorByTemplateFeed[templateId][feedId];

        // Allow same roundId across lock/resolve, but never allow time-travel.
        if (oracleRoundId < c.roundId) {
            revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
        }
        if (oracleRoundId == c.roundId && publishTime < c.publishTime) {
            revert OracleSampleNotMonotonic(oracleRoundId, c.roundId, publishTime, c.publishTime);
        }

        c.roundId = oracleRoundId;
        c.publishTime = publishTime;

        // Backwards-compat: keep old per-template roundId cursor moving forward (best-effort).
        if (oracleRoundId > lastOracleRoundIdByTemplate[templateId]) {
            lastOracleRoundIdByTemplate[templateId] = oracleRoundId;
        }
    }

    /// @dev Read oracle sample, reverting on adapter failure.
    /// Tries optional `IPriceOracleWithRoundId` first; falls back to `IPriceOracle` when not supported.
    function _readOracleOrRevert(bytes32 templateId, bytes32 feedId, uint64 maxDelay, uint64 nowTs)
        internal
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId)
    {
        try IPriceOracleWithRoundId(address(priceOracle)).getNormalizedPriceWithRoundId(feedId, maxDelay, nowTs) returns (
            uint80 rid, int256 p, uint64 pt, uint256 c
        ) {
            _enforceAndUpdateOracleCursor(templateId, feedId, rid, pt);
            return (p, pt, c, rid);
        } catch {
            (priceE8, publishTime, confidenceE8) = priceOracle.getNormalizedPrice(feedId, maxDelay, nowTs);
            _enforceAndUpdateOracleCursor(templateId, feedId, 0, publishTime);
            return (priceE8, publishTime, confidenceE8, 0);
        }
    }

    /// @dev Best-effort oracle read used by rolling keepers.
    /// Returns `(ok=false, ...)` instead of reverting so rolling can halt safely on oracle failures.
    function _tryReadOracle(bytes32 templateId, bytes32 feedId, uint64 maxDelay, uint64 nowTs)
        internal
        returns (bool ok, int256 priceE8, uint64 publishTime, uint256 confidenceE8, uint80 oracleRoundId)
    {
        try IPriceOracleWithRoundId(address(priceOracle)).getNormalizedPriceWithRoundId(feedId, maxDelay, nowTs) returns (
            uint80 rid, int256 p, uint64 pt, uint256 c
        ) {
            _enforceAndUpdateOracleCursor(templateId, feedId, rid, pt);
            return (true, p, pt, c, rid);
        } catch {
            try priceOracle.getNormalizedPrice(feedId, maxDelay, nowTs) returns (int256 p2, uint64 pt2, uint256 c2) {
                _enforceAndUpdateOracleCursor(templateId, feedId, 0, pt2);
                return (true, p2, pt2, c2, 0);
            } catch {
                return (false, 0, 0, 0, 0);
            }
        }
    }

    /// @dev Template validation invoked by `upsertTemplate`.
    function _validateTemplate(MarketTypes.Template storage t) internal view {
        if (t.outcomeCount > maxOutcomes) revert TooManyOutcomes();
        if (t.switchFeeBps > 10_000 || t.settlementFeeBps > 10_000) revert InvalidFeeBps();

        if (t.marketType == MarketTypes.MarketType.Direction) {
            if (t.outcomeCount != 2) revert InvalidTemplate();
            if (t.thresholdRule != MarketTypes.ThresholdRule.None) revert InvalidTemplate();
            if (!t.equalPriceVoids) revert InvalidTemplate();
        } else if (t.marketType == MarketTypes.MarketType.Threshold) {
            if (t.outcomeCount != 2) revert InvalidTemplate();
            if (t.thresholdRule != MarketTypes.ThresholdRule.Absolute) revert InvalidTemplate();
        } else {
            if (t.outcomeCount < 2) revert InvalidTemplate();
            for (uint256 i = 1; i < uint256(t.outcomeCount) - 1; i++) {
                if (!(t.rangeBoundsE8[i - 1] < t.rangeBoundsE8[i])) revert InvalidTemplate();
            }
        }
        if (t.oracleMaxConfidenceBps > 0 && t.oracleMaxConfidenceBps > 10_000) revert InvalidFeeBps();
    }

    function _canDepositToOutcome(
        MarketTypes.Position storage pos,
        uint8 outcomeIndex,
        uint8 outcomeCount,
        bool allowMultiSide
    ) internal view returns (bool) {
        if (allowMultiSide) return true;
        if (pos.totalStake == 0) return true;
        for (uint256 i = 0; i < outcomeCount; i++) {
            if (i != outcomeIndex && pos.stakes[i] != 0) return false;
        }
        return true;
    }

    function _isSingleSidedOn(MarketTypes.Position storage pos, uint8 outcomeIndex, uint8 outcomeCount)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < outcomeCount; i++) {
            if (i != outcomeIndex && pos.stakes[i] != 0) return false;
        }
        return true;
    }
}
