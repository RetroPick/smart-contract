// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChainlinkAdapter} from "../adapters/ChainlinkAdapter.sol";

/// @notice Chainlink equity-feed adapter for `OracleClass` routing.
/// @dev Mirrors existing `ChainlinkAdapter` behaviour for normalized reads.
contract EquityAdapter is ChainlinkAdapter {
    constructor(address sequencerFeed) ChainlinkAdapter(sequencerFeed) {}
}
