// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Resolvers} from "../src/logic/Resolvers.sol";
import {MarketTypes} from "../src/types/MarketTypes.sol";

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
}
