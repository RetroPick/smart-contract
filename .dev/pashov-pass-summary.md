# Pashov-style audit pass (condensed)

This is a **single-engineer structured pass** aligned with [`.agents/vendor/pashov-skills/solidity-auditor/SKILL.md`](../../.agents/vendor/pashov-skills/solidity-auditor/SKILL.md) (judging gates, multi-dimension themes) and [`.agents/skills/solidity-security-best-practices/SKILL.md`](../../.agents/skills/solidity-security-best-practices/SKILL.md). It is **not** a substitute for spawning eight parallel agents or an external audit firm.

## Scope

- **In scope:** `src/**/*.sol` — **43** Solidity files at last count (production contracts; tests and mocks excluded from Pashov’s default exclude list).
- **Periphery reviewed with this change:** [`script/ScriptSelectorMatrix.sol`](../../script/ScriptSelectorMatrix.sol) (deployment wiring; single `_delegatedEntry` table driving `wireAll` and `delegatedSelectors`).

## Judging gates (abbreviated application)

| Theme | Verdict |
|-------|---------|
| **Access control** (`MarketEngineDispatcher`) | `allowModuleCodeHash`, `registerModule`, `setSelectorModule` are **`onlyAdmin`**. Root-owned selectors cannot be rebound via `setSelectorModule`. Unprivileged users cannot change module wiring. **Gate 3 (unprivileged trigger):** no path for non-admin to set delegate targets. |
| **Delegatecall / storage** | `_delegateForSelector` requires **approved** module + **matching code hash** + **storage compatibility** marker. Wrong module still requires admin to have registered it — **privileged** mistake, not unprivileged exploit. |
| **Script layer** | `ScriptSelectorMatrix.wireAll` runs in **broadcast** context as **admin**; operational risk is misconfiguration, mitigated by hash locking + refactored single table + `requireAllDelegatedSelectorsWired` / e2e tests. |
| **Economic / yield** | Not re-audited in full in this pass; existing suites (`test/invariants/`, yield security tests) remain the authority. |

**Net:** No new **unprivileged** high-severity path identified in the scoped review. Residual risk remains **admin key compromise**, **UUPS upgrade**, and **module bytecode** trust — as documented in dispatcher natspec.

## Follow-ups (optional, full Pashov skill)

- Run the skill’s **Turn 1–4** flow (source bundles + eight agent dimensions + `judging.md` single-pass) before mainnet, if a full-strength internal review is required.
- Keep **forge** + **invariant** tests green in CI; treat external “risk score” tools as process signals ([`.dev/risk-score-and-coverage.md`](./risk-score-and-coverage.md)).
