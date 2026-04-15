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
import {TrustedReporterAdapter} from "../src/oracle/TrustedReporterAdapter.sol";
import {ScriptSelectorMatrix} from "./ScriptSelectorMatrix.sol";

/// @dev Local / CI: mock token + oracle + UUPS `MarketEngine` proxy with `initialize` (no `--ffi`).
contract DeployLocal is Script {
    event DeploymentCompleted(address indexed proxy, address indexed implementation);

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
        DeployInitParams memory p =
            DeployInitParams({stakeToken: address(token), priceOracle: address(oracle), admin: admin});
        IMarketEngine.InitConfig memory initConfig = _buildInitConfig(p);
        bytes memory initData = abi.encodeCall(MarketEngineDispatcher.initialize, (initConfig));
        address proxy = UnsafeUpgrades.deployUUPSProxy(address(impl), initData);
        MarketEngineDispatcher dispatcher = MarketEngineDispatcher(payable(proxy));
        _deployAndWireModules(dispatcher);

        TrustedReporterAdapter troAdapter = new TrustedReporterAdapter(admin, admin, 3600);
        _logDeployment(address(troAdapter), p.stakeToken, p.priceOracle, proxy, address(impl));
        emit DeploymentCompleted(proxy, address(impl));

        vm.stopBroadcast();
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

    function _logDeployment(address tro, address token, address oracle, address proxy, address implementation) internal view {
        console2.log("TrustedReporterAdapter", tro);
        console2.log("MockERC20", token);
        console2.log("MockPriceOracle", oracle);
        console2.log("MarketEngineDispatcher proxy", proxy);
        console2.log("MarketEngineDispatcher implementation", implementation);
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
