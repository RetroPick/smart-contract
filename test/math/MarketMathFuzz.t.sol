// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MarketMath} from "../../src/math/MarketMath.sol";

contract MarketMathFuzzTest is Test {
    function testFuzz_computeSwitch_feeLeGross(uint128 gross, uint16 bps) public pure {
        bps = uint16(bound(bps, 0, 10_000));
        gross = uint128(bound(gross, 1, type(uint128).max / 2));
        (uint256 net, uint256 fee) = MarketMath.computeSwitch(gross, bps);
        assertLe(fee, gross);
        assertEq(net + fee, gross);
    }
}
