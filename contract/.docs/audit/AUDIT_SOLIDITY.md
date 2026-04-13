# RetroPick MarketEngine (Solidity) — engineer-led review

This document is an **internal design and security review** of the Foundry port in this repository. It is **not** a substitute for an independent professional audit before mainnet deployment with material value.

## Threat model

- **Roles**: **`admin`** (protocol + **UUPS upgrade** authority), `workerAuthority`, `treasury`. There is **no** persistent `deployer` role: the engine uses `initialize` once behind an ERC1967 proxy (atomic deploy+init recommended). `admin` and `workerAuthority` can open/lock/resolve/cancel epochs; only `admin` manages templates and pause (user-facing worker paths respect pause); `treasury` or `admin` may withdraw fee reserves. **`admin` also governs `setDepositExecutor`** (allowlisted contracts may call `depositToSideFor` to credit a beneficiary); compromise of an allowlisted router is a separate trust surface — see [`.docs/abstraction/`](./abstraction/README.md).
- **Oracle**: The engine trusts `IPriceOracle` (production: [`ChainlinkAdapter`](src/adapters/ChainlinkAdapter.sol)) to return **e8** prices with timestamps consistent with the on-chain clock. A malicious or buggy oracle adapter can mis-resolve markets. Checkpoint **confidence** is stored as **uint128**; the Chainlink adapter returns **zero** confidence—configure `oracleMaxConfidenceBps` accordingly.
- **Token**: The implementation uses **standard `ERC20`** (`transfer` / `transferFrom`). **Fee-on-transfer and rebasing tokens are not supported** without additional balance reconciliation.
- **Framing / ordering**: `initialize` is **`initializer`**-gated (once per proxy). If someone deploys an **uninitialized** implementation or leaves a proxy uninitialized, it can be taken over — **mitigation**: use OpenZeppelin Foundry Upgrades / ERC1967 proxy **constructor data** so the proxy is initialized in the **same** transaction as creation, or a private mempool / bundled deploy.

## Structured internal review (audit map)

Internal pass aligned with Solidity security skills (CEI ordering, reentrancy surfaces, role boundaries, proxy rules). Not a substitute for an external audit.

| Boundary | What to verify | Primary locations |
|----------|----------------|-------------------|
| Asset custody | Vault `active` / `claims` / `fees` vs `stakeToken` balance; claim/fee withdrawal does not double-pay | [`MarketEngine.sol`](../src/MarketEngine.sol) (`claim`, `withdrawFees`, resolve/cancel paths) |
| Oracle trust | Staleness, publish-time ordering vs checkpoints, confidence vs price magnitude | [`ChainlinkAdapter.sol`](../src/adapters/ChainlinkAdapter.sol), [`MarketTypes.validateCheckpoint*PublishTime`](../src/types/MarketTypes.sol) |
| Roles | `onlyAdmin`, `onlyWorkerOrAdmin`, `onlyTreasuryOrAdmin`, deposit executor allowlist | Modifiers and gated setters in [`MarketEngine.sol`](../src/MarketEngine.sol) |
| Reentrancy | External calls only after state updates where applicable; `nonReentrant` on token-moving paths | Token transfers, oracle `view` calls |
| Upgrades | UUPS `_authorizeUpgrade` only `admin`; storage gap; no new state before `__gap` without layout discipline | [`MarketEngine.sol`](../src/MarketEngine.sol) |

**CEI / reentrancy:** User-facing value movement (`claim`, deposits, switches, fee withdraw) uses `nonReentrant` where external ERC20 calls occur; view-only oracle reads do not reenter.

**UUPS:** Implementation is `Initializable` with `_disableInitializers()` in the constructor; proxy must be initialized atomically with deploy or in the same bundle—see *Threat model* above.

## Behavioral parity (vs Anchor `market_engine` v5)

- Epoch sequencing, deposits, switches (ceil fee), lock with optional checkpoint A for `Direction`, resolve with checkpoint B, void/refund path, cancel, claim with last-winner dust sweep, and per-template vault accounting are intended to match the Rust reference.
- Templates mirror `upsert_template` with `equalPriceVoids` and `feeOnLosingPool` forced **true**.

## Checklist (manual)

- [x] Reentrancy: `nonReentrant` on token-moving paths; external calls after state updates where applicable.
- [x] Integer safety: Solidity 0.8 checked arithmetic; explicit underflow checks in ledger helpers.
- [x] Access control: modifiers aligned with Anchor (`Unauthorized` patterns).
- [x] Pause: User ops (`deposit`, `switch`) and worker ops (`open`, `lock`, `resolve`) honor `globalPaused`; cancel/claim/fee withdraw match Anchor (no pause on cancel/claim/withdraw).
- [x] Oracle: Staleness via Chainlink `updatedAt` vs `maxDelaySeconds`; confidence versus `|priceE8| * maxConfidenceBps / 10_000` (often unused when adapter returns zero confidence).
- [ ] Economic edge cases: multi-template aggregate ERC20 balance vs. sum of internal vaults should be monitored off-chain; rounding dust is swept on the final winner claim.

## Static analysis (Slither)

Install [Slither](https://github.com/crytic/slither) and run from this package root:

```bash
pip install slither-analyzer
slither . --config-file slither.config.json
```

[`slither.config.json`](../slither.config.json) sets `filter_paths` to **`lib/|test|script/`** so reports focus on [`src/`](../src/) (dependencies and tests are excluded from analysis). `exclude_dependencies` is enabled where supported.

**Triage (do not treat as vulnerabilities without review):**

- **`incorrect-equality` / `timestamp` on `e.marketType`**: enum dispatch for resolve branches; Slither also groups unrelated comparisons under `timestamp` for the same function.
- **`uninitialized-local`**: addressed where appropriate via explicit zero-init or storage-to-memory copy; remaining cases are static-analysis limits (e.g. try/catch assignment).
- **`unused-return`** on `MarketMath.computeEpochClaimLiabilityStorage`**: third return is `distributableLosingPool`; resolve accounting only needs claim liability + settlement fee. [`ChainlinkAdapter`](../src/adapters/ChainlinkAdapter.sol) ignores Aggregator tuple slots documented at each call.
- **`calls-loop`**: batch keeper entrypoints intentionally call the oracle per item; bound batch sizes operationally.
- **`naming-convention` / `unused-state` on `__gap`**: intentional UUPS storage reservation.
- **OpenZeppelin / Chainlink under `lib/`**: excluded from scope when using the config above.

**Code hardening from Slither-driven review:** [`ChainlinkAdapter`](../src/adapters/ChainlinkAdapter.sol) reverts if the sequencer uptime feed reports **up** (`answer == 0`) but **`startedAt == 0`**, which would otherwise skip the post-recovery grace semantics.

**Remaining informational findings (expected):** with the config above, Slither typically still reports on the order of **~15** items in `src/`, mainly **`calls-loop`** (batch keepers), **`timestamp`** (epoch scheduling), and **`cyclomatic-complexity`** on large functions. Treat these as design/gas notes, not automatic vulnerabilities. Slither may exit non-zero when any findings remain—use exit codes in CI only after agreeing a threshold.

The repository may add a **manual** GitHub Actions workflow (`workflow_dispatch`) for Slither; failing rules should be triaged, not blindly ignored.

### Halmos (symbolic tests)

[Halmos](https://github.com/a16z/halmos) expects at least one Foundry test whose name matches `check_*` or `invariant_*`. A minimal smoke test lives in [`test/halmos/HalmosSmoke.t.sol`](../test/halmos/HalmosSmoke.t.sol). Run `halmos --contract HalmosSmokeTest` (or `halmos` after adding more `check_*` specs). Extend with real properties and optional `halmos-cheatcodes` as needed.

## Integration guidance

- Approve the engine **only for intended deposit amounts** (avoid infinite approvals to the market contract).
- Verify **Chainlink feed proxy addresses** and **heartbeat** per chain using [Chainlink data feed addresses](https://docs.chain.link/data-feeds/price-feeds/addresses).

## Known limitations

- **UUPS upgrades**: **`admin` can change implementation** — compromised or malicious `admin` can brick or steal funds via a bad upgrade. Mitigate with multisig, operational policy, timelocks off-chain, and upgrade rehearsal on testnets. Run OpenZeppelin storage/layout checks (`forge script` / `--ffi`) before production upgrades.
- **Implementation bytecode** may sit **near or above** the EIP-170 24 576 B runtime cap depending on compiler profile; use [`deploybudget`](../foundry.toml) and [`script/check-contract-sizes.sh`](../script/check-contract-sizes.sh); see [DEPLOYMENT_AND_EPOCHS.md](./DEPLOYMENT_AND_EPOCHS.md).
- `via_ir = true` is enabled in `foundry.toml` to avoid stack-too-deep in `resolveEpoch`; review optimizer settings for production deployments.
