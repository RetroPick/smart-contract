# MarketEngine Selector Compatibility Matrix

This file freezes external selector compatibility for the EIP-170 modular refactor.

Source of selectors:
- `forge inspect src/MarketEngine.sol:MarketEngine methodIdentifiers`

## Function Selectors

| Selector | Signature | Target Module |
|---|---|---|
| `0xad3cb1cc` | `UPGRADE_INTERFACE_VERSION()` | Root/UUPS |
| `0xf851a440` | `admin()` | Root storage getter |
| `0x658ec38a` | `cancelEpoch(bytes32,uint64,uint8,bool)` | CoreLifecycle |
| `0x75fb689e` | `cancelRollingEpochWhileHalted(bytes32,uint64,uint8,bool)` | RollingLifecycle |
| `0x5ca3e1e9` | `claim(bytes32,uint64)` | Claims |
| `0xa6b6d8d1` | `claimMany(bytes32,uint64[])` | Claims |
| `0x2eab45e7` | `configInitialized()` | Root storage getter |
| `0xd21125ee` | `defaultSettlementFeeBps()` | Root storage getter |
| `0xb9131821` | `depositToSide(bytes32,uint64,uint8,uint256)` | UserOps |
| `0xb701cace` | `depositToSideFor(address,bytes32,uint64,uint8,uint256)` | UserOps |
| `0xeba76a35` | `epochs(bytes32,uint64)` | Root storage getter |
| `0x6d9754a4` | `executeRollingRound(bytes32)` | RollingLifecycle |
| `0xa584ce58` | `executeRollingRoundBatch(bytes32[])` | RollingLifecycle |
| `0xd4256b4b` | `genesisLockRolling(bytes32)` | RollingLifecycle |
| `0xfb515038` | `genesisStartRolling(bytes32)` | RollingLifecycle |
| `0x1ba9ad96` | `getEpoch(bytes32,uint64)` | Views |
| `0x4b4b06dc` | `getRollingLifecycle(bytes32)` | Views |
| `0xda08b78a` | `getUserEpochs(bytes32,address,uint256,uint256)` | Views |
| `0xca033f13` | `getVaultBalances(bytes32)` | Views |
| `0x61a552dc` | `globalPaused()` | Root storage getter |
| `0x0f3ed99e` | `haltRollingMarket(bytes32)` | RollingLifecycle |
| `0x7b89ffdb` | `initialize((address,address,address,address,address,uint16,uint16,uint8,uint8,uint64,uint16))` | Root/UUPS |
| `0xe2fe583d` | `initializeMarket(bytes32)` | AdminConfig |
| `0x63930472` | `isDepositExecutor(address)` | Root storage getter |
| `0xcd5e8cbd` | `ledgers(bytes32)` | Root storage getter |
| `0x1310276e` | `lockEpoch(bytes32,uint64)` | CoreLifecycle |
| `0x00de7b12` | `lockEpochsBatch(bytes32[],uint64[])` | CoreLifecycle |
| `0xeffd46b4` | `maxOutcomes()` | Root storage getter |
| `0xfb32c56b` | `maxSwitchFeeBps()` | Root storage getter |
| `0x778acc3c` | `openEpoch(bytes32,uint64,uint64,uint64,uint64)` | CoreLifecycle |
| `0xdf50de60` | `openEpochsBatch(bytes32[],uint64[],uint64[],uint64[],uint64[])` | CoreLifecycle |
| `0x324b8d6e` | `oracleConfig()` | Root storage getter |
| `0xa676be29` | `pauseProgram(bool)` | AdminConfig |
| `0xe2c73d0d` | `positionKey(bytes32,uint64)` | Root utility |
| `0x2630c12f` | `priceOracle()` | Root storage getter |
| `0x52d1902d` | `proxiableUUID()` | Root/UUPS |
| `0xafe53192` | `resetRollingLifecycle(bytes32,uint64)` | RollingLifecycle |
| `0xf1282803` | `resolveEpoch(bytes32,uint64)` | CoreLifecycle |
| `0x7de2ec76` | `resolveEpochsBatch(bytes32[],uint64[])` | CoreLifecycle |
| `0x4f6916d1` | `setDepositExecutor(address,bool)` | AdminConfig |
| `0xf0f44260` | `setTreasury(address)` | AdminConfig |
| `0x8db50d4d` | `setWorkerAuthority(address)` | AdminConfig |
| `0x54977e3c` | `setYieldRouter(address,uint16)` | YieldAdmin |
| `0xdbb97b54` | `setLmRewardsEnabled(bool)` | YieldAdmin |
| `0x939cab22` | `keeperClaimLmRewards(bytes32)` | YieldAdmin / Worker |
| `0x51ed6a30` | `stakeToken()` | Root storage getter |
| `0xc7dbf2cb` | `switchSide(bytes32,uint64,uint8,uint8,uint256)` | UserOps |
| `0x03135bea` | `templateIdFromSlug(string)` | Root utility |
| `0x0a631576` | `templates(bytes32)` | Root storage getter |
| `0x61d027b3` | `treasury()` | Root storage getter |
| `0x4f1ef286` | `upgradeToAndCall(address,bytes)` | Root/UUPS |
| `0x880a2213` | `upsertTemplate((string,string,bytes32,uint8,uint8,uint8,bool,uint8,int256,int256[7],uint16,uint16,bool,uint8,uint64,uint64,uint64,uint16))` | AdminConfig |
| `0x6ec3a91d` | `withdrawFees(bytes32,uint256)` | Claims |
| `0x027b7761` | `workerAuthority()` | Root storage getter |
| `0xf8937fae` | `yieldEmergencyWithdraw(bytes32)` | YieldAdmin |
| `0x59c1c142` | `yieldFeeBps()` | Root storage getter |
| `0x08ccadd8` | `yieldRouter()` | Root storage getter |
| `0x80ff5287` | `lmRewardsEnabled()` | Root storage getter |

## Event Signature Compatibility

All current event signatures in `src/MarketEngine.sol` are preserved as-is for indexer/backfill safety:
- `ConfigInitialized(address,address,address)`
- `TemplateUpserted(bytes32,string,uint8,uint8,uint64,uint16)`
- `MarketInitialized(bytes32)`
- `EpochOpened(bytes32,uint64,uint64,uint64,uint64)`
- `PositionDeposited(bytes32,uint64,address,uint8,uint256)`
- `UserEpochIndexed(bytes32,uint64,address)`
- `SideSwitched(bytes32,uint64,address,uint8,uint8,uint256,uint256,uint256)`
- `EpochLocked(bytes32,uint64,int256,uint64)`
- `EpochLockedV2(bytes32,uint64,int256,uint64,uint80)`
- `EpochResolved(bytes32,uint64,uint256,uint256,uint256,bool)`
- `EpochResolvedV2(bytes32,uint64,uint80,int256,uint64)`
- `YieldRouterSet(address,address,uint16)`
- `EpochYieldAccrued(bytes32,uint64,uint256,uint256,uint256)`
- `YieldRouterWithdrawFailed(bytes32,uint64,uint256)`
- `YieldRouterDepositFailed(bytes32,uint256)`
- `LMRewardReceived(bytes32,address,uint256)`
- `LMRewardsEnabledUpdated(bool)`
- `EpochCancelled(bytes32,uint64,uint8)`
- `Claimed(bytes32,uint64,address,uint256)`
- `FeesWithdrawn(bytes32,uint256)`
- `RollingGenesisStarted(bytes32,uint64,uint64,uint64)`
- `RollingGenesisLocked(bytes32,uint64,uint64)`
- `RollingRoundExecuted(bytes32,uint64,uint64,uint64)`
- `RollingHalted(bytes32,uint8,uint64)`
- `RollingLifecycleReset(bytes32,uint64)`
- `DepositExecutorSet(address,bool)`
- `WorkerAuthorityUpdated(address,address)`
- `TreasuryUpdated(address,address)`
