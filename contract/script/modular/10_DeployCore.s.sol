// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";

contract DeployCoreModular is Script {
    function run() external {
        IERC20 stakeToken = IERC20(vm.envAddress("STAKE_TOKEN"));
        IPriceOracle priceOracle = IPriceOracle(vm.envAddress("PRICE_ORACLE"));
        address admin = vm.envAddress("ADMIN");
        address treasury = vm.envAddress("TREASURY");
        address worker = vm.envAddress("WORKER_AUTHORITY");

        vm.startBroadcast();
        address proxy = Upgrades.deployUUPSProxy(
            "engine/MarketEngineDispatcher.sol:MarketEngineDispatcher",
            abi.encodeCall(
                MarketEngineDispatcher.initialize,
                (IMarketEngine.InitConfig({
                    stakeToken: stakeToken,
                    priceOracle: priceOracle,
                    admin: admin,
                    treasury: treasury,
                    worker: worker,
                    defaultSettlementFeeBps: uint16(vm.envUint("DEFAULT_SETTLEMENT_FEE_BPS")),
                    maxSwitchFeeBps: uint16(vm.envUint("MAX_SWITCH_FEE_BPS")),
                    maxOutcomes: uint8(vm.envUint("MAX_OUTCOMES")),
                    oracleKind: MarketTypes.OracleKind.Chainlink,
                    oracleMaxDelaySeconds: uint64(vm.envUint("ORACLE_MAX_DELAY_SECONDS")),
                    oracleMaxConfidenceBps: uint16(vm.envUint("ORACLE_MAX_CONFIDENCE_BPS"))
                }))
            )
        );
        vm.stopBroadcast();

        console2.log("MarketEngineDispatcher proxy", proxy);
        console2.log("Implementation", Upgrades.getImplementationAddress(proxy));
    }
}
