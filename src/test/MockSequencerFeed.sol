// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @dev Simulates Chainlink L2 sequencer uptime feed: answer 0 = up, 1 = down.
contract MockSequencerFeed is AggregatorV3Interface {
    int256 private _answer;
    uint256 private _startedAt;

    constructor() {
        _answer = 0;
        // `timeSinceUp = block.timestamp - _startedAt` must exceed adapter grace; use a fixed past
        // timestamp when tests run with `vm.warp` ≥ ~2h (see ChainlinkAdapter.t.sol).
        _startedAt = 1;
    }

    function decimals() external pure override returns (uint8) {
        return 0;
    }

    function description() external pure override returns (string memory) {
        return "SEQ";
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
        return (1, _answer, _startedAt, _startedAt, 1);
    }

    function getRoundData(uint80) external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (1, _answer, _startedAt, _startedAt, 1);
    }

    function setDown() external {
        _answer = 1;
        _startedAt = block.timestamp;
    }

    function setUpStable() external {
        _answer = 0;
        _startedAt = block.timestamp - 7200;
    }

    /// @notice Sequencer up but still inside grace window (relative to `block.timestamp`).
    function setRecoveringInGracePeriod() external {
        _answer = 0;
        _startedAt = block.timestamp - 30;
    }

    /// @notice Malformed round: reports up (`answer == 0`) but `startedAt == 0` (adapter must revert).
    function setUpWithZeroStartedAt() external {
        _answer = 0;
        _startedAt = 0;
    }
}
