// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle {
    struct Data {
        int256 priceE8;
        uint64 publishTime;
        uint256 confidenceE8;
    }

    mapping(bytes32 => Data) public feeds;

    function set(bytes32 feedId, int256 priceE8, uint64 publishTime, uint256 confidenceE8) external {
        feeds[feedId] = Data({priceE8: priceE8, publishTime: publishTime, confidenceE8: confidenceE8});
    }

    /// @inheritdoc IPriceOracle
    function getNormalizedPrice(bytes32 feedId, uint64, uint64)
        external
        view
        override
        returns (int256, uint64, uint256)
    {
        Data memory d = feeds[feedId];
        return (d.priceE8, d.publishTime, d.confidenceE8);
    }
}
