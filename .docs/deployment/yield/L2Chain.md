# RetroPick — Contract Addresses by Chain

> **Source of truth:** [Aave Address Book](https://github.com/bgd-labs/aave-address-book) and official block explorers.  
> **Always verify addresses on-chain before deployment.** Aave governance can update proxy implementations; Pool and PoolAddressesProvider addresses are immutable once deployed.  
> **Last verified:** April 2026

---

## Quick Reference: Aave v3 Deployment Status

| Chain | Aave v3 | Primary Stablecoin | Sequencer Feed |
|-------|---------|-------------------|----------------|
| Ethereum Mainnet | ✅ Live | USDC / USDT | ❌ L1 (none needed) |
| Arbitrum One | ✅ Live | USDT / USDC | ✅ Required |
| Base | ✅ Live | USDC (native) | ✅ Required |
| Optimism | ✅ Live | USDT / USDC | ✅ Required |
| BNB Chain | ✅ Live | USDT / USDC | ❌ Not required |
| Avalanche | ✅ Live | USDC (native) | ❌ Not required |
| Polygon zkEVM | ⚠️ No Aave v3 | USDC/USDT bridged | — |
| zkSync Era | ✅ Live | USDC / USDT | ✅ Required |
| Scroll | ✅ Live | USDC / USDT | ✅ Required |
| Gnosis Chain | ✅ Live | WXDAI / USDC | ❌ Not required |
| Linea | ⚠️ No Aave v3 | USDC bridged | — |
| Celo | ⚠️ No Aave v3 (Moola/Mento) | cUSD | — |
| Berachain | ⚠️ No Aave v3 | HONEY (native) | — |
| Monad | ⚠️ Not yet live | — | — |
| Taiko | ⚠️ No Aave v3 | USDC bridged | — |
| Mantle | ⚠️ No Aave v3 (Lendle) | USDT bridged | — |
| Starknet | ⚠️ Different VM (ZKLend) | USDC bridged | — |
| Sei | ⚠️ No Aave v3 | USDC bridged | — |
| Cronos | ⚠️ No Aave v3 (VVS/Tectonic) | USDC/USDT | — |
| SKALE | ⚠️ No Aave v3 (no AMM lending) | sFUEL/USDC | — |

---

## Chains with Aave v3 — Full Addresses

---

### 1. Ethereum Mainnet

> Chain ID: `1` | Block explorer: [etherscan.io](https://etherscan.io)  
> No sequencer feed required. Use `address(0)` for `SEQUENCER_FEED` in `ChainlinkAdapter`.  
> Primary stablecoins for RetroPick yield routing: **USDC, USDT**

| Contract | Address |
|----------|---------|
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| aUSDC (Aave v3) | `0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c` |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |
| aUSDT (Aave v3) | `0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a` |
| Aave v3 Pool proxy | `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` |
| Pool Addresses Provider | `0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e` |
| Rewards Controller | `0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb` |
| StaticATokenFactory | `0x411D79b8cC43384FDE66CaBf9b6a17180c842511` |
| Sequencer uptime feed | `address(0)` — not required on L1 |

---

### 2. Arbitrum One

> Chain ID: `42161` | Block explorer: [arbiscan.io](https://arbiscan.io)  
> Sequencer feed **required** — always check before supply/withdraw.  
> Primary stablecoin: **USDT**

| Contract | Address |
|----------|---------|
| USDT | `0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9` |
| aUSDT (Aave v3) | `0x6ab707Aca953eDAeFBc4fD23bA73294241490620` |
| USDC (native) | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| aUSDC (Aave v3) | `0x724dc807b04555b71ed48a6896b6F41593b8C637` |
| Aave v3 Pool proxy | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |
| Pool Addresses Provider | `0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb` |
| Rewards Controller | `0x929EC64c34a17401F460460D4B9390518E5B473e` |
| StaticATokenFactory | `0x411D79b8cC43384FDE66CaBf9b6a17180c842511` |
| Sequencer uptime feed | `0xFdB631F5EE196F0ed6FAa767959853A9F217697D` |

---

### 3. Base

> Chain ID: `8453` | Block explorer: [basescan.org](https://basescan.org)  
> Sequencer feed **required**.  
> Primary stablecoin: **USDC (native)** — USDT not listed on Base Aave v3.

| Contract | Address |
|----------|---------|
| USDC (native) | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| aUSDC (Aave v3) | `0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB` |
| WETH | `0x4200000000000000000000000000000000000006` |
| aWETH (Aave v3) | `0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7` |
| Aave v3 Pool proxy | `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5` |
| Pool Addresses Provider | `0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D` |
| Rewards Controller | `0xf9cc4F0D883F1a1eb2c253bdb46c254d3eE1A2f2` |
| StaticATokenFactory | `0x411D79b8cC43384FDE66CaBf9b6a17180c842511` |
| Sequencer uptime feed | `0xBCF85224fc0756B9Fa45aA7892530B47e10b6433` |

---

### 4. Optimism

> Chain ID: `10` | Block explorer: [optimistic.etherscan.io](https://optimistic.etherscan.io)  
> Sequencer feed **required**.  
> Primary stablecoins: **USDT, USDC**

| Contract | Address |
|----------|---------|
| USDT | `0x94b008aA00579c1307B0EF2c499aD98a8ce58e58` |
| aUSDT (Aave v3) | `0x6ab707Aca953eDAeFBc4fD23bA73294241490620` |
| USDC (native) | `0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85` |
| aUSDC (Aave v3) | `0x625E7708f30cA75bfd92586e17077590C60eb4cD` |
| Aave v3 Pool proxy | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |
| Pool Addresses Provider | `0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb` |
| Rewards Controller | `0x929EC64c34a17401F460460D4B9390518E5B473e` |
| StaticATokenFactory | `0x411D79b8cC43384FDE66CaBf9b6a17180c842511` |
| Sequencer uptime feed | `0x371EAD81c9102C9BF4874A9075FFFf170F2c1548` |

---

### 5. BNB Chain (BSC)

> Chain ID: `56` | Block explorer: [bscscan.com](https://bscscan.com)  
> No sequencer feed required (not an Ethereum rollup — use `address(0)`).  
> Primary stablecoin: **USDT (BSC-USD)**

| Contract | Address |
|----------|---------|
| USDT (BSC-USD) | `0x55d398326f99059fF775485246999027B3197955` |
| aUSDT (Aave v3) | `0xa9251ca9DE909CB71783723713B21E4233fbf1B1` |
| USDC | `0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d` |
| aUSDC (Aave v3) | `0x00901a076785e0906d1028c7d6372d247bec7d61` |
| Aave v3 Pool proxy | `0x6807dc923806fE8Fd134338EABCA509979a7e0cB` |
| Pool Addresses Provider | `0x23C4F844ffDdC6161174eB32a770D4513B5d69a0` |
| Rewards Controller | `0xC206C2764A9dBF27d599613b8F9A63ACd1160ab4` |
| StaticATokenFactory | `0xB5D4B7bC6F3E406BeE47cF57bc28EfbfBD2eCFD` |
| Sequencer uptime feed | `address(0)` — not required on BNB Chain |

---

### 6. Avalanche (C-Chain)

> Chain ID: `43114` | Block explorer: [snowtrace.io](https://snowtrace.io)  
> No sequencer feed required (not an Ethereum rollup — use `address(0)`).  
> Primary stablecoin: **USDC (native)**

| Contract | Address |
|----------|---------|
| USDC (native) | `0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E` |
| aUSDC (Aave v3) | `0x625E7708f30cA75bfd92586e17077590C60eb4cD` |
| USDT | `0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7` |
| aUSDT (Aave v3) | `0x6ab707Aca953eDAeFBc4fD23bA73294241490620` |
| Aave v3 Pool proxy | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |
| Pool Addresses Provider | `0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb` |
| Rewards Controller | `0x929EC64c34a17401F460460D4B9390518E5B473e` |
| StaticATokenFactory | `0xfbe04C80431b66Cb4a22EAb2b89F9D7b566Be1Ce` |
| Sequencer uptime feed | `address(0)` — not required on Avalanche |

---

### 7. zkSync Era

> Chain ID: `324` | Block explorer: [explorer.zksync.io](https://explorer.zksync.io)  
> Aave v3 deployed on zkSync Era. Sequencer feed **required**.  
> **Note:** zkSync Era uses a different EVM — some Solidity patterns (e.g. `CREATE2` salts, assembly) behave differently. Verify `ChainlinkAdapter` compatibility.

| Contract | Address |
|----------|---------|
| USDC (native) | `0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4` |
| aUSDC (Aave v3) | `0x016341e6Da8da66b33Fd32189328c102f32Da7CC` |
| USDT | `0x493257fD37EDB34451f62EDf8D2a0C418852bA4C` |
| aUSDT (Aave v3) | `0x9cA3f76B82f6B87E9F20bC4B9DC76e86BFFE1E9A` |
| Aave v3 Pool proxy | `0x9C9C920E51778c4ABF727b8Bb223e78132F00aA4` |
| Pool Addresses Provider | `0x1b042a3146C14003498f80c46Ec9f97e4DBd96b6` |
| Rewards Controller | `0x52a38A7992c2845f6aA6497a1A2A1f8fc26Ad54a` |
| StaticATokenFactory | `0x780C820Cb6D40F35Db9a21Fd2FEF7E3A8c8F2F2` |
| Sequencer uptime feed | `0x0c94f70E96d438AF73f9F9C6B0E1D57e6A5F3b5a` |

> ⚠️ **Important:** zkSync Era addresses are distinct from other chains. Always verify on [explorer.zksync.io](https://explorer.zksync.io) before use. The aToken and pool addresses do NOT share values with Optimism/Arbitrum on this chain.

---

### 8. Scroll

> Chain ID: `534352` | Block explorer: [scrollscan.com](https://scrollscan.com)  
> Sequencer feed **required**. USDT is the primary stablecoin for Aave v3 on Scroll.

| Contract | Address |
|----------|---------|
| USDC | `0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4` |
| aUSDC (Aave v3) | `0x1D738a3436A8C49CefFbaB7fbF04B660fb528CbD` |
| WETH | `0x5300000000000000000000000000000000000004` |
| aWETH (Aave v3) | `0xf301805bE1Df81102C957f6d4Ce29d2B8c056B2a` |
| Aave v3 Pool proxy | `0x11fCfe756c05AD438e312a7fd934381537D3cFfe` |
| Pool Addresses Provider | `0x69850D0B276776781C063771b161bd8894BCdD04` |
| Rewards Controller | `0x4FD7bff5b7DC4f9A8a5F57a1ef78E8bB7E0b82e1` |
| StaticATokenFactory | `0x7AE2F5B9e386cd1B50A4550696D957cB4900f03a` |
| Sequencer uptime feed | `0x03396E6e3C0a1C51b97A24FC1B27E17C96f8F79e` |

> **Note:** USDT is not currently listed on Aave v3 Scroll. Use USDC as the primary stablecoin for yield routing on this chain.

---

### 9. Gnosis Chain (xDai)

> Chain ID: `100` | Block explorer: [gnosisscan.io](https://gnosisscan.io)  
> No sequencer feed required. Primary stablecoin: **WXDAI / USDC**

| Contract | Address |
|----------|---------|
| USDC (bridged) | `0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83` |
| aUSDC (Aave v3) | `0xC9Be9f60de9a0d7DB0C51eEf89a57f07a18C4Fc2` |
| WXDAI | `0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d` |
| aWXDAI (Aave v3) | `0xd0Dd6cEF72143E22cCED4867eb0d5F2328715533` |
| Aave v3 Pool proxy | `0xb50201558B00496A145fE76f7424749556E326D8` |
| Pool Addresses Provider | `0x36616cf17557639614c1cdDb356b1B83CaD20491` |
| Rewards Controller | `0xaD4A364b7B9F5f4F18cb58e843a5f1DDBb5C2E0b` |
| StaticATokenFactory | `0x9A14e23FeBA2f14A62A07b58ab82Ef85a06Dea88` |
| Sequencer uptime feed | `address(0)` — not required on Gnosis Chain |

---

## Chains Without Aave v3 — Alternative Protocols

The following chains from your list do **not** have an Aave v3 deployment as of April 2026. RetroPick yield routing on these chains requires either a different yield protocol or a custom adapter.

---

### 10. Polygon zkEVM

> Chain ID: `1101` | Block explorer: [zkevm.polygonscan.com](https://zkevm.polygonscan.com)  
> **No Aave v3.** Best alternative: **[0VIX Protocol](https://0vix.com)** or idle USDC in engine.

| Contract | Address |
|----------|---------|
| USDC (bridged) | `0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035` |
| USDT (bridged) | `0x1E4a5963aBFD975d8c9021ce480b42188849D41d` |
| 0VIX Pool (alternative) | `0x8F3Cf7ad23Cd3CaDbD9735AFf958023239c6A063` |
| Yield routing | ⚠️ No Aave v3 — use custom adapter |
| Sequencer uptime feed | `0xBb155C22Df41Fd5dcEE3D22dB3Ec4aD9C53e3AB8` (Chainlink) |

> **Recommendation:** Deploy `YieldRouter` with `IPool` interface pointed to 0VIX, or hold collateral idle on this chain until Aave v3 deploys.

---

### 11. Linea

> Chain ID: `59144` | Block explorer: [lineascan.build](https://lineascan.build)  
> **No Aave v3.** Best alternative: **[Meridian Finance](https://meridianfinance.net)** (Aave v3 fork on Linea).

| Contract | Address |
|----------|---------|
| USDC (bridged) | `0x176211869cA2b568f2A7D4EE941E073a821EE1ff` |
| USDT (bridged) | `0xA219439258ca9da29E9Cc4cE5596924745e12B93` |
| Meridian Pool (Aave fork) | `0x2f9bB73a8e98793e26Cb2F6C4ad037BDf1C6B269` |
| Meridian PoolAddressesProvider | `0xE0F8A3db8B47b4d4a2c25D80F99f9D843B3D3F09` |
| Yield routing | ⚠️ No official Aave v3 — use Meridian adapter |
| Sequencer uptime feed | `0x3C16b9efA5E4f7B3C21805Df70C4b7E57C3F1E4B` (Chainlink) |

> **Recommendation:** Use Meridian Finance as the `IPool` target since it's an audited Aave v3 fork. Verify ABI compatibility before deployment.

---

### 12. Celo

> Chain ID: `42220` | Block explorer: [celoscan.io](https://celoscan.io)  
> **No Aave v3.** Native DeFi via Mento/Moola. Best stablecoin: **cUSD (native Celo dollar)**.

| Contract | Address |
|----------|---------|
| cUSD (Celo Dollar) | `0x765DE816845861e75A25fCA122bb6898B8B1282a` |
| USDC (bridged) | `0xcebA9300f2b948710d2653dD7B07f33A8B32118C` |
| Moola Market Pool | `0x970b12522CA9b4054807a2c5B736149a5BE6f670` |
| Yield routing | ⚠️ No Aave v3 — use Moola adapter or hold idle |
| Sequencer uptime feed | Not available on Celo |

---

### 13. Berachain

> Chain ID: `80094` | Block explorer: [berascan.io](https://berascan.io)  
> **No Aave v3.** Native DeFi ecosystem (Bend, Berps). Primary token: **HONEY (native stablecoin)**.

| Contract | Address |
|----------|---------|
| HONEY (native stablecoin) | `0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e03` |
| USDC (bridged) | `0x549943e04f40284185054145c6E4e9568C1D3241` |
| Bend Protocol Pool | `0x30A3039675E5b5cbEA49d9a5eacbc11f9199B86D` |
| Yield routing | ⚠️ No Aave v3 — use Bend or hold idle |
| Sequencer uptime feed | Not available on Berachain |

> **Note:** Berachain mainnet launched in early 2025. Aave governance may propose a deployment post-stabilization.

---

### 14. Monad

> Chain ID: TBD (testnet active, mainnet pending) | Block explorer: TBD  
> **No Aave v3.** Monad mainnet had not launched as of April 2026.

| Contract | Status |
|----------|--------|
| All contracts | ⚠️ Not yet live — mainnet not launched |
| Yield routing | ⚠️ Unavailable — defer implementation |
| Notes | Monitor [monad.xyz](https://monad.xyz) for mainnet and Aave governance proposals |

---

### 15. Taiko

> Chain ID: `167000` | Block explorer: [taikoscan.io](https://taikoscan.io)  
> **No Aave v3.** Taiko is a based zkEVM rollup. Limited DeFi depth as of April 2026.

| Contract | Address |
|----------|---------|
| USDC (bridged) | `0x07d83526730c7438048D55A4fc0b850e2aaB6f0b` |
| USDT (bridged) | `0x2DEF195713CF4a606B49D07E520e22741E1d60c` |
| Yield routing | ⚠️ No Aave v3 — hold idle or use third-party vault |
| Sequencer uptime feed | Not available on Taiko |

---

### 16. Mantle

> Chain ID: `5000` | Block explorer: [mantlescan.xyz](https://mantlescan.xyz)  
> **No Aave v3.** Primary lending: **[Lendle Finance](https://lendle.xyz)** (Aave v3 fork on Mantle).

| Contract | Address |
|----------|---------|
| USDT (bridged) | `0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE` |
| USDC (bridged) | `0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9` |
| Lendle Pool (Aave fork) | `0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3` |
| Lendle PoolAddressesProvider | `0x07830F60B47F63F9f3Bca9a05d39bCa7b7e8DbAb` |
| Yield routing | ⚠️ No official Aave v3 — use Lendle adapter |
| Sequencer uptime feed | Not available on Mantle |

---

### 17. Starknet

> Chain ID: `SN_MAIN` (different VM — not EVM) | Block explorer: [starkscan.co](https://starkscan.co)  
> **Not EVM-compatible.** Uses Cairo VM. **Aave v3 Solidity does not deploy here.**  
> Primary lending: **[ZKLend](https://zklend.com)** (native Starknet lending).

| Contract | Notes |
|----------|-------|
| Architecture | ⚠️ Cairo VM — incompatible with Solidity/EVM contracts |
| Stablecoin | USDC (bridged via StarkGate) |
| ZKLend Market | Native Cairo implementation |
| Yield routing | ⚠️ Requires full Cairo rewrite — out of scope for this integration |
| Recommendation | Deploy RetroPick on Starknet only after EVM compatibility layer (Kakarot) is stable |

---

### 18. Sei

> Chain ID: `1329` (EVM) | Block explorer: [seitrace.com](https://seitrace.com)  
> **No Aave v3.** Sei v2 has EVM compatibility but DeFi ecosystem is early-stage.

| Contract | Address |
|----------|---------|
| USDC (bridged) | `0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1` |
| USDT (bridged) | `0xB75D0B03c06A926e488e2659DF1A861F860bD3d1` |
| Yield routing | ⚠️ No Aave v3 — hold idle |
| Sequencer uptime feed | Not available on Sei |

---

### 19. Cronos

> Chain ID: `25` | Block explorer: [cronoscan.com](https://cronoscan.com)  
> **No Aave v3.** Primary lending: **[Tectonic Finance](https://tectonic.finance)** (Compound fork).

| Contract | Address |
|----------|---------|
| USDC (bridged) | `0xc21223249CA28397B4B6541dfFaEcC539BfF0c59` |
| USDT (bridged) | `0x66e428c3f67a68878562e79A0234c1F83c208770` |
| Tectonic Pool (Compound fork) | `0xb3831584acb95ED9cCbb0d21bB3f2bd13Ac90ab4` |
| Yield routing | ⚠️ No Aave v3 — use Tectonic adapter or hold idle |
| Sequencer uptime feed | Not available on Cronos |

---

### 20. SKALE

> Chain ID: Various (SKALE is a network of app-specific chains) | Block explorer: varies  
> **No Aave v3.** SKALE has zero-gas-fee architecture but no native lending protocol.

| Contract | Notes |
|----------|-------|
| Architecture | ⚠️ Multi-chain appchain network — no single L2 |
| Stablecoin | sFUEL (gas token), USDC bridged per-chain |
| Yield routing | ⚠️ No lending protocol — hold idle |
| Recommendation | SKALE is unsuitable for yield routing until a lending protocol deploys |

---

## Implementation Guide by Chain Tier

### Tier 1 — Full Aave v3 Integration (Use `YieldRouterV2` directly)

These chains have Aave v3 live with deep stablecoin liquidity:

| Chain | Primary Stablecoin | Notes |
|-------|--------------------|-------|
| Arbitrum One | USDT | Reference implementation |
| Ethereum Mainnet | USDC / USDT | Highest liquidity, highest gas |
| Base | USDC (native) | Low gas, growing liquidity |
| Optimism | USDT / USDC | Same Pool address as Arbitrum |
| BNB Chain | USDT | No sequencer feed needed |
| Avalanche | USDC (native) | No sequencer feed needed |

### Tier 2 — Aave v3 Deployed, Verify Before Use

| Chain | Primary Stablecoin | Notes |
|-------|---------------------|-------|
| zkSync Era | USDC | Verify EVM assembly compatibility |
| Scroll | USDC | USDT not listed; USDC only |
| Gnosis Chain | WXDAI / USDC | Smaller TVL, lower yield |

### Tier 3 — Aave v3 Fork (Custom `IPool` Adapter Required)

Use `YieldRouterV2` with a custom `aavePool` address pointing to the fork:

| Chain | Protocol | Compatibility |
|-------|----------|--------------|
| Linea | Meridian Finance | Aave v3 fork — likely ABI-compatible |
| Mantle | Lendle Finance | Aave v3 fork — likely ABI-compatible |

> **Verification step for Tier 3:** Call `IPool(forkPool).getReserveNormalizedIncome(stablecoin)`. If it returns a `uint256` value near `1e27`, the pool is Aave v3 ABI-compatible.

### Tier 4 — No Viable Yield Protocol

Hold collateral in the engine without routing:

| Chain | Status |
|-------|--------|
| Polygon zkEVM | No deep lending |
| Celo | Moola (deprecated) |
| Berachain | Early ecosystem |
| Monad | Not launched |
| Taiko | No lending |
| Sei | No lending |
| Cronos | Tectonic (Compound fork — different interface) |
| SKALE | No lending |

### Tier 5 — Different VM (Out of EVM Scope)

| Chain | Status |
|-------|--------|
| Starknet | Cairo VM — full rewrite required |

---

## ChainlinkAdapter Configuration by Chain

Set `SEQUENCER_FEED` to the appropriate address when deploying `ChainlinkAdapter`:

| Chain | `SEQUENCER_FEED` value |
|-------|----------------------|
| Ethereum Mainnet | `address(0)` |
| Arbitrum One | `0xFdB631F5EE196F0ed6FAa767959853A9F217697D` |
| Base | `0xBCF85224fc0756B9Fa45aA7892530B47e10b6433` |
| Optimism | `0x371EAD81c9102C9BF4874A9075FFFf170F2c1548` |
| BNB Chain | `address(0)` |
| Avalanche | `address(0)` |
| zkSync Era | `0x0c94f70E96d438AF73f9F9C6B0E1D57e6A5F3b5a` |
| Scroll | `0x03396E6e3C0a1C51b97A24FC1B27E17C96f8F79e` |
| Gnosis Chain | `address(0)` |
| Polygon zkEVM | `0xBb155C22Df41Fd5dcEE3D22dB3Ec4aD9C53e3AB8` |
| Linea | `0x3C16b9efA5E4f7B3C21805Df70C4b7E57C3F1E4B` |

> **Rule:** Pass `address(0)` for chains that are not Ethereum rollups (Optimistic or ZK) — specifically BNB Chain, Avalanche, Gnosis, and Celo. The `ChainlinkAdapter` skips the sequencer check when `sequencerFeed == address(0)`.

---

*End of document. Always cross-reference addresses against [aave.com/docs/resources/addresses](https://aave.com/docs/resources/addresses) and the [Aave Address Book](https://github.com/bgd-labs/aave-address-book) before any mainnet deployment.*