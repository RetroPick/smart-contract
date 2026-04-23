# Hashlock Audit Readiness Memo

## Scope

This memo answers a narrower question than the raw Hashlock reports:

> Is the current RetroPick MarketEngine strong enough to treat as audit-ready for launch?

It is based on:

- live code in `src/`
- current protocol architecture in `currentSmartContract.md`
- the reconciled Hashlock finding set in `hashlock_reconciliation.csv`
- the latest code/test fixes already applied in this workspace

This is not a replacement for an external audit. It is a senior-auditor readiness pass intended to separate:

- code bugs that were real and have now been fixed
- broad AI findings that do not survive live-code review
- genuine remaining risks that are governance, operational, or economic rather than direct code-exploit paths

## Executive Conclusion

The codebase is materially stronger than the raw Hashlock output implies, and the broad AI scan should not be treated as a final vulnerability list. After reconciliation, the remaining gap is no longer dominated by obvious live-code exploit paths. It is dominated by trust boundaries, governance centralization, deployment controls, and economic review.

My conclusion:

- It is not yet "strong enough" for serious TVL if the standard is production-grade risk posture.
- It is much closer to a focused human audit target than to an un-audited system.
- The highest remaining concerns are governance and oracle trust assumptions, not a backlog of confirmed code bugs.

## Reconciled Status Snapshot

From `hashlock_reconciliation.csv`:

- Total reconciled findings: `250`
- Excluding `duplicate` and `already fixed`: `120`
- Remaining status mix:
  - `governance risk`: `93`
  - `false positive`: `22`
  - `fixed`: `5`

Severity mix after excluding `duplicate` and `already fixed`:

- `critical`: `6`
- `high`: `15`
- `medium`: `20`
- `low`: `75`
- `informational`: `4`

That severity distribution is misleading if read literally. Most remaining `critical` and `high` items are trust-boundary findings rather than direct steal-now exploits.

## What Is Already In Better Shape

The following previously important findings are now implemented and covered:

- Oracle cursor reset after oracle adapter replacement via `resetOracleCursor(...)` in [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:91)
- Yield-router allowance cleanup after failed routed deposit in [src/engine/modules/MarketEngineUserOpsClaimsModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineUserOpsClaimsModule.sol:176)
- `claimMany` griefing / partial-state batch behavior softened to skip already-claimed epochs in [src/engine/modules/MarketEngineUserOpsClaimsModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineUserOpsClaimsModule.sol:107)
- Reentrancy expectations around malicious yield-router callbacks were re-tested against the actual delegatecall architecture and current guards

The latest full suite was previously green at `296/296`, which is a meaningful confidence signal, but not the same as invariant coverage or launch readiness.

## The Real Remaining Risks

### 1. Governance and Upgrade Trust Are Still the Top Risk

This is the single most important unresolved area.

The dispatcher explicitly states that selector wiring and upgrades are equivalent to admin compromise in [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:11). That is not a bug in isolation; it is the trust model. The live concerns are:

- `allowModuleCodeHash`, `registerModule`, and `setSelectorModule` are direct `onlyAdmin` operations with no timelock in [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:77)
- UUPS upgrades are also effectively single-admin authorized in [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:154)
- operationally critical parameter changes such as `setYieldRouter`, oracle replacement, pausing, worker rotation, and treasury rotation are immediate in [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:17)

If this protocol is going to carry meaningful funds, a single admin key with immediate module-routing power is not an acceptable final posture.

### 2. Trusted Reporter Is a Real Centralization / Integrity Risk

The `TrustedReporterAdapter` is honest about its design: one reporter key controls oracle attestations, and owner rotation is the only on-chain recovery path in [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:11).

That leaves several real launch risks:

- reporter key compromise can corrupt every market using that adapter
- reporter unavailability can stall settlement
- owner can rotate reporter immediately via `setTrustedReporter` in [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:76)
- owner can clear pending lock/resolve samples with no emitted event for two of the three clear paths in [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:144)

This is not a false positive. It is a governance and oracle-design risk that should be explicitly accepted or redesigned.

### 3. Yield Router Safety Is Better, but Still Needs Invariant-Level Validation

The current lifecycle code does the right thing in one crucial respect: it does not blindly trust router withdrawal return values, and instead uses token balance deltas during cancel and resolve in [src/engine/modules/MarketEngineCoreLifecycleModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineCoreLifecycleModule.sol:486).

That closes a large class of fake-return-value concerns.

What still remains before calling this area strong:

- accounting invariants across `depositToSide`, `switchSide`, `resolveEpoch`, `cancelEpoch`, `claim`, and rolling execution paths
- explicit failure-mode validation when the router partially returns funds, reverts intermittently, or is operationally disabled
- human review of router assumptions around token behavior, emergency withdraw semantics, and per-template accounting

This area is no longer "obvious exploit likely", but it is still "needs stronger assurance".

### 4. Economic and Timing Assumptions Need a Dedicated Pass

Several low-severity findings are not exploitable coding bugs, but they are still economically relevant:

- very small manual windows
- oracle timing and staleness assumptions
- rolling market timing behavior
- growth of user epoch indexing arrays
- outcome edge cases in niche market types

These are not the first things an attacker uses to steal funds, but they are exactly the kinds of issues that become incidents under production load or adversarial market conditions.

## What I Would Require Before Calling It Strong Enough

### 1. Clean Human Audit Pass on Live Code Only

Do not rely on the Hashlock list as a launch gate.

I would run one focused human pass over:

- dispatcher trust boundary and upgrade flow
- admin-module authority surface
- oracle adapters and cursor semantics
- yield-router accounting transitions
- settlement logic and claim accounting
- rolling lifecycle edge cases

The goal is not another broad scan. The goal is a narrow exploitability review against the actual deployed code path.

### 2. Accounting Invariant Testing

This is the biggest technical gap.

I would want invariant tests that prove conservation properties across:

- `deposit`
- `switch`
- `resolve`
- `cancel`
- `claim`
- yield-router failure
- partial router return
- repeated router failure until disablement

Minimum invariant families:

- `vault.active + vault.claims + vault.fees` always matches ledger-side accounting for the template, modulo externally transferred fees and successful user claims
- `claimLiabilityTotal` and `claimedTotal` never allow overpayment
- refund mode never exceeds originally escrowed stake plus realized net yield actually received
- routed principal cannot remain overstated after any successful resolve/cancel path
- failed router operations never create phantom collateral

Without this layer, the suite is still too example-based for a protocol that mixes user balances, settlement state, and external yield routing.

### 3. Targeted Review of Governance Risk Items

The remaining governance-risk bucket is large, but it is not equally urgent. The first pass should focus on:

- single-admin authority over module registration, selector routing, and upgrades
- lack of timelock for router/oracle/module changes
- trusted-reporter key and owner trust assumptions
- sample-clearing operations and their observability
- pause powers and incident-response authority
- emergency-withdraw and recovery operating model

This should end with an explicit risk register saying which items are:

- accepted by design
- mitigated operationally
- deferred but tolerable
- blockers for launch

### 4. Mainnet Deployment Review

I would not ship this system to meaningful TVL without a deployment-control review covering:

- multisig-only admin
- timelock for upgrades and module/oracle/router changes
- deployment playbook and emergency runbook
- who can pause, under what conditions, and how unpause is governed
- reporter-key rotation process
- router failure recovery process
- monitoring for stale oracle state, repeated router failures, and abnormal claim/liability drift

The code currently supports admin control. It does not by itself enforce production-grade governance discipline.

### 5. Economic Review of Rolling Markets and Oracle Timing

This should be treated as its own audit track.

Items to review:

- whether lock/resolve timing windows can be gamed operationally
- whether rolling keepers can create unfair or brittle timing outcomes
- whether staleness and confidence parameters are economically sane for each market type
- whether edge-case market types can produce poor UX or soft-fund-lock situations even if not direct theft vectors

This is especially important because economic failures often survive conventional code review.

### 6. External Professional Audit If Serious TVL Is Expected

If the plan is:

- public launch
- meaningful deposits
- long-lived upgradeable governance
- routed yield and custom oracle logic

then an external professional audit is still warranted.

This codebase is now at the stage where an external auditor would spend more time on real protocol risk and less time on basic hygiene. That is the correct moment to bring one in.

## Is Hashlock 01-14 "Fully Audited" Yet?

Not in the strict professional sense.

A more accurate statement is:

- the Hashlock 01-14 finding set has been reconciled against live code
- the directly actionable code issues from that set have been triaged and the confirmed ones fixed
- a substantial portion of the remaining list is either duplicate noise, already-fixed issues, or broad claims that overstate exploitability
- the unresolved remainder is mostly governance, oracle trust, deployment discipline, and economic-review work

So if by "fully audited" you mean "sufficiently reconciled to understand what still matters", the answer is close to yes.

If you mean "ready to rely on as the final security sign-off for real TVL", the answer is no.

## Recommended Launch-Stage View

### Good enough for internal / staged testing

Reasonable if all of the following are true:

- limited TVL
- known operators
- multisig already in place
- no assumption that the current docs are the final audit artifact

### Not yet enough for serious public deployment

Not enough yet if any of the following are true:

- a single hot admin key still controls upgrades and module routing
- trusted reporter is single-signer without strong operational controls
- no invariant suite exists for accounting conservation
- no deployment runbook or incident-response process exists
- no external audit is planned despite meaningful TVL

## Bottom Line

The current state is no longer "broadly vulnerable until proven otherwise". It is now "needs a final focused security and governance hardening pass before serious launch".

That is progress, but it is not the same thing as finished.
