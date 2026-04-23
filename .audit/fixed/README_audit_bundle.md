# RetroPick Audit Bundle

This directory contains the current security-review bundle for the RetroPick MarketEngine V1 contracts.

## Included Artifacts

- [1_byHashLock.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_byHashLock.md)
The reconciled finding matrix. This is the compact source-of-truth table that maps each Hashlock-listed issue and each GPT-5.4 attacker-mode finding to:
  - severity
  - status
  - short note
  - affected file(s)
  - test path(s)

- [1_Report.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_Report.md)
The full narrative audit report. This is the main human-readable artifact and should be treated as the primary report for reviewers, operators, partners, and external auditors.

- [future_artifact_production_grade.md](/home/asyam/dev/Project/RetroPick/V1/contract/future_artifact_production_grade.md)
The deeper production-grade hardening and future-work artifact. This is useful for understanding the broader engineering roadmap and the reasoning behind the later attacker-mode hardening work.

- [production_readiness_verdict.md](/home/asyam/dev/Project/RetroPick/V1/contract/production_readiness_verdict.md)
Short-form production-readiness view focused on whether the protocol is ready to launch and under what assumptions.

- [launch_gate_checklist.md](/home/asyam/dev/Project/RetroPick/V1/contract/launch_gate_checklist.md)
Operational launch checklist for the centralized deployment model.

## Recommended Reading Order

1. Start with [1_Report.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_Report.md)
This gives the best full-picture understanding:
  - architecture
  - scope
  - methodology
  - findings
  - residual risk
  - production-readiness conclusion

2. Then review [1_byHashLock.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_byHashLock.md)
Use this to verify the exact reconciliation status for each listed vulnerability and to locate the corresponding test and file quickly.

3. Then review [production_readiness_verdict.md](/home/asyam/dev/Project/RetroPick/V1/contract/production_readiness_verdict.md) and [launch_gate_checklist.md](/home/asyam/dev/Project/RetroPick/V1/contract/launch_gate_checklist.md)
These are the most useful artifacts for launch decision-makers and operators.

4. Use [future_artifact_production_grade.md](/home/asyam/dev/Project/RetroPick/V1/contract/future_artifact_production_grade.md) for deeper engineering context
This is the best reference for why some residual work is now more invariant-level and operational rather than another obvious single-call exploit.

## How the Artifacts Relate

- `1_byHashLock.md` is the matrix
- `1_Report.md` is the narrative report derived from that matrix
- the production and launch docs describe what still matters after code hardening

In short:

- matrix for reconciliation
- report for explanation
- readiness docs for launch and operational judgment

## Current Security Interpretation

The most important practical conclusion from this bundle is:

- many originally catalogued issues were already fixed in the live code
- the meaningful live findings confirmed during the deeper attacker-mode pass were concentrated in:
  - routed principal recovery
  - rolling reset safety
  - trusted-reporter replay invalidation
  - oracle continuity and correction flows
- those issues were fixed and regression-tested
- the strongest residual risks are governance and operational risks tied to the intentionally centralized architecture

## Notes on Evidence

The report and matrix intentionally reference concrete Foundry tests wherever possible. For most important fixed findings, the intended verification trail is:

1. read the finding in [1_Report.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_Report.md)
2. confirm the status and file/test linkage in [1_byHashLock.md](/home/asyam/dev/Project/RetroPick/V1/contract/1_byHashLock.md)
3. inspect the named Solidity file and referenced test file

## CSV Status

A `hashlock_reconciliation.csv` file is not currently included in this bundle.

If needed, it can be generated from the reconciled matrix with columns such as:

- `doc`
- `severity`
- `finding`
- `status`
- `note`
- `file`
- `test`

## Intended Audience

This bundle is suitable for:

- internal engineering review
- multisig signers and protocol operators
- partner diligence
- external professional auditors as prior-art context

For a centralized serious-TVL deployment, the report should be read together with the operational readiness artifacts, not in isolation.
