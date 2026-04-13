// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {MarketTypes} from "../types/MarketTypes.sol";
import {IMarketEngine} from "./IMarketEngine.sol";
import {MarketEngineState} from "./MarketEngineState.sol";

/// @notice UUPS root dispatcher for MarketEngine modular architecture.
/// @dev Routes calls by selector to trusted module contracts via delegatecall.
/// Trust: `admin` wiring via `setSelectorModule` points delegatecall targets at this proxy’s storage—incorrect modules
/// or malicious bytecode are equivalent to a compromised admin. UUPS upgrades share the same trust boundary.
contract MarketEngineDispatcher is Initializable, ReentrancyGuardTransient, UUPSUpgradeable, MarketEngineState {
    bytes4 private constant SELECTOR_INITIALIZE = 0x7b89ffdb;
    bytes4 private constant SELECTOR_UPGRADE_TO_AND_CALL = 0x4f1ef286;
    bytes4 private constant SELECTOR_PROXIABLE_UUID = 0x52d1902d;
    bytes4 private constant SELECTOR_SET_SELECTOR_MODULE = 0x5837c6a8; // setSelectorModule(bytes4,address,bool)

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IMarketEngine.InitConfig calldata config) external initializer onlyProxy {
        if (configInitialized) revert Unauthorized();
        if (address(config.stakeToken) == address(0) || address(config.priceOracle) == address(0)) revert Unauthorized();
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

    function setSelectorModule(bytes4 selector, address module, bool makeImmutable) external onlyAdmin {
        if (module == address(0) || module.code.length == 0) revert InvalidModule();
        if (selectorImmutable[selector]) revert SelectorImmutable(selector);
        if (_isRootOwnedSelector(selector)) revert SelectorImmutable(selector);
        selectorToModule[selector] = module;
        if (makeImmutable) selectorImmutable[selector] = true;
        emit SelectorModuleSet(selector, module, makeImmutable);
    }

    function getSelectorModule(bytes4 selector) external view returns (address module, bool immutableSelector_) {
        return (selectorToModule[selector], selectorImmutable[selector]);
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
            || selector == SELECTOR_PROXIABLE_UUID || selector == SELECTOR_SET_SELECTOR_MODULE;
    }

    function _delegateForSelector(bytes4 selector) private {
        address module = selectorToModule[selector];
        if (module == address(0)) revert ModuleNotSet(selector);

        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch success
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    fallback() external payable {
        _delegateForSelector(msg.sig);
    }

    receive() external payable {}
}
