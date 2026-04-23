# Change Management Policy

## Objective

Define how privileged protocol changes are proposed, reviewed, executed, and verified.

This policy applies to:

- upgrades
- module registration and selector routing
- oracle changes
- yield-router changes
- reporter rotation
- treasury and worker rotation

## Change Classes

### Class 1: Emergency

Examples:

- `pauseProgram(true)`
- `yieldEmergencyWithdraw`
- rolling-halt recovery actions
- emergency trusted reporter rotation after compromise

Requirements:

- incident must be declared
- rationale recorded before or immediately after execution
- execution can bypass normal delay
- post-action review required

### Class 2: High Risk

Examples:

- UUPS upgrade
- `allowModuleCodeHash`
- `registerModule`
- `setSelectorModule`
- `setYieldRouter`
- `setRateOracle`
- `setSmartDataOracle`
- `setMacroOracle`
- `setEquityOracle`

Requirements:

- two human reviewers minimum
- dry-run output archived
- calldata reviewed
- delayed execution or timelock strongly recommended
- post-execution verification mandatory

### Class 3: Medium Risk

Examples:

- `setWorkerAuthority`
- `setTreasury`
- `resetOracleCursor`
- `resetYieldRouterFailures`
- enabling or disabling LM rewards

Requirements:

- one preparer, one reviewer
- execution record archived
- verification mandatory

## Required Workflow

1. Prepare change request.
2. Classify by risk level.
3. Attach source commit hash and deployment target.
4. Attach dry-run logs.
5. Attach post-execution verification plan.
6. Obtain required approvals.
7. Execute via multisig or approved control path.
8. Run verification checklist.
9. Archive artifacts.

## Mandatory Change Request Fields

- title
- change class
- affected contracts and addresses
- exact calldata or transaction bundle
- source commit hash
- expected events/state changes
- rollback plan
- reviewer names
- target execution window

## Rollback Requirement

Every Class 2 change must have a rollback posture before execution:

- previous implementation address
- previous module mapping
- expected restore sequence
- pause criteria

## No-Go Conditions

Do not execute if:

- calldata differs from reviewed payload
- target chain ID differs from expected chain
- there is no rollback path
- dry-run and broadcast artifacts do not match
- reviewer cannot reproduce the expected state change

## Evidence Sources

- [.runbook.md](/home/asyam/dev/Project/RetroPick/V1/contract/.runbook.md:1)
- [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:77)
- [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:44)
