# Oracle Configuration Matrix

## Objective

Track the exact settlement data path for every market family and template category.

This file is a required launch artifact because settlement correctness depends on:

- adapter choice
- feed identity
- max delay
- confidence threshold
- sequencer dependency
- trusted-reporter policy where applicable

## Oracle Families

| Oracle family | Contract surface | Trust model | Primary risks |
| --- | --- | --- | --- |
| Chainlink price | `priceOracle` | decentralized external feed with adapter checks | staleness, wrong feed config, sequencer edge cases |
| Chainlink rate | `rateOracle` | decentralized external feed with adapter checks | wrong adapter assignment, stale rate interpretation |
| Chainlink smart data | `smartDataOracle` | decentralized external feed with adapter checks | feed mapping and semantic mismatch |
| Chainlink macro | `macroOracle` | decentralized external feed with adapter checks | event timing and feed interpretation |
| Chainlink equity | `equityOracle` | decentralized external feed with adapter checks | market-hours semantics and staleness |
| Trusted reporter | `eventOracle` on template | centralized signer and owner-controlled correction path | key compromise, correction abuse, opaque operations |

## Required Per-Template Fields

Each launched template must record:

- `templateId`
- slug
- execution mode
- market type
- oracle class
- oracle family address
- feed identifier
- `oracleMaxDelaySeconds`
- `oracleMaxConfidenceBps`
- whether sequencer feed applies
- whether round monotonicity is expected
- whether trusted-reporter correction path exists

## Review Questions

Before launch of any template:

1. Is the selected oracle class the intended data source?
2. Is the feed identifier mapped to the correct asset or metric?
3. Is `oracleMaxDelaySeconds` economically sane for this market?
4. Is `oracleMaxConfidenceBps` strict enough for settlement?
5. If L2 is used, are sequencer downtime assumptions documented?
6. If trusted reporter is used, is the centralization justified and disclosed?

## Minimum Monitoring

- stale oracle reads
- monotonicity violations
- oracle-cursor resets
- rolling halts caused by oracle failure
- trusted-reporter correction actions

## Current Gap

The code supports multiple oracle families cleanly, but production safety still depends on off-chain configuration quality. This matrix must be populated before public launch.
