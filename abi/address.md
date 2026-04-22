# Base Sepolia (chain id 84532)

This file is filled automatically after a **real** deploy (not a dry run).

1. Deploy (keystore; optional non-interactive password via `ETH_PASSWORD` in the shell if your `.env` cannot hold it):

   ```bash
   FOUNDRY_PROFILE=production forge build
   ./scripts/deploy-testnet.sh --broadcast --verify
   ```

2. If verify did not run or failed, verify from the saved broadcast (Basescan API = `ETHERSCAN_API_KEY` in `.env`):

   ```bash
   ./scripts/verify-base-sepolia-contracts.sh
   ```

3. Regenerate this table and refresh ABIs:

   ```bash
   RPC_URL="$RPC_URL" ./scripts/update-abi-address-md.sh
   ./scripts/export-abi.sh
   # or: SKIP_BUILD=1 ./scripts/export-abi.sh
   ```

| Contract | Address |
|----------|---------|
| *(run `./scripts/update-abi-address-md.sh` after `broadcast/DeployTestnet.s.sol/84532/run-latest.json` exists)* | — |

**Notes**

- The user-facing **MarketEngine** is the **ERC1967Proxy** address (UUPS). The `MarketEngineDispatcher` row in the broadcast is the **implementation** behind that proxy.
- Sourcify is optional; this repo’s scripts use **Basescan** with `ETHERSCAN_API_KEY` (not the `RPSGame` / Sourcify example from a different project).
