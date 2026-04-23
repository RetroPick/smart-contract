# Monitoring Alert Specification

## Objective

Define the minimum monitoring package required for public operation.

## Critical Alerts

### Governance / privileged actions

- dispatcher upgrade executed
- module registered
- selector remapped
- oracle replaced
- yield router replaced
- treasury changed
- worker changed
- oracle cursor reset

### Lifecycle health

- `RollingHalted`
- unresolved epoch backlog exceeds threshold
- repeated lifecycle revert on keeper path

### Yield-router health

- `YieldRouterWithdrawFailed`
- `YieldRouterFailureRecorded`
- `YieldRouterDisabled`
- `YieldEmergencyWithdrawn`

### Oracle / settlement health

- reporter rotation
- trusted-reporter sample clear action
- abnormal increase in stale oracle failures
- oracle monotonicity failure

### Claims and accounting health

- abnormal claim failure rate
- fee withdrawal outside planned window
- vault reconciliation mismatch detected by off-chain checker

## Monitoring Outputs

- dashboard for live protocol health
- paging for critical alerts
- retained incident log
- daily reconciliation report

## Current Gap

Many useful events already exist, but not all sensitive correction flows are fully observable. This spec should be paired with event-coverage review before production launch.
