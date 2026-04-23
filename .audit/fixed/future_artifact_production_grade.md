# Future Artifact: Production-Grade Launch Checklist

## Purpose

This document maps what still needs to exist before RetroPick `MarketEngine` should be treated as production-grade for meaningful TVL.

It is written from the perspective of:

- senior protocol engineering
- smart contract security review
- launch and operations readiness

It is not a generic checklist. It is derived from the actual system in this repo:

- modular UUPS dispatcher in [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:11)
- shared storage anchor in [src/engine/MarketEngineState.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineState.sol:11)
- admin surface in [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:17)
- manual lifecycle in [src/engine/modules/MarketEngineCoreLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineCoreLifecycleModule.sol:169)
- rolling lifecycle in [src/engine/modules/MarketEngineRollingLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineRollingLifecycleModule.sol:126)
- oracle trust surface in [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:11)
- current upgrade runbook in [.runbook.md](/home/asyam/dev/Project/RetroPick/V1/contract/.runbook.md:1)
- protocol technical reference in [currentSmartContract.md](/home/asyam/dev/Project/RetroPick/V1/contract/currentSmartContract.md:1)

## Executive Assessment

Current posture:

- core code quality is materially better than the raw AI audit output suggested
- directly actionable code findings from the reconciled Hashlock set are mostly already fixed
- the remaining path to production-grade is dominated by:
  - governance hardening
  - invariant testing
  - oracle trust and operations
  - yield-router failure readiness
  - deployment discipline
  - economic review

Bottom line:

- suitable for continued internal validation and guarded staging
- not yet sufficient for serious public TVL under a strict production-grade standard

## Production-Grade Standard

For this protocol, "production-grade" should mean all of the following are true:

1. No known high-confidence accounting exploit remains in live code.
2. Governance compromise is materially harder than compromise of one signer or hot wallet.
3. Upgrade, module-routing, oracle, and yield-router changes are observable, reviewable, and delayed when appropriate.
4. Core accounting invariants are machine-checked under adversarial sequencing.
5. Rolling-market and oracle timing assumptions have been economically reviewed, not just unit-tested.
6. Operations can safely pause, recover, and communicate during incidents.
7. Launch evidence is documented well enough that an external auditor or reviewer can reproduce the safety case.

## Main Risk Domains

### 1. Governance and Upgrade Concentration

The dispatcher correctly documents its trust boundary: admin-controlled module routing and upgrades are equivalent to protocol control in [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:13).

What this means in practice:

- `allowModuleCodeHash`
- `registerModule`
- `setSelectorModule`
- UUPS upgrades
- admin module setters for oracles, router, treasury, worker, and pause

are all part of the same governance attack surface.

Production-grade implication:

- a single admin signer is not enough
- a pure multisig without delay is better, but still weak for non-emergency changes
- the protocol needs a governance policy, not just admin functions

### 2. Oracle Integrity and Settlement Trust

Two oracle models exist:

- Chainlink-family adapters
- trusted-reporter signed payload adapter

The trusted-reporter model is intentionally centralized in [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:13). That is acceptable only if the centralization is explicitly acknowledged and operationally hardened.

Production-grade implication:

- if trusted reporter remains single-signer, the protocol must narrow which markets use it and document that trust assumption clearly
- if serious TVL depends on it, stronger controls should be added around reporter rotation and settlement correction flows

### 3. Accounting and External Yield-Router Integration

The code has already improved here:

- user deposits require exact token delta in [src/engine/modules/MarketEngineUserOpsClaimsModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineUserOpsClaimsModule.sol:150)
- resolve/cancel logic uses engine token balance delta rather than trusting router return values in [src/engine/modules/MarketEngineCoreLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineCoreLifecycleModule.sol:486) and [src/engine/modules/MarketEngineRollingLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineRollingLifecycleModule.sol:470)
- failure counting and auto-disable exist in [src/engine/MarketEngineState.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineState.sol:65)

But this area is not production-grade until the invariants are proven.

### 4. Rolling Lifecycle Operational Brittleness

Rolling markets can halt on:

- buffer misses
- oracle failure
- oracle confidence too wide
- resolve-path router problems that degrade the rolling pipeline

This behavior is visible in [src/engine/modules/MarketEngineRollingLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineRollingLifecycleModule.sol:174).

Production-grade implication:

- the protocol needs explicit staffing, monitoring, and recovery procedures for rolling mode
- the current runbook is a good start, but not yet a full production operations artifact

### 5. Economic Correctness

Several risks are not simple bugs. They are market-design questions:

- timing windows
- staleness parameters
- confidence-band strictness
- rolling buffer sizing
- low-liquidity edge cases
- niche market-type payout behavior

These require a protocol-economic sign-off, not just test coverage.

## Launch Stages

### Stage 0: Internal Dev / Research

Acceptable assumptions:

- team-operated only
- small test balances
- fast iteration
- no external security claims

Required:

- green unit/fuzz suite
- documented known risks
- no claim of production safety

### Stage 1: Guarded Testnet / Private Mainnet Pilot

Acceptable assumptions:

- restricted participant set
- low capped exposure
- multisig admin already live
- active monitoring during all operations

Required:

- checklist items in Governance, Testing, Oracle Ops, and Incident Response sections below
- dry-run and broadcast rehearsals
- explicit exposure cap

### Stage 2: Public Mainnet With Limited TVL

Required:

- invariant suite for accounting conservation
- multisig admin plus governance delay for non-emergency changes
- formal incident runbooks
- monitored oracle and rolling lifecycle alerts
- documented supported-token and supported-market policy
- external audit scheduled or completed

### Stage 3: Serious TVL / Production-Grade

Required:

- external professional audit completed
- critical findings resolved
- change-management discipline proven in practice
- formal launch packet containing evidence for every gate in this document

## Detailed Launch Checklist

## A. Governance Hardening

### A1. Admin custody

Status:

- partially implied in docs, not enforced by code

Required artifact:

- governance architecture memo

Must include:

- admin is a multisig, not EOA
- signer set, quorum, and signer separation policy
- named emergency signers and escalation path
- key-rotation policy

Go/No-Go:

- no launch with a single hot admin key

### A2. Timelock policy

Status:

- not present on-chain for dispatcher/admin actions

Required artifact:

- change-management policy with operation classes

Must classify:

- emergency actions:
  - `pauseProgram`
  - rolling cancel/reset flows
  - emergency router recovery
- delayed actions:
  - module registration and selector remap
  - upgrades
  - oracle replacement
  - yield-router replacement
  - reporter rotation, unless clearly emergency-only

Recommended target:

- non-emergency governance delay
- dual review before execution
- pre-published calldata for upgrades and selector changes

Go/No-Go:

- public launch with no delay on upgrades/module/oracle/router changes is not production-grade

### A3. Module and upgrade control

Status:

- code hash allowlist exists, but trust still concentrates in admin

Required artifact:

- module registry verification checklist

Must verify for every module:

- bytecode hash
- expected source commit
- storage compatibility review
- selector map reviewed by two humans
- rollback target prepared

Evidence sources:

- [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:77)
- [.runbook.md](/home/asyam/dev/Project/RetroPick/V1/contract/.runbook.md:238)

## B. Testing and Formal Assurance

### B1. Accounting invariant suite

Status:

- missing as a meaningful harness today

Required artifact:

- `test/invariants/` suite plus invariant design note

Minimum invariants:

- template conservation:
  - `vault.active + vault.claims + vault.fees`
  - consistent with ledger reserves and realized external token transfers
- claims cannot exceed reserved liabilities
- claim total across all users cannot exceed:
  - resolved claim liability for normal settlement
  - refund liability for refund mode
- routed principal is never double-counted as active collateral
- router failure cannot mint phantom collateral
- fee withdrawals reduce only fee reserves
- rolling cancel/reset cannot leave active-vs-claims accounting impossible to reconcile

Required adversarial actions in harness:

- deposit
- switch
- resolve
- cancel
- claim
- claimMany
- router revert
- router short return
- router repeated failure until disablement
- rolling halt then admin recovery

Go/No-Go:

- no serious TVL without invariant coverage

### B2. Differential or scenario-model tests

Required artifact:

- scenario matrix doc plus tests

Should include:

- manual mode full lifecycle
- rolling mode full lifecycle
- refund-mode lifecycle
- no-winner / edge market outcomes
- trusted-reporter settlement and correction flow
- oracle adapter swap during template lifecycle
- router disable and emergency withdraw

### B3. Upgrade continuity tests

Status:

- partially present

Required artifact:

- explicit storage continuity regression suite for every release branch

Must cover:

- pre-upgrade state snapshot
- upgrade execution
- post-upgrade selector map
- read/write continuity
- claimability and reserves continuity

## C. Oracle and Settlement Operations

### C1. Chainlink-family oracle policy

Required artifact:

- oracle configuration matrix

For each market family:

- oracle class
- feed address
- max delay
- confidence threshold
- sequencer dependency
- acceptable downtime behavior

Need explicit review of:

- stale price handling
- round monotonicity expectations
- per-market delay values
- base/L2 sequencer edge cases if applicable

### C2. Trusted reporter operating model

Status:

- major governance/trust risk remains

Required artifact:

- trusted-reporter operational security doc

Must define:

- who controls `owner`
- who controls `trustedReporter`
- how signatures are generated and stored
- how reporter rotation is approved
- when `clearLockSample` / `clearResolveResult` / `clearOhlcResult` may be used
- user/public disclosure policy when correction flows are used

Strong recommendation:

- emit events for all clear operations
- require stricter human process around result-clearing and re-posting
- prefer market classes using Chainlink-family adapters when feasible

Go/No-Go:

- serious public usage of trusted-reporter markets without a written correction policy is not acceptable

### C3. Settlement observability

Required artifact:

- monitoring and alert spec

Alerts should fire on:

- repeated oracle read failures
- non-monotonic cursor errors
- trusted-reporter clears
- rolling halts
- delayed resolution backlog
- yield-router failures
- yield-router disabled state

Relevant events exist already for several of these in [src/engine/MarketEngineState.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineState.sol:140), but not all sensitive oracle-correction actions are currently observable.

## D. Yield Router and Treasury Safety

### D1. Supported token policy

Required artifact:

- supported collateral policy

Must state:

- whether fee-on-transfer tokens are unsupported
- whether rebasing tokens are unsupported
- whether non-standard ERC20s are unsupported except where explicitly handled

Rationale:

- user deposit path enforces exact token delta
- router integrations still assume standard token behavior

### D2. Router recovery policy

Required artifact:

- yield-router failure and recovery runbook

Must define:

- what happens after `YieldRouterFailureRecorded`
- what happens after `YieldRouterDisabled`
- when `resetYieldRouterFailures` is allowed
- when `yieldEmergencyWithdraw` is used
- who verifies recovered balance before re-enabling normal operations

References:

- [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:121)
- [src/engine/modules/MarketEngineCoreLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineCoreLifecycleModule.sol:512)
- [src/engine/modules/MarketEngineRollingLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineRollingLifecycleModule.sol:530)

### D3. Treasury control

Required artifact:

- treasury wallet and fee handling policy

Must define:

- treasury address custody
- how LM rewards are handled
- fee withdrawal review process
- accounting reconciliation frequency

## E. Rolling-Market Production Readiness

### E1. Timing and keeper SLOs

Required artifact:

- keeper service-level objective doc

Must include:

- target execution latency relative to lock/resolve boundaries
- acceptable missed-buffer rate
- primary and backup keepers
- alerting escalation tree

### E2. Rolling halt recovery

Status:

- code supports halt, cancel while halted, and reset
- runbook mentions recovery flow

Required artifact:

- rolling-halt playbook

Must define exact sequence:

1. detect halt reason
2. pause if needed
3. assess unresolved/open epochs
4. cancel affected epochs while halted if required
5. recover router/oracle issue
6. reset lifecycle cursor
7. run smoke check
8. resume

References:

- [currentSmartContract.md](/home/asyam/dev/Project/RetroPick/V1/contract/currentSmartContract.md:903)
- [src/engine/modules/MarketEngineRollingLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineRollingLifecycleModule.sol:126)

### E3. Economic review of rolling assumptions

Required artifact:

- rolling-market economic review memo

Must analyze:

- interval length
- buffer size
- oracle freshness windows
- volatility sensitivity
- low-liquidity settlement edge cases
- whether halting conditions are too brittle or too permissive

## F. Incident Response and Operations

### F1. Incident severity framework

Required artifact:

- severity classification doc

Suggested levels:

- `SEV-1`: funds at risk or incorrect settlement likely
- `SEV-2`: market halt or oracle compromise without confirmed loss
- `SEV-3`: degraded ops, delayed keeper execution, or monitoring outage

Each severity must specify:

- who can declare it
- who signs pause/unpause actions
- public communication timeline
- required postmortem

### F2. Pause and unpause governance

Required artifact:

- pause authority matrix

Must define:

- when `pauseProgram(true)` is mandatory
- whether worker can request but not execute pause
- evidence required before unpause
- who approves unpause

Go/No-Go:

- public launch without clear unpause rules creates governance ambiguity during incidents

### F3. Monitoring package

Required artifact:

- monitoring dashboard + alert runbook

At minimum monitor:

- `RollingHalted`
- `YieldRouterFailureRecorded`
- `YieldRouterDisabled`
- `YieldRouterWithdrawFailed`
- `OracleCursorReset`
- unusually high claim failure rate
- unresolved epoch backlog

## G. Economic and Market-Type Review

### G1. Market-type safety memo

Required artifact:

- market-type approval matrix

For each market type:

- settlement data source
- operator complexity
- edge-case payout behavior
- whether suitable for public launch now

Recommendation:

- stage rollout by market type
- launch simpler and better-observed types first
- keep more complex trusted-reporter or niche payout types gated until operational confidence exists

### G2. Parameter sanity review

Required artifact:

- parameter bounds review

Should explicitly review:

- `MIN_MANUAL_DEPOSIT_WINDOW`
- `MIN_MANUAL_LOCK_WINDOW`
- rolling interval minimums
- oracle delay thresholds
- confidence thresholds
- fee caps

References:

- [src/engine/MarketEngineState.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineState.sol:23)

## H. External Review

### H1. External audit trigger

Required before serious TVL:

- one external professional audit

Best timing:

- after invariants exist
- after governance/runbooks are written
- before public uncapped deployment

Reason:

- external auditors are most effective once the internal code and operations story is coherent enough that they can focus on real protocol risk rather than unfinished hygiene

## Concrete Artifact List

The following files should exist before calling the protocol production-grade:

1. `docs/governance_architecture.md`
2. `docs/change_management_policy.md`
3. `docs/oracle_configuration_matrix.md`
4. `docs/trusted_reporter_ops.md`
5. `docs/yield_router_recovery_runbook.md`
6. `docs/rolling_halt_playbook.md`
7. `docs/incident_response.md`
8. `docs/monitoring_alert_spec.md`
9. `docs/market_type_approval_matrix.md`
10. `docs/parameter_bounds_review.md`
11. `docs/launch_signoff_packet.md`
12. `test/invariants/` suite with accounting conservation invariants

## Production Go/No-Go Gates

All must be true:

- multisig admin is live
- non-emergency upgrade/module/oracle/router changes have review and delay policy
- accounting invariants are implemented and passing
- rolling-halt recovery has been rehearsed
- trusted-reporter correction flow is documented and monitored
- yield-router failure recovery has been rehearsed
- deployment and rollback runbooks are finalized
- launch packet is reviewed by at least two humans
- external audit is completed or explicitly scheduled before TVL expansion

If any of the following are true, the protocol is not production-grade:

- single-signer admin controls upgrades and selector routing
- no invariant suite exists
- no written incident response exists
- no clear policy exists for trusted-reporter correction or rotation
- no tested recovery path exists for rolling halts or router disablement

## Priority Order

If resources are limited, the highest-value order is:

1. invariant suite for accounting conservation
2. governance hardening and multisig-plus-delay policy
3. trusted-reporter and oracle operations docs
4. yield-router recovery runbook
5. rolling-market economic and operational review
6. external audit

## Final View

The codebase is no longer at the "unknown unknowns everywhere" stage. It has crossed into a more mature phase where the remaining launch blockers are the things that actually matter for real money:

- who can change what
- how accounting is proven
- how settlement trust is governed
- how incidents are handled
- how operations recover under stress

That is exactly where a serious protocol should be before public launch. The missing work is not cosmetic. It is the final layer that turns solid code into a production system.
