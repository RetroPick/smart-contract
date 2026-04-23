# Trusted Reporter Operations

## Objective

Define the operational model for markets that use `TrustedReporterAdapter`.

Reference:

- [src/oracle/TrustedReporterAdapter.sol](/home/asyam/dev/Project/RetroPick/V1/contract/src/oracle/TrustedReporterAdapter.sol:11)

## Trust Statement

Markets using the trusted-reporter path are not trust-minimized in the same way as Chainlink-family markets.

Users must assume:

- one reporter key can attest settlement-relevant payloads
- owner can rotate the reporter
- owner can clear pending samples before engine consumption

This is a design choice, not an implementation accident.

## Roles

### Reporter

Can:

- sign lock samples
- sign resolve results
- sign OHLC results

Cannot:

- directly change on-chain config

### Oracle Owner

Can:

- set trusted reporter
- set max signature age
- clear lock sample
- clear resolve result
- clear OHLC result

## Required Operational Controls

- reporter key stored in hardened signing environment
- owner key controlled by multisig or equivalent governance
- written approval process for reporter rotation
- written approval process for sample clearing
- incident log for every correction action

## Allowed Uses Of Clear Operations

`clearLockSample` or `clearResolveResult` may only be used for:

- objectively wrong submission
- reporter key compromise response
- testnet recovery

They must not be used for:

- discretionary market outcome changes
- silent operator overrides
- informal retry without incident logging

## Required Process For Correction

1. Declare incident or correction case.
2. Record market/template/epoch affected.
3. Record why the original sample is incorrect.
4. Execute clear action.
5. Re-post corrected data if appropriate.
6. Publish operator note internally, and publicly if production funds are affected.

## Recommended Hardening

- emit events for all clear actions
- narrow use of trusted-reporter markets until operations mature
- prefer Chainlink-family sources for higher-value templates

## Launch Gate

No public trusted-reporter market should go live without:

- named owner control body
- named reporter rotation process
- written sample-clearing policy
- monitoring for every clear action
