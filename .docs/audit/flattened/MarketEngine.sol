// SPDX-License-Identifier: MIT
pragma solidity >=0.4.11 >=0.4.16 >=0.6.2 ^0.8.20 ^0.8.21 ^0.8.22 ^0.8.24;

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/Errors.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol

// OpenZeppelin Contracts (last updated v5.4.0) (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/IERC1967.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1967.sol)

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 */
interface IERC1967 {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// src/interfaces/IPriceOracle.sol

/// @notice Chain-agnostic normalized oracle surface for the market engine.
/// @dev `feedId` encodes the Chainlink feed proxy address as `bytes32(uint256(uint160(proxy)))`.
///      `nowTs` is ignored by on-chain adapters (staleness uses `block.timestamp` / feed timestamps).
///      Mocks may use `nowTs` in tests.
interface IPriceOracle {
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external
        view
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reinitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Pointer to storage slot. Allows integrators to override it with a custom storage location.
     *
     * NOTE: Consider following the ERC-7201 formula to derive storage locations.
     */
    function _initializableStorageSlot() internal pure virtual returns (bytes32) {
        return INITIALIZABLE_STORAGE;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/LowLevelCall.sol

// OpenZeppelin Contracts (last updated v5.6.0) (utils/LowLevelCall.sol)

/**
 * @dev Library of low level call functions that implement different calling strategies to deal with the return data.
 *
 * WARNING: Using this library requires an advanced understanding of Solidity and how the EVM works. It is recommended
 * to use the {Address} library instead.
 */
library LowLevelCall {
    /// @dev Performs a Solidity function call using a low level `call` and ignoring the return data.
    function callNoReturn(address target, bytes memory data) internal returns (bool success) {
        return callNoReturn(target, 0, data);
    }

    /// @dev Same as {callNoReturn-address-bytes}, but allows specifying the value to be sent in the call.
    function callNoReturn(address target, uint256 value, bytes memory data) internal returns (bool success) {
        assembly ("memory-safe") {
            success := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `call` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple with two single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.
    function callReturn64Bytes(
        address target,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        return callReturn64Bytes(target, 0, data);
    }

    /// @dev Same as {callReturn64Bytes-address-bytes}, but allows specifying the value to be sent in the call.
    function callReturn64Bytes(
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            success := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0x40)
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Performs a Solidity function call using a low level `staticcall` and ignoring the return data.
    function staticcallNoReturn(address target, bytes memory data) internal view returns (bool success) {
        assembly ("memory-safe") {
            success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `staticcall` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple with two single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.
    function staticcallReturn64Bytes(
        address target,
        bytes memory data
    ) internal view returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Performs a Solidity function call using a low level `delegatecall` and ignoring the return data.
    function delegatecallNoReturn(address target, bytes memory data) internal returns (bool success) {
        assembly ("memory-safe") {
            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `delegatecall` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple with two single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.
    function delegatecallReturn64Bytes(
        address target,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Returns the size of the return data buffer.
    function returnDataSize() internal pure returns (uint256 size) {
        assembly ("memory-safe") {
            size := returndatasize()
        }
    }

    /// @dev Returns a buffer containing the return data from the last call.
    function returnData() internal pure returns (bytes memory result) {
        assembly ("memory-safe") {
            result := mload(0x40)
            mstore(result, returndatasize())
            returndatacopy(add(result, 0x20), 0x00, returndatasize())
            mstore(0x40, add(result, add(0x20, returndatasize())))
        }
    }

    /// @dev Revert with the return data from the last call.
    function bubbleRevert() internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            returndatacopy(fmp, 0x00, returndatasize())
            revert(fmp, returndatasize())
        }
    }

    function bubbleRevert(bytes memory returndata) internal pure {
        assembly ("memory-safe") {
            revert(add(returndata, 0x20), mload(returndata))
        }
    }
}

// src/types/MarketTypes.sol

/// @dev Mirrors `retropick_market_engine_v5` Anchor state + packed storage for L2 gas.
library MarketTypes {
    uint8 internal constant VERSION = 1;
    uint8 internal constant MAX_OUTCOMES = 8;
    uint8 internal constant RANGE_BOUNDS_LEN = MAX_OUTCOMES - 1;
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant SLUG_MAX_LEN = 32;
    uint256 internal constant ASSET_SYMBOL_MAX_LEN = 16;

    enum MarketType {
        Direction,
        Threshold,
        RangeClose
    }

    enum Condition {
        AtOrAbove,
        Below
    }

    enum ThresholdRule {
        None,
        Absolute
    }

    enum EpochStatus {
        Scheduled,
        Open,
        Locked,
        Resolved,
        Cancelled,
        Voided
    }

    enum OracleKind {
        Chainlink
    }

    enum CancelReason {
        NoneReason,
        OracleUnavailable,
        OracleStale,
        InvalidTemplate,
        InvalidTiming,
        EmergencyPaused,
        ManualAdminCancel
    }

    /// @dev Manual = discrete open/lock/resolve txs (Anchor v5 parity). Rolling = Pancake-style pipeline.
    enum ExecutionMode {
        Manual,
        Rolling
    }

    /// @dev Rolling lifecycle per ledger; see rolling-rounds.md.
    enum RollingPhase {
        Uninitialized,
        GenesisOpen,
        Live,
        Halted
    }

    /// @dev Why a rolling template entered `RollingPhase.Halted` (stored on ledger).
    enum RollingHaltReason {
        NoneReason,
        BufferMissOnLock,
        BufferMissOnResolve,
        OracleFailure,
        OracleConfidenceWide,
        ManualAdmin
    }

    struct OracleConfig {
        OracleKind oracleKind;
        uint64 maxDelaySeconds;
        uint16 maxConfidenceBps;
    }

    /// @dev Packed: one slot for price + one slot for conf/publishTime/written (vs ~4 slots naive).
    struct OracleCheckpoint {
        int256 valueE8;
        uint128 confidenceE8;
        uint64 publishTime;
        bool written;
    }

    struct MarketTiming {
        uint64 openAt;
        uint64 lockAt;
        uint64 resolveAt;
    }

    /// @dev Small fields first for single warm slots; strings last (dynamic).
    struct Template {
        uint8 version;
        MarketType marketType;
        Condition condition;
        ThresholdRule thresholdRule;
        bool active;
        uint8 outcomeCount;
        uint16 switchFeeBps;
        uint16 settlementFeeBps;
        bool equalPriceVoids;
        bool feeOnLosingPool;
        bool allowMultiSidePositions;
        ExecutionMode executionMode;
        uint64 rollingIntervalSeconds;
        uint64 rollingBufferSeconds;
        string slug;
        string assetSymbol;
        bytes32 oracleFeedId;
        int256 absoluteThresholdValueE8;
        int256[RANGE_BOUNDS_LEN] rangeBoundsE8;
        /// @dev 0 = inherit global `Config.oracle_config.max_delay_seconds` (snapshot copied to each epoch at open).
        uint64 oracleMaxDelaySeconds;
        /// @dev 0 = inherit global `max_confidence_bps`.
        uint16 oracleMaxConfidenceBps;
    }

    struct Ledger {
        bool initialized;
        uint8 version;
        uint64 activeEpochId;
        uint64 lastResolvedEpochId;
        uint64 rollingNextEpochId;
        uint64 haltedAtEpochId;
        uint256 activeCollateralTotal;
        uint256 claimsReserveTotal;
        uint256 feeReserveTotal;
        uint256 insuranceReserveTotal;
        RollingPhase rollingPhase;
        RollingHaltReason rollingHaltReason;
    }

    struct VaultBalances {
        uint256 active;
        uint256 claims;
        uint256 fees;
    }

    /// @dev Hot small fields packed at the front; `timing`+`createdAt` share one slot when possible.
    struct Epoch {
        uint8 version;
        EpochStatus status;
        CancelReason cancelReason;
        uint8 outcomeCount;
        MarketType marketType;
        Condition condition;
        uint16 switchFeeBps;
        uint16 settlementFeeBps;
        bool equalPriceVoids;
        bool feeOnLosingPool;
        bool allowMultiSidePositions;
        bool refundMode;
        bool claimable;
        bool exists;
        uint64 epochId;
        uint32 totalPositions;
        MarketTiming timing;
        uint64 createdAt;
        uint64 lockedAt;
        uint64 resolvedAt;
        /// @dev Snapshot from template at open; 0 = use global at effective* time.
        uint64 oracleMaxDelaySeconds;
        /// @dev Snapshot from template at open; 0 = use global.
        uint16 oracleMaxConfidenceBps;
        OracleCheckpoint checkpointA;
        OracleCheckpoint checkpointB;
        bytes32 oracleFeedId;
        int256 absoluteThresholdValueE8;
        int256[RANGE_BOUNDS_LEN] rangeBoundsE8;
        uint256 winningOutcomeMask;
        uint256 totalPool;
        uint256[MAX_OUTCOMES] outcomePools;
        uint256 switchFeeTotal;
        uint256 settlementFeeTotal;
        uint256 claimLiabilityTotal;
        uint256 totalRefundLiability;
        uint256 claimedTotal;
        uint256 remainingWinningStake;
    }

    struct Position {
        uint8 version;
        uint256[MAX_OUTCOMES] stakes;
        uint256 totalStake;
        uint256 switchFeesPaid;
        uint256 entryFeesPaid;
        uint256 claimedAmount;
        bool claimed;
        bool initialized;
    }

    function isEpochOpen(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Open && nowTs >= e.timing.openAt && nowTs < e.timing.lockAt;
    }

    function isLockable(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Open && nowTs >= e.timing.lockAt;
    }

    function isResolvable(Epoch storage e, uint64 nowTs) internal view returns (bool) {
        return e.status == EpochStatus.Locked && nowTs >= e.timing.resolveAt;
    }

    function requiresCheckpointAOnLock(Epoch storage e) internal view returns (bool) {
        return e.marketType == MarketType.Direction;
    }

    /// @dev Push-oracle compatible freshness check.
    ///      - rejects future timestamps (publishTime > nowTs)
    ///      - enforces staleness window (nowTs - publishTime <= maxDelaySeconds)
    function validatePublishTimeFresh(uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
        internal
        pure
        returns (bool)
    {
        if (publishTime == 0) return false;
        if (publishTime > nowTs) return false;
        unchecked {
            return (nowTs - publishTime) <= maxDelaySeconds;
        }
    }

    /// @dev Checkpoint A time rule for push-oracles: freshness only.
    ///      (Do NOT require publishTime >= lockAt; Chainlink `updatedAt` may be before lockAt.)
    function validateCheckpointAPublishTime(Epoch storage, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
        internal
        pure
        returns (bool)
    {
        return validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds);
    }

    /// @dev Checkpoint B time rule for push-oracles:
    ///      - freshness vs now/maxDelaySeconds
    ///      - monotonic vs checkpoint A publishTime if A exists
    function validateCheckpointBPublishTime(Epoch storage e, uint64 publishTime, uint64 nowTs, uint64 maxDelaySeconds)
        internal
        view
        returns (bool)
    {
        if (!validatePublishTimeFresh(publishTime, nowTs, maxDelaySeconds)) return false;
        if (e.checkpointA.written && publishTime < e.checkpointA.publishTime) return false;
        return true;
    }

    function winningPoolTotal(Epoch memory e) internal pure returns (uint256 sum) {
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if ((e.winningOutcomeMask >> i) & 1 == 1) {
                sum += e.outcomePools[i];
            }
        }
    }

    function winningPoolTotalStorage(Epoch storage e) internal view returns (uint256 sum) {
        for (uint256 i = 0; i < e.outcomeCount; i++) {
            if ((e.winningOutcomeMask >> i) & 1 == 1) {
                sum += e.outcomePools[i];
            }
        }
    }

    /// @notice Effective staleness window: epoch snapshot if non-zero, else global (Anchor `effective_oracle_max_delay_seconds`).
    function effectiveOracleMaxDelaySeconds(Epoch storage e, uint64 globalDelaySeconds) internal view returns (uint64) {
        if (e.oracleMaxDelaySeconds > 0) return e.oracleMaxDelaySeconds;
        return globalDelaySeconds;
    }

    /// @notice Effective confidence cap: epoch snapshot if non-zero, else global.
    function effectiveOracleMaxConfidenceBps(Epoch storage e, uint16 globalMaxConfidenceBps)
        internal
        view
        returns (uint16)
    {
        if (e.oracleMaxConfidenceBps > 0) return e.oracleMaxConfidenceBps;
        return globalMaxConfidenceBps;
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/TransientSlot.sol

// OpenZeppelin Contracts (last updated v5.3.0) (utils/TransientSlot.sol)
// This file was procedurally generated from scripts/generate/templates/TransientSlot.js.

/**
 * @dev Library for reading and writing value-types to specific transient storage slots.
 *
 * Transient slots are often used to store temporary values that are removed after the current transaction.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 *  * Example reading and writing values using transient storage:
 * ```solidity
 * contract Lock {
 *     using TransientSlot for *;
 *
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _LOCK_SLOT = 0xf4678858b2b588224636b8522b729e7722d32fc491da849ed75b3fdf3c84f542;
 *
 *     modifier locked() {
 *         require(!_LOCK_SLOT.asBoolean().tload());
 *
 *         _LOCK_SLOT.asBoolean().tstore(true);
 *         _;
 *         _LOCK_SLOT.asBoolean().tstore(false);
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library TransientSlot {
    /**
     * @dev UDVT that represents a slot holding an address.
     */
    type AddressSlot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a AddressSlot.
     */
    function asAddress(bytes32 slot) internal pure returns (AddressSlot) {
        return AddressSlot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a bool.
     */
    type BooleanSlot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a BooleanSlot.
     */
    function asBoolean(bytes32 slot) internal pure returns (BooleanSlot) {
        return BooleanSlot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a bytes32.
     */
    type Bytes32Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Bytes32Slot.
     */
    function asBytes32(bytes32 slot) internal pure returns (Bytes32Slot) {
        return Bytes32Slot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a uint256.
     */
    type Uint256Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Uint256Slot.
     */
    function asUint256(bytes32 slot) internal pure returns (Uint256Slot) {
        return Uint256Slot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a int256.
     */
    type Int256Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Int256Slot.
     */
    function asInt256(bytes32 slot) internal pure returns (Int256Slot) {
        return Int256Slot.wrap(slot);
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(AddressSlot slot) internal view returns (address value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(AddressSlot slot, address value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(BooleanSlot slot) internal view returns (bool value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(BooleanSlot slot, bool value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Bytes32Slot slot) internal view returns (bytes32 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Bytes32Slot slot, bytes32 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Uint256Slot slot) internal view returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Uint256Slot slot, uint256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Int256Slot slot) internal view returns (int256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Int256Slot slot, int256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/draft-IERC1822.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC-1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

// src/math/MarketMath.sol

library MarketMath {
    using MarketTypes for MarketTypes.Epoch;

    error MathOverflow();
    error NoWinningOutcome();

    uint256 internal constant BPS_DENOMINATOR = MarketTypes.BPS_DENOMINATOR;

    function computeSwitch(uint256 grossAmount, uint16 switchFeeBps) internal pure returns (uint256 net, uint256 fee) {
        if (switchFeeBps == 0) return (grossAmount, 0);
        fee = (grossAmount * uint256(switchFeeBps) + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
        if (fee > grossAmount) revert MathOverflow();
        net = grossAmount - fee;
    }

    function computeSettlementFee(uint256 totalPool, uint256 losingPool, uint16 feeBps, bool feeOnLosingPool)
        internal
        pure
        returns (uint256)
    {
        uint256 base = feeOnLosingPool ? losingPool : totalPool;
        return (base * uint256(feeBps)) / BPS_DENOMINATOR;
    }

    function winningPoolTotal(uint256 winningMask, uint8 outcomeCount, uint256[8] memory outcomePools)
        internal
        pure
        returns (uint256 sum)
    {
        for (uint256 i = 0; i < outcomeCount; i++) {
            if ((winningMask >> i) & 1 == 1) {
                sum += outcomePools[i];
            }
        }
    }

    function computeClaimLiabilityComponents(
        uint256 totalPool,
        uint256 winningPool,
        uint16 feeBps,
        bool feeOnLosingPool
    ) internal pure returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool) {
        if (winningPool == 0) revert NoWinningOutcome();
        if (totalPool < winningPool) revert MathOverflow();
        uint256 losingPool = totalPool - winningPool;
        settlementFee = computeSettlementFee(totalPool, losingPool, feeBps, feeOnLosingPool);
        if (losingPool < settlementFee) revert MathOverflow();
        distributableLosingPool = losingPool - settlementFee;
        claimLiabilityTotal = winningPool + distributableLosingPool;
    }

    function computeEpochClaimLiability(MarketTypes.Epoch memory epoch, uint16 feeBps, bool feeOnLosingPool)
        internal
        pure
        returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool)
    {
        uint256 wp = epoch.winningPoolTotal();
        return computeClaimLiabilityComponents(epoch.totalPool, wp, feeBps, feeOnLosingPool);
    }

    function computeEpochClaimLiabilityStorage(MarketTypes.Epoch storage epoch, uint16 feeBps, bool feeOnLosingPool)
        internal
        view
        returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool)
    {
        uint256 wp = 0;
        for (uint256 i = 0; i < epoch.outcomeCount; i++) {
            if ((epoch.winningOutcomeMask >> i) & 1 == 1) {
                wp += epoch.outcomePools[i];
            }
        }
        return computeClaimLiabilityComponents(epoch.totalPool, wp, feeBps, feeOnLosingPool);
    }

    function totalWinningStake(uint256 winningMask, uint8 outcomeCount, uint256[8] memory stakes)
        internal
        pure
        returns (uint256 s)
    {
        for (uint256 i = 0; i < outcomeCount; i++) {
            if ((winningMask >> i) & 1 == 1) {
                s += stakes[i];
            }
        }
    }

    function computeTotalUserEntitlementResolved(
        MarketTypes.Epoch memory epoch,
        uint256[8] memory stakes,
        uint16 settlementFeeBps,
        bool feeOnLosingPool
    ) internal pure returns (uint256) {
        uint256 userWinning = totalWinningStake(epoch.winningOutcomeMask, epoch.outcomeCount, stakes);
        if (userWinning == 0) return 0;
        uint256 winningPool = epoch.winningPoolTotal();
        (,, uint256 distributableLosing) =
            computeClaimLiabilityComponents(epoch.totalPool, winningPool, settlementFeeBps, feeOnLosingPool);
        uint256 proRata = (userWinning * distributableLosing) / winningPool;
        return userWinning + proRata;
    }

    function computeClaimPayout(MarketTypes.Epoch memory epoch, uint256[8] memory stakes, uint256 claimsReserveTotal)
        internal
        pure
        returns (uint256 payout, uint256 userWinningStake_)
    {
        userWinningStake_ = totalWinningStake(epoch.winningOutcomeMask, epoch.outcomeCount, stakes);
        if (userWinningStake_ == 0) return (0, 0);

        uint256 entitlement =
            computeTotalUserEntitlementResolved(epoch, stakes, epoch.settlementFeeBps, epoch.feeOnLosingPool);

        if (epoch.remainingWinningStake == userWinningStake_) {
            payout = claimsReserveTotal;
        } else {
            payout = entitlement;
        }
        return (payout, userWinningStake_);
    }

    /// @dev Avoids copying full `Epoch` to memory on each claim (L2 hot path).
    function computeClaimPayoutStorage(
        MarketTypes.Epoch storage epoch,
        uint256[8] memory stakes,
        uint256 claimsReserveTotal
    ) internal view returns (uint256 payout, uint256 userWinningStake_) {
        userWinningStake_ = totalWinningStake(epoch.winningOutcomeMask, epoch.outcomeCount, stakes);
        if (userWinningStake_ == 0) return (0, 0);

        uint256 winningPool = 0;
        for (uint256 i = 0; i < epoch.outcomeCount; i++) {
            if ((epoch.winningOutcomeMask >> i) & 1 == 1) {
                winningPool += epoch.outcomePools[i];
            }
        }
        (,, uint256 distributableLosing) =
            computeClaimLiabilityComponents(epoch.totalPool, winningPool, epoch.settlementFeeBps, epoch.feeOnLosingPool);
        uint256 entitlement = userWinningStake_ + (userWinningStake_ * distributableLosing) / winningPool;

        if (epoch.remainingWinningStake == userWinningStake_) {
            payout = claimsReserveTotal;
        } else {
            payout = entitlement;
        }
        return (payout, userWinningStake_);
    }

    function computeRefundTotal(uint256 totalStake) internal pure returns (uint256) {
        return totalStake;
    }

    function reserveClaimsFromActive(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
        ledger.claimsReserveTotal += amount;
    }

    function reserveFeesFromActive(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
        ledger.feeReserveTotal += amount;
    }

    function releaseClaimOnWithdraw(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.claimsReserveTotal = _sub(ledger.claimsReserveTotal, amount);
    }

    function releaseFeeOnWithdraw(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.feeReserveTotal = _sub(ledger.feeReserveTotal, amount);
    }

    function increaseActiveCollateral(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal += amount;
    }

    function decreaseActiveCollateral(MarketTypes.Ledger storage ledger, uint256 amount) internal {
        ledger.activeCollateralTotal = _sub(ledger.activeCollateralTotal, amount);
    }

    function _sub(uint256 a, uint256 b) private pure returns (uint256) {
        if (a < b) revert MathOverflow();
        return a - b;
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/ReentrancyGuardTransient.sol

// OpenZeppelin Contracts (last updated v5.5.0) (utils/ReentrancyGuardTransient.sol)

/**
 * @dev Variant of {ReentrancyGuard} that uses transient storage.
 *
 * NOTE: This variant only works on networks where EIP-1153 is available.
 *
 * _Available since v5.1._
 *
 * @custom:stateless
 */
abstract contract ReentrancyGuardTransient {
    using TransientSlot for *;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /**
     * @dev A `view` only version of {nonReentrant}. Use to block view functions
     * from being called, preventing reading from inconsistent contract state.
     *
     * CAUTION: This is a "view" modifier and does not change the reentrancy
     * status. Use it only on view functions. For payable or non-payable functions,
     * use the standard {nonReentrant} modifier instead.
     */
    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, REENTRANCY_GUARD_STORAGE.asBoolean().tload() will be false
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        _reentrancyGuardStorageSlot().asBoolean().tstore(true);
    }

    function _nonReentrantAfter() private {
        _reentrancyGuardStorageSlot().asBoolean().tstore(false);
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().asBoolean().tload();
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}

// src/logic/Resolvers.sol

library Resolvers {
    error InvalidEpochState();
    error InvalidTemplate();

    /// @return voided When true, treat as refund mode (no winning side).
    /// @return mask Bitmask of winning outcomes (Rust `1u64 << idx`); undefined if voided.
    function resolveDirection(
        MarketTypes.OracleCheckpoint memory a,
        MarketTypes.OracleCheckpoint memory b,
        bool voidOnEqual
    ) internal pure returns (bool voided, uint256 mask) {
        if (!a.written || !b.written) revert InvalidEpochState();
        if (b.valueE8 > a.valueE8) return (false, uint256(1) << 0);
        if (b.valueE8 < a.valueE8) return (false, uint256(1) << 1);
        if (voidOnEqual) return (true, 0);
        return (false, uint256(1) << 1);
    }

    function resolveThreshold(
        MarketTypes.Condition condition,
        int256 thresholdValueE8,
        MarketTypes.OracleCheckpoint memory b
    ) internal pure returns (uint256 mask) {
        if (!b.written) revert InvalidEpochState();
        bool yes =
            condition == MarketTypes.Condition.AtOrAbove ? b.valueE8 >= thresholdValueE8 : b.valueE8 < thresholdValueE8;
        return yes ? (uint256(1) << 0) : (uint256(1) << 1);
    }

    function resolveRangeClose(
        MarketTypes.OracleCheckpoint memory b,
        uint8 outcomeCount,
        int256[7] memory rangeBoundsE8
    ) internal pure returns (uint256 mask) {
        if (!b.written) revert InvalidEpochState();
        if (outcomeCount < 2) revert InvalidTemplate();
        int256 value = b.valueE8;
        uint256 idx;
        if (value < rangeBoundsE8[0]) {
            idx = 0;
        } else {
            idx = uint256(outcomeCount) - 1;
            for (uint256 i = 1; i < uint256(outcomeCount) - 1; i++) {
                if (value < rangeBoundsE8[i]) {
                    idx = i;
                    break;
                }
            }
        }
        return uint256(1) << idx;
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.5.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }
        if (LowLevelCall.callNoReturn(recipient, amount, "")) {
            // call successful, nothing to do
            return;
        } else if (LowLevelCall.returnDataSize() > 0) {
            LowLevelCall.bubbleRevert();
        } else {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        bool success = LowLevelCall.callNoReturn(target, value, data);
        if (success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)) {
            return LowLevelCall.returnData();
        } else if (success) {
            revert AddressEmptyCode(target);
        } else if (LowLevelCall.returnDataSize() > 0) {
            LowLevelCall.bubbleRevert();
        } else {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        bool success = LowLevelCall.staticcallNoReturn(target, data);
        if (success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)) {
            return LowLevelCall.returnData();
        } else if (success) {
            revert AddressEmptyCode(target);
        } else if (LowLevelCall.returnDataSize() > 0) {
            LowLevelCall.bubbleRevert();
        } else {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        bool success = LowLevelCall.delegatecallNoReturn(target, data);
        if (success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)) {
            return LowLevelCall.returnData();
        } else if (success) {
            revert AddressEmptyCode(target);
        } else if (LowLevelCall.returnDataSize() > 0) {
            LowLevelCall.bubbleRevert();
        } else {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     *
     * NOTE: This function is DEPRECATED and may be removed in the next major release.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        // only check if target is a contract if the call was successful and the return data is empty
        // otherwise we already know that it was a contract
        if (success && (returndata.length > 0 || target.code.length > 0)) {
            return returndata;
        } else if (success) {
            revert AddressEmptyCode(target);
        } else if (returndata.length > 0) {
            LowLevelCall.bubbleRevert(returndata);
        } else {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else if (returndata.length > 0) {
            LowLevelCall.bubbleRevert(returndata);
        } else {
            revert Errors.FailedCall();
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_safeTransfer(token, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_safeTransferFrom(token, from, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _safeTransfer(token, to, value, false);
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _safeTransferFrom(token, from, to, value, false);
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        if (!_safeApprove(token, spender, value, false)) {
            if (!_safeApprove(token, spender, 0, true)) revert SafeERC20FailedOperation(address(token));
            if (!_safeApprove(token, spender, value, true)) revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that relies on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that relies on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Oppositely, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity `token.transfer(to, value)` call, relaxing the requirement on the return value: the
     * return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.transfer.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(to, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }

    /**
     * @dev Imitates a Solidity `token.transferFrom(from, to, value)` call, relaxing the requirement on the return
     * value: the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param from The sender of the tokens
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value,
        bool bubble
    ) private returns (bool success) {
        bytes4 selector = IERC20.transferFrom.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(from, shr(96, not(0))))
            mstore(0x24, and(to, shr(96, not(0))))
            mstore(0x44, value)
            success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
            mstore(0x60, 0)
        }
    }

    /**
     * @dev Imitates a Solidity `token.approve(spender, value)` call, relaxing the requirement on the return value:
     * the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param spender The spender of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeApprove(IERC20 token, address spender, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.approve.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(spender, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol

// OpenZeppelin Contracts (last updated v5.6.0) (proxy/ERC1967/ERC1967Utils.sol)

/**
 * @dev This library provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[ERC-1967] slots.
 */
library ERC1967Utils {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit IERC1967.Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by ERC-1967) using
     * the https://ethereum.org/developers/docs/apis/json-rpc/#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit IERC1967.AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the ERC-1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit IERC1967.BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.5.0) (proxy/utils/UUPSUpgradeable.sol)

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * @custom:stateless
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC-1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC-1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    /**
     * @dev Implementation of the ERC-1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC-1967 compliant implementation pointing to self.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC-1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}

// src/MarketEngine.sol

/// @title MarketEngine
/// @notice EVM port of `retropick_market_engine_v5` (Anchor) — same state machine, math, and oracle checks.
/// @dev UUPS: deploy `MarketEngine` implementation + ERC1967 proxy (`initialize` in proxy creation calldata). Upgrades: `admin` only via `_authorizeUpgrade`.
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

    /// @dev Reserved for future storage variables; do not remove or move (UUPS upgrade safety).
    // slither-disable-next-line unused-state,naming-convention -- UUPS storage gap; OZ reserved name
    uint256[50] private __gap;

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
    error RollingNotDirection();
    error RollingInvalidParams();
    error RollingGenesisAlreadyStarted();
    error RollingHaltedUserOps();
    error InvalidRollingRecovery();
    error NotDepositExecutor();

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
    constructor() {
        _disableInitializers();
    }

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
    ) external initializer {
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
            if (p.marketType != MarketTypes.MarketType.Direction) revert RollingNotDirection();
            if (p.rollingIntervalSeconds == 0) revert RollingInvalidParams();
            if (!(p.rollingBufferSeconds < p.rollingIntervalSeconds)) revert RollingInvalidParams();
        }

        _validateTemplate(t);
        emit TemplateUpserted(
            tid, p.slug, uint8(uint256(p.marketType)), p.outcomeCount, p.oracleMaxDelaySeconds, p.oracleMaxConfidenceBps
        );
    }

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

    /// @notice Pancake-style genesis: open the next rolling epoch id (`rollingNextEpochId`, starts at 1).
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

    /// @notice Lock the genesis-open epoch and open the next; enters Live rolling phase. Missed buffer or oracle issues halt instead of reverting.
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

        int256 priceE8 = 0;
        uint64 publishTime = 0;
        uint256 confidenceE8 = 0;
        uint64 maxDelay = MarketTypes.effectiveOracleMaxDelaySeconds(e1, oracleConfig.maxDelaySeconds);
        uint16 maxConf = MarketTypes.effectiveOracleMaxConfidenceBps(e1, oracleConfig.maxConfidenceBps);
        try priceOracle.getNormalizedPrice(t.oracleFeedId, maxDelay, nowTs) returns (int256 p, uint64 pt, uint256 c) {
            priceE8 = p;
            publishTime = pt;
            confidenceE8 = c;
        } catch {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleFailure, k);
            return;
        }
        if (!_confidenceWithinBand(priceE8, confidenceE8, maxConf)) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleConfidenceWide, k);
            return;
        }

        _applyLock(templateId, k, priceE8, publishTime, confidenceE8, maxDelay, maxConf, nowTs);

        uint64 newOpen = _openRollingEpoch(templateId, nowTs, t);
        ledger.rollingPhase = MarketTypes.RollingPhase.Live;
        emit RollingGenesisLocked(templateId, k, newOpen);
    }

    /// @notice One keeper tx: resolve (k-1), lock (k), open (k+1). Same oracle sample for lock A and resolve B.
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

        uint64 dPrev = MarketTypes.effectiveOracleMaxDelaySeconds(ePrev, oracleConfig.maxDelaySeconds);
        uint64 dCur = MarketTypes.effectiveOracleMaxDelaySeconds(eCur, oracleConfig.maxDelaySeconds);
        uint64 maxDelay = dPrev < dCur ? dPrev : dCur;
        uint16 cPrev = MarketTypes.effectiveOracleMaxConfidenceBps(ePrev, oracleConfig.maxConfidenceBps);
        uint16 cCur = MarketTypes.effectiveOracleMaxConfidenceBps(eCur, oracleConfig.maxConfidenceBps);
        uint16 maxConf = cPrev < cCur ? cPrev : cCur;

        int256 priceE8 = 0;
        uint64 publishTime = 0;
        uint256 confidenceE8 = 0;
        try priceOracle.getNormalizedPrice(t.oracleFeedId, maxDelay, nowTs) returns (int256 p, uint64 pt, uint256 c) {
            priceE8 = p;
            publishTime = pt;
            confidenceE8 = c;
        } catch {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleFailure, k);
            return;
        }
        if (!_confidenceWithinBand(priceE8, confidenceE8, maxConf)) {
            _haltRolling(templateId, ledger, MarketTypes.RollingHaltReason.OracleConfidenceWide, k);
            return;
        }

        _finishResolveEpochRolling(templateId, prev, priceE8, publishTime, confidenceE8, maxDelay);
        _applyLock(templateId, k, priceE8, publishTime, confidenceE8, maxDelay, maxConf, nowTs);
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

    /// @notice Amortizes fixed calldata/base gas for keepers maintaining multiple templates.
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

    /// @dev Rolling-only open: uses `ledger.rollingNextEpochId`, then advances it. No manual sequential open guard.
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
    function setDepositExecutor(address account, bool allowed) external onlyAdmin {
        isDepositExecutor[account] = allowed;
        emit DepositExecutorSet(account, allowed);
    }

    function depositToSide(bytes32 templateId, uint64 epochId, uint8 outcomeIndex, uint256 amount)
        external
        nonReentrant
        notPausedUserOps
    {
        _depositToSide(msg.sender, msg.sender, templateId, epochId, outcomeIndex, amount);
    }

    /// @notice Pull stake token from `msg.sender` (must be an allowlisted executor) and credit `beneficiary`.
    /// @dev Used by routers after swap so the end user receives position ownership without being `msg.sender` on `depositToSide`.
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

        stakeToken.safeTransferFrom(payer, address(this), amount);

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

        emit PositionDeposited(templateId, epochId, beneficiary, outcomeIndex, amount);
    }

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

        emit SideSwitched(templateId, epochId, msg.sender, fromOutcome, toOutcome, grossAmount, feeAmount, netAmount);
    }

    function lockEpoch(bytes32 templateId, uint64 epochId) external onlyWorkerOrAdmin notPausedWorkerOps {
        _lockEpoch(templateId, epochId);
    }

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
            (int256 priceE8, uint64 publishTime, uint256 confidenceE8) =
                priceOracle.getNormalizedPrice(e.oracleFeedId, maxDelay, nowTs);
            _applyLock(templateId, epochId, priceE8, publishTime, confidenceE8, maxDelay, maxConf, nowTs);
        } else {
            _applyLock(templateId, epochId, 0, 0, 0, 0, 0, nowTs);
        }
    }

    /// @dev Shared lock transition; for Direction uses supplied oracle sample (single read in rolling execute).
    function _applyLock(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
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
    }

    function resolveEpoch(bytes32 templateId, uint64 epochId)
        external
        onlyWorkerOrAdmin
        notPausedWorkerOps
        nonReentrant
    {
        _resolveEpoch(templateId, epochId);
    }

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
        (int256 priceE8, uint64 publishTime, uint256 confidenceE8) =
            priceOracle.getNormalizedPrice(e.oracleFeedId, maxDelay, nowTs);
        _enforceConfidence(priceE8, confidenceE8, maxConf);
        _finishResolveEpoch(templateId, epochId, priceE8, publishTime, confidenceE8, maxDelay, false, nowTs);
    }

    function _finishResolveEpochRolling(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
        uint64 maxDelaySeconds
    ) internal {
        uint64 nowTs = uint64(block.timestamp);
        _finishResolveEpoch(templateId, epochId, priceE8, publishTime, confidenceE8, maxDelaySeconds, true, nowTs);
    }

    /// @param rollingLink true: resolve epoch `epochId` where `epochId + 1 == activeEpochId` (rolling pipeline).
    function _finishResolveEpoch(
        bytes32 templateId,
        uint64 epochId,
        int256 priceE8,
        uint64 publishTime,
        uint256 confidenceE8,
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

        bool refundMode;
        uint256 winningMask;
        uint256 claimLiabilityTotal;
        uint256 settlementFeeTotal;

        // slither-disable-next-line incorrect-equality -- enum branch for resolve math
        if (e.marketType == MarketTypes.MarketType.Direction) {
            (bool voided, uint256 mask) = Resolvers.resolveDirection(e.checkpointA, e.checkpointB, e.equalPriceVoids);
            if (voided) {
                refundMode = true;
                winningMask = 0;
                claimLiabilityTotal = e.totalPool;
                settlementFeeTotal = 0;
            } else {
                refundMode = false;
                winningMask = mask;
                e.winningOutcomeMask = mask;
                // slither-disable-next-line unused-return -- third value is distributable losing pool; vault split uses claim + fee only
                (claimLiabilityTotal, settlementFeeTotal,) =
                    MarketMath.computeEpochClaimLiabilityStorage(e, e.settlementFeeBps, e.feeOnLosingPool);
            }
        // slither-disable-next-line incorrect-equality -- enum branch for resolve math
        } else if (e.marketType == MarketTypes.MarketType.Threshold) {
            refundMode = false;
            winningMask = Resolvers.resolveThreshold(e.condition, e.absoluteThresholdValueE8, e.checkpointB);
            e.winningOutcomeMask = winningMask;
            // slither-disable-next-line unused-return -- third value is distributable losing pool; vault split uses claim + fee only
            (claimLiabilityTotal, settlementFeeTotal,) =
                MarketMath.computeEpochClaimLiabilityStorage(e, e.settlementFeeBps, e.feeOnLosingPool);
        } else {
            refundMode = false;
            winningMask = Resolvers.resolveRangeClose(e.checkpointB, e.outcomeCount, e.rangeBoundsE8);
            e.winningOutcomeMask = winningMask;
            // slither-disable-next-line unused-return -- third value is distributable losing pool; vault split uses claim + fee only
            (claimLiabilityTotal, settlementFeeTotal,) =
                MarketMath.computeEpochClaimLiabilityStorage(e, e.settlementFeeBps, e.feeOnLosingPool);
        }

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
        e.remainingWinningStake = refundMode ? 0 : MarketTypes.winningPoolTotalStorage(e);
        e.refundMode = refundMode;
        e.claimable = true;
        e.status = refundMode ? MarketTypes.EpochStatus.Voided : MarketTypes.EpochStatus.Resolved;
        e.resolvedAt = nowTs;
        ledger.lastResolvedEpochId = epochId;

        emit EpochResolved(templateId, epochId, winningMask, claimLiabilityTotal, settlementFeeTotal, refundMode);
    }

    function cancelEpoch(bytes32 templateId, uint64 epochId, MarketTypes.CancelReason reason, bool voided)
        external
        onlyWorkerOrAdmin
        nonReentrant
    {
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

    function claim(bytes32 templateId, uint64 epochId) external nonReentrant {
        if (!configInitialized) revert Unauthorized();
        MarketTypes.Ledger storage ledger = ledgers[templateId];
        if (!ledger.initialized) revert InvalidTemplate();

        MarketTypes.Epoch storage e = epochs[templateId][epochId];
        if (!e.claimable) revert ClaimNotAvailable();

        bytes32 pk = positionKey(templateId, epochId);
        MarketTypes.Position storage pos = positions[pk][msg.sender];
        if (pos.claimed) revert AlreadyClaimed();

        uint256 amount;
        uint256 winningStake;
        if (e.refundMode) {
            amount = MarketMath.computeRefundTotal(pos.totalStake);
            winningStake = 0;
        } else {
            // Must match `MarketTypes.MAX_OUTCOMES` (8).
            uint256[8] memory stakes = pos.stakes;
            (amount, winningStake) = MarketMath.computeClaimPayoutStorage(e, stakes, ledger.claimsReserveTotal);
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

        stakeToken.safeTransfer(msg.sender, amount);

        emit Claimed(templateId, epochId, msg.sender, amount);
    }

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

    function templateIdFromSlug(string memory slug) public pure returns (bytes32) {
        return keccak256(bytes(slug));
    }

    function positionKey(bytes32 templateId, uint64 epochId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(templateId, epochId));
    }

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

    function _toConf128(uint256 confidenceE8) internal pure returns (uint128) {
        if (confidenceE8 > type(uint128).max) revert ConfidenceOverflow();
        // forge-lint: disable-next-line(unsafe-typecast) -- guarded by revert above
        return uint128(confidenceE8);
    }

    function _confidenceWithinBand(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps)
        internal
        pure
        returns (bool)
    {
        if (priceE8 == type(int256).min) revert InvalidOraclePrice();
        uint256 abs;
        if (priceE8 >= 0) {
            // forge-lint: disable-next-line(unsafe-typecast) -- non-negative price path
            abs = uint256(priceE8);
        } else {
            // forge-lint: disable-next-line(unsafe-typecast) -- |price| for negative prices
            abs = uint256(-priceE8);
        }
        uint256 limit = (abs * uint256(maxConfidenceBps)) / 10_000;
        return confidenceE8 <= limit;
    }

    function _enforceConfidence(int256 priceE8, uint256 confidenceE8, uint16 maxConfidenceBps) internal pure {
        if (!_confidenceWithinBand(priceE8, confidenceE8, maxConfidenceBps)) revert OracleConfidenceTooWide();
    }

    function _requireCanOpenNextEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (ledger.activeEpochId != ledger.lastResolvedEpochId) revert PreviousEpochUnresolved();
        if (epochId != ledger.activeEpochId + 1) revert EpochAlreadyExists();
    }

    function _requireActiveEpoch(MarketTypes.Ledger storage ledger, uint64 epochId) internal view {
        if (epochId != ledger.activeEpochId) revert EpochNotActive();
    }

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

