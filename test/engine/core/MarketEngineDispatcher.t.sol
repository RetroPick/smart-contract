// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IMarketEngine} from "../../../src/engine/IMarketEngine.sol";
import {MarketEngineDispatcher} from "../../../src/engine/MarketEngineDispatcher.sol";
import {MarketTypes} from "../../../src/types/MarketTypes.sol";
import {MockERC20} from "../../../src/test/MockERC20.sol";
import {MockPriceOracle} from "../../../src/test/MockPriceOracle.sol";
import {MockDispatcherModule} from "../../../src/test/MockDispatcherModule.sol";
import {MockNonCompliantModule} from "../../../src/test/MockNonCompliantModule.sol";
import {MarketEngineState} from "../../../src/engine/MarketEngineState.sol";

contract MarketEngineDispatcherTest is Test {
    MockERC20 internal token;
    MockPriceOracle internal oracle;
    MockDispatcherModule internal module;
    MockNonCompliantModule internal nonCompliantModule;
    MarketEngineDispatcher internal engine;

    address internal admin = makeAddr("admin");
    address internal treasury = makeAddr("treasury");
    address internal worker = makeAddr("worker");

    function setUp() public {
        token = new MockERC20();
        oracle = new MockPriceOracle();
        module = new MockDispatcherModule();
        nonCompliantModule = new MockNonCompliantModule();

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

    function _registerMockModule() internal {
        vm.prank(admin);
        engine.registerModule(address(module), keccak256(address(module).code));
    }

    function test_AdminCanSetSelectorModuleAndDelegateCall() public {
        _registerMockModule();
        vm.prank(admin);
        engine.setSelectorModule(bytes4(keccak256("pauseProgram(bool)")), address(module), false);

        vm.prank(admin);
        (bool ok,) = address(engine).call(abi.encodeWithSignature("pauseProgram(bool)", true));
        assertTrue(ok);
        assertTrue(engine.globalPaused());
    }

    function test_RejectRootOwnedSelectorRegistration() public {
        _registerMockModule();
        vm.prank(admin);
        bytes4 initSelector = bytes4(
            keccak256("initialize((address,address,address,address,address,uint16,uint16,uint8,uint8,uint64,uint16))")
        );
        vm.expectRevert(abi.encodeWithSelector(MarketEngineState.SelectorImmutable.selector, initSelector));
        engine.setSelectorModule(initSelector, address(module), false);
    }

    function test_ImmutableSelectorCannotBeReplaced() public {
        _registerMockModule();
        bytes4 selector = bytes4(keccak256("setTreasury(address)"));
        vm.startPrank(admin);
        engine.setSelectorModule(selector, address(module), true);
        vm.expectRevert(abi.encodeWithSelector(MarketEngineState.SelectorImmutable.selector, selector));
        engine.setSelectorModule(selector, address(module), false);
        vm.stopPrank();
    }

    function test_setSelectorModule_reverts_for_unauthorized_and_invalid_module() public {
        bytes4 selector = bytes4(keccak256("setWorkerAuthority(address)"));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.setSelectorModule(selector, address(module), false);

        vm.prank(admin);
        vm.expectRevert(MarketEngineState.InvalidModule.selector);
        engine.setSelectorModule(selector, address(0), false);

        vm.prank(admin);
        vm.expectRevert(MarketEngineState.InvalidModule.selector);
        engine.setSelectorModule(selector, makeAddr("eoa"), false);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(MarketEngineState.UnapprovedModule.selector, address(module)));
        engine.setSelectorModule(selector, address(module), false);
    }

    function test_getSelectorModule_returns_set_values() public {
        _registerMockModule();
        bytes4 selector = bytes4(keccak256("pauseProgram(bool)"));
        vm.prank(admin);
        engine.setSelectorModule(selector, address(module), true);

        (address moduleAddr, bool immutableSelector) = engine.getSelectorModule(selector);
        assertEq(moduleAddr, address(module));
        assertTrue(immutableSelector);
    }

    function test_fallback_reverts_when_module_not_set() public {
        bytes4 selector = bytes4(keccak256("withdrawFees(bytes32,uint256)"));
        (bool ok, bytes memory ret) = address(engine).call(abi.encodeWithSelector(selector, bytes32("x"), 1));
        assertFalse(ok);
        bytes4 errSel;
        assembly {
            errSel := mload(add(ret, 0x20))
        }
        assertEq(errSel, MarketEngineState.ModuleNotSet.selector);
    }

    function test_registerModule_reverts_on_codehash_mismatch() public {
        bytes32 wrongHash = keccak256("wrong");
        bytes32 actualHash = keccak256(address(module).code);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketEngineState.ModuleCodeHashMismatch.selector, address(module), wrongHash, actualHash
            )
        );
        engine.registerModule(address(module), wrongHash);
    }

    function test_registerModule_reverts_for_storage_incompatible_module() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketEngineState.IncompatibleModuleStorage.selector, address(nonCompliantModule)
            )
        );
        engine.registerModule(address(nonCompliantModule), keccak256(address(nonCompliantModule).code));
    }

    function test_revokeModule_blocks_delegatecall_path() public {
        bytes4 selector = bytes4(keccak256("pauseProgram(bool)"));
        _registerMockModule();

        vm.prank(admin);
        engine.setSelectorModule(selector, address(module), false);

        vm.prank(admin);
        engine.revokeModule(address(module));

        vm.prank(admin);
        (bool ok, bytes memory ret) = address(engine).call(abi.encodeWithSignature("pauseProgram(bool)", true));
        assertFalse(ok);
        bytes4 errSel;
        assembly {
            errSel := mload(add(ret, 0x20))
        }
        assertEq(errSel, MarketEngineState.UnapprovedModule.selector);
    }
}
