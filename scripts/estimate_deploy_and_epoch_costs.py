#!/usr/bin/env python3
"""
Estimate MarketEngine deployment cost and keeper-driven epoch maintenance on an EVM chain.

Gas figures default to values parsed from the repo's `.gas-snapshot`, produced by Foundry tests:
  - DeploymentScriptExecutionTest — full DeployProduction / testnet / local / upgrade scripts
  - EpochGasTest — manual ExecutionMode: openEpoch, lockEpoch, resolveEpoch, claim
  - MarketEngineRollingTest — rolling: genesisStartRolling, genesisLockRolling, executeRollingRound

Usage:
  python3 scripts/estimate_deploy_and_epoch_costs.py
  python3 scripts/estimate_deploy_and_epoch_costs.py --rpc-url https://mainnet.base.org
  MANUAL_EPOCHS_PER_DAY=4 ROLLING_INTERVAL_SECONDS=3600 python3 scripts/estimate_deploy_and_epoch_costs.py

Env (optional):
  RPC_URL / BASE_RPC_URL     Live gas price via `cast` when set
  ETH_PRICE_USD              Override native token USD price
  MANUAL_EPOCHS_PER_DAY, MANUAL_TEMPLATES, ROLLING_INTERVAL_SECONDS, ROLLING_TEMPLATES
  NO_COLOR                   Disable ANSI colors

CLI:
  --color auto|always|never  --no-color
  --tx-overhead-gas N        Add N gas per on-chain tx (0 = snapshot-only; try 21000 for rough intrinsic gas)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from decimal import Decimal, getcontext
from pathlib import Path
from urllib.request import Request, urlopen

getcontext().prec = 40

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SNAPSHOT = REPO_ROOT / ".gas-snapshot"
COINGECKO_ETH = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"

GAS_KEYS: dict[str, str] = {
    "deploy_production": "DeploymentScriptExecutionTest:test_deployProduction_success_configAndSelectors",
    "deploy_testnet_with_faucet": "DeploymentScriptExecutionTest:test_deployTestnet_success_withFaucet",
    "deploy_testnet_no_faucet": "DeploymentScriptExecutionTest:test_deployTestnet_success_withoutFaucet",
    "deploy_local": "DeploymentScriptExecutionTest:test_deployLocal_success_emitsDeployment",
    "upgrade_production": "DeploymentScriptExecutionTest:test_upgradeProduction_success",
    "upgrade_testnet": "DeploymentScriptExecutionTest:test_upgradeTestnet_success",
    "upgrade_market_engine": "DeploymentScriptExecutionTest:test_upgradeMarketEngine_success",
    "manual_open_epoch_cold": "EpochGasTest:test_gas_openEpoch_cold",
    "manual_lock_epoch_threshold": "EpochGasTest:test_gas_lockEpoch_threshold",
    "manual_lock_epoch_direction": "EpochGasTest:test_gas_lockEpoch_direction",
    "manual_resolve_epoch_threshold": "EpochGasTest:test_gas_resolveEpoch_threshold",
    "manual_resolve_epoch_direction": "EpochGasTest:test_gas_resolveEpoch_direction",
    "user_claim_after_resolve": "EpochGasTest:test_gas_claim_afterResolve",
    "rolling_genesis_start": "MarketEngineRollingTest:test_gas_genesis_start_rolling",
    "rolling_genesis_lock": "MarketEngineRollingTest:test_gas_genesis_lock_rolling",
    "rolling_execute_one_tick": "MarketEngineRollingTest:test_gas_rolling_execute_one_tick",
}

FALLBACK_GAS: dict[str, int] = {
    "deploy_production": 44_907_600,
    "deploy_testnet_with_faucet": 46_267_619,
    "deploy_testnet_no_faucet": 45_996_955,
    "deploy_local": 39_166_467,
    "upgrade_production": 52_006_929,
    "upgrade_testnet": 52_043_248,
    "upgrade_market_engine": 52_107_014,
    "manual_open_epoch_cold": 195_375,
    "manual_lock_epoch_threshold": 19_181,
    "manual_lock_epoch_direction": 95_067,
    "manual_resolve_epoch_threshold": 178_325,
    "manual_resolve_epoch_direction": 150_645,
    "user_claim_after_resolve": 59_469,
    "rolling_genesis_start": 207_084,
    "rolling_genesis_lock": 265_935,
    "rolling_execute_one_tick": 416_745,
}

SNAPSHOT_LINE = re.compile(r"^([^:]+):([^\s]+)\(\) \(gas: (\d+)\)\s*$")


class Term:
    """ANSI SGR codes; disabled when color=False."""

    def __init__(self, color: bool) -> None:
        self._c = color

    def wrap(self, code: str, s: str) -> str:
        if not self._c:
            return s
        return f"\033[{code}m{s}\033[0m"

    def bold(self, s: str) -> str:
        return self.wrap("1", s)

    def dim(self, s: str) -> str:
        return self.wrap("2", s)

    def cyan(self, s: str) -> str:
        return self.wrap("36", s)

    def green(self, s: str) -> str:
        return self.wrap("32", s)

    def yellow(self, s: str) -> str:
        return self.wrap("33", s)

    def magenta(self, s: str) -> str:
        return self.wrap("35", s)

    def blue(self, s: str) -> str:
        return self.wrap("34", s)

    def red(self, s: str) -> str:
        return self.wrap("31", s)


def parse_gas_snapshot(path: Path) -> dict[str, int]:
    out: dict[str, int] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        m = SNAPSHOT_LINE.match(line.strip())
        if not m:
            continue
        contract, name, gas_s = m.group(1), m.group(2), m.group(3)
        out[f"{contract}:{name}"] = int(gas_s)
    return out


def resolve_gas_table(raw: dict[str, int]) -> tuple[dict[str, int], dict[str, bool]]:
    """Returns (gas values, key -> True if value came from snapshot)."""
    resolved: dict[str, int] = {}
    from_snap: dict[str, bool] = {}
    for logical, test_path in GAS_KEYS.items():
        if test_path in raw:
            resolved[logical] = raw[test_path]
            from_snap[logical] = True
        elif logical in FALLBACK_GAS:
            resolved[logical] = FALLBACK_GAS[logical]
            from_snap[logical] = False
        else:
            resolved[logical] = 0
            from_snap[logical] = False
    return resolved, from_snap


def fetch_eth_usd() -> Decimal:
    req = Request(COINGECKO_ETH, headers={"User-Agent": "retro-pick-cost-estimator/1.0"})
    with urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
    return Decimal(str(data["ethereum"]["usd"]))


def cast_gas_price_wei(rpc_url: str) -> int:
    if not shutil.which("cast"):
        raise RuntimeError("cast not found in PATH")
    out = subprocess.check_output(["cast", "gas-price", "--rpc-url", rpc_url], text=True).strip()
    return int(out)


def eth_from_gas(gas: int, gas_price_wei: int) -> Decimal:
    return (Decimal(gas) * Decimal(gas_price_wei)) / Decimal(10**18)


def usd_from_eth(eth: Decimal, eth_usd: Decimal) -> Decimal:
    return eth * eth_usd


def fmt_usd(x: Decimal) -> str:
    return f"${x.quantize(Decimal('0.01')):,.2f}"


def fmt_eth(x: Decimal) -> str:
    if x == 0:
        return "0 ETH"
    if x < Decimal("1e-8"):
        return f"{x:.12f}".rstrip("0").rstrip(".") + " ETH"
    return f"{x:.8f}".rstrip("0").rstrip(".") + " ETH"


def fmt_int(n: int) -> str:
    return f"{n:,}"


def pad_cell(s: str, w: int, align: str) -> str:
    if align == "right":
        return s.rjust(w)
    return s.ljust(w)


def print_table(
    t: Term,
    title: str,
    headers: list[str],
    rows: list[list[str]],
    aligns: list[str],
    *,
    total_row_indices: set[int] | None = None,
) -> None:
    total_row_indices = total_row_indices or set()
    n = len(headers)
    col_widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            col_widths[i] = max(col_widths[i], len(cell))

    bar = "+" + "+".join("-" * (w + 2) for w in col_widths) + "+"
    border = t.dim(bar)

    print()
    print(t.bold(t.cyan(title)))
    print(border)

    header_cells = [t.bold(pad_cell(headers[i], col_widths[i], aligns[i])) for i in range(n)]
    inner = (" " + t.dim("|") + " ").join(header_cells)
    print(t.dim("|") + " " + inner + " " + t.dim("|"))
    print(border)

    for ri, row in enumerate(rows):
        is_total = ri in total_row_indices
        cells: list[str] = []
        for i, cell in enumerate(row):
            padded = pad_cell(cell, col_widths[i], aligns[i])
            if is_total:
                if i == 0:
                    padded = t.bold(t.yellow(padded))
                elif aligns[i] == "right" and cell.startswith("$"):
                    padded = t.bold(t.green(pad_cell(cell, col_widths[i], aligns[i])))
                elif aligns[i] == "right" and "ETH" in cell:
                    padded = t.bold(t.magenta(pad_cell(cell, col_widths[i], aligns[i])))
                else:
                    padded = t.bold(t.yellow(pad_cell(cell, col_widths[i], aligns[i])))
            else:
                if aligns[i] == "right" and cell.startswith("$"):
                    padded = t.green(padded)
                elif aligns[i] == "right" and "ETH" in cell:
                    padded = t.magenta(padded)
            cells.append(padded)
        inner_r = (" " + t.dim("|") + " ").join(cells)
        print(t.dim("|") + " " + inner_r + " " + t.dim("|"))

    print(border)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--snapshot", type=Path, default=DEFAULT_SNAPSHOT, help="Path to Foundry .gas-snapshot")
    p.add_argument("--rpc-url", default=os.environ.get("RPC_URL") or os.environ.get("BASE_RPC_URL"))
    p.add_argument("--gas-price-gwei", type=Decimal, default=None)
    p.add_argument("--eth-price-usd", type=Decimal, default=None)
    p.add_argument("--multiplier", type=Decimal, default=Decimal("1.15"), help="Safety multiplier on execution gas")
    p.add_argument(
        "--tx-overhead-gas",
        type=int,
        default=0,
        help="Extra gas per on-chain tx (e.g. 21000 intrinsic). Manual keeper=3 txs/epoch; rolling bootstrap=2 txs; each tick=1.",
    )
    p.add_argument("--json", action="store_true")
    p.add_argument(
        "--color",
        choices=("auto", "always", "never"),
        default="auto",
        help="Terminal colors (default: auto)",
    )
    p.add_argument("--no-color", action="store_true", help="Same as --color never")
    args = p.parse_args()

    use_ansi = args.color == "always"
    if args.color == "auto" and not args.no_color:
        use_ansi = sys.stdout.isatty() and os.environ.get("NO_COLOR", "") == ""
    if args.no_color or os.environ.get("NO_COLOR", ""):
        use_ansi = False
    term = Term(use_ansi)

    raw = parse_gas_snapshot(args.snapshot)
    gas, from_snap = resolve_gas_table(raw)

    gas_price_wei: Decimal
    gas_price_source = "override"
    if args.gas_price_gwei is not None:
        gas_price_wei = args.gas_price_gwei * Decimal(10**9)
    elif args.rpc_url:
        try:
            gas_price_wei = Decimal(cast_gas_price_wei(args.rpc_url))
            gas_price_source = "rpc (cast gas-price)"
        except Exception as e:
            print(f"WARN: could not read gas price from RPC ({e}); using 0.01 gwei placeholder.", file=sys.stderr)
            gas_price_wei = Decimal("10000000")
            gas_price_source = "placeholder"
    else:
        gas_price_wei = Decimal("10000000")
        gas_price_source = "placeholder"
        print("WARN: no --rpc-url; using 0.01 gwei placeholder. Pass --rpc-url or --gas-price-gwei.", file=sys.stderr)

    eth_usd = args.eth_price_usd
    eth_source = "override"
    if eth_usd is None:
        env_p = os.environ.get("ETH_PRICE_USD")
        if env_p:
            eth_usd = Decimal(env_p)
            eth_source = "env"
        else:
            try:
                eth_usd = fetch_eth_usd()
                eth_source = "coingecko"
            except Exception as e:
                print(f"WARN: ETH price fetch failed ({e}); using 3000 USD.", file=sys.stderr)
                eth_usd = Decimal("3000")
                eth_source = "fallback"

    m = args.multiplier
    oh = max(0, args.tx_overhead_gas)

    def eff_gas_units(base_gas: int, tx_count: int = 0) -> int:
        """Execution gas from snapshot × multiplier + optional per-tx overhead."""
        exec_part = int(Decimal(base_gas) * m)
        return exec_part + tx_count * oh

    def cost_units(units: int) -> tuple[Decimal, Decimal]:
        e = eth_from_gas(units, int(gas_price_wei))
        return e, usd_from_eth(e, eth_usd)

    manual_epochs_per_day = Decimal(os.environ.get("MANUAL_EPOCHS_PER_DAY", "1"))
    rolling_interval = Decimal(os.environ.get("ROLLING_INTERVAL_SECONDS", "3600"))
    rolling_templates = Decimal(os.environ.get("ROLLING_TEMPLATES", "1"))
    manual_templates = Decimal(os.environ.get("MANUAL_TEMPLATES", "1"))

    # Manual:3 txs per epoch (open, lock, resolve)
    mt_open = gas["manual_open_epoch_cold"]
    mt_lock_t = gas["manual_lock_epoch_threshold"]
    mt_res_t = gas["manual_resolve_epoch_threshold"]
    mt_lock_d = gas["manual_lock_epoch_direction"]
    mt_res_d = gas["manual_resolve_epoch_direction"]
    keeper_t_base = mt_open + mt_lock_t + mt_res_t
    keeper_d_base = mt_open + mt_lock_d + mt_res_d

    keeper_t_units = eff_gas_units(keeper_t_base, 3)
    keeper_d_units = eff_gas_units(keeper_d_base, 3)
    claim_units = eff_gas_units(gas["user_claim_after_resolve"], 1)

    rolling_bootstrap_base = gas["rolling_genesis_start"] + gas["rolling_genesis_lock"]
    rolling_bootstrap_units = eff_gas_units(rolling_bootstrap_base, 2)
    rolling_tick_units = eff_gas_units(gas["rolling_execute_one_tick"], 1)

    rolling_ticks_per_day = Decimal(86400) / rolling_interval
    rolling_day_steady_units = int(rolling_ticks_per_day * Decimal(rolling_tick_units) * rolling_templates)

    manual_day_t_units = int(manual_epochs_per_day * Decimal(keeper_t_units) * manual_templates)
    manual_day_d_units = int(manual_epochs_per_day * Decimal(keeper_d_units) * manual_templates)

    snap_hits = sum(1 for v in from_snap.values() if v)
    snap_total = len(from_snap)

    if args.json:
        def pack_units(units: int) -> dict:
            e, u = cost_units(units)
            return {"gas_units": units, "eth": str(e), "usd": str(u)}

        payload = {
            "snapshot_path": str(args.snapshot),
            "snapshot_keys_resolved": f"{snap_hits}/{snap_total}",
            "gas_price_wei": str(int(gas_price_wei)),
            "gas_price_source": gas_price_source,
            "eth_usd": str(eth_usd),
            "eth_price_source": eth_source,
            "multiplier": str(m),
            "tx_overhead_gas_per_tx": oh,
            "gas_table_raw": gas,
            "from_snapshot": from_snap,
            "deploy": {
                "production": pack_units(eff_gas_units(gas["deploy_production"], 0)),
                "testnet_with_faucet": pack_units(eff_gas_units(gas["deploy_testnet_with_faucet"], 0)),
                "testnet_no_faucet": pack_units(eff_gas_units(gas["deploy_testnet_no_faucet"], 0)),
                "local": pack_units(eff_gas_units(gas["deploy_local"], 0)),
            },
            "upgrade": {
                "production": pack_units(eff_gas_units(gas["upgrade_production"], 0)),
                "testnet": pack_units(eff_gas_units(gas["upgrade_testnet"], 0)),
                "market_engine": pack_units(eff_gas_units(gas["upgrade_market_engine"], 0)),
            },
            "manual_per_epoch": {
                "threshold_keeper_3tx": pack_units(keeper_t_units),
                "direction_keeper_3tx": pack_units(keeper_d_units),
                "user_claim_1tx": pack_units(claim_units),
                "threshold_full_with_one_claim": pack_units(keeper_t_units + claim_units),
                "direction_full_with_one_claim": pack_units(keeper_d_units + claim_units),
            },
            "rolling": {
                "bootstrap_2tx": pack_units(rolling_bootstrap_units),
                "steady_tick_1tx": pack_units(rolling_tick_units),
                "first_day_steady_ticks_only": pack_units(int(rolling_ticks_per_day * Decimal(rolling_tick_units) * rolling_templates)),
            },
            "projected_keeper_daily": {
                "manual_threshold": pack_units(manual_day_t_units),
                "manual_direction": pack_units(manual_day_d_units),
                "rolling_steady": pack_units(rolling_day_steady_units),
                "rolling_first_day_bootstrap_plus_ticks": pack_units(rolling_bootstrap_units + rolling_day_steady_units),
            },
        }
        print(json.dumps(payload, indent=2))
        return 0

    # --- Human: assumptions + tables ---
    print(term.bold(term.cyan(" MarketEngine — deployment & epoch cost estimate ")))
    print(
        term.dim(
            f"Snapshot: {args.snapshot}  |  {snap_hits}/{snap_total} gas figures from file "
            f"(rest: embedded fallback)  |  mult=x{m}  |  tx overhead: +{oh} gas/tx"
        )
    )
    print(
        term.dim(
            f"Gas price: {gas_price_wei / Decimal(10**9):.6f} gwei ({gas_price_source})  |  "
            f"Token USD: {eth_usd:.2f} ({eth_source})"
        )
    )

    _u_prod = eff_gas_units(gas["deploy_production"], 0)
    _e_prod, _usd_prod = cost_units(_u_prod)
    _u_tn = eff_gas_units(gas["deploy_testnet_with_faucet"], 0)
    _e_tn, _usd_tn = cost_units(_u_tn)
    _e_mkt, _usd_mkt = cost_units(keeper_t_units)
    _e_mkd, _usd_mkd = cost_units(keeper_d_units)
    _e_rb, _usd_rb = cost_units(rolling_bootstrap_units)
    _e_rt, _usd_rt = cost_units(rolling_tick_units)
    print_table(
        term,
        "At-a-glance: headline costs (USD / ETH)",
        ["Item", "Gas (eff.)", "ETH", "USD"],
        [
            ["Production deploy", fmt_int(_u_prod), fmt_eth(_e_prod), fmt_usd(_usd_prod)],
            ["Testnet deploy (+ faucet)", fmt_int(_u_tn), fmt_eth(_e_tn), fmt_usd(_usd_tn)],
            ["Manual keeper / epoch (threshold)", fmt_int(keeper_t_units), fmt_eth(_e_mkt), fmt_usd(_usd_mkt)],
            ["Manual keeper / epoch (direction)", fmt_int(keeper_d_units), fmt_eth(_e_mkd), fmt_usd(_usd_mkd)],
            ["Rolling bootstrap (once / template)", fmt_int(rolling_bootstrap_units), fmt_eth(_e_rb), fmt_usd(_usd_rb)],
            ["Rolling steady tick (each interval)", fmt_int(rolling_tick_units), fmt_eth(_e_rt), fmt_usd(_usd_rt)],
        ],
        ["left", "right", "right", "right"],
        total_row_indices={0, 1},
    )

    # Deployment totals
    deploy_rows: list[list[str]] = []
    deploy_keys = [
        ("Production (mainnet script)", "deploy_production"),
        ("Testnet + faucet", "deploy_testnet_with_faucet"),
        ("Testnet, no faucet", "deploy_testnet_no_faucet"),
        ("Local / Anvil script", "deploy_local"),
    ]
    for label, key in deploy_keys:
        u = eff_gas_units(gas[key], 0)
        e, usd = cost_units(u)
        src = "snap" if from_snap.get(key) else "fb"
        deploy_rows.append([label, fmt_int(u), fmt_eth(e), fmt_usd(usd), src])
    print_table(
        term,
        "One-time deployment (forge script execution gas; entire script as one tx chain)",
        ["Scenario", "Gas (eff.)", "ETH", "USD", "src"],
        deploy_rows,
        ["left", "right", "right", "right", "right"],
        total_row_indices={0},
    )

    up_rows: list[list[str]] = []
    for label, key in [
        ("Upgrade production", "upgrade_production"),
        ("Upgrade testnet", "upgrade_testnet"),
        ("Upgrade MarketEngine", "upgrade_market_engine"),
    ]:
        u = eff_gas_units(gas[key], 0)
        e, usd = cost_units(u)
        src = "snap" if from_snap.get(key) else "fb"
        up_rows.append([label, fmt_int(u), fmt_eth(e), fmt_usd(usd), src])
    print_table(
        term,
        "One-time upgrades (script gas)",
        ["Scenario", "Gas (eff.)", "ETH", "USD", "src"],
        up_rows,
        ["left", "right", "right", "right", "right"],
    )

    # Manual breakdown
    def row_line(label: str, base: int, txs: int) -> list[str]:
        u = eff_gas_units(base, txs)
        e, usd = cost_units(u)
        return [label, fmt_int(base), str(txs), fmt_int(u), fmt_eth(e), fmt_usd(usd)]

    e_t, u_t = cost_units(keeper_t_units)
    manual_rows: list[list[str]] = [
        row_line("openEpoch (cold)", mt_open, 1),
        row_line("lockEpoch (threshold)", mt_lock_t, 1),
        row_line("resolveEpoch (threshold)", mt_res_t, 1),
        [
            "Total keeper (threshold)",
            fmt_int(keeper_t_base),
            "3",
            fmt_int(keeper_t_units),
            fmt_eth(e_t),
            fmt_usd(u_t),
        ],
    ]

    manual_rows.extend(
        [
            row_line("lockEpoch (direction)", mt_lock_d, 1),
            row_line("resolveEpoch (direction)", mt_res_d, 1),
        ]
    )
    e_d, u_d = cost_units(keeper_d_units)
    manual_rows.append(
        [
            "Total keeper (direction)",
            fmt_int(keeper_d_base),
            "3",
            fmt_int(keeper_d_units),
            fmt_eth(e_d),
            fmt_usd(u_d),
        ]
    )
    e_c, u_c = cost_units(claim_units)
    manual_rows.append(
        ["User claim (after resolve)", fmt_int(gas["user_claim_after_resolve"]), "1", fmt_int(claim_units), fmt_eth(e_c), fmt_usd(u_c)]
    )
    e_f_t, u_f_t = cost_units(keeper_t_units + claim_units)
    manual_rows.append(
        [
            "Full cycle +1 claimer (threshold)",
            fmt_int(keeper_t_base + gas["user_claim_after_resolve"]),
            "4",
            fmt_int(keeper_t_units + claim_units),
            fmt_eth(e_f_t),
            fmt_usd(u_f_t),
        ]
    )
    e_f_d, u_f_d = cost_units(keeper_d_units + claim_units)
    manual_rows.append(
        [
            "Full cycle + 1 claimer (direction)",
            fmt_int(keeper_d_base + gas["user_claim_after_resolve"]),
            "4",
            fmt_int(keeper_d_units + claim_units),
            fmt_eth(e_f_d),
            fmt_usd(u_f_d),
        ]
    )

    print_table(
        term,
        "Manual markets — per epoch (per template)",
        ["Line item", "Gas snap", "txs", "Gas eff.", "ETH", "USD"],
        manual_rows,
        ["left", "right", "right", "right", "right", "right"],
        total_row_indices={3, 6, 8, 9},
    )

    # Rolling
    rs = gas["rolling_genesis_start"]
    rl = gas["rolling_genesis_lock"]
    e_b, u_b = cost_units(rolling_bootstrap_units)
    roll_rows = [
        row_line("genesisStartRolling", rs, 1),
        row_line("genesisLockRolling", rl, 1),
        [
            "Bootstrap total",
            fmt_int(rs + rl),
            "2",
            fmt_int(rolling_bootstrap_units),
            fmt_eth(e_b),
            fmt_usd(u_b),
        ],
    ]
    e_k, u_k = cost_units(rolling_tick_units)
    roll_rows.append(
        ["executeRollingRound (steady tick)", fmt_int(gas["rolling_execute_one_tick"]), "1", fmt_int(rolling_tick_units), fmt_eth(e_k), fmt_usd(u_k)]
    )

    print_table(
        term,
        "Rolling markets — bootstrap & steady tick (per template)",
        ["Line item", "Gas snap", "txs", "Gas eff.", "ETH", "USD"],
        roll_rows,
        ["left", "right", "right", "right", "right", "right"],
        total_row_indices={2},
    )

    print_table(
        term,
        "Assumptions & limits",
        ["Field", "Value"],
        [
            ["Execution gas source", "Foundry `.gas-snapshot` tests (execution gas, not incl. calldata)"],
            ["Effective gas", f"floor(snapshot × {m}) + (txs × {oh})"],
            ["Manual keeper txs / epoch", "3 (openEpoch, lockEpoch, resolveEpoch)"],
            ["Rolling bootstrap txs", "2 (genesisStartRolling, genesisLockRolling)"],
            ["Rolling steady txs / tick", "1 (executeRollingRound)"],
            ["MANUAL_EPOCHS_PER_DAY", str(manual_epochs_per_day)],
            ["MANUAL_TEMPLATES", str(manual_templates)],
            ["ROLLING_INTERVAL_SECONDS", str(int(rolling_interval))],
            ["ROLLING_TEMPLATES", str(rolling_templates)],
            ["Rolling ticks / day (per template)", str(int(rolling_ticks_per_day))],
        ],
        ["left", "left"],
    )

    # Opex summary
    e_dt, u_dt = cost_units(manual_day_t_units)
    e_dd, u_dd = cost_units(manual_day_d_units)
    e_dr, u_dr = cost_units(rolling_day_steady_units)
    rolling_day1_units = rolling_bootstrap_units + rolling_day_steady_units
    e_d1, u_d1 = cost_units(rolling_day1_units)

    opex_rows = [
        [
            "Manual keeper (threshold) all templates",
            fmt_int(manual_day_t_units),
            fmt_eth(e_dt),
            fmt_usd(u_dt),
            fmt_usd(u_dt * 7),
            fmt_usd(u_dt * 30),
        ],
        [
            "Manual keeper (direction) all templates",
            fmt_int(manual_day_d_units),
            fmt_eth(e_dd),
            fmt_usd(u_dd),
            fmt_usd(u_dd * 7),
            fmt_usd(u_dd * 30),
        ],
        [
            "Rolling steady (ticks only) all templates",
            fmt_int(rolling_day_steady_units),
            fmt_eth(e_dr),
            fmt_usd(u_dr),
            fmt_usd(u_dr * 7),
            fmt_usd(u_dr * 30),
        ],
        [
            "Rolling 1st day (bootstrap + that day's ticks; not a daily run-rate)",
            fmt_int(rolling_day1_units),
            fmt_eth(e_d1),
            fmt_usd(u_d1),
            "-",
            "-",
        ],
    ]
    print_table(
        term,
        "Projected keeper opex (daily / weekly / ~30-day)",
        ["Scenario", "Gas/day", "ETH/day", "USD/day", "USD/wk", "USD (~30d)"],
        opex_rows,
        ["left", "right", "right", "right", "right", "right"],
        total_row_indices={3},
    )

    print()
    print(term.dim("src column: snap = from .gas-snapshot, fb = fallback constant in script."))
    print(term.dim("Last opex row is a one-off first-day total (bootstrap + ticks), not a daily rate."))
    print(term.dim("Refresh gas: forge snapshot --match-contract 'DeploymentScriptExecutionTest|EpochGasTest|MarketEngineRollingTest'"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
