// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineBase} from "../../MarketEngineBase.t.sol";
import {IMarketEngine as MarketEngine} from "../../../src/engine/IMarketEngine.sol";

contract MarketEngineDepositForTest is MarketEngineBase {
    address internal beneficiary = address(0xBEEF);

    function test_revert_depositToSideFor_not_executor() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_defaultTemplate("df"));
        bytes32 tid = _tid("df");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 10_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 10, t0 + 20, t0 + 30);
        vm.warp(t0 + 15);

        token.mint(address(this), 1000e18);
        token.approve(address(engine), type(uint256).max);

        vm.expectRevert(bytes4(keccak256("NotDepositExecutor()")));
        engine.depositToSideFor(beneficiary, tid, 1, 0, 100e18);
    }

    function test_revert_depositToSideFor_zero_beneficiary() public {
        vm.startPrank(admin);
        engine.setDepositExecutor(address(this), true);
        engine.upsertTemplate(_defaultTemplate("dfz"));
        bytes32 tid = _tid("dfz");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 10_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 10, t0 + 20, t0 + 30);
        vm.warp(t0 + 15);

        token.mint(address(this), 1000e18);
        token.approve(address(engine), type(uint256).max);

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.depositToSideFor(address(0), tid, 1, 0, 100e18);
    }

    function test_depositToSideFor_credits_beneficiary() public {
        vm.startPrank(admin);
        engine.setDepositExecutor(address(this), true);
        engine.upsertTemplate(_defaultTemplate("dfb"));
        bytes32 tid = _tid("dfb");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 20_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.openEpoch(tid, 1, t0 + 10, t0 + 20, t0 + 30);
        vm.warp(t0 + 15);

        uint256 amt = 500e18;
        token.mint(address(this), amt);
        token.approve(address(engine), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit MarketEngine.PositionDeposited(tid, 1, beneficiary, 0, amt);
        engine.depositToSideFor(beneficiary, tid, 1, 0, amt);
    }

    function test_setDepositExecutor_only_admin() public {
        vm.prank(address(0x1234));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        engine.setDepositExecutor(address(0xABC), true);
    }
}
