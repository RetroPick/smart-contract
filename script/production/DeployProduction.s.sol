// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";
import {MarketEngineAdminModule} from "../../src/engine/modules/MarketEngineAdminModule.sol";
import {MarketEngineViewModule} from "../../src/engine/modules/MarketEngineViewModule.sol";
import {MarketEngineUserOpsClaimsModule} from "../../src/engine/modules/MarketEngineUserOpsClaimsModule.sol";
import {MarketEngineCoreLifecycleModule} from "../../src/engine/modules/MarketEngineCoreLifecycleModule.sol";
import {MarketEngineRollingLifecycleModule} from "../../src/engine/modules/MarketEngineRollingLifecycleModule.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";
import {ChainlinkAdapter} from "../../src/adapters/ChainlinkAdapter.sol";
import {RateAdapter} from "../../src/oracle/RateAdapter.sol";
import {SmartDataAdapter} from "../../src/oracle/SmartDataAdapter.sol";
import {MacroAdapter} from "../../src/oracle/MacroAdapter.sol";
import {EquityAdapter} from "../../src/oracle/EquityAdapter.sol";
import {TrustedReporterAdapter} from "../../src/oracle/TrustedReporterAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";
import {ScriptSelectorMatrix} from "../ScriptSelectorMatrix.sol";

/// @notice Production deployment: deploy `ChainlinkAdapter` + UUPS proxy for `MarketEngine` with atomic `initialize`.
/// @dev Run with `--ffi` so OpenZeppelin upgrades validations can run.
/// @dev Use Foundry keystore with `--account`, do not pass raw private keys.
///
/// Required env:
/// - STAKE_TOKEN
/// - SEQUENCER_FEED (use address(0) on L1, Chainlink uptime feed on L2)
/// - ADMIN, TREASURY, WORKER
/// - DEFAULT_SETTLEMENT_FEE_BPS, MAX_SWITCH_FEE_BPS, MAX_OUTCOMES
/// - ORACLE_MAX_DELAY_SECONDS, ORACLE_MAX_CONFIDENCE_BPS
///
/// Optional (Trusted Reporter Oracle — `upsertTemplate` with `templateOracleKind=TrustedReporter`):
/// - TRUSTED_REPORTER: if non-zero, deploys `TrustedReporterAdapter(TRUSTED_REPORTER, ADMIN, maxAge)`
/// - TRO_MAX_SIGNATURE_AGE_SECONDS (default 3600; must be within adapter min/max)
contract DeployProduction is Script {
    event DeploymentCompleted(address indexed proxy, address indexed adapter);

    struct EnvConfig {
        address stakeToken;
        address sequencerFeed;
        address admin;
        address treasury;
        address worker;
        uint16 defFee;
        uint16 maxSw;
        uint8 maxOut;
        uint64 delay;
        uint16 conf;
    }

    struct DeployInitParams {
        address stakeToken;
        address adapter;
        address admin;
        address treasury;
        address worker;
        uint16 defFee;
        uint16 maxSw;
        uint8 maxOut;
        uint64 delay;
        uint16 conf;
    }

    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        require(expectedChainId != 0, "EXPECTED_CHAIN_ID=0");
        require(block.chainid == expectedChainId, "wrong chain");

        vm.startBroadcast();

        EnvConfig memory c = _loadEnvConfig();
        ChainlinkAdapter adapter = new ChainlinkAdapter(c.sequencerFeed);
        console2.log(
            "Post-deploy: call ChainlinkAdapter.setFeedDecimals per feed before upsertTemplate (see FeedDecimalsNotConfigured)"
        );
        RateAdapter rateAdapter = new RateAdapter(c.sequencerFeed);
        SmartDataAdapter smartDataAdapter = new SmartDataAdapter(c.sequencerFeed);
        MacroAdapter macroAdapter = new MacroAdapter(c.sequencerFeed);
        EquityAdapter equityAdapter = new EquityAdapter(c.sequencerFeed);

        _deployOptionalTrustedReporter(c.admin);

        DeployInitParams memory p = DeployInitParams({
            stakeToken: c.stakeToken,
            adapter: address(adapter),
            admin: c.admin,
            treasury: c.treasury,
            worker: c.worker,
            defFee: c.defFee,
            maxSw: c.maxSw,
            maxOut: c.maxOut,
            delay: c.delay,
            conf: c.conf
        });

        IMarketEngine.InitConfig memory initConfig = _buildInitConfig(p);
        bytes memory initData = abi.encodeCall(MarketEngineDispatcher.initialize, (initConfig));

        Options memory opts;
        opts.unsafeSkipAllChecks = vm.envOr("OZ_UNSAFE_SKIP_ALL_CHECKS", false);
        address proxy =
            Upgrades.deployUUPSProxy("MarketEngineDispatcher.sol:MarketEngineDispatcher", initData, opts);
        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));
        _deployAndWireModules(dispatcher);

        // Lightweight post-deploy verification (still do independent RPC checks per ProductionChecklist).
        IMarketEngine engine = IMarketEngine(proxy);
        require(engine.configInitialized(), "configInitialized=false");
        require(address(engine.stakeToken()) == p.stakeToken, "stakeToken mismatch");
        require(address(engine.priceOracle()) == address(adapter), "priceOracle mismatch");
        require(engine.admin() == p.admin, "admin mismatch");
        require(engine.treasury() == p.treasury, "treasury mismatch");
        require(engine.workerAuthority() == p.worker, "worker mismatch");
        engine.setRateOracle(address(rateAdapter));
        engine.setSmartDataOracle(address(smartDataAdapter));
        engine.setMacroOracle(address(macroAdapter));
        engine.setEquityOracle(address(equityAdapter));

        _logDeployment(
            address(adapter),
            address(rateAdapter),
            address(smartDataAdapter),
            address(macroAdapter),
            address(equityAdapter),
            proxy,
            p.admin,
            p.treasury,
            p.worker
        );
        emit DeploymentCompleted(proxy, address(adapter));

        vm.stopBroadcast();
    }

    function _loadEnvConfig() internal view returns (EnvConfig memory c) {
        c.stakeToken = vm.envAddress("STAKE_TOKEN");
        c.sequencerFeed = vm.envAddress("SEQUENCER_FEED");
        c.admin = vm.envAddress("ADMIN");
        c.treasury = vm.envAddress("TREASURY");
        c.worker = vm.envAddress("WORKER");

        uint256 defFeeRaw = vm.envUint("DEFAULT_SETTLEMENT_FEE_BPS");
        uint256 maxSwRaw = vm.envUint("MAX_SWITCH_FEE_BPS");
        uint256 maxOutRaw = vm.envUint("MAX_OUTCOMES");
        uint256 delayRaw = vm.envUint("ORACLE_MAX_DELAY_SECONDS");
        uint256 confRaw = vm.envUint("ORACLE_MAX_CONFIDENCE_BPS");

        require(c.stakeToken != address(0), "STAKE_TOKEN=0");
        require(c.admin != address(0), "ADMIN=0");
        require(c.treasury != address(0), "TREASURY=0");
        require(c.worker != address(0), "WORKER=0");

        require(defFeeRaw <= 10_000, "DEFAULT_SETTLEMENT_FEE_BPS>10000");
        require(maxSwRaw <= 10_000, "MAX_SWITCH_FEE_BPS>10000");
        require(maxOutRaw <= 8, "MAX_OUTCOMES>8");
        require(delayRaw <= type(uint64).max, "ORACLE_MAX_DELAY_SECONDS overflow");
        require(confRaw <= 10_000, "ORACLE_MAX_CONFIDENCE_BPS>10000");

        // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
        c.defFee = uint16(defFeeRaw);
        // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
        c.maxSw = uint16(maxSwRaw);
        // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
        c.maxOut = uint8(maxOutRaw);
        // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
        c.delay = uint64(delayRaw);
        // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
        c.conf = uint16(confRaw);
    }

    function _deployOptionalTrustedReporter(address admin) internal {
        address trustedReporter = vm.envOr("TRUSTED_REPORTER", address(0));
        if (trustedReporter == address(0)) return;

        uint256 troMaxAgeRaw = vm.envOr("TRO_MAX_SIGNATURE_AGE_SECONDS", uint256(3600));
        // Bounds must match `TrustedReporterAdapter` constructor validation.
        require(troMaxAgeRaw >= 60 && troMaxAgeRaw <= 48 hours, "TRO_MAX_SIGNATURE_AGE_SECONDS range");
        TrustedReporterAdapter tro = new TrustedReporterAdapter(trustedReporter, admin, troMaxAgeRaw);
        console2.log("TrustedReporterAdapter", address(tro));
    }

    function _deployAndWireModules(MarketEngineDispatcher dispatcher) internal {
        ScriptSelectorMatrix.wireAll(
            dispatcher,
            ScriptSelectorMatrix.Modules({
                admin: address(new MarketEngineAdminModule()),
                viewModule: address(new MarketEngineViewModule()),
                userOpsClaims: address(new MarketEngineUserOpsClaimsModule()),
                coreLifecycle: address(new MarketEngineCoreLifecycleModule()),
                rollingLifecycle: address(new MarketEngineRollingLifecycleModule())
            })
        );
    }

    function _logDeployment(
        address adapter,
        address rateAdapter,
        address smartDataAdapter,
        address macroAdapter,
        address equityAdapter,
        address proxy,
        address admin,
        address treasury,
        address worker
    ) internal view {
        console2.log("ChainlinkAdapter", adapter);
        console2.log("RateAdapter", rateAdapter);
        console2.log("SmartDataAdapter", smartDataAdapter);
        console2.log("MacroAdapter", macroAdapter);
        console2.log("EquityAdapter", equityAdapter);
        console2.log("MarketEngineDispatcher proxy", proxy);
        console2.log("MarketEngineDispatcher implementation", Upgrades.getImplementationAddress(proxy));
        console2.log("Admin", admin);
        console2.log("Treasury", treasury);
        console2.log("Worker", worker);
    }

    function _buildInitConfig(DeployInitParams memory p) internal pure returns (IMarketEngine.InitConfig memory cfg) {
        cfg = IMarketEngine.InitConfig({
            stakeToken: IERC20(p.stakeToken),
            priceOracle: IPriceOracle(p.adapter),
            admin: p.admin,
            treasury: p.treasury,
            worker: p.worker,
            defaultSettlementFeeBps: p.defFee,
            maxSwitchFeeBps: p.maxSw,
            maxOutcomes: p.maxOut,
            oracleKind: MarketTypes.OracleKind.Chainlink,
            oracleMaxDelaySeconds: p.delay,
            oracleMaxConfidenceBps: p.conf
        });
    }
}

