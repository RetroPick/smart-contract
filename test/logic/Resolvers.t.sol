// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Resolvers} from "../../src/logic/Resolvers.sol";
import {MarketTypes} from "../../src/types/MarketTypes.sol";

contract ResolversTest is Test {
    function test_direction_yes() public pure {
        MarketTypes.OracleCheckpoint memory a =
            MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory b =
            MarketTypes.OracleCheckpoint({valueE8: 110, publishTime: 0, confidenceE8: 0, written: true});
        (bool v, uint256 m) = Resolvers.resolveDirection(a, b, true);
        assertFalse(v);
        assertEq(m, 1);
    }

    function test_direction_equal_void() public pure {
        MarketTypes.OracleCheckpoint memory a =
            MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory b =
            MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        (bool v, uint256 m) = Resolvers.resolveDirection(a, b, true);
        assertTrue(v);
        assertEq(m, 0);
    }

    function test_threshold_atOrAbove() public pure {
        MarketTypes.OracleCheckpoint memory b =
            MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        uint256 m = Resolvers.resolveThreshold(MarketTypes.Condition.AtOrAbove, 100, b);
        assertEq(m, 1);
    }

    function test_range_buckets() public pure {
        MarketTypes.OracleCheckpoint memory b =
            MarketTypes.OracleCheckpoint({valueE8: 150, publishTime: 0, confidenceE8: 0, written: true});
        int256[7] memory bounds;
        bounds[0] = 100;
        bounds[1] = 200;
        uint256 m = Resolvers.resolveRangeClose(b, 3, bounds);
        assertEq(m, 2);
    }

    function test_anchor_matches_threshold_semantics() public pure {
        MarketTypes.OracleCheckpoint memory b =
            MarketTypes.OracleCheckpoint({valueE8: 99, publishTime: 0, confidenceE8: 0, written: true});
        uint256 m = Resolvers.resolveAnchor(MarketTypes.Condition.AtOrAbove, 100, b);
        assertEq(m, 1 << 1);
    }

    function test_velocity_buckets_by_bps_move() public pure {
        MarketTypes.OracleCheckpoint memory a =
            MarketTypes.OracleCheckpoint({valueE8: 100_000_000, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory b =
            MarketTypes.OracleCheckpoint({valueE8: 101_000_000, publishTime: 0, confidenceE8: 0, written: true});
        uint32[7] memory vb;
        vb[0] = 50;
        vb[1] = 200;
        uint256 m = Resolvers.resolveVelocity(a, b, 3, vb);
        assertEq(m, 1 << 1);
    }

    /// @dev External hop so `vm.expectRevert` observes the library revert boundary.
    function _velocityTinyBaseExt() external pure {
        MarketTypes.OracleCheckpoint memory a =
            MarketTypes.OracleCheckpoint({valueE8: 500, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory b =
            MarketTypes.OracleCheckpoint({valueE8: 600, publishTime: 0, confidenceE8: 0, written: true});
        uint32[7] memory vb;
        Resolvers.resolveVelocity(a, b, 3, vb);
    }

    function test_RevertWhen_velocity_base_too_small() public {
        vm.expectRevert(Resolvers.InvalidEpochState.selector);
        this._velocityTinyBaseExt();
    }

    function test_ladder_same_as_range_on_bounds() public pure {
        MarketTypes.OracleCheckpoint memory cp =
            MarketTypes.OracleCheckpoint({valueE8: 150, publishTime: 0, confidenceE8: 0, written: true});
        int256[7] memory bounds;
        bounds[0] = 100;
        bounds[1] = 200;
        assertEq(Resolvers.resolveLadder(cp, 3, bounds), Resolvers.resolveRangeClose(cp, 3, bounds));
    }

    function test_convergence_narrows_spread_yes() public pure {
        MarketTypes.OracleCheckpoint memory a1 =
            MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory a2 =
            MarketTypes.OracleCheckpoint({valueE8: 110, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory b1 =
            MarketTypes.OracleCheckpoint({valueE8: 105, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory b2 =
            MarketTypes.OracleCheckpoint({valueE8: 106, publishTime: 0, confidenceE8: 0, written: true});
        (bool voided, uint256 m) = Resolvers.resolveConvergence(a1, a2, b1, b2, 0);
        assertFalse(voided);
        assertEq(m, 1);
    }

    function test_convergence_void_in_band() public pure {
        MarketTypes.OracleCheckpoint memory a1 =
            MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory a2 =
            MarketTypes.OracleCheckpoint({valueE8: 110, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory b1 =
            MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        MarketTypes.OracleCheckpoint memory b2 =
            MarketTypes.OracleCheckpoint({valueE8: 110, publishTime: 0, confidenceE8: 0, written: true});
        (bool voided, uint256 m) = Resolvers.resolveConvergence(a1, a2, b1, b2, 0);
        assertTrue(voided);
        assertEq(m, 0);
    }

    function test_composite_and_requires_all() public pure {
        MarketTypes.Condition[4] memory cond;
        cond[0] = MarketTypes.Condition.AtOrAbove;
        cond[1] = MarketTypes.Condition.AtOrAbove;
        int256[4] memory th;
        th[0] = 100;
        th[1] = 100;
        MarketTypes.OracleCheckpoint[4] memory cps;
        cps[0] = MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        cps[1] = MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        uint256 m = Resolvers.resolveComposite(MarketTypes.CompositeLogic.And, 2, cond, th, cps);
        assertEq(m, 1);
    }

    function test_composite_majority() public pure {
        MarketTypes.Condition[4] memory cond;
        int256[4] memory th;
        MarketTypes.OracleCheckpoint[4] memory cps;
        for (uint256 i = 0; i < 3; i++) {
            cond[i] = MarketTypes.Condition.AtOrAbove;
            th[i] = 100;
            int256 v = i < 2 ? int256(100) : int256(99);
            cps[i] = MarketTypes.OracleCheckpoint({valueE8: v, publishTime: 0, confidenceE8: 0, written: true});
        }
        uint256 m = Resolvers.resolveComposite(MarketTypes.CompositeLogic.Majority, 3, cond, th, cps);
        assertEq(m, 1);
    }

    function test_composite_majority_two_feeds_one_pass_is_yes() public pure {
        MarketTypes.Condition[4] memory cond;
        cond[0] = MarketTypes.Condition.AtOrAbove;
        cond[1] = MarketTypes.Condition.AtOrAbove;
        int256[4] memory th;
        th[0] = 100;
        th[1] = 100;
        MarketTypes.OracleCheckpoint[4] memory cps;
        cps[0] = MarketTypes.OracleCheckpoint({valueE8: 100, publishTime: 0, confidenceE8: 0, written: true});
        cps[1] = MarketTypes.OracleCheckpoint({valueE8: 99, publishTime: 0, confidenceE8: 0, written: true});
        uint256 m = Resolvers.resolveComposite(MarketTypes.CompositeLogic.Majority, 2, cond, th, cps);
        assertEq(m, 1);
    }

    function test_corridor_inside_and_break_high() public pure {
        assertEq(Resolvers.resolveCorridor(105, 95, 110, 90), 1);
        assertEq(Resolvers.resolveCorridor(115, 95, 110, 90), 1 << 1);
        assertEq(Resolvers.resolveCorridor(105, 85, 110, 90), 1 << 2);
    }

    function test_cascade_downward_levels() public pure {
        int256[7] memory bounds;
        bounds[0] = 95;
        bounds[1] = 90;
        uint256 m = Resolvers.resolveCascade(100, 88, 3, bounds, true);
        assertEq(m, 1 << 2);
    }
}
