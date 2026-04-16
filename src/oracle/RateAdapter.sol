// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChainlinkAdapter} from "../adapters/ChainlinkAdapter.sol";

/// @notice Chainlink rate-feed adapter for per-template `OracleClass` routing.
/// @dev Uses the same normalization + sequencer safety model as `ChainlinkAdapter`.
contract RateAdapter is ChainlinkAdapter {
    constructor(address sequencerFeed) ChainlinkAdapter(sequencerFeed) {}
}
