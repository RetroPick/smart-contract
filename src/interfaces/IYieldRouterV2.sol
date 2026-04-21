// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IYieldRouter} from "./IYieldRouter.sol";

/// @title IYieldRouterV2
/// @notice Yield router with scaled aToken accounting, optional ERC-4626 Stata path, and LM reward sweeps.
/// @dev **Access control:** Extends `IYieldRouter` requirements. Engine-gated mutators (`depositScaled`,
///      `withdrawScaled`, `claimLmRewards`) MUST only be callable by the authorized `MarketEngine`.
///      `setTemplateYieldPath` MUST be admin/owner-only (not engine, not public): routing is a governance/config concern.
///
/// **Rounding:** Partial `withdrawScaled` amounts are inherently floor-rounded; dust may remain until a final full unwind.
///      Implementations SHOULD use overflow-safe `mulDiv`-style math for proportional slices.
///
/// **V1 vs V2 entrypoints:** `IYieldRouter`’s `deposit`/`withdraw`/`emergencyWithdraw` MUST delegate to the same scaled
///      accounting as `depositScaled`/`withdrawScaled` so integrators cannot accidentally double-move funds via two paths.
///
/// **`globalScaledBalance` vs per-template sums:** `globalScaledBalance()` (where present) reflects **aggregate on-chain
///      position** for the router’s shared pool token (e.g. total scaled aToken for the router). It is **not** a strict
///      checksum of `sum(scaledPrincipalOf)` unless the implementation explicitly reconciles external transfers (donations,
///      direct aToken sends, rounding drift). Treat as an operational/accounting view, not an enforced protocol invariant.
interface IYieldRouterV2 is IYieldRouter {
    enum YieldPath {
        AToken,
        StataToken
    }

    /// @notice Monotonic integrator hint: bump when the router’s `IYieldRouterV2` surface or semantics change materially.
    /// @dev Not a substitute for bytecode verification; off-chain tooling MAY pair with `address` + `chainId`.
    function yieldRouterApiVersion() external pure returns (uint256);

    /// @notice Supply stake token for `templateId` using the template's configured path; returns attribution units
    ///         (scaled balance delta for AToken path, shares minted for StataToken path).
    /// @dev **MUST** be `onlyEngine` (or equivalent): not publicly callable.
    function depositScaled(bytes32 templateId, uint256 amount) external returns (uint256 attributionUnits);

    /// @notice Detailed deposit surface for engine-side sub-bucket accounting.
    /// @dev `principalAdded` is the stake-token principal moved into the router for the template.
    ///      `attributionUnitsAdded` are router-native units: scaled aToken balance for AToken path,
    ///      or ERC-4626 shares for Stata path.
    function depositDetailed(bytes32 templateId, uint256 amount)
        external
        returns (uint256 principalAdded, uint256 attributionUnitsAdded);

    /// @notice Withdraw underlying for `templateId` against `principalAmount` of tracked principal (proportional slice).
    /// @dev **MUST** be `onlyEngine` (or equivalent): not publicly callable.
    /// @return grossAmount SHOULD equal underlying actually sent to the engine; callers SHOULD verify `stakeToken`
    ///         balance deltas instead of trusting a malicious return value alone.
    function withdrawScaled(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);

    /// @notice Detailed principal withdrawal surface for engine-side accounting.
    function withdrawDetailed(bytes32 templateId, uint256 principalAmount)
        external
        returns (uint256 grossAmount, uint256 principalConsumed, uint256 attributionUnitsBurned);

    /// @notice Withdraw by router-native attribution units rather than by principal.
    function withdrawAttribution(bytes32 templateId, uint256 attributionUnits)
        external
        returns (uint256 grossAmount, uint256 principalConsumed, uint256 attributionUnitsBurned);

    /// @notice Current underlying value of the template's yield position.
    function currentValueOf(bytes32 templateId) external view returns (uint256);

    /// @notice Current underlying value attributable to `attributionUnits` for `templateId`.
    function previewValueByAttribution(bytes32 templateId, uint256 attributionUnits)
        external
        view
        returns (uint256 currentValue);

    /// @notice Claim liquidity-mining rewards for aToken (no-op if rewards controller is zero).
    /// @dev **MUST** be restricted (typically `onlyEngine` when invoked via engine admin flows): not publicly callable.
    ///      Implementations MUST transfer claimed reward ERC20s to a deterministic recipient (in RetroPick’s router,
    ///      the immutable `ENGINE` address) so tokens are not stranded in the router; distribution to end users is an engine/treasury policy.
    function claimLmRewards(bytes32 templateId)
        external
        returns (address[] memory rewardsList, uint256[] memory amounts);

    /// @notice Pending LM rewards view (may be gas-heavy).
    function pendingLmRewards(bytes32 templateId)
        external
        view
        returns (address[] memory tokens, uint256[] memory pending);

    /// @dev Per-template path; default is AToken. StataToken requires `stataToken` configured on the router.
    ///      **MUST** be owner/admin-only (`onlyOwner` or equivalent), not `onlyEngine` and not publicly callable.
    ///      Implementations SHOULD reject path changes while the template has non-zero principal / shares on the router
    ///      (see `YieldRouterV2.CannotChangePath`) to avoid mid-flight accounting mismatches.
    function setTemplateYieldPath(bytes32 templateId, YieldPath path) external;

    function getTemplateYieldPath(bytes32 templateId) external view returns (YieldPath);

    /// @dev See interface `@dev` on aggregate vs per-template totals.
    function globalScaledBalance() external view returns (uint256);

    function principalOf(bytes32 templateId) external view returns (uint256);

    function scaledPrincipalOf(bytes32 templateId) external view returns (uint256);

    function stataSharesOf(bytes32 templateId) external view returns (uint256);
}
