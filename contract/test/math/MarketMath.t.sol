// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MarketMath} from "../../src/math/MarketMath.sol";
import {MarketTypes as MT} from "../../src/types/MarketTypes.sol";

contract MarketMathHarness {
    function computeClaimLiabilityComponents(uint256 totalPool, uint256 winningPool, uint16 feeBps, bool feeOnLosingPool)
        external
        pure
        returns (uint256 claimLiabilityTotal, uint256 settlementFee, uint256 distributableLosingPool)
    {
        return MarketMath.computeClaimLiabilityComponents(totalPool, winningPool, feeBps, feeOnLosingPool);
    }
}

contract MarketMathTest is Test {
    MarketMathHarness internal harness;

    function setUp() public {
        harness = new MarketMathHarness();
    }

    function test_computeSwitch_withFee() public pure {
        (uint256 net, uint256 fee) = MarketMath.computeSwitch(10_000, 200);
        assertEq(fee, 200);
        assertEq(net, 9800);
    }

    function test_computeSwitch_noFee() public pure {
        (uint256 net, uint256 fee) = MarketMath.computeSwitch(1000, 0);
        assertEq(fee, 0);
        assertEq(net, 1000);
    }

    function test_switchFee_roundsUp() public pure {
        (uint256 net, uint256 fee) = MarketMath.computeSwitch(199, 1);
        assertEq(fee, 1);
        assertEq(net, 198);
    }

    function test_feeOnLosingPool() public pure {
        uint256 fee = MarketMath.computeSettlementFee(1000, 400, 500, true);
        assertEq(fee, 20);
    }

    function test_claimLiability_balancedBinary() public pure {
        (uint256 claims,,) = MarketMath.computeClaimLiabilityComponents(1000, 600, 500, true);
        assertEq(claims, 980);
    }

    function test_claimLiability_no_winners_refunds_full_pool() public pure {
        (uint256 claims, uint256 fee, uint256 distributableLosing) =
            MarketMath.computeClaimLiabilityComponents(1000, 0, 500, true);
        assertEq(claims, 1000);
        assertEq(fee, 0);
        assertEq(distributableLosing, 1000);
    }

    function test_finalWinnerSweepsRemainingDust() public pure {
        MT.Epoch memory epoch;
        epoch.status = MT.EpochStatus.Resolved;
        epoch.winningOutcomeMask = 1;
        epoch.totalPool = 10;
        epoch.outcomePools = [uint256(3), 7, 0, 0, 0, 0, 0, 0];
        epoch.outcomeCount = 2;
        epoch.settlementFeeBps = 0;
        epoch.feeOnLosingPool = true;
        epoch.remainingWinningStake = 1;

        uint256[8] memory stakes;
        stakes[0] = 1;

        (uint256 payout, uint256 ws) = MarketMath.computeClaimPayout(epoch, stakes, 4);
        assertEq(ws, 1);
        assertEq(payout, 4);
    }

    function test_splitSwitches_doNotAvoidFees() public pure {
        (, uint256 singleFee) = MarketMath.computeSwitch(19_900, 1);
        uint256 splitFee = 0;
        for (uint256 i = 0; i < 100; i++) {
            (, uint256 f) = MarketMath.computeSwitch(199, 1);
            splitFee += f;
        }
        assertGe(splitFee, singleFee);
    }

    function test_claimLiability_reverts_when_winning_pool_exceeds_total_pool() public {
        vm.expectRevert(MarketMath.MathOverflow.selector);
        harness.computeClaimLiabilityComponents(100, 101, 100, true);
    }

    function test_claimLiability_reverts_when_fee_exceeds_losing_pool() public {
        vm.expectRevert(MarketMath.MathOverflow.selector);
        harness.computeClaimLiabilityComponents(100, 99, 20_000, true);
    }
}
