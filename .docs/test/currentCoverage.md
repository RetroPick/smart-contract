Latest `forge coverage` (production contracts only: `src/`, excluding `src/test/` and `script/`)

Baseline (before expansion): `78.44%` lines, `72.21%` statements, `33.49%` branches, `72.55%` funcs

Current aggregate:
- Lines: `87.33%` (`1289/1476`)
- Statements: `80.73%` (`1487/1842`)
- Branches: `45.95%` (`187/407`)
- Functions: `87.03%` (`161/185`)

| File | % Lines | % Statements | % Branches | % Funcs |
|---|---:|---:|---:|---:|
| `src/adapters/ChainlinkAdapter.sol` | 98.21% (55/56) | 91.89% (68/74) | 64.71% (11/17) | 100.00% (7/7) |
| `src/engine/MarketEngineDispatcher.sol` | 88.00% (44/50) | 89.39% (59/66) | 54.55% (6/11) | 81.82% (9/11) |
| `src/engine/MarketEngineState.sol` | 83.33% (5/6) | 100.00% (6/6) | 100.00% (1/1) | 66.67% (2/3) |
| `src/engine/modules/MarketEngineAdminModule.sol` | 88.73% (63/71) | 82.42% (75/91) | 64.00% (16/25) | 100.00% (10/10) |
| `src/engine/modules/MarketEngineCoreLifecycleModule.sol` | 83.86% (291/347) | 75.34% (333/442) | 42.86% (48/112) | 100.00% (28/28) |
| `src/engine/modules/MarketEngineRollingLifecycleModule.sol` | 90.20% (368/408) | 81.46% (391/480) | 40.87% (47/115) | 96.97% (32/33) |
| `src/engine/modules/MarketEngineUserOpsClaimsModule.sol` | 91.22% (135/148) | 79.47% (151/190) | 41.67% (20/48) | 100.00% (11/11) |
| `src/libraries/YieldAccounting.sol` | 85.00% (17/20) | 78.57% (22/28) | 50.00% (2/4) | 83.33% (5/6) |
| `src/math/MarketMath.sol` | 79.52% (66/83) | 73.74% (73/99) | 52.94% (9/17) | 77.78% (14/18) |
| `src/yield/YieldRouterAaveV3.sol` | 75.36% (52/69) | 83.78% (62/74) | 62.50% (5/8) | 57.89% (11/19) |
| `src/yield/YieldRouterV2.sol` | 86.71% (124/143) | 86.24% (163/189) | 51.72% (15/29) | 71.43% (15/21) |