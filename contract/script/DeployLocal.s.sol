// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MarketEngineDispatcher} from "../src/engine/MarketEngineDispatcher.sol";
import {MarketEngineAdminModule} from "../src/engine/modules/MarketEngineAdminModule.sol";
import {MarketEngineViewModule} from "../src/engine/modules/MarketEngineViewModule.sol";
import {MarketEngineUserOpsClaimsModule} from "../src/engine/modules/MarketEngineUserOpsClaimsModule.sol";
import {MarketEngineCoreLifecycleModule} from "../src/engine/modules/MarketEngineCoreLifecycleModule.sol";
import {MarketEngineRollingLifecycleModule} from "../src/engine/modules/MarketEngineRollingLifecycleModule.sol";
import {IMarketEngine} from "../src/engine/IMarketEngine.sol";
import {MockERC20} from "../src/test/MockERC20.sol";
import {MockPriceOracle} from "../src/test/MockPriceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";

/// @dev Local / CI: mock token + oracle + UUPS `MarketEngine` proxy with `initialize` (no `--ffi`).
contract DeployLocal is Script {
    struct DeployInitParams {
        address stakeToken;
        address priceOracle;
        address admin;
    }

    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        vm.startBroadcast(pk);

        MockERC20 token = new MockERC20();
        MockPriceOracle oracle = new MockPriceOracle();
        MarketEngineDispatcher impl = new MarketEngineDispatcher();

        address admin = vm.addr(pk);
        DeployInitParams memory p = DeployInitParams({stakeToken: address(token), priceOracle: address(oracle), admin: admin});
        IMarketEngine.InitConfig memory initConfig = _buildInitConfig(p);
        bytes memory initData = abi.encodeCall(MarketEngineDispatcher.initialize, (initConfig));
        address proxy = UnsafeUpgrades.deployUUPSProxy(address(impl), initData);
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

        console2.log("MockERC20", address(token));
        console2.log("MockPriceOracle", address(oracle));
        console2.log("MarketEngineDispatcher proxy", proxy);
        console2.log("MarketEngineDispatcher implementation", address(impl));

        vm.stopBroadcast();
    }

    function _buildInitConfig(DeployInitParams memory p) internal pure returns (IMarketEngine.InitConfig memory cfg) {
        cfg = IMarketEngine.InitConfig({
            stakeToken: IERC20(p.stakeToken),
            priceOracle: IPriceOracle(p.priceOracle),
            admin: p.admin,
            treasury: p.admin,
            worker: p.admin,
            defaultSettlementFeeBps: 100,
            maxSwitchFeeBps: 500,
            maxOutcomes: 8,
            oracleKind: MarketTypes.OracleKind.Chainlink,
            oracleMaxDelaySeconds: 3600,
            oracleMaxConfidenceBps: 10_000
        });
    }
}
