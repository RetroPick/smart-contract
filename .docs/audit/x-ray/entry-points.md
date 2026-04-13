# Entry Point Map

> RetroPick MarketEngine | 21 entry points | 4 permissionless | 1 role-gated | 16 admin/keeper

---

## Protocol Flow Paths

### Setup (Admin)

`initialize()` → `upsertTemplate()` → `initializeMarket()` → `openEpoch()` *(manual)* or `genesisStartRolling()` *(rolling)*

### User Flow (Manual mode)

`[setup above]` → `openEpoch()` → `depositToSide()` / `switchSide()` → `lockEpoch()` → `resolveEpoch()` → `claim()` / `claimMany()`

### Rolling Flow (Keeper)

`[setup above]` → `genesisStartRolling()` → `genesisLockRolling()` → (`executeRollingRound()` / `executeRollingRoundBatch()`) → `claim()` / `claimMany()`

### Emergency / Recovery (Admin)

`pauseProgram(true)` → `haltRollingMarket()` → `cancelRollingEpochWhileHalted()` → `resetRollingLifecycle()` → `genesisStartRolling()`

---

## Permissionless

### `MarketEngine.depositToSide(bytes32,uint64,uint8,uint256)`

| Aspect | Detail |
|--------|--------|
| Visibility | `external`, `nonReentrant`, `notPausedUserOps` |
| Caller | User |
| Parameters | `templateId (user-controlled)`, `epochId (user-controlled)`, `outcomeIndex (user-controlled)`, `amount (user-controlled)` |
| Call chain | `→ MarketEngine._depositToSide() → IERC20.safeTransferFrom()` |
| State modified | `positions[...]`, `epochs[templateId][epochId]`, `ledgers[templateId]`, `vaults[templateId]`, `userEpochs[...]` |
| Value flow | Tokens: `payer → MarketEngine` |
| Reentrancy guard | yes |

### `MarketEngine.switchSide(bytes32,uint64,uint8,uint8,uint256)`

| Aspect | Detail |
|--------|--------|
| Visibility | `external`, `nonReentrant`, `notPausedUserOps` |
| Caller | User |
| Parameters | `templateId (user-controlled)`, `epochId (user-controlled)`, `fromOutcome (user-controlled)`, `toOutcome (user-controlled)`, `grossAmount (user-controlled)` |
| Call chain | `→ MarketMath.computeSwitch() → MarketMath.reserveFeesFromActive()` |
| State modified | `positions[...]`, `epochs[templateId][epochId]`, `vaults[templateId]`, `ledgers[templateId]` |
| Value flow | None (internal accounting rebalances stake + fees) |
| Reentrancy guard | yes |

### `MarketEngine.claim(bytes32,uint64)`

| Aspect | Detail |
|--------|--------|
| Visibility | `external`, `nonReentrant` |
| Caller | User |
| Parameters | `templateId (user-controlled)`, `epochId (user-controlled)` |
| Call chain | `→ MarketEngine._claimOne() → IERC20.safeTransfer()` |
| State modified | `positions[...]`, `epochs[templateId][epochId]`, `vaults[templateId]`, `ledgers[templateId]` |
| Value flow | Tokens: `MarketEngine → user` |
| Reentrancy guard | yes |

### `MarketEngine.claimMany(bytes32,uint64[])`

| Aspect | Detail |
|--------|--------|
| Visibility | `external`, `nonReentrant` |
| Caller | User |
| Parameters | `templateId (user-controlled)`, `epochIds (user-controlled)` |
| Call chain | `→ MarketEngine._claimOne() [loop] → IERC20.safeTransfer()` |
| State modified | `positions[...]`, `epochs[templateId][epochId]`, `vaults[templateId]`, `ledgers[templateId]` |
| Value flow | Tokens: `MarketEngine → user` |
| Reentrancy guard | yes |

---

## Role-Gated

### Deposit Executor

#### `MarketEngine.depositToSideFor(address,bytes32,uint64,uint8,uint256)`

| Aspect | Detail |
|--------|--------|
| Visibility | `external`, `nonReentrant`, `notPausedUserOps` |
| Caller | Allowlisted executor (`isDepositExecutor[msg.sender] == true`) |
| Parameters | `beneficiary (protocol-derived)`, `templateId (user-controlled)`, `epochId (user-controlled)`, `outcomeIndex (user-controlled)`, `amount (user-controlled)` |
| Call chain | `→ MarketEngine._depositToSide() → IERC20.safeTransferFrom()` |
| State modified | `positions[...]`, `epochs[templateId][epochId]`, `ledgers[templateId]`, `vaults[templateId]`, `userEpochs[...]` |
| Value flow | Tokens: `executor → MarketEngine` (credited to `beneficiary`) |
| Reentrancy guard | yes |

---

## Admin/Worker (keeper) Surface

### Initialization

| Contract | Function | Parameters | State Modified |
|----------|----------|------------|----------------|
| `MarketEngine` | `initialize(...)` | token/oracle/admin/treasury/worker + fee/limits/oracle config | core config state |

### Admin-only (`onlyAdmin`)

| Contract | Function | Parameters | State Modified |
|----------|----------|------------|----------------|
| `MarketEngine` | `upsertTemplate(UpsertTemplateParams)` | template config | `templates[templateId]` |
| `MarketEngine` | `initializeMarket(bytes32)` | `templateId` | `ledgers[templateId]` |
| `MarketEngine` | `pauseProgram(bool)` | `paused` | `globalPaused` |
| `MarketEngine` | `haltRollingMarket(bytes32)` | `templateId` | `ledgers[templateId]` (halt flags) |
| `MarketEngine` | `resetRollingLifecycle(bytes32,uint64)` | `templateId,nextRollingEpochId` | `ledgers[templateId]` |
| `MarketEngine` | `cancelRollingEpochWhileHalted(bytes32,uint64,CancelReason,bool)` | epoch cancel params | `epochs[...]`, `vaults[...]`, `ledgers[...]` |
| `MarketEngine` | `setWorkerAuthority(address)` | `worker` | `workerAuthority` |
| `MarketEngine` | `setTreasury(address)` | `treasury` | `treasury` |
| `MarketEngine` | `setDepositExecutor(address,bool)` | allowlist toggle | `isDepositExecutor[account]` |

### Worker-or-Admin (`onlyWorkerOrAdmin`)

| Contract | Function | Parameters | State Modified |
|----------|----------|------------|----------------|
| `MarketEngine` | `genesisStartRolling(bytes32)` | `templateId` | `epochs[...]`, `ledgers[...]` |
| `MarketEngine` | `genesisLockRolling(bytes32)` | `templateId` | `epochs[...]`, `ledgers[...]` |
| `MarketEngine` | `executeRollingRound(bytes32)` | `templateId` | `epochs[...]`, `ledgers[...]`, `vaults[...]` |
| `MarketEngine` | `executeRollingRoundBatch(bytes32[])` | `templateIds[]` | `epochs[...]`, `ledgers[...]`, `vaults[...]` |
| `MarketEngine` | `openEpoch(bytes32,uint64,uint64,uint64,uint64)` | epoch timing | `epochs[...]`, `ledgers[...]` |
| `MarketEngine` | `openEpochsBatch(bytes32[],uint64[],uint64[],uint64[],uint64[])` | batch | `epochs[...]`, `ledgers[...]` |
| `MarketEngine` | `lockEpoch(bytes32,uint64)` | `templateId,epochId` | `epochs[...]` |
| `MarketEngine` | `lockEpochsBatch(bytes32[],uint64[])` | batch | `epochs[...]` |
| `MarketEngine` | `resolveEpoch(bytes32,uint64)` | `templateId,epochId` | `epochs[...]`, `vaults[...]`, `ledgers[...]` |
| `MarketEngine` | `resolveEpochsBatch(bytes32[],uint64[])` | batch | `epochs[...]`, `vaults[...]`, `ledgers[...]` |
| `MarketEngine` | `cancelEpoch(bytes32,uint64,CancelReason,bool)` | epoch cancel params | `epochs[...]`, `vaults[...]`, `ledgers[...]` |

### Treasury-or-Admin (`onlyTreasuryOrAdmin`)

| Contract | Function | Parameters | State Modified |
|----------|----------|------------|----------------|
| `MarketEngine` | `withdrawFees(bytes32,uint256)` | `templateId,amount` | `vaults[...]`, `ledgers[...]` |

---

## Notes / Exclusions

- View/pure functions excluded (e.g. `getUserEpochs`, `getVaultBalances`, `getRollingLifecycle`).
- Interfaces excluded.

