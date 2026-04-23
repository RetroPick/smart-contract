# Yield Router Recovery Runbook

## Objective

Define the recovery sequence when the configured yield router degrades, partially fails, or becomes untrusted.

References:

- [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:121)
- [src/engine/modules/MarketEngineCoreLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineCoreLifecycleModule.sol:512)
- [src/engine/modules/MarketEngineRollingLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineRollingLifecycleModule.sol:470)
- [src/engine/MarketEngineState.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineState.sol:192)

## Trigger Conditions

This runbook activates if any of the following occur:

- repeated `YieldRouterWithdrawFailed`
- `YieldRouterDisabled`
- router returns less than expected or behaves inconsistently
- suspected router compromise
- downstream Aave or vault dependency issue

## Immediate Actions

1. Assess whether user operations should be paused.
2. Determine whether only one template is affected or all routed templates.
3. Confirm current `yieldRouterFailureCount` and `yieldRouterDisabled` state.
4. Preserve logs and current balances.

## Decision Tree

### Case 1: Transient failure, funds believed safe

- pause only if settlement correctness is at risk
- inspect downstream dependency
- do not reset failure state until root cause is understood

### Case 2: Router unhealthy but recoverable

- pause if needed
- use `yieldEmergencyWithdraw(templateId)` where appropriate
- verify engine balance increase and routed-principal expectations
- only then consider `resetYieldRouterFailures`

### Case 3: Router no longer trusted

- pause protocol
- emergency withdraw where possible
- replace router through governed change process
- verify template accounting before resuming

## Verification Checklist

- engine token balance before and after recovery action
- affected template `vault` state
- affected epoch `routedPrincipal`
- any outstanding claim/refund liability
- whether rolling markets halted as a secondary effect

## Unpause Conditions

Do not resume normal operations until:

- root cause is identified
- recovered balance is reconciled
- target templates are smoke-tested
- reviewers sign off on resumed routing or routing disablement

## Required Monitoring

- alert on every `YieldRouterWithdrawFailed`
- alert when `YieldRouterFailureRecorded` increments
- critical alert on `YieldRouterDisabled`
