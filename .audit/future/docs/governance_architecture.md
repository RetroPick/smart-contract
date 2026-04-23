# Governance Architecture

## Objective

Define the minimum governance model required for RetroPick `MarketEngine` to operate safely with meaningful TVL.

This document governs the highest-trust surfaces in:

- [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:77)
- [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:17)
- [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:76)

## Governance Principle

Any actor that can:

- upgrade the dispatcher
- register or remap modules
- replace oracle adapters
- replace the yield router
- pause or resume operations
- rotate the trusted reporter

can materially affect solvency, settlement correctness, or liveness.

These powers must not sit behind a single hot signer.

## Required Roles

### 1. Admin Multisig

Purpose:

- final authority over protocol upgrades and core configuration

Controls:

- `allowModuleCodeHash`
- `registerModule`
- `setSelectorModule`
- UUPS upgrades
- `pauseProgram`
- `setTreasury`
- `setWorkerAuthority`
- `setYieldRouter`
- oracle replacement
- `resetOracleCursor`
- `resetYieldRouterFailures`
- `yieldEmergencyWithdraw`

Requirements:

- must be a multisig
- must not be an EOA
- quorum must require more than one human
- signer devices should be operationally separated
- at least one signer must be held outside the normal deployment team path

### 2. Worker Authority

Purpose:

- lifecycle and keeper operations only

Controls:

- open/lock/resolve in manual mode
- rolling execution
- LM reward claims where allowed

Requirements:

- must not hold upgrade or module-routing power
- may be a bot or service key
- should be rotated independently from admin

### 3. Treasury

Purpose:

- receive protocol fees

Requirements:

- must be a dedicated wallet or multisig
- must not be reused as worker authority
- should be operationally distinct from admin where possible

### 4. Oracle Owner

Purpose:

- manage `TrustedReporterAdapter` ownership and reporter rotation

Requirements:

- if trusted-reporter markets are live, the oracle owner must be governed with controls equal to or stronger than admin
- if oracle owner differs from protocol admin, the separation and escalation path must be documented

## Authority Separation Matrix

| Action | Admin multisig | Worker | Treasury | Oracle owner |
| --- | --- | --- | --- | --- |
| Upgrade dispatcher | yes | no | no | no |
| Register/remap modules | yes | no | no | no |
| Pause protocol | yes | no | no | no |
| Resume protocol | yes | no | no | no |
| Open/lock/resolve manual markets | yes or delegated | yes | no | no |
| Execute rolling rounds | yes or delegated | yes | no | no |
| Withdraw fees | yes | no | yes | no |
| Rotate trusted reporter | no unless same control body | no | no | yes |
| Clear reporter samples | no unless same control body | no | no | yes |
| Replace yield router | yes | no | no | no |

## Required Governance Posture By Launch Stage

### Guarded pilot

- multisig admin mandatory
- dual review mandatory for upgrades and module remaps

### Public mainnet

- multisig admin mandatory
- non-emergency changes delayed by policy or timelock
- signed approvals recorded for each privileged action

### Serious TVL

- multisig admin plus formal delayed execution for non-emergency changes
- pre-announced governance actions
- independent audit or review of governance process itself

## Non-Emergency Actions That Must Be Delayed

- upgrades
- module registration
- selector remaps
- yield-router replacement
- price-oracle replacement
- trusted reporter rotation where not incident-driven

## Emergency Actions

These may be executed without delay if user funds or settlement integrity are at risk:

- `pauseProgram(true)`
- rolling-halt recovery actions when markets are already degraded
- `yieldEmergencyWithdraw`
- emergency reporter rotation after key compromise

Emergency use must trigger:

- incident declaration
- written justification
- post-action review

## Evidence Required Before Public Launch

- admin multisig address documented
- signer set and quorum documented
- worker authority documented
- treasury address documented
- oracle owner documented
- separation-of-duties diagram signed off

## Current Gap Assessment

Current code is compatible with strong governance, but does not enforce it on-chain. That means production safety depends on operational discipline. This is acceptable only if the protocol treats governance as part of the security boundary and documents it accordingly.
