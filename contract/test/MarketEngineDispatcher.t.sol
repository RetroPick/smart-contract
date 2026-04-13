// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IMarketEngine} from "../src/engine/IMarketEngine.sol";
import {MarketEngineDispatcher} from "../src/engine/MarketEngineDispatcher.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";
import {MockERC20} from "../src/test/MockERC20.sol";
import {MockPriceOracle} from "../src/test/MockPriceOracle.sol";
import {MockDispatcherModule} from "../src/test/MockDispatcherModule.sol";
import {MarketEngineState} from "../src/engine/MarketEngineState.sol";

contract MarketEngineDispatcherTest is Test {
    MockERC20 internal token;
    MockPriceOracle internal oracle;
    MockDispatcherModule internal module;
    MarketEngineDispatcher internal engine;

    address internal admin = makeAddr("admin");
    address internal treasury = makeAddr("treasury");
    address internal worker = makeAddr("worker");

    function setUp() public {
        token = new MockERC20();
        oracle = new MockPriceOracle();
        module = new MockDispatcherModule();

        MarketEngineDispatcher impl = new MarketEngineDispatcher();
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            address(impl),
            abi.encodeCall(
                MarketEngineDispatcher.initialize,
                (IMarketEngine.InitConfig({
                    stakeToken: token,
                    priceOracle: oracle,
                    admin: admin,
                    treasury: treasury,
                    worker: worker,
                    defaultSettlementFeeBps: 50,
                    maxSwitchFeeBps: 200,
                    maxOutcomes: 8,
                    oracleKind: MarketTypes.OracleKind.Chainlink,
                    oracleMaxDelaySeconds: 600,
                    oracleMaxConfidenceBps: 0
                }))
            )
        );
        engine = MarketEngineDispatcher(payable(proxy));
    }

    function test_AdminCanSetSelectorModuleAndDelegateCall() public {
        vm.prank(admin);
        engine.setSelectorModule(bytes4(keccak256("pauseProgram(bool)")), address(module), false);

        vm.prank(admin);
        (bool ok,) = address(engine).call(abi.encodeWithSignature("pauseProgram(bool)", true));
        assertTrue(ok);
        assertTrue(engine.globalPaused());
    }

    function test_RejectRootOwnedSelectorRegistration() public {
        vm.prank(admin);
        bytes4 initSelector = bytes4(
            keccak256("initialize((address,address,address,address,address,uint16,uint16,uint8,uint8,uint64,uint16))")
        );
        vm.expectRevert(abi.encodeWithSelector(MarketEngineState.SelectorImmutable.selector, initSelector));
        engine.setSelectorModule(initSelector, address(module), false);
    }

    function test_ImmutableSelectorCannotBeReplaced() public {
        bytes4 selector = bytes4(keccak256("setTreasury(address)"));
        vm.startPrank(admin);
        engine.setSelectorModule(selector, address(module), true);
        vm.expectRevert(abi.encodeWithSelector(MarketEngineState.SelectorImmutable.selector, selector));
        engine.setSelectorModule(selector, address(module), false);
        vm.stopPrank();
    }
}
