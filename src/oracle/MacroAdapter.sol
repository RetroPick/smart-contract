// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChainlinkAdapter} from "../adapters/ChainlinkAdapter.sol";

/// @notice Chainlink macro-data adapter for `OracleClass` routing.
/// @dev Uses the same interface and safety checks as the base Chainlink adapter.
contract MacroAdapter is ChainlinkAdapter {
    constructor(address sequencerFeed) ChainlinkAdapter(sequencerFeed) {}
}
