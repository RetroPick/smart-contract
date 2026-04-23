# Parameter Bounds Review

## Objective

Review whether protocol constants and template-level bounds are economically and operationally sane.

Reference constants:

- [src/engine/MarketEngineState.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/engine/MarketEngineState.sol:23)

## Parameters Requiring Sign-Off

### Global constants

- `MAX_BATCH_SIZE`
- `MIN_MANUAL_DEPOSIT_WINDOW`
- `MIN_MANUAL_LOCK_WINDOW`
- `MAX_MANUAL_EPOCH_DURATION`
- `MIN_ROLLING_INTERVAL_SECONDS`
- `MAX_ROLLING_INTERVAL_SECONDS`
- `MAX_YIELD_ROUTER_FAILURES`
- `YIELD_BUFFER_BPS`

### Template-level bounds

- `oracleMaxDelaySeconds`
- `oracleMaxConfidenceBps`
- `rollingIntervalSeconds`
- `rollingBufferSeconds`
- `switchFeeBps`
- `settlementFeeBps`

## Review Questions

1. Are manual windows too short for fair user participation?
2. Are rolling buffers wide enough for keeper latency and chain conditions?
3. Are oracle delay limits strict enough to reject stale settlement?
4. Are confidence bounds too permissive or too brittle?
5. Can fee settings create poor UX or unexpected user outcomes?

## Required Output

For each launched template family:

- parameter values
- justification
- reviewer
- date approved

## Current Gap

The code exposes sensible constraints, but production-grade launch requires a written parameter rationale, not just defaults in Solidity.
