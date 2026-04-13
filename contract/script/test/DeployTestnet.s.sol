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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";
import {TokenFaucet} from "../../src/test/faucet/TokenFaucet.sol";

/// @notice Testnet deployment: same atomic UUPS init as production, with optional oracle smoke checks.
/// @dev Run with `--ffi` so OpenZeppelin upgrades validations can run.
/// @dev Use Foundry keystore with `--account`, do not pass raw private keys.
///
/// Required env (same shape as production):
/// - STAKE_TOKEN (optional if `DEPLOY_FAUCET=1`; then the faucet token becomes STAKE_TOKEN)
/// - SEQUENCER_FEED (use address(0) on L1 testnets; on L2 testnets set Chainlink uptime feed)
/// - ADMIN, TREASURY, WORKER
/// - DEFAULT_SETTLEMENT_FEE_BPS, MAX_SWITCH_FEE_BPS, MAX_OUTCOMES
/// - ORACLE_MAX_DELAY_SECONDS, ORACLE_MAX_CONFIDENCE_BPS
///
/// Optional env for smoke checks:
/// - SMOKE_FEED_ADDRESS: an AggregatorV3 proxy address for the testnet (e.g. ETH/USD)
/// - SMOKE_MAX_AGE_SECONDS: max age used for the smoke read (defaults to ORACLE_MAX_DELAY_SECONDS)
///
/// Optional env for deploying a demo faucet + MockERC20 stake token:
/// - DEPLOY_FAUCET (0/1; default 0)
/// - FAUCET_TOKEN_NAME (default "Demo USD")
/// - FAUCET_TOKEN_SYMBOL (default "dUSD")
/// - FAUCET_COOLDOWN_SECONDS (default 3600)
/// - FAUCET_MAX_MINT_AMOUNT (default 1000e18)
contract DeployTestnet is Script {
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
        vm.startBroadcast();

        address sequencerFeed = vm.envAddress("SEQUENCER_FEED");
        address admin = vm.envAddress("ADMIN");
        address treasury = vm.envAddress("TREASURY");
        address worker = vm.envAddress("WORKER");

        uint256 defFeeRaw = vm.envUint("DEFAULT_SETTLEMENT_FEE_BPS");
        uint256 maxSwRaw = vm.envUint("MAX_SWITCH_FEE_BPS");
        uint256 maxOutRaw = vm.envUint("MAX_OUTCOMES");
        uint256 delayRaw = vm.envUint("ORACLE_MAX_DELAY_SECONDS");
        uint256 confRaw = vm.envUint("ORACLE_MAX_CONFIDENCE_BPS");

        require(admin != address(0), "ADMIN=0");
        require(treasury != address(0), "TREASURY=0");
        require(worker != address(0), "WORKER=0");

        require(defFeeRaw <= 10_000, "DEFAULT_SETTLEMENT_FEE_BPS>10000");
        require(maxSwRaw <= 10_000, "MAX_SWITCH_FEE_BPS>10000");
        require(maxOutRaw <= 8, "MAX_OUTCOMES>8");
        require(delayRaw <= type(uint64).max, "ORACLE_MAX_DELAY_SECONDS overflow");
        require(confRaw <= 10_000, "ORACLE_MAX_CONFIDENCE_BPS>10000");

        // forge-lint: disable-next-line(unsafe-typecast) -- bounded by require(...) checks above
        uint64 delay = uint64(delayRaw);

        ChainlinkAdapter adapter = new ChainlinkAdapter(sequencerFeed);

        // Optional: deploy faucet + demo token for testnet UX.
        address stakeToken = vm.envOr("STAKE_TOKEN", address(0));
        uint256 deployFaucet = vm.envOr("DEPLOY_FAUCET", uint256(0));
        if (deployFaucet == 1) {
            string memory name = vm.envOr("FAUCET_TOKEN_NAME", string("Demo USD"));
            string memory symbol = vm.envOr("FAUCET_TOKEN_SYMBOL", string("dUSD"));
            uint64 cooldownSeconds = uint64(vm.envOr("FAUCET_COOLDOWN_SECONDS", uint256(3600)));
            uint256 maxMintAmount = vm.envOr("FAUCET_MAX_MINT_AMOUNT", uint256(1000e18));

            TokenFaucet.FaucetConfig memory cfg =
                TokenFaucet.FaucetConfig({cooldownSeconds: cooldownSeconds, maxMintAmount: maxMintAmount});
            TokenFaucet faucet = new TokenFaucet(name, symbol, cfg);
            stakeToken = address(faucet.token());

            console2.log("TokenFaucet", address(faucet));
            console2.log("Faucet token (STAKE_TOKEN)", stakeToken);
            console2.log("Faucet cooldownSeconds", cooldownSeconds);
            console2.log("Faucet maxMintAmount", maxMintAmount);
        }

        require(stakeToken != address(0), "STAKE_TOKEN=0 (set STAKE_TOKEN or DEPLOY_FAUCET=1)");

        // Optional smoke check: read a known testnet feed through the adapter.
        // This helps catch: wrong sequencer feed (L2), stale testnet feeds, grace period, etc.
        address smokeFeed = vm.envOr("SMOKE_FEED_ADDRESS", address(0));
        if (smokeFeed != address(0)) {
            uint64 smokeMaxAge = uint64(vm.envOr("SMOKE_MAX_AGE_SECONDS", uint256(delay)));
            bytes32 feedId = bytes32(uint256(uint160(smokeFeed)));
            (int256 priceE8, uint64 publishTime, uint256 confidenceE8) =
                adapter.getNormalizedPrice(feedId, smokeMaxAge, uint64(block.timestamp));
            // forge-lint: disable-next-line(unsafe-typecast) -- smoke check only; Chainlink prices are expected positive
            console2.log("Smoke priceE8", uint256(int256(priceE8)));
            console2.log("Smoke publishTime", publishTime);
            console2.log("Smoke confidenceE8", confidenceE8);
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
            delay: delay,
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
        _wireModules(
            dispatcher,
            adminModule,
            viewModule,
            userOpsClaimsModule,
            coreLifecycleModule,
            rollingLifecycleModule
        );

        _verifyAndLogDeployment(proxy, p);

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

    function _wireModules(
        MarketEngineDispatcher dispatcher,
        address adminModule,
        address viewModule,
        address userOpsClaimsModule,
        address coreLifecycleModule,
        address rollingLifecycleModule
    ) internal {
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
    }

    function _verifyAndLogDeployment(address proxy, DeployInitParams memory p) internal view {
        IMarketEngine engine = IMarketEngine(proxy);
        require(engine.configInitialized(), "configInitialized=false");
        require(address(engine.stakeToken()) == p.stakeToken, "stakeToken mismatch");
        require(address(engine.priceOracle()) == p.adapter, "priceOracle mismatch");
        require(engine.admin() == p.admin, "admin mismatch");
        require(engine.treasury() == p.treasury, "treasury mismatch");
        require(engine.workerAuthority() == p.worker, "worker mismatch");

        console2.log("ChainlinkAdapter", p.adapter);
        console2.log("MarketEngineDispatcher proxy", proxy);
        console2.log("MarketEngineDispatcher implementation", Upgrades.getImplementationAddress(proxy));
        console2.log("STAKE_TOKEN", p.stakeToken);
    }
}

