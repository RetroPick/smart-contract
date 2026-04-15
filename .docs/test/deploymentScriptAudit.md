## Deployment Script Control-Plane Audit

Scope:
- `script/*.s.sol`
- `script/production/*.s.sol`
- `script/test/*.s.sol`
- `script/modular/*.s.sol`

### Trust Boundaries
- `admin` controls dispatcher selector wiring through `setSelectorModule`.
- Proxy upgrade authority and selector wiring authority are equivalent critical trust domains.
- Env-driven scripts are part of the protocol control plane; incorrect env can reconfigure live behavior.

### Key Risks Identified
- **Selector drift risk**: duplicated selector wiring blocks across multiple scripts could diverge.
- **Narrowing cast risk**: modular core deploy previously cast env uints without explicit bounds checks.
- **Operator config risk**: mixed worker env naming (`WORKER` vs `WORKER_AUTHORITY`) can cause misconfiguration.
- **Rollback blast radius**: rollback script can remap arbitrary selector/module pairs.
- **Validation depth risk**: modular validate script checks only representative selectors and role fields.

### Mitigations Implemented
- Centralized selector wiring into `script/ScriptSelectorMatrix.sol`.
- Added explicit bounds and zero-address guards in modular preflight/core deploy paths.
- Added worker env fallback (`WORKER_AUTHORITY` or `WORKER`) while enforcing nonzero value.
- Added script events for deterministic test assertions (`DeploymentCompleted`, `UpgradeCompleted`, etc.).
- Added dedicated script-level test suites covering success paths and critical reverts.
