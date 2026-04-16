// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MarketEngineState} from "../engine/MarketEngineState.sol";
import {MarketTypes} from "../types/MarketTypes.sol";

contract MockDispatcherModule is MarketEngineState {
    function pauseProgram(bool paused) external {
        globalPaused = paused;
    }

    function setTreasury(address nextTreasury) external {
        treasury = nextTreasury;
    }

    function getVaultBalances(bytes32 templateId) external view returns (uint256 active, uint256 claims, uint256 fees) {
        MarketTypes.VaultBalances storage v = _vaults[templateId];
        return (v.active, v.claims, v.fees);
    }
}
