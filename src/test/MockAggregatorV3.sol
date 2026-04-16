// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @dev Test double for Chainlink price feeds (`AggregatorV3Interface`).
contract MockAggregatorV3 is AggregatorV3Interface {
    uint8 private _decimals;
    int256 private _answer;
    uint256 private _updatedAt;
    uint80 private _roundId;
    uint80 private _answeredInRound;
    bool private _shouldRevert;
    string private _revertMsg;

    constructor(uint8 decimals_, int256 initialAnswer) {
        _decimals = decimals_;
        _answer = initialAnswer;
        _updatedAt = block.timestamp;
        _roundId = 1;
        _answeredInRound = 1;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "MOCK";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (_shouldRevert) revert(_revertMsg);
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }

    function getRoundData(uint80 rid) external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (rid, _answer, _updatedAt, _updatedAt, rid);
    }

    function setAnswer(int256 answer_) external {
        _answer = answer_;
    }

    function setUpdatedAt(uint256 ts) external {
        _updatedAt = ts;
    }

    function setRoundData(uint80 roundId_, uint80 answeredInRound_) external {
        _roundId = roundId_;
        _answeredInRound = answeredInRound_;
    }

    /// @notice Simulate staleness: `updatedAt` far in the past.
    function makeStale(uint256 secondsAgo) external {
        _updatedAt = block.timestamp - secondsAgo;
    }

    /// @notice `answeredInRound < roundId` (incomplete / carried answer).
    function makeIncompleteRound() external {
        _roundId = 2;
        _answeredInRound = 1;
    }

    function setShouldRevert(bool v, string calldata msg_) external {
        _shouldRevert = v;
        _revertMsg = msg_;
    }
}
