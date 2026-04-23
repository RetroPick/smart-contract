# Incident Response

## Objective

Define severity, authority, and communication rules for production incidents.

## Severity Levels

### SEV-1

Definition:

- user funds may be at risk
- settlement may be wrong
- governance compromise suspected
- oracle compromise suspected on live markets

Default action:

- immediate pause unless doing so worsens user harm

### SEV-2

Definition:

- rolling halted
- router degraded
- settlement delayed
- no confirmed loss yet

Default action:

- evaluate pause quickly
- begin runbook execution

### SEV-3

Definition:

- monitoring degraded
- keeper lag
- non-critical operational misconfiguration

Default action:

- repair without emergency control use if safe

## Authority

- admin multisig executes pause/unpause
- worker or operators may escalate, but not unilaterally resume the system
- oracle owner must coordinate on trusted-reporter incidents

## Mandatory Incident Steps

1. Declare severity.
2. Name incident commander.
3. Freeze further unrelated privileged changes.
4. Preserve logs and chain evidence.
5. Execute relevant runbook.
6. Publish internal status updates on fixed cadence.
7. Approve recovery.
8. Publish postmortem.

## Unpause Requirements

- root cause identified
- remediation implemented or risk accepted explicitly
- affected paths smoke-tested
- at least two humans approve resume

## Communication Expectations

For SEV-1 and SEV-2:

- internal notice immediately
- user/public notice if production users are affected
- postmortem required
