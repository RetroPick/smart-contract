// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {MarketTypes} from "../types/MarketTypes.sol";
import {IMarketEngine} from "./IMarketEngine.sol";
import {MarketEngineAdminModule} from "./modules/MarketEngineAdminModule.sol";
import {MarketEngineUserOpsClaimsModule} from "./modules/MarketEngineUserOpsClaimsModule.sol";

/// @notice UUPS root dispatcher for MarketEngine modular architecture.
/// @dev Routes calls by selector to trusted module contracts via delegatecall.
/// Trust: `admin` wiring via `setSelectorModule` points delegatecall targets at this proxy’s storage—incorrect modules
/// or malicious bytecode are equivalent to a compromised admin. UUPS upgrades share the same trust boundary.
/// Module onboarding is two-step: `allowModuleCodeHash` commits to an exact bytecode artifact, then `registerModule`
/// pins a live address to that hash. The storage-compatibility marker is auxiliary; layout safety requires modules
/// to inherit `MarketEngineState` (or an audited equivalent) and off-chain verification.
contract MarketEngineDispatcher is
    Initializable,
    UUPSUpgradeable,
    MarketEngineAdminModule,
    MarketEngineUserOpsClaimsModule
{
    bytes4 private constant SELECTOR_INITIALIZE = 0x7b89ffdb;
    bytes4 private constant SELECTOR_UPGRADE_TO_AND_CALL = 0x4f1ef286;
    bytes4 private constant SELECTOR_PROXIABLE_UUID = 0x52d1902d;
    bytes4 private constant SELECTOR_SET_SELECTOR_MODULE = 0x5837c6a8; // setSelectorModule(bytes4,address,bool)
    /// @dev keccak256(abi.encode(uint256(keccak256("retropick.storage.MarketEngineDispatcher.ModuleRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MODULE_REGISTRY_STORAGE_LOCATION =
        0x97dc697845f891728b442225407661712d01fa686d06d21698367248a953bc00;
    bytes4 private constant SELECTOR_STORAGE_COMPATIBILITY = bytes4(keccak256("marketEngineStorageCompatibility()"));

    /// @custom:storage-location erc7201:retropick.storage.MarketEngineDispatcher.ModuleRegistry
    struct ModuleRegistryStorage {
        mapping(bytes4 selector => address module) selectorToModule;
        mapping(bytes4 selector => bool immutableSelector) selectorImmutable;
        mapping(address module => bool approved) approvedModules;
        mapping(address module => bytes32 codeHash) moduleCodeHash;
        mapping(bytes32 codeHash => bool allowed) allowedModuleCodeHashes;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _moduleRegistryStorage() private pure returns (ModuleRegistryStorage storage $) {
        assembly {
            $.slot := MODULE_REGISTRY_STORAGE_LOCATION
        }
    }

    function initialize(IMarketEngine.InitConfig calldata config) external initializer onlyProxy {
        if (configInitialized) revert Unauthorized();
        if (address(config.stakeToken) == address(0) || address(config.priceOracle) == address(0)) {
            revert Unauthorized();
        }
        if (config.admin == address(0) || config.treasury == address(0) || config.worker == address(0)) {
            revert Unauthorized();
        }
        if (config.defaultSettlementFeeBps > 10_000 || config.maxSwitchFeeBps > 10_000) revert InvalidFeeBps();
        if (config.maxOutcomes > MarketTypes.MAX_OUTCOMES) revert TooManyOutcomes();
        if (config.oracleKind != MarketTypes.OracleKind.Chainlink) revert InvalidOracleFeed();

        stakeToken = config.stakeToken;
        priceOracle = config.priceOracle;
        admin = config.admin;
        treasury = config.treasury;
        workerAuthority = config.worker;
        defaultSettlementFeeBps = config.defaultSettlementFeeBps;
        maxSwitchFeeBps = config.maxSwitchFeeBps;
        maxOutcomes = config.maxOutcomes;
        oracleConfig = MarketTypes.OracleConfig({
            oracleKind: config.oracleKind,
            maxDelaySeconds: config.oracleMaxDelaySeconds,
            maxConfidenceBps: config.oracleMaxConfidenceBps
        });
        configInitialized = true;
        emit ConfigInitialized(config.admin, config.treasury, config.worker);
    }

    function allowModuleCodeHash(bytes32 codeHash) external onlyAdmin {
        if (codeHash == bytes32(0)) revert ModuleCodeHashNotAllowed(codeHash);
        ModuleRegistryStorage storage $ = _moduleRegistryStorage();
        $.allowedModuleCodeHashes[codeHash] = true;
        emit ModuleCodeHashAllowed(codeHash);
    }

    function disallowModuleCodeHash(bytes32 codeHash) external onlyAdmin {
        ModuleRegistryStorage storage $ = _moduleRegistryStorage();
        delete $.allowedModuleCodeHashes[codeHash];
        emit ModuleCodeHashDisallowed(codeHash);
    }

    function isModuleCodeHashAllowed(bytes32 codeHash) external view returns (bool) {
        return _moduleRegistryStorage().allowedModuleCodeHashes[codeHash];
    }

    function registerModule(address module, bytes32 expectedCodeHash) external onlyAdmin {
        if (module == address(0) || module.code.length == 0) revert InvalidModule();
        _enforceModuleStorageCompatibility(module);
        bytes32 actualCodeHash = keccak256(module.code);
        if (actualCodeHash != expectedCodeHash) {
            revert ModuleCodeHashMismatch(module, expectedCodeHash, actualCodeHash);
        }

        ModuleRegistryStorage storage $ = _moduleRegistryStorage();
        if (!$.allowedModuleCodeHashes[actualCodeHash]) revert ModuleCodeHashNotAllowed(actualCodeHash);
        $.approvedModules[module] = true;
        $.moduleCodeHash[module] = expectedCodeHash;
        emit ModuleRegistered(module, expectedCodeHash);
    }

    function revokeModule(address module) external onlyAdmin {
        ModuleRegistryStorage storage $ = _moduleRegistryStorage();
        delete $.approvedModules[module];
        delete $.moduleCodeHash[module];
        emit ModuleRevoked(module);
    }

    function isModuleApproved(address module) external view returns (bool) {
        return _moduleRegistryStorage().approvedModules[module];
    }

    function getModuleCodeHash(address module) external view returns (bytes32) {
        return _moduleRegistryStorage().moduleCodeHash[module];
    }

    function setSelectorModule(bytes4 selector, address module, bool makeImmutable) external onlyAdmin {
        if (module == address(0) || module.code.length == 0) revert InvalidModule();
        _enforceApprovedModule(module);

        ModuleRegistryStorage storage $ = _moduleRegistryStorage();
        if ($.selectorImmutable[selector]) revert SelectorImmutable(selector);
        if (_isRootOwnedSelector(selector)) revert SelectorImmutable(selector);
        $.selectorToModule[selector] = module;
        if (makeImmutable) $.selectorImmutable[selector] = true;
        emit SelectorModuleSet(selector, module, makeImmutable);
    }

    function getSelectorModule(bytes4 selector) external view returns (address module, bool immutableSelector_) {
        ModuleRegistryStorage storage $ = _moduleRegistryStorage();
        return ($.selectorToModule[selector], $.selectorImmutable[selector]);
    }

    // Backward-compatible mapping getters (same selectors as legacy monolith).
    function templates(bytes32 templateId) external view returns (MarketTypes.Template memory) {
        return _templates[templateId];
    }

    function ledgers(bytes32 templateId) external view returns (MarketTypes.Ledger memory) {
        return _ledgers[templateId];
    }

    function epochs(bytes32 templateId, uint64 epochId) external view returns (MarketTypes.Epoch memory) {
        return _epochs[templateId][epochId];
    }

    function _authorizeUpgrade(address) internal override onlyAdmin {}

    function _isRootOwnedSelector(bytes4 selector) private pure returns (bool) {
        return selector == SELECTOR_INITIALIZE || selector == SELECTOR_UPGRADE_TO_AND_CALL
            || selector == SELECTOR_PROXIABLE_UUID || selector == SELECTOR_SET_SELECTOR_MODULE
            || _isDirectAdminSelector(selector) || _isDirectUserOpsSelector(selector);
    }

    function _isDirectAdminSelector(bytes4 selector) private pure returns (bool) {
        return selector == IMarketEngine.pauseProgram.selector || selector == IMarketEngine.setWorkerAuthority.selector
            || selector == IMarketEngine.setTreasury.selector
            || selector == IMarketEngine.setDepositExecutor.selector
            || selector == IMarketEngine.setYieldRouter.selector
            || selector == IMarketEngine.setRateOracle.selector
            || selector == IMarketEngine.setSmartDataOracle.selector
            || selector == IMarketEngine.setMacroOracle.selector
            || selector == IMarketEngine.setEquityOracle.selector
            || selector == IMarketEngine.resetOracleCursor.selector
            || selector == IMarketEngine.setLmRewardsEnabled.selector
            || selector == IMarketEngine.keeperClaimLmRewards.selector
            || selector == IMarketEngine.yieldEmergencyWithdraw.selector
            || selector == IMarketEngine.reconcileEpochRoutedPrincipal.selector
            || selector == IMarketEngine.recoverRoutedSettledClaims.selector
            || selector == IMarketEngine.finalizeRecoveredYield.selector
            || selector == IMarketEngine.reassignRecoveredBalance.selector
            || selector == IMarketEngine.resetYieldRouterFailures.selector
            || selector == IMarketEngine.initializeMarket.selector || selector == IMarketEngine.withdrawFees.selector;
    }

    function _isDirectUserOpsSelector(bytes4 selector) private pure returns (bool) {
        return selector == IMarketEngine.depositToSide.selector || selector == IMarketEngine.depositToSideFor.selector
            || selector == IMarketEngine.switchSide.selector || selector == IMarketEngine.claim.selector
            || selector == IMarketEngine.claimMany.selector;
    }

    function _delegateForSelector(bytes4 selector) private {
        ModuleRegistryStorage storage $ = _moduleRegistryStorage();
        address module = $.selectorToModule[selector];
        if (module == address(0)) revert ModuleNotSet(selector);
        _enforceApprovedModule(module);

        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch success
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _enforceApprovedModule(address module) private view {
        ModuleRegistryStorage storage $ = _moduleRegistryStorage();
        if (!$.approvedModules[module]) revert UnapprovedModule(module);

        bytes32 expectedCodeHash = $.moduleCodeHash[module];
        bytes32 actualCodeHash = keccak256(module.code);
        if (actualCodeHash != expectedCodeHash) {
            revert ModuleCodeHashMismatch(module, expectedCodeHash, actualCodeHash);
        }
        _enforceModuleStorageCompatibility(module);
    }

    function _enforceModuleStorageCompatibility(address module) private view {
        (bool ok, bytes memory out) = module.staticcall(abi.encodeWithSelector(SELECTOR_STORAGE_COMPATIBILITY));
        if (!ok || out.length != 32) revert IncompatibleModuleStorage(module);
        bytes32 marker = abi.decode(out, (bytes32));
        if (marker != MODULE_STORAGE_COMPATIBILITY_ID) revert IncompatibleModuleStorage(module);
    }

    fallback() external payable {
        _delegateForSelector(msg.sig);
    }

    receive() external payable {}
}
