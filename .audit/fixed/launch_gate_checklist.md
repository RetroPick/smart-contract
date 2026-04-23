# Launch Gate Checklist

## Status Legend

- `pass`: sufficient evidence exists in code/tests/docs for the stated launch stage
- `conditional`: acceptable only for capped/guarded launch with explicit operational restrictions
- `blocker`: not sufficient for serious-TVL production signoff

## Current Overall Status

- internal/team-operated: `pass`
- guarded public pilot with explicit cap: `conditional`
- serious TVL production: `blocker`

This checklist is derived from:

- [production_readiness_verdict.md](/home/asyam/dev/Project/RetroPick/V1/contract/production_readiness_verdict.md:1)
- [future_artifact_production_grade.md](/home/asyam/dev/Project/RetroPick/V1/contract/future_artifact_production_grade.md:1)
- [1_byHashLock.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_byHashLock.md:1)
- [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:1)
- [.runbook.md](/home/asyam/dev/Project/RetroPick/V1/contract/.runbook.md:1)

## Gate Matrix

| gate | current status | launch stage impact | owner | required artifact | evidence |
|------|----------------|---------------------|-------|-------------------|----------|
| Code-level accounting safety for manual lifecycle | pass | supports guarded launch | protocol engineering | regression tests kept green per release | [test/engine/security/MarketEngineEmergencyRecovery.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/security/MarketEngineEmergencyRecovery.t.sol:1); [test/engine/core/MarketEngineYieldRouting.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/core/MarketEngineYieldRouting.t.sol:1) |
| Code-level accounting safety for rolling lifecycle | pass | supports guarded launch | protocol engineering | regression tests kept green per release | [test/engine/rolling/MarketEngineRollingOracle.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/rolling/MarketEngineRollingOracle.t.sol:1); [test/engine/rolling/MarketEngineRollingRecovery.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/rolling/MarketEngineRollingRecovery.t.sol:1) |
| Reentrancy and router callback safety | pass | supports guarded launch | protocol engineering | dedicated malicious-router regression set | [test/engine/security/MarketEngineReentrancy.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/security/MarketEngineReentrancy.t.sol:1) |
| Oracle migration safety for live epochs | pass | supports guarded launch | protocol engineering | oracle-change regression set | [test/engine/core/MarketEngineCoreMarketUpgrade.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/core/MarketEngineCoreMarketUpgrade.t.sol:1); [test/engine/security/MarketEngineOracleParity.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/security/MarketEngineOracleParity.t.sol:1) |
| Recovery and disabled-router safety | pass | supports guarded launch | protocol engineering + ops | pause/recovery drills and regression tests | [test/engine/security/MarketEngineEmergencyRecovery.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/security/MarketEngineEmergencyRecovery.t.sol:1); [test/engine/security/MarketEngineYieldRouterDisabledSafety.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/engine/security/MarketEngineYieldRouterDisabledSafety.t.sol:1) |
| Base accounting invariants | conditional | acceptable for cap, insufficient for serious TVL | protocol engineering | expanded invariant design note + additional harness coverage | [test/invariants/MarketEngineAccountingInvariants.t.sol](/home/asyam/dev/Project/RetroPick/V1/contract/test/invariants/MarketEngineAccountingInvariants.t.sol:1) |
| Routed-principal and emergency-recovery invariants | blocker | blocks serious TVL | protocol engineering | new invariant suite covering deposit/resolve/cancel/emergency/reconcile/finalize | [production_readiness_verdict.md](/home/asyam/dev/Project/RetroPick/V1/contract/production_readiness_verdict.md:27) |
| Multisig admin custody evidence | conditional | required before any public pilot | governance/ops | governance architecture memo + signer policy | [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:11); [.runbook.md](/home/asyam/dev/Project/RetroPick/V1/contract/.runbook.md:27) |
| Non-emergency change delay / change control | blocker | blocks serious TVL | governance/ops | change-management policy for upgrades/modules/oracles/router | [future_artifact_production_grade.md](/home/asyam/dev/Project/RetroPick/V1/contract/future_artifact_production_grade.md:220) |
| Module-release verification discipline | conditional | required before public pilot | protocol engineering + governance | module registry verification checklist | [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:77) |
| Trusted-reporter operating model | blocker if trusted-reporter markets are live | blocks serious TVL for reporter-settled markets | oracle ops + governance | reporter operations and correction-policy memo | [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:1); [production_readiness_verdict.md](/home/asyam/dev/Project/RetroPick/V1/contract/production_readiness_verdict.md:58) |
| Oracle configuration matrix | conditional | needed before public pilot | oracle ops | per-market oracle matrix with delay/confidence settings | [future_artifact_production_grade.md](/home/asyam/dev/Project/RetroPick/V1/contract/future_artifact_production_grade.md:283) |
| Rolling incident and recovery runbooks | blocker | blocks serious TVL | ops | production incident runbook + rehearsal log | [src/engine/modules/MarketEngineRollingLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineRollingLifecycleModule.sol:1); [production_readiness_verdict.md](/home/asyam/dev/Project/RetroPick/V1/contract/production_readiness_verdict.md:42) |
| Keeper SLOs and alerting | conditional | required before public pilot | ops | monitoring spec + on-call playbook | [future_artifact_production_grade.md](/home/asyam/dev/Project/RetroPick/V1/contract/future_artifact_production_grade.md:319) |
| Supported collateral/token policy | conditional | required before public pilot | protocol engineering + ops | supported-token policy doc | [src/engine/modules/MarketEngineUserOpsClaimsModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineUserOpsClaimsModule.sol:1); [future_artifact_production_grade.md](/home/asyam/dev/Project/RetroPick/V1/contract/future_artifact_production_grade.md:350) |
| Treasury and fee-handling controls | conditional | required before public pilot | treasury ops | treasury custody + withdrawal review policy | [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:228) |
| Economic parameter signoff | blocker | blocks serious TVL | protocol engineering + risk | launch parameter envelope and economic review note | [production_readiness_verdict.md](/home/asyam/dev/Project/RetroPick/V1/contract/production_readiness_verdict.md:74) |
| External professional audit | blocker | blocks serious TVL | founders/governance | external audit report + remediation tracker | [production_readiness_verdict.md](/home/asyam/dev/Project/RetroPick/V1/contract/production_readiness_verdict.md:135) |

## Deep Assessment By Gate

### 1. Code Safety Gates

Status:

- manual lifecycle: `pass`
- rolling lifecycle: `pass`
- router/recovery regressions: `pass`
- live-epoch oracle migration safety: `pass`

Why:

- recent attacker-mode findings were reproduced, fixed, and retested
- the contract now fails closed on several previously dangerous recovery/oracle transition paths
- per-epoch snapshots removed two important mutable-admin retroactivity risks:
  - oracle adapter source
  - yield fee

Residual risk:

- this does not eliminate governance or operator risk
- this does not replace broader invariants for serious TVL

### 2. Invariant and State-Machine Assurance

Status:

- current accounting invariants: `conditional`
- full routed-principal state-machine assurance: `blocker`

Why:

- current invariants prove useful conservation properties and are a real positive signal
- however, the most important bugs found in the last passes were recovery-state-machine bugs
- those require broader machine-checked adversarial sequencing than the current harness provides

Missing invariant families:

- routed principal cannot be lost, duplicated, or silently fee-booked across recovery paths
- unreconciled recovered balances cannot be cleared incorrectly
- rolling halt/reset/rebootstrap cannot strand claims or active balances
- per-template and cross-template recovery buckets remain reconcilable under repeated emergency flows

### 3. Governance and Change-Control Gates

Status:

- multisig admin evidence: `conditional`
- non-emergency delay / change discipline: `blocker`
- module verification discipline: `conditional`

Why:

- the dispatcher architecture is explicitly governance-centric
- the security of the live system depends heavily on who controls:
  - upgrades
  - selector remaps
  - module approval
  - oracle changes
  - router changes

For a centralized protocol, this is acceptable only if the operational governance is correspondingly strong.

Minimum required before any public pilot:

- multisig, not EOA
- named signer policy
- no hot-key deploy/upgrade behavior
- reviewed module registry process

Minimum required before serious TVL:

- strong change-management policy
- non-emergency delay or equivalent friction and review control
- explicit rollback and emergency exception rules

### 4. Oracle and Reporter Gates

Status:

- Chainlink-family code-level safety: `pass`
- oracle operations matrix: `conditional`
- trusted-reporter production use: `blocker` until operating model is formalized

Why:

- code-level migration/continuity protections are substantially better now
- but trusted settlement remains an operations and trust problem, not only a code problem

If trusted-reporter markets remain live, the following must exist before serious TVL:

- written correction policy
- reporter key custody policy
- rotation policy
- compromise response policy
- user disclosure policy when results are cleared and reposted

### 5. Rolling-Lifecycle Production Gates

Status:

- code-level halt/recovery logic: `pass`
- operational runbooks and rehearsal evidence: `blocker`

Why:

- rolling mode now halts more safely than before
- but rolling safety in production depends on humans and systems responding correctly under time pressure

Minimum evidence needed:

- keeper SLO
- alert routing
- incident response flow
- rollback/recovery decision tree
- rehearsal log for halt/cancel/reset/rebootstrap

### 6. Economic-Review Gates

Status:

- parameter review: `blocker`

Why:

- no obvious code exploit may remain, but poor parameterization can still create bad live outcomes
- rolling markets, confidence thresholds, staleness windows, and payout edge cases require explicit signoff

Required artifact:

- launch parameter envelope specifying allowed settings for initial production markets

## Required Deliverables Before Each Launch Stage

### Guarded Public Pilot

Must be complete:

- multisig admin evidence
- supported-token policy
- oracle configuration matrix
- treasury and fee policy
- keeper monitoring and alert spec
- incident operators identified
- explicit TVL cap
- no ad hoc upgrade/module/oracle/router changes

Can remain incomplete:

- full serious-TVL invariant suite
- full external audit
- full production-grade rolling rehearsal evidence

### Serious TVL Production

Must be complete:

- external audit report and remediation tracker
- governance architecture memo
- change-management policy
- routed-principal/recovery invariant suite
- rolling incident and recovery runbook
- keeper SLO and rehearsal evidence
- trusted-reporter operating model if reporter markets are enabled
- economic parameter signoff

## Immediate Next Actions

### Highest Priority

1. Build the routed-principal and emergency-recovery invariant suite.
2. Write the governance/change-management memo for dispatcher/module/oracle/router powers.
3. Produce a rolling incident-response runbook with actual rehearsal steps.
4. Produce the oracle/reporter operations memo.
5. Lock the launch parameter envelope for the first public market set.

### Before Any Public Launch

1. Prove admin custody is multisig-based.
2. Freeze the initial supported market configurations.
3. Freeze the supported-token policy.
4. Freeze the emergency recovery policy and operator roster.

## Final Signoff Position

If asked today whether this is "production-grade ready," my answer remains:

- guarded launch: `conditional yes`
- serious TVL production: `no`

The good news is that this is no longer because the engine looks obviously broken. It is because the remaining work is the hard production work:

- governance
- invariants
- operations
- economic signoff
- external review
