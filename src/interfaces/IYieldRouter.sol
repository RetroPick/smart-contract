// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IYieldRouter
/// @notice Pluggable yield backend interface for RetroPick `MarketEngine`.
/// @dev Router implementations hold yield-bearing assets on behalf of the engine and account per templateId.
///      **Access control:** This interface does not enforce callers on-chain. Implementations MUST restrict every
///      state-changing function below so that only the authorized `MarketEngine` contract (or an immutable alias
///      agreed at deploy time) may invoke it. Unrestricted implementations allow anyone to move or mis-account funds.
///
/// **V2 routers (`IYieldRouterV2`):** Implementations SHOULD make `withdraw` / `deposit` thin aliases of the scaled
/// entrypoints (`withdrawScaled` / `depositScaled`) so there is a single accounting path—never two independent withdraw implementations.
interface IYieldRouter {
    /// @notice Deploy `amount` of stakeToken into the yield source.
    /// @dev Called by `MarketEngine` after it has received stakeToken from the user.
    ///      **MUST** be `onlyEngine` (or equivalent): not publicly callable.
    function deposit(bytes32 templateId, uint256 amount) external;

    /// @notice Withdraw `principalAmount` (plus any accrued yield) to the engine.
    /// @dev Called by `MarketEngine` during epoch resolution. Implementations must transfer stakeToken to the engine.
    ///      **MUST** be `onlyEngine` (or equivalent): not publicly callable.
    /// @return grossAmount SHOULD equal the stake token amount actually transferred to the engine; the engine uses
    ///         `stakeToken` balance deltas around `withdrawScaled` paths and MUST NOT credit yield solely on a lying return value.
    function withdraw(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);

    /// @notice Current yield-bearing balance attributable to `templateId` in router-native units.
    /// @dev For Aave, this is the aToken share amount attributed to the template.
    function balanceOf(bytes32 templateId) external view returns (uint256);

    /// @notice Emergency: withdraw all yield-bearing assets attributable to `templateId` to the engine.
    /// @dev Intended for pause/recovery flows.
    ///      **MUST** be `onlyEngine` (or equivalent): not publicly callable.
    /// @return grossAmount SHOULD equal tokens actually transferred; engines SHOULD prefer balance measurement where used.
    function emergencyWithdraw(bytes32 templateId) external returns (uint256 grossAmount);
}

