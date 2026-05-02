<claude-mem-context>
# Memory Context

# [contract] recent context, 2026-04-22 4:26pm GMT+7

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (21,370t read) | 444,320t work | 95% savings

### Apr 18, 2026
S1 User requested memory check — no prior memories exist for this project (Apr 18, 10:14 AM)
S3 Memory status check — user asked "memory" to see what has been persisted across sessions (Apr 18, 10:27 AM)
40 10:16p 🔴 resolveEpoch Reentrancy Guard Not Blocking withdrawScaled Reentry — Confirmed Failing Test
42 10:17p 🔵 resolveEpoch Reentrancy Root Cause: withdrawScaled Wrapped in try/catch, Allows Callback to depositToSideFor
50 10:18p 🔵 Dispatcher Module Architecture: resolveEpoch and depositToSideFor Live in Different Delegatecall Modules, Breaking Cross-Module Reentrancy Guard
51 10:20p 🔴 Four Security Fixes Applied: Oracle Cursor Reset, claimMany Soft-Skip, Allowance Cleanup, Reentrancy Test Redesign
57 10:21p ✅ Full Test Suite Green: 296/296 Tests Pass Across 42 Suites After Security Fixes
60 10:22p 🔵 Full Hashlock Audit Document Index: 14 Files, Critical/High/Medium/Low/Gas/Info Findings Enumerated
62 10:24p 🔵 TrustedReporterAdapter Findings: clearOhlcResult Already Fixed; clearLockSample/clearResolveResult Still Emit No Events
### Apr 21, 2026
65 8:45p 🔵 RetroPick V1 MarketEngine Yield Routing Architecture
66 " 🔵 RetroPick V1 Epoch Settlement and Claim Flow
67 8:46p 🔵 RetroPick V1 Emergency Yield Recovery Flow
68 " 🔵 RetroPick V1 Ledger Accounting Buckets: active / claims / fees
69 " 🔵 RetroPick V1 Agent Skills Infrastructure for Security Auditing
70 8:50p 🔵 YieldRouterV2 Architecture: Dual-Path Aave v3 Yield Router
71 " 🔵 MarketEngine YieldRouter Shortfall: Adversarial Boundary Tests
72 " 🔵 MarketEngine Emergency Recovery Flow: Multi-Step Router Failure Protocol
73 " 🔵 Invariant Test Suite: MarketEngineRoutedRecoveryHandler with Chaos Router
74 8:57p ✅ Documentation Restructure: Root Markdown Files Deleted, New .dev/ and .operator/ Dirs Added
75 " 🔵 YieldAccounting Library: Ray Math for Aave v3 Scaled Balance Operations
76 " 🔵 IYieldRouterV2 Interface: Extended Yield Router with LM Rewards and Path Selection
77 " 🔵 MarketTypes.Epoch Struct: Dense Packed Storage with routedPrincipal Field
78 8:58p 🔵 Two Aave V3 Router Implementations: Legacy YieldRouterAaveV3 vs YieldRouterV2
79 " 🔵 MockYieldRouterReentrant: Reentrancy Attack Vector Tests via depositToSideFor Callback
80 9:00p 🔵 IMarketEngine Interface: Rich View Layer with Operator, Yield, and Position Structs
81 " 🟣 IYieldRouterV2 Extended with Sub-Bucket Accounting Functions
82 " 🔵 MarketEngineAdminModule: Emergency Recovery Implementation with Balance-Delta Safety
83 9:01p 🟣 YieldRouterV2: Implemented depositDetailed, withdrawDetailed, withdrawAttribution, previewValueByAttribution
84 " 🟣 YieldRouterAaveV3: Implemented IYieldRouterV2 Sub-Bucket Accounting Functions
85 9:02p ✅ Test Mock Routers Updated to Implement Extended IYieldRouterV2 Interface
86 " ✅ MockLyingEmergencyYieldRouter and MockViewYieldRouter Updated for IYieldRouterV2 Extended Interface
87 " ✅ MockYieldRouterReentrant Extended: Reentrancy Attack Now Covers depositDetailed and withdrawDetailed/withdrawAttribution
88 9:03p 🟣 MarketEngineState: SettledClaimRouting Struct and Per-Epoch Settled Claims State Added
89 " ✅ SettledClaimRouting State Repositioned After Yield Router Fields for Storage Layout Safety
90 " 🟣 MarketMath: computeTotalUserEntitlementResolvedStorage Added for Storage-Reference Entitlement Calculation
91 " 🟣 _tryRouteSettledClaimsAfterSettlement: Engine Re-Routes Settled Claim Liabilities Back Into Yield Router
92 9:04p 🟣 _claimOneRoutedSettled: Claim Payout Path Now Draws from Yield Router via withdrawAttribution
93 9:05p 🟣 Settled Claim Routing Hooked into All Epoch Settlement Paths: Cancel, Resolve, Rolling Cancel, Rolling Resolve
94 " 🔵 Full Forge Build Passes After IYieldRouterV2 Extension and Settled Claim Routing Implementation
95 " 🔴 Two Accounting Corrections in Settled Claim Routing: Refund Mode Gate and claimedTotal Tracking
96 9:06p 🟣 recoverRoutedSettledClaims: Admin Recovery Path for Failed Settled Claim Router Positions
97 " ✅ Test Dispatcher Setup Updated: recoverRoutedSettledClaims Selector Registered in Test Bases
98 9:07p 🔴 Compile Error: baseEntitlement Patch Applied to Wrong Function in _claimOne
99 " 🔴 claimedTotal Swap Patch Hit Wrong Pair: _claimOneIfClaimable Now Has Undeclared baseEntitlement
100 9:08p 🔴 Stack Too Deep in _claimOneRoutedSettled: Too Many Local Variables Without viaIR
101 " 🔵 _claimOneRoutedSettled Refactor Patch Failed to Apply: Original Monolithic Body Persists
102 9:09p 🔴 Stack Too Deep Fixed: _claimOneRoutedSettled Refactored into Three Helper Functions
103 9:10p 🔵 MockAavePool and MockAToken: Simplified Test Aave Infrastructure with Yield Simulation
104 " 🟣 _tryRouteSettledClaimsAfterSettlement Hardened with Balance-Delta Invariant Check on depositDetailed
105 9:11p 🟣 New Test Suite: MarketEnginePostResolveClaimsYieldTest — Post-Settlement Yield and Recovery Flows
106 " 🔴 MarketEnginePostResolveClaimsYieldTest: All 3 Tests Pass After vm.startPrank/stopPrank Fix
107 " 🟣 IMarketEngine View Structs Extended with Settled Claim Routing Fields

Access 444k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>

## Learned User Preferences

- Expects explicit distinction between gasless-for-the-user (relayer/sponsor pays) and zero gas on-chain; state changes always consume native gas on the deployment chain.

## Learned Workspace Facts

- Registry and embedded testnet flows target Base Sepolia (`84532`); Ethereum Sepolia (`11155111`) native ETH does not pay gas for Base Sepolia contract calls unless the product is redeployed or bridged to that chain.
- `TokenFaucet.requestWithSig` is intended for any caller (relayer pays gas); gasless UX uses API relay env (`FAUCET_RELAY_ENABLED`, funded Base Sepolia relayer key) plus user EIP-712 signatures—no redeploy when the live faucet already matches this interface.
- Canonical `TokenFaucet` JSON ABI for integrators: `package/abi/TokenFaucet.json` (and backend copy); keep `nonces` / `requestWithSig` aligned with `TokenFaucet.sol` after contract changes.
- EVM contract edits cannot remove gas for state updates globally; they only change who submits the paying transaction (user EOA, relayer, treasury, or paymaster path).

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.
