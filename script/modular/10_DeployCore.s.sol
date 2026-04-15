// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {MarketEngineDispatcher} from "../../src/engine/MarketEngineDispatcher.sol";
import {IMarketEngine} from "../../src/engine/IMarketEngine.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";

contract DeployCoreModular is Script {
    event CoreDeployed(address indexed proxy, address indexed implementation);

    function run() external {
        uint256 expectedChainId = vm.envUint("EXPECTED_CHAIN_ID");
        require(expectedChainId != 0, "EXPECTED_CHAIN_ID=0");
        require(block.chainid == expectedChainId, "wrong chain");

        IERC20 stakeToken = IERC20(vm.envAddress("STAKE_TOKEN"));
        IPriceOracle priceOracle = IPriceOracle(vm.envAddress("PRICE_ORACLE"));
        address admin = vm.envAddress("ADMIN");
        address treasury = vm.envAddress("TREASURY");
        address worker = vm.envOr("WORKER_AUTHORITY", vm.envOr("WORKER", address(0)));
        uint256 defFeeRaw = vm.envUint("DEFAULT_SETTLEMENT_FEE_BPS");
        uint256 maxSwitchRaw = vm.envUint("MAX_SWITCH_FEE_BPS");
        uint256 maxOutcomesRaw = vm.envUint("MAX_OUTCOMES");
        uint256 maxDelayRaw = vm.envUint("ORACLE_MAX_DELAY_SECONDS");
        uint256 maxConfidenceRaw = vm.envUint("ORACLE_MAX_CONFIDENCE_BPS");

        require(address(stakeToken) != address(0), "STAKE_TOKEN=0");
        require(address(priceOracle) != address(0), "PRICE_ORACLE=0");
        require(admin != address(0), "ADMIN=0");
        require(treasury != address(0), "TREASURY=0");
        require(worker != address(0), "WORKER_AUTHORITY=0");
        require(defFeeRaw <= 10_000, "DEFAULT_SETTLEMENT_FEE_BPS>10000");
        require(maxSwitchRaw <= 10_000, "MAX_SWITCH_FEE_BPS>10000");
        require(maxOutcomesRaw <= 8, "MAX_OUTCOMES>8");
        require(maxDelayRaw <= type(uint64).max, "ORACLE_MAX_DELAY_SECONDS overflow");
        require(maxConfidenceRaw <= 10_000, "ORACLE_MAX_CONFIDENCE_BPS>10000");

        vm.startBroadcast();
        Options memory opts;
        opts.unsafeSkipAllChecks = vm.envOr("OZ_UNSAFE_SKIP_ALL_CHECKS", false);
        address proxy = Upgrades.deployUUPSProxy(
            "MarketEngineDispatcher.sol:MarketEngineDispatcher",
            abi.encodeCall(
                MarketEngineDispatcher.initialize,
                (IMarketEngine.InitConfig({
                        stakeToken: stakeToken,
                        priceOracle: priceOracle,
                        admin: admin,
                        treasury: treasury,
                        worker: worker,
                        // forge-lint: disable-next-line(unsafe-typecast)
                        defaultSettlementFeeBps: uint16(defFeeRaw),
                        // forge-lint: disable-next-line(unsafe-typecast)
                        maxSwitchFeeBps: uint16(maxSwitchRaw),
                        // forge-lint: disable-next-line(unsafe-typecast)
                        maxOutcomes: uint8(maxOutcomesRaw),
                        oracleKind: MarketTypes.OracleKind.Chainlink,
                        // forge-lint: disable-next-line(unsafe-typecast)
                        oracleMaxDelaySeconds: uint64(maxDelayRaw),
                        // forge-lint: disable-next-line(unsafe-typecast)
                        oracleMaxConfidenceBps: uint16(maxConfidenceRaw)
                    }))
            ),
            opts
        );
        vm.stopBroadcast();

        console2.log("MarketEngineDispatcher proxy", proxy);
        address implementation = Upgrades.getImplementationAddress(proxy);
        console2.log("Implementation", implementation);
        emit CoreDeployed(proxy, implementation);
    }
}
