// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldAccounting} from "../../src/libraries/YieldAccounting.sol";

contract YieldAccountingHarness {
    function callRayDiv(uint256 a, uint256 b) external pure returns (uint256) {
        return YieldAccounting.rayDiv(a, b);
    }
}

contract YieldAccountingTest is Test {
    using YieldAccounting for uint256;
    YieldAccountingHarness internal harness;

    function setUp() public {
        harness = new YieldAccountingHarness();
    }

    function test_scaledToReal_identity() public pure {
        assertEq(YieldAccounting.scaledToReal(1e6, 1e27), 1e6);
    }

    function test_scaledToReal_doubledIndex() public pure {
        assertEq(YieldAccounting.scaledToReal(1e6, 2e27), 2e6);
    }

    function test_proportionalUnderlying_half() public pure {
        uint256 u = YieldAccounting.proportionalUnderlying(1000e18, 1000e18, 500e18, 1e27);
        assertEq(u, 500e18);
    }

    function test_rayDiv_reverts_on_zero_divisor() public {
        vm.expectRevert(YieldAccounting.YieldAccountingDivZero.selector);
        harness.callRayDiv(1e18, 0);
    }

    function test_computeYield_with_fee() public pure {
        (uint256 grossValue, uint256 grossYield, uint256 netYield, uint256 fee) =
            YieldAccounting.computeYield(1000e18, 11e26, 1000e18, 1000);
        assertEq(grossValue, 1100e18);
        assertEq(grossYield, 100e18);
        assertEq(fee, 10e18);
        assertEq(netYield, 90e18);
    }

    function test_proportionalUnderlying_full_withdraw_returns_total_value() public pure {
        uint256 u = YieldAccounting.proportionalUnderlying(1000e18, 1000e18, 1000e18, 12e26);
        assertEq(u, 1200e18);
    }
}
