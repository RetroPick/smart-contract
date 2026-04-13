// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";

contract WireModulesModular is Script {
    function run() external {
        address payable proxy = payable(vm.envAddress("ENGINE_PROXY"));
        address adminModule = vm.envAddress("MODULE_ADMIN");
        address viewModule = vm.envAddress("MODULE_VIEW");
        address userOpsClaimsModule = vm.envAddress("MODULE_USEROPS_CLAIMS");
        address coreLifecycleModule = vm.envAddress("MODULE_CORE_LIFECYCLE");
        address rollingLifecycleModule = vm.envAddress("MODULE_ROLLING_LIFECYCLE");

        vm.startBroadcast();
        MarketEngineDispatcher engine = MarketEngineDispatcher(proxy);
        // Admin / config selectors
        engine.setSelectorModule(bytes4(keccak256("pauseProgram(bool)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("setTreasury(address)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("setWorkerAuthority(address)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("setDepositExecutor(address,bool)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("setYieldRouter(address,uint16)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("setLmRewardsEnabled(bool)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("keeperClaimLmRewards(bytes32)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("yieldEmergencyWithdraw(bytes32)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("initializeMarket(bytes32)")), adminModule, false);
        engine.setSelectorModule(bytes4(keccak256("withdrawFees(bytes32,uint256)")), adminModule, false);

        // View selectors
        engine.setSelectorModule(bytes4(keccak256("getUserEpochs(bytes32,address,uint256,uint256)")), viewModule, false);
        engine.setSelectorModule(bytes4(keccak256("getVaultBalances(bytes32)")), viewModule, false);
        engine.setSelectorModule(bytes4(keccak256("getRollingLifecycle(bytes32)")), viewModule, false);
        engine.setSelectorModule(bytes4(keccak256("getEpoch(bytes32,uint64)")), viewModule, false);

        // User operations + claims selectors
        engine.setSelectorModule(bytes4(keccak256("depositToSide(bytes32,uint64,uint8,uint256)")), userOpsClaimsModule, false);
        engine.setSelectorModule(
            bytes4(keccak256("depositToSideFor(address,bytes32,uint64,uint8,uint256)")), userOpsClaimsModule, false
        );
        engine.setSelectorModule(
            bytes4(keccak256("switchSide(bytes32,uint64,uint8,uint8,uint256)")), userOpsClaimsModule, false
        );
        engine.setSelectorModule(bytes4(keccak256("claim(bytes32,uint64)")), userOpsClaimsModule, false);
        engine.setSelectorModule(bytes4(keccak256("claimMany(bytes32,uint64[])")), userOpsClaimsModule, false);

        // Core lifecycle selectors
        engine.setSelectorModule(
            bytes4(
                keccak256(
                    "upsertTemplate((string,string,bytes32,uint8,uint8,uint8,bool,uint8,int256,int256[7],uint16,uint16,bool,uint8,uint64,uint64,uint64,uint16))"
                )
            ),
            coreLifecycleModule,
            false
        );
        engine.setSelectorModule(
            bytes4(keccak256("openEpoch(bytes32,uint64,uint64,uint64,uint64)")), coreLifecycleModule, false
        );
        engine.setSelectorModule(
            bytes4(keccak256("openEpochsBatch(bytes32[],uint64[],uint64[],uint64[],uint64[])")),
            coreLifecycleModule,
            false
        );
        engine.setSelectorModule(bytes4(keccak256("lockEpoch(bytes32,uint64)")), coreLifecycleModule, false);
        engine.setSelectorModule(
            bytes4(keccak256("lockEpochsBatch(bytes32[],uint64[])")), coreLifecycleModule, false
        );
        engine.setSelectorModule(bytes4(keccak256("resolveEpoch(bytes32,uint64)")), coreLifecycleModule, false);
        engine.setSelectorModule(
            bytes4(keccak256("resolveEpochsBatch(bytes32[],uint64[])")), coreLifecycleModule, false
        );
        engine.setSelectorModule(
            bytes4(keccak256("cancelEpoch(bytes32,uint64,uint8,bool)")), coreLifecycleModule, false
        );

        // Rolling lifecycle selectors
        engine.setSelectorModule(bytes4(keccak256("genesisStartRolling(bytes32)")), rollingLifecycleModule, false);
        engine.setSelectorModule(bytes4(keccak256("genesisLockRolling(bytes32)")), rollingLifecycleModule, false);
        engine.setSelectorModule(bytes4(keccak256("executeRollingRound(bytes32)")), rollingLifecycleModule, false);
        engine.setSelectorModule(bytes4(keccak256("executeRollingRoundBatch(bytes32[])")), rollingLifecycleModule, false);
        engine.setSelectorModule(bytes4(keccak256("haltRollingMarket(bytes32)")), rollingLifecycleModule, false);
        engine.setSelectorModule(
            bytes4(keccak256("cancelRollingEpochWhileHalted(bytes32,uint64,uint8,bool)")), rollingLifecycleModule, false
        );
        engine.setSelectorModule(
            bytes4(keccak256("resetRollingLifecycle(bytes32,uint64)")), rollingLifecycleModule, false
        );
        vm.stopBroadcast();
    }
}
