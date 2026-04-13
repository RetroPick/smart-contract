# Contract sketches (routers and `depositToSideFor`)

This document describes **patterns**, not a pinned production deployment. On-chain references point to [`MarketEngine`](../src/MarketEngine.sol).

## Implemented in `MarketEngine`

### `depositToSideFor` and `setDepositExecutor`

Source: [`MarketEngine.sol`](../src/MarketEngine.sol).

- **`isDepositExecutor(address)`** — public mapping; only `admin` may flip via **`setDepositExecutor(account, allowed)`** (emits `DepositExecutorSet`).
- **`depositToSideFor(beneficiary, templateId, epochId, outcomeIndex, amount)`** — reverts with `NotDepositExecutor` if `msg.sender` is not allowlisted; reverts `Unauthorized` if `beneficiary == address(0)`.

Behavior matches `depositToSide` except:

- Stake token is pulled with `safeTransferFrom(msg.sender, address(this), amount)` — the **executor** must hold stake token after its swap step.
- Position updates and `PositionDeposited` use **`beneficiary`**, not `msg.sender`.

**Invariants:** Same as `depositToSide` (epoch open, template initialized, single-side rules, pause, rolling halt).

### Admin governance

- Typical setup: allow your **RetroPickRouter** contract address; keep arbitrary EOAs disallowed (`isDepositExecutor[eoa] == false`).

## Reference router (pseudocode)

Not shipped in this repo by default; implement per chain with your chosen aggregator.

```text
contract RetroPickRouter {
    IERC20 public immutable stakeToken;
    MarketEngine public immutable engine;
    IAggregator public aggregator; // 1inch / 0x router — example

    function depositWithToken(
        address beneficiary,
        bytes32 templateId,
        uint64 epochId,
        uint8 outcomeIndex,
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minStakeOut,
        bytes calldata swapData
    ) external {
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        // swap tokenIn -> stakeToken held by this contract
        uint256 out = aggregator.swap(tokenIn, stakeToken, amountIn, minStakeOut, swapData);
        stakeToken.approve(address(engine), out);
        engine.depositToSideFor(beneficiary, templateId, epochId, outcomeIndex, out);
    }
}
```

**Notes:**

- `minStakeOut` protects against slippage before deposit.
- Router must be **`setDepositExecutor(router, true)`** on the engine.
- End user approves **router** for `tokenIn`, not necessarily `MarketEngine`.

## Open meta-tx vs allowlisted executor

| Approach | Pros | Cons |
|----------|------|------|
| **Allowlisted executor** (current) | Simple, auditable; no signature replay logic in engine | Admin must maintain list; trust in listed contracts |
| **EIP-712 `deposit` signed by user** | Permissionless fillers | Engine must implement nonces, domain separator, cancellation — higher complexity and audit scope |

Future work could add signed meta-deposits if product needs **permissionless** solvers without a single router contract.

## Failure modes

- **Swap returns less than `minStakeOut`:** revert before `depositToSideFor`.
- **Executor not allowlisted:** `NotDepositExecutor`.
- **Epoch closed / paused:** same errors as `depositToSide`.
- **User never approved router:** `transferFrom` fails on router path.
