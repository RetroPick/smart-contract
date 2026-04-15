// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

        address stakeToken = vm.envAddress("STAKE_TOKEN");
        address sequencerFeed = vm.envAddress("SEQUENCER_FEED");
        address admin = vm.envAddress("ADMIN");
        address treasury = vm.envAddress("TREASURY");
        address worker = vm.envAddress("WORKER");

        uint256 defFeeRaw = vm.envUint("DEFAULT_SETTLEMENT_FEE_BPS");
        uint256 maxSwRaw = vm.envUint("MAX_SWITCH_FEE_BPS");
        uint256 maxOutRaw = vm.envUint("MAX_OUTCOMES");
        uint256 delayRaw = vm.envUint("ORACLE_MAX_DELAY_SECONDS");
        uint256 confRaw = vm.envUint("ORACLE_MAX_CONFIDENCE_BPS");

        require(stakeToken != address(0), "STAKE_TOKEN=0");
        require(admin != address(0), "ADMIN=0");
        require(treasury != address(0), "TREASURY=0");
        require(worker != address(0), "WORKER=0");

        require(defFeeRaw <= 10_000, "DEFAULT_SETTLEMENT_FEE_BPS>10000");
        require(maxSwRaw <= 10_000, "MAX_SWITCH_FEE_BPS>10000");
        require(maxOutRaw <= 8, "MAX_OUTCOMES>8");
        require(delayRaw <= type(uint64).max, "ORACLE_MAX_DELAY_SECONDS overflow");
        require(confRaw <= 10_000, "ORACLE_MAX_CONFIDENCE_BPS>10000");

        ChainlinkAdapter adapter = new ChainlinkAdapter(sequencerFeed);
        RateAdapter rateAdapter = new RateAdapter(sequencerFeed);
        SmartDataAdapter smartDataAdapter = new SmartDataAdapter(sequencerFeed);
        MacroAdapter macroAdapter = new MacroAdapter(sequencerFeed);
        EquityAdapter equityAdapter = new EquityAdapter(sequencerFeed);

        address trustedReporter = vm.envOr("TRUSTED_REPORTER", address(0));
        if (trustedReporter != address(0)) {
            uint256 troMaxAgeRaw = vm.envOr("TRO_MAX_SIGNATURE_AGE_SECONDS", uint256(3600));
            // Bounds must match `TrustedReporterAdapter` constructor validation.
            require(troMaxAgeRaw >= 60 && troMaxAgeRaw <= 48 hours, "TRO_MAX_SIGNATURE_AGE_SECONDS range");
            TrustedReporterAdapter tro = new TrustedReporterAdapter(trustedReporter, admin, troMaxAgeRaw);
            console2.log("TrustedReporterAdapter", address(tro));
        }

        DeployInitParams memory p = DeployInitParams({
            stakeToken: stakeToken,
            adapter: address(adapter),
            admin: admin,
            treasury: treasury,
            worker: worker,
            // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
            defFee: uint16(defFeeRaw),
            // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
            maxSw: uint16(maxSwRaw),
            // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
            maxOut: uint8(maxOutRaw),
            // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
            delay: uint64(delayRaw),
            // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
            conf: uint16(confRaw)
        });

        IMarketEngine.InitConfig memory initConfig = _buildInitConfig(p);
        bytes memory initData = abi.encodeCall(MarketEngineDispatcher.initialize, (initConfig));

        Options memory opts;
        opts.unsafeSkipAllChecks = vm.envOr("OZ_UNSAFE_SKIP_ALL_CHECKS", false);
        address proxy =
            Upgrades.deployUUPSProxy("MarketEngineDispatcher.sol:MarketEngineDispatcher", initData, opts);
        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));
        address adminModule = address(new MarketEngineAdminModule());
        address viewModule = address(new MarketEngineViewModule());
        address userOpsClaimsModule = address(new MarketEngineUserOpsClaimsModule());
        address coreLifecycleModule = address(new MarketEngineCoreLifecycleModule());
        address rollingLifecycleModule = address(new MarketEngineRollingLifecycleModule());
        ScriptSelectorMatrix.wireAll(
            dispatcher,
            ScriptSelectorMatrix.Modules({
                admin: adminModule,
                viewModule: viewModule,
                userOpsClaims: userOpsClaimsModule,
                coreLifecycle: coreLifecycleModule,
                rollingLifecycle: rollingLifecycleModule
            })
        );

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

        console2.log("ChainlinkAdapter", address(adapter));
        console2.log("RateAdapter", address(rateAdapter));
        console2.log("SmartDataAdapter", address(smartDataAdapter));
        console2.log("MacroAdapter", address(macroAdapter));
        console2.log("EquityAdapter", address(equityAdapter));
        console2.log("MarketEngineDispatcher proxy", proxy);
        console2.log("MarketEngineDispatcher implementation", Upgrades.getImplementationAddress(proxy));
        console2.log("Admin", p.admin);
        console2.log("Treasury", p.treasury);
        console2.log("Worker", p.worker);
        emit DeploymentCompleted(proxy, address(adapter));

        vm.stopBroadcast();
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

