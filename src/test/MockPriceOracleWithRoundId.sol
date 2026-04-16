// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPriceOracleWithRoundId} from "../interfaces/IPriceOracleWithRoundId.sol";

contract MockPriceOracleWithRoundId is IPriceOracle, IPriceOracleWithRoundId {
    struct Data {
        uint80 roundId;
        int256 priceE8;
        uint64 publishTime;
        uint256 confidenceE8;
    }

    mapping(bytes32 => Data) public feeds;

    function set(bytes32 feedId, uint80 roundId, int256 priceE8, uint64 publishTime, uint256 confidenceE8) external {
        feeds[feedId] = Data({roundId: roundId, priceE8: priceE8, publishTime: publishTime, confidenceE8: confidenceE8});
    }

    function getNormalizedPrice(bytes32 feedId, uint64, uint64)
        external
        view
        override
        returns (int256, uint64, uint256)
    {
        Data memory d = feeds[feedId];
        return (d.priceE8, d.publishTime, d.confidenceE8);
    }

    function getNormalizedPriceWithRoundId(bytes32 feedId, uint64, uint64)
        external
        view
        override
        returns (uint80, int256, uint64, uint256)
    {
        Data memory d = feeds[feedId];
        return (d.roundId, d.priceE8, d.publishTime, d.confidenceE8);
    }
}

