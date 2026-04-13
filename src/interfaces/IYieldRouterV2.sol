// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IYieldRouter} from "./IYieldRouter.sol";

/// @title IYieldRouterV2
/// @notice Yield router with scaled aToken accounting, optional ERC-4626 Stata path, and LM reward sweeps.
interface IYieldRouterV2 is IYieldRouter {
    enum YieldPath {
        AToken,
        StataToken
    }

    /// @notice Supply stake token for `templateId` using the template's configured path; returns attribution units
    ///         (scaled balance delta for AToken path, shares minted for StataToken path).
    function depositScaled(bytes32 templateId, uint256 amount) external returns (uint256 attributionUnits);

    /// @notice Withdraw underlying for `templateId` against `principalAmount` of tracked principal (proportional slice).
    /// @return grossAmount Underlying received by the engine (principal slice + yield on that slice).
    function withdrawScaled(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);

    /// @notice Current underlying value of the template's yield position.
    function currentValueOf(bytes32 templateId) external view returns (uint256);

    /// @notice Claim liquidity-mining rewards for aToken (no-op if rewards controller is zero).
    function claimLmRewards(bytes32 templateId)
        external
        returns (address[] memory rewardsList, uint256[] memory amounts);

    /// @notice Pending LM rewards view (may be gas-heavy).
    function pendingLmRewards(bytes32 templateId)
        external
        view
        returns (address[] memory tokens, uint256[] memory pending);

    /// @dev Per-template path; default is AToken. StataToken requires `stataToken` configured on the router.
    function setTemplateYieldPath(bytes32 templateId, YieldPath path) external;

    function getTemplateYieldPath(bytes32 templateId) external view returns (YieldPath);

    function globalScaledBalance() external view returns (uint256);

    function principalOf(bytes32 templateId) external view returns (uint256);

    function scaledPrincipalOf(bytes32 templateId) external view returns (uint256);

    function stataSharesOf(bytes32 templateId) external view returns (uint256);
}
