// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {MarketEngineState} from "../MarketEngineState.sol";
import {MarketTypes} from "../../types/MarketTypes.sol";

/// @notice Read-only module for dispatcher-routed views.
contract MarketEngineViewModule is MarketEngineState {
    function getUserEpochs(bytes32 templateId, address user, uint256 cursor, uint256 size)
        external
        view
        returns (uint64[] memory epochIds, uint256 nextCursor)
    {
        uint64[] storage src = _userEpochs[templateId][user];
        uint256 n = src.length;
        if (cursor >= n) return (new uint64[](0), cursor);
        uint256 end = cursor + size;
        if (end > n) end = n;
        uint256 outLen = end - cursor;
        epochIds = new uint64[](outLen);
        for (uint256 i = 0; i < outLen; i++) {
            epochIds[i] = src[cursor + i];
        }
        nextCursor = end;
    }

    function getVaultBalances(bytes32 templateId) external view returns (uint256 active, uint256 claims, uint256 fees) {
        MarketTypes.VaultBalances storage v = _vaults[templateId];
        return (v.active, v.claims, v.fees);
    }

    function getRollingLifecycle(bytes32 templateId)
        external
        view
        returns (
            MarketTypes.RollingPhase phase,
            MarketTypes.RollingHaltReason haltReason,
            uint64 haltedAtEpochId,
            uint64 rollingNextEpochId,
            uint64 activeEpochId,
            uint64 lastResolvedEpochId
        )
    {
        MarketTypes.Ledger storage ledger = _ledgers[templateId];
        return (
            ledger.rollingPhase,
            ledger.rollingHaltReason,
            ledger.haltedAtEpochId,
            ledger.rollingNextEpochId,
            ledger.activeEpochId,
            ledger.lastResolvedEpochId
        );
    }

    function getEpoch(bytes32 templateId, uint64 epochId) external view returns (MarketTypes.Epoch memory) {
        return _epochs[templateId][epochId];
    }
}
