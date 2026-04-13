// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {MarketEngineDispatcher} from "../src/engine/MarketEngineDispatcher.sol";
import {MarketEngineAdminModule} from "../src/engine/modules/MarketEngineAdminModule.sol";
import {MarketEngineViewModule} from "../src/engine/modules/MarketEngineViewModule.sol";
import {MarketEngineUserOpsClaimsModule} from "../src/engine/modules/MarketEngineUserOpsClaimsModule.sol";
import {MarketEngineCoreLifecycleModule} from "../src/engine/modules/MarketEngineCoreLifecycleModule.sol";
import {MarketEngineRollingLifecycleModule} from "../src/engine/modules/MarketEngineRollingLifecycleModule.sol";
import {IMarketEngine} from "../src/engine/IMarketEngine.sol";
import {ChainlinkAdapter} from "../src/adapters/ChainlinkAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";

/// @notice Deploy `ChainlinkAdapter` + UUPS proxy for `MarketEngine`, with `initialize` in the proxy constructor path.
/// @dev Run with `--ffi` so OpenZeppelin upgrades validations can run (see README).
///   Required env (example):
///   STAKE_TOKEN, SEQUENCER_FEED (use `address(0)` on L1), ADMIN, TREASURY, WORKER,
///   DEFAULT_SETTLEMENT_FEE_BPS, MAX_SWITCH_FEE_BPS, MAX_OUTCOMES,
///   ORACLE_MAX_DELAY_SECONDS, ORACLE_MAX_CONFIDENCE_BPS
contract Deploy is Script {
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
        // Production checklist alignment:
        // - Do not embed private keys in env vars. Use Foundry keystore via `--account` and/or `--sender`.
        // - Deploy proxy with atomic init calldata (Upgrades.deployUUPSProxy already does this).
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
        address proxy =
            Upgrades.deployUUPSProxy("engine/MarketEngineDispatcher.sol:MarketEngineDispatcher", initData, opts);

        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));
        address adminModule = address(new MarketEngineAdminModule());
        address viewModule = address(new MarketEngineViewModule());
        address userOpsClaimsModule = address(new MarketEngineUserOpsClaimsModule());
        address coreLifecycleModule = address(new MarketEngineCoreLifecycleModule());
        address rollingLifecycleModule = address(new MarketEngineRollingLifecycleModule());

        dispatcher.setSelectorModule(bytes4(keccak256("pauseProgram(bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setTreasury(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setWorkerAuthority(address)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setDepositExecutor(address,bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setYieldRouter(address,uint16)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("setLmRewardsEnabled(bool)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("keeperClaimLmRewards(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("yieldEmergencyWithdraw(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("initializeMarket(bytes32)")), adminModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("withdrawFees(bytes32,uint256)")), adminModule, false);

        dispatcher.setSelectorModule(bytes4(keccak256("getUserEpochs(bytes32,address,uint256,uint256)")), viewModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("getVaultBalances(bytes32)")), viewModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("getRollingLifecycle(bytes32)")), viewModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("getEpoch(bytes32,uint64)")), viewModule, false);

        dispatcher.setSelectorModule(bytes4(keccak256("depositToSide(bytes32,uint64,uint8,uint256)")), userOpsClaimsModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("depositToSideFor(address,bytes32,uint64,uint8,uint256)")), userOpsClaimsModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("switchSide(bytes32,uint64,uint8,uint8,uint256)")), userOpsClaimsModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("claim(bytes32,uint64)")), userOpsClaimsModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("claimMany(bytes32,uint64[])")), userOpsClaimsModule, false);

        dispatcher.setSelectorModule(
            bytes4(
                keccak256(
                    "upsertTemplate((string,string,bytes32,uint8,uint8,uint8,bool,uint8,int256,int256[7],uint16,uint16,bool,uint8,uint64,uint64,uint64,uint16))"
                )
            ),
            coreLifecycleModule,
            false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("openEpoch(bytes32,uint64,uint64,uint64,uint64)")), coreLifecycleModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("openEpochsBatch(bytes32[],uint64[],uint64[],uint64[],uint64[])")),
            coreLifecycleModule,
            false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("lockEpoch(bytes32,uint64)")), coreLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("lockEpochsBatch(bytes32[],uint64[])")), coreLifecycleModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("resolveEpoch(bytes32,uint64)")), coreLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("resolveEpochsBatch(bytes32[],uint64[])")), coreLifecycleModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("cancelEpoch(bytes32,uint64,uint8,bool)")), coreLifecycleModule, false
        );

        dispatcher.setSelectorModule(bytes4(keccak256("genesisStartRolling(bytes32)")), rollingLifecycleModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("genesisLockRolling(bytes32)")), rollingLifecycleModule, false);
        dispatcher.setSelectorModule(bytes4(keccak256("executeRollingRound(bytes32)")), rollingLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("executeRollingRoundBatch(bytes32[])")), rollingLifecycleModule, false
        );
        dispatcher.setSelectorModule(bytes4(keccak256("haltRollingMarket(bytes32)")), rollingLifecycleModule, false);
        dispatcher.setSelectorModule(
            bytes4(keccak256("cancelRollingEpochWhileHalted(bytes32,uint64,uint8,bool)")), rollingLifecycleModule, false
        );
        dispatcher.setSelectorModule(
            bytes4(keccak256("resetRollingLifecycle(bytes32,uint64)")), rollingLifecycleModule, false
        );

        // Post-deploy verification (script-level; still do independent RPC checks per checklist).
        IMarketEngine engine = IMarketEngine(proxy);
        require(engine.configInitialized(), "configInitialized=false");
        require(address(engine.stakeToken()) == p.stakeToken, "stakeToken mismatch");
        require(address(engine.priceOracle()) == address(adapter), "priceOracle mismatch");
        require(engine.admin() == p.admin, "admin mismatch");
        require(engine.treasury() == p.treasury, "treasury mismatch");
        require(engine.workerAuthority() == p.worker, "worker mismatch");

        console2.log("ChainlinkAdapter", address(adapter));
        console2.log("MarketEngineDispatcher proxy", proxy);
        console2.log("MarketEngineDispatcher implementation", Upgrades.getImplementationAddress(proxy));
        console2.log("MODULE_ADMIN", adminModule);
        console2.log("MODULE_VIEW", viewModule);
        console2.log("MODULE_USEROPS_CLAIMS", userOpsClaimsModule);
        console2.log("MODULE_CORE_LIFECYCLE", coreLifecycleModule);
        console2.log("MODULE_ROLLING_LIFECYCLE", rollingLifecycleModule);
        console2.log("Admin", p.admin);
        console2.log("Treasury", p.treasury);
        console2.log("Worker", p.worker);

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
