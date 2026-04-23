# Rolling Halt Playbook

## Objective

Provide a deterministic operational path for rolling-market halts.

References:

- [src/engine/modules/MarketEngineRollingLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineRollingLifecycleModule.sol:174)
- [currentSmartContract.md](/home/asyam/dev/Project/RetroPick/V1/contract/currentSmartContract.md:877)

## Halt Causes

Rolling may halt due to:

- buffer miss on resolve
- buffer miss on lock
- oracle failure
- oracle confidence too wide
- resolve-path router degradation that prevents healthy continuation

## Immediate Triage

1. Identify `templateId`.
2. Identify halt reason.
3. Record `haltedAtEpochId`.
4. Determine whether active epoch and prior epoch are consistent.
5. Decide whether global pause is required.

## Recovery Sequence

### Phase 1: Stabilize

- if user fairness or settlement correctness is uncertain, call `pauseProgram(true)`
- stop keeper automation for affected template
- capture current epoch and vault state

### Phase 2: Diagnose

- if halt was oracle-related, inspect oracle liveness and publish-time assumptions
- if halt was timing-related, inspect keeper latency and rolling buffer configuration
- if halt was router-related, invoke yield-router recovery process

### Phase 3: Repair

If open or locked epochs must be unwound:

- use `cancelRollingEpochWhileHalted(...)` as appropriate

If rolling cursor must be repaired:

- use `resetRollingLifecycle(templateId, nextRollingEpochId)`

### Phase 4: Validate

- verify last resolved epoch
- verify next open epoch cursor
- verify no impossible claim/refund state exists
- run smoke lifecycle on a safe template if practical

### Phase 5: Resume

- unpause only after human review
- re-enable keepers
- watch first live rounds with heightened monitoring

## Required Evidence For Postmortem

- halt reason
- timestamps
- affected epochs
- whether users were exposed to incorrect settlement or liveness loss
- exact admin actions taken
- whether parameters should change to prevent recurrence
