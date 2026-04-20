# RetroPick V1 Operations Index

## Purpose

This file is the entry point for the RetroPick V1 production operations document set.

It is intended for:

- protocol operators
- Safe signers
- governance reviewers
- treasury operators
- oracle operators
- external auditors reviewing live operational readiness

The goal is simple:

- tell each reader what to read first
- tell them which document answers which question
- make the production bundle usable during both normal operation and incidents

## Core Principle

RetroPick V1 is a centralized, operator-controlled protocol.

That means the production document set is part of protocol security.

Read these docs as operational controls, not just reference notes.

## Reading Order

### 1. Production Overview

Read first:

- [.production.md](/home/asyam/dev/Project/RetroPick/V1/contract/.production.md:1)

Use this when you need the complete end-to-end production picture:

- Safe setup
- governance topology
- mainnet deployment
- post-deploy validation
- maintenance expectations
- upgrade posture

### 2. Live Operations

Read second:

- [.runbook.md](/home/asyam/dev/Project/RetroPick/V1/contract/.runbook.md:1)

Use this for:

- day-to-day operations
- pause / unpause handling
- router incidents
- oracle incidents
- rolling lifecycle incidents
- trusted-reporter incident handling

### 3. Governance and Change Control

Read when approving privileged actions:

- [.governance.md](/home/asyam/dev/Project/RetroPick/V1/contract/.governance.md:1)

Use this for:

- Safe governance policy
- change classes
- approval thresholds
- upgrade and router/oracle/module governance
- recordkeeping requirements

### 4. Oracle and Reporter Operations

Read when managing settlement infrastructure:

- [.oracle_ops.md](/home/asyam/dev/Project/RetroPick/V1/contract/.oracle_ops.md:1)

Use this for:

- oracle matrix operations
- adapter replacement rules
- cursor reset rules
- trusted-reporter key management
- correction procedures

### 5. Module Release Control

Read before any module onboarding or selector change:

- [.module_release.md](/home/asyam/dev/Project/RetroPick/V1/contract/.module_release.md:1)

Use this for:

- bytecode release discipline
- code-hash allowlisting
- module registration
- selector manifest control
- rollback planning

## Audit and Security Context

These documents explain why the production controls above are necessary.

### Main Narrative Audit Report

- [1_Report.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_Report.md:1)

Use this for:

- architecture
- findings
- technical vulnerability analysis
- remediation status
- production-readiness interpretation

### Finding Reconciliation Matrix

- [1_byHashLock.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_byHashLock.md:1)

Use this for:

- row-by-row vulnerability tracking
- status lookup
- affected files
- related test paths

## Deployment and Code Surfaces

These files are the primary live-code references for operators.

### Production Deploy Script

- [script/production/DeployProduction.s.sol](/home/asyam/dev/Project/RetroPick/V1/contract/script/production/DeployProduction.s.sol:1)

### Production Upgrade Script

- [script/production/UpgradeProduction.s.sol](/home/asyam/dev/Project/RetroPick/V1/contract/script/production/UpgradeProduction.s.sol:1)

### Dispatcher

- [src/engine/MarketEngineDispatcher.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineDispatcher.sol:1)

### Admin Module

- [src/engine/modules/MarketEngineAdminModule.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/modules/MarketEngineAdminModule.sol:1)

### Trusted Reporter Adapter

- [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:1)

## Environment Templates

Use these as the starting point for real deployments:

- [.env.base-mainnet.example](/home/asyam/dev/Project/RetroPick/V1/contract/.env.base-mainnet.example:1)
- [.env.example](/home/asyam/dev/Project/RetroPick/V1/contract/.env.example:1)

## Which Document To Use By Situation

### “We are preparing a mainnet launch.”

Read:

- `.production.md`
- `.governance.md`
- `.runbook.md`

### “We need to sign an upgrade or module change.”

Read:

- `.governance.md`
- `.module_release.md`
- `.production.md`

### “Router failed or recovery is needed.”

Read:

- `.runbook.md`
- `.production.md`

### “We need to rotate or correct the trusted reporter.”

Read:

- `.oracle_ops.md`
- `.runbook.md`
- `.governance.md`

### “Auditor or reviewer wants to understand why these controls exist.”

Read:

- `1_Report.md`
- `1_byHashLock.md`
- `.production.md`

## Minimum Mandatory Set For Production Operators

Every operator with privileged influence should read:

1. `.production.md`
2. `.runbook.md`
3. `.governance.md`

Additional mandatory reading by role:

- oracle operators: `.oracle_ops.md`
- governance reviewers and signers: `.module_release.md`
- auditors and technical reviewers: `1_Report.md`

## Maintenance

Whenever any of the following change, this index should be updated:

- production document filenames
- deployment scripts
- privileged control surfaces
- audit artifact names
- live governance model

## Final Note

If a signer or operator cannot identify which document governs the action they are about to take, they should stop and escalate before acting.
