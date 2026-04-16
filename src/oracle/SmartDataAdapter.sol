// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChainlinkAdapter} from "../adapters/ChainlinkAdapter.sol";

/// @notice Chainlink SmartData-feed adapter for `OracleClass` routing.
/// @dev Keeps sequencing/freshness semantics consistent with existing adapter behavior.
contract SmartDataAdapter is ChainlinkAdapter {
    constructor(address sequencerFeed) ChainlinkAdapter(sequencerFeed) {}
}
