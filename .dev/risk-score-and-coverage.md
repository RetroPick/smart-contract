# Risk score (e.g. 0.65) and forge coverage

## Source of the banner

A repository search of this workspace shows **no hook or script** that prints lines like `Analyzed N changed file(s)`, `test gap(s)`, or `Overall risk score` (as of the audit follow-up). That output is almost certainly from **tooling outside this repo**: for example a global git `commit-msg` / `pre-commit` hook, a Cursor/IDE extension, or a **code-review-graph** (or similar) analyzer that runs on `git diff`.

**Interpretation:** the number is a **heuristic process-risk index** (change size, static “test reachability,” graph flow), not a CVSS score or a substitute for a professional audit.

Many such tools **pair a changed file with a co-located test file** by path (e.g. `script/ScriptSelectorMatrix.sol` → `test/script/ScriptSelectorMatrix.t.sol`). References to `ScriptSelectorMatrix.wireAll` only under `test/script/ModularAndYieldScripts.t.sol` may still be reported as **untested** for `ScriptSelectorMatrix.sol`. This repo keeps `test_ScriptSelectorMatrix_wireAll` on `ScriptSelectorMatrixWireIntegrationTest` in `test/script/ScriptSelectorMatrix.t.sol` so those edges exist in the paired file.

## Map to forge coverage

Use Foundry to measure **actual** test coverage of contracts:

```bash
cd "$(git rev-parse --show-toplevel)"
forge coverage --report summary
# Optional: LCOV for CI or HTML
forge coverage --report lcov --report-file lcov.info
```

- **`script/ScriptSelectorMatrix.sol`**: after wiring, `requireAllDelegatedSelectorsWired` and the modular e2e test in `test/script/ModularAndYieldScripts.t.sol` exercise the deployment path. Coverage reports treat **libraries** and **internal** functions according to inlining; e2e tests that call `wireAll` (via `WireModulesModular`) cover the refactored single-source table.
- **Lowering external tool scores** (if the tool keys off “no direct `test_` per symbol”): keep `forge test` and optional **coverage gates** in CI; document the tool name in your global hook config if you need an exact match.
- **Library coverage:** `forge coverage` may report **0% lines** on `script/ScriptSelectorMatrix.sol` even when `wireAll` / `delegatedSelectors` are executed, because library code can be inlined into call sites. Treat **passing** `test/script/ScriptSelectorMatrix.t.sol` and `test_modular_pipeline_endToEnd` as the ground truth for this path.

## Single source of truth

[`script/ScriptSelectorMatrix.sol`](../script/ScriptSelectorMatrix.sol) centralizes delegated selector + module kind in `_delegatedEntry`. `wireAll` and `delegatedSelectors()` both consume it, so **selector drift** between wiring and the validation list is a compile-time / single-function maintenance surface.
