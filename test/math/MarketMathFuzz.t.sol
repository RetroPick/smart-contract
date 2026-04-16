// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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

    function testFuzz_computeClaimLiabilityComponents_conservesTotalPool(
        uint128 totalPool_,
        uint128 winningPool_,
        uint16 feeBps
    ) public pure {
        feeBps = uint16(bound(feeBps, 0, 10_000));
        uint256 totalPool = bound(uint256(totalPool_), 1, type(uint128).max);
        uint256 winningPool = bound(uint256(winningPool_), 0, totalPool);
        (uint256 claimLiab, uint256 settlementFee,) =
            MarketMath.computeClaimLiabilityComponents(totalPool, winningPool, feeBps, true);
        if (winningPool == 0) {
            assertEq(claimLiab, totalPool);
            assertEq(settlementFee, 0);
        } else {
            assertEq(claimLiab + settlementFee, totalPool);
        }
    }
}
