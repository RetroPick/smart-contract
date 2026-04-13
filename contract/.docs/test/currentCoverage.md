Latest `forge coverage` (production contracts only: `src/`, excluding `src/test/` and `script/`)

Baseline (before expansion): `78.44%` lines, `72.21%` statements, `33.49%` branches, `72.55%` funcs

Current aggregate:
- Lines: `86.65%` (`1279/1476`)
- Statements: `80.08%` (`1475/1842`)
- Branches: `44.23%` (`180/407`)
- Functions: `86.49%` (`160/185`)

| File | % Lines | % Statements | % Branches | % Funcs |
|---|---:|---:|---:|---:|
| `src/adapters/ChainlinkAdapter.sol` | 98.21% (55/56) | 91.89% (68/74) | 64.71% (11/17) | 100.00% (7/7) |
| `src/engine/modules/MarketEngineAdminModule.sol` | 88.73% (63/71) | 82.42% (75/91) | 64.00% (16/25) | 100.00% (10/10) |
| `src/engine/modules/MarketEngineCoreLifecycleModule.sol` | 81.56% (283/347) | 73.53% (325/442) | 39.29% (44/112) | 100.00% (28/28) |
| `src/engine/modules/MarketEngineRollingLifecycleModule.sol` | 90.20% (368/408) | 81.46% (391/480) | 40.87% (47/115) | 96.97% (32/33) |
| `src/engine/modules/MarketEngineUserOpsClaimsModule.sol` | 91.22% (135/148) | 79.47% (151/190) | 41.67% (20/48) | 100.00% (11/11) |
| `src/libraries/YieldAccounting.sol` | 85.00% (17/20) | 78.57% (22/28) | 50.00% (2/4) | 83.33% (5/6) |
| `src/math/MarketMath.sol` | 79.52% (66/83) | 73.74% (73/99) | 52.94% (9/17) | 77.78% (14/18) |
| `src/yield/YieldRouterAaveV3.sol` | 75.36% (52/69) | 83.78% (62/74) | 62.50% (5/8) | 57.89% (11/19) |
| `src/yield/YieldRouterV2.sol` | 86.71% (124/143) | 86.24% (163/189) | 51.72% (15/29) | 71.43% (15/21) |