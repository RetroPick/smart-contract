#!/usr/bin/env python3
"""
Estimate MarketEngine deployment cost and keeper-driven epoch maintenance on Base Sepolia.

The script combines:
  - Foundry `.gas-snapshot` execution gas from repo tests
  - live Base Sepolia L2 gas pricing
  - OP Stack L1 data-fee estimates from `GasPriceOracle.getL1Fee(bytes)`
  - optional `forge script` dry-run simulations for `script/test` and `script/production`

Usage:
  python3 scripts/estimate_deploy_and_epoch_costs.py
  python3 scripts/estimate_deploy_and_epoch_costs.py --rpc-url https://sepolia.base.org
  python3 scripts/estimate_deploy_and_epoch_costs.py --no-deploy-sim --json

Env (optional):
  RPC_URL / BASE_SEPOLIA_RPC_URL / BASE_RPC_URL
  ETH_PRICE_USD
  MANUAL_EPOCHS_PER_DAY, MANUAL_TEMPLATES, ROLLING_INTERVAL_SECONDS, ROLLING_TEMPLATES
  NO_COLOR

CLI:
  --color auto|always|never  --no-color
  --tx-overhead-gas N        Add N gas per tx on top of execution gas (default 0)
  --no-deploy-sim            Skip `forge script` dry-runs and use snapshot/fallback deploy gas only
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from decimal import Decimal, getcontext
from pathlib import Path
from urllib.request import Request, urlopen

getcontext().prec = 40

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SNAPSHOT = REPO_ROOT / ".gas-snapshot"
DEFAULT_BASE_SEPOLIA_RPC = "https://sepolia.base.org"
COINGECKO_ETH = "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"

BASE_SEPOLIA_CHAIN_ID = 84_532
BASE_MAINNET_CHAIN_ID = 8_453
DEFAULT_SENDER = "0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38"
DEFAULT_TREASURY = "0x1111111111111111111111111111111111111111"
DEFAULT_WORKER = "0x2222222222222222222222222222222222222222"
DEFAULT_STAKE_TOKEN = "0x4200000000000000000000000000000000000006"  # Base WETH predeploy
BASE_GAS_PRICE_ORACLE = "0x420000000000000000000000000000000000000F"
TARGET_PROXY_PLACEHOLDER = "0x3333333333333333333333333333333333333333"

OPEN_EPOCH_SELECTOR = bytes.fromhex("778acc3c")
LOCK_EPOCH_SELECTOR = bytes.fromhex("1310276e")
RESOLVE_EPOCH_SELECTOR = bytes.fromhex("f1282803")
EXECUTE_ROLLING_SELECTOR = bytes.fromhex("6d9754a4")
CLAIM_SELECTOR = bytes.fromhex("5ca3e1e9")

FORGE_TOTAL_GAS_RE = re.compile(r"Estimated total gas used for script:\s*([\d,]+)")
FORGE_TX_PATH_RE = re.compile(r"Transactions saved to:\s*(.+run-latest\.json)")
SNAPSHOT_LINE = re.compile(r"^([^:]+):([^\s]+)\(\) \(gas: (\d+)\)\s*$")

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


@dataclass
class FeeBreakdown:
    gas_units: int
    execution_fee_wei: int
    l1_data_fee_wei: int
    total_fee_wei: int
    tx_count: int
    fee_mode: str
    l1_priced: bool


@dataclass
class DeployEstimate:
    label: str
    gas_units: int
    execution_fee_wei: int
    l1_data_fee_wei: int
    total_fee_wei: int
    tx_count: int
    gas_source: str
    fee_mode: str
    simulation_ok: bool
    notes: list[str]


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
    req = Request(COINGECKO_ETH, headers={"User-Agent": "retro-pick-cost-estimator/2.0"})
    with urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
    return Decimal(str(data["ethereum"]["usd"]))


def run_cmd(cmd: list[str], *, env: dict[str, str] | None = None) -> str:
    out = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    if out.returncode != 0:
        err = out.stderr.strip() or out.stdout.strip() or f"command failed: {' '.join(cmd)}"
        raise RuntimeError(err)
    return out.stdout.strip()


def cast_gas_price_wei(rpc_url: str) -> int:
    if not shutil.which("cast"):
        raise RuntimeError("cast not found in PATH")
    return int(run_cmd(["cast", "gas-price", "--rpc-url", rpc_url]))


def cast_chain_id(rpc_url: str) -> int:
    return int(run_cmd(["cast", "chain-id", "--rpc-url", rpc_url]))


def cast_l1_fee_wei(rpc_url: str, raw_tx_hex: str) -> int:
    out = run_cmd(
        [
            "cast",
            "call",
            BASE_GAS_PRICE_ORACLE,
            "getL1Fee(bytes)(uint256)",
            raw_tx_hex,
            "--rpc-url",
            rpc_url,
        ]
    )
    return int(out.split()[0], 0)


def eth_from_wei(wei: int) -> Decimal:
    return Decimal(wei) / Decimal(10**18)


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


def warn(msg: str) -> None:
    print(f"WARN: {msg}", file=sys.stderr)


def env_rpc_url() -> str:
    return (
        os.environ.get("RPC_URL")
        or os.environ.get("BASE_SEPOLIA_RPC_URL")
        or os.environ.get("BASE_RPC_URL")
        or DEFAULT_BASE_SEPOLIA_RPC
    )


def hex_to_bytes(value: str) -> bytes:
    if value.startswith("0x"):
        value = value[2:]
    if len(value) % 2 == 1:
        value = "0" + value
    return bytes.fromhex(value)


def int_to_be(value: int) -> bytes:
    if value == 0:
        return b""
    return value.to_bytes((value.bit_length() + 7) // 8, "big")


def rlp_encode(item: object) -> bytes:
    if isinstance(item, int):
        if item == 0:
            payload = b""
        else:
            payload = int_to_be(item)
        return rlp_encode(payload)

    if isinstance(item, bytes):
        if len(item) == 1 and item[0] < 0x80:
            return item
        if len(item) <= 55:
            return bytes([0x80 + len(item)]) + item
        length_bytes = int_to_be(len(item))
        return bytes([0xB7 + len(length_bytes)]) + length_bytes + item

    if isinstance(item, list):
        payload = b"".join(rlp_encode(x) for x in item)
        if len(payload) <= 55:
            return bytes([0xC0 + len(payload)]) + payload
        length_bytes = int_to_be(len(payload))
        return bytes([0xF7 + len(length_bytes)]) + length_bytes + payload

    raise TypeError(f"unsupported RLP item: {type(item)!r}")


def build_unsigned_eip1559_tx(
    *,
    chain_id: int,
    nonce: int,
    gas_limit: int,
    to: str | None,
    value: int,
    data_hex: str,
    max_fee_per_gas: int,
    max_priority_fee_per_gas: int,
) -> str:
    to_bytes = b"" if not to else hex_to_bytes(to)
    data_bytes = hex_to_bytes(data_hex)
    payload = [
        chain_id,
        nonce,
        max_priority_fee_per_gas,
        max_fee_per_gas,
        gas_limit,
        to_bytes,
        value,
        data_bytes,
        [],
    ]
    return "0x02" + rlp_encode(payload).hex()


def read_broadcast_transactions(path: Path) -> list[dict[str, object]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    txs: list[dict[str, object]] = []
    for entry in data.get("transactions", []):
        tx = entry.get("transaction")
        if isinstance(tx, dict):
            txs.append(tx)
    return txs


def estimate_l1_fees_for_transactions(
    rpc_url: str,
    chain_id: int,
    txs: list[dict[str, object]],
    gas_price_wei: int,
) -> int:
    total = 0
    for tx in txs:
        gas_limit = int(str(tx["gas"]), 16)
        nonce = int(str(tx["nonce"]), 16)
        value = int(str(tx.get("value", "0x0")), 16)
        to = tx.get("to")
        raw_hex = build_unsigned_eip1559_tx(
            chain_id=chain_id,
            nonce=nonce,
            gas_limit=gas_limit,
            to=str(to) if to else None,
            value=value,
            data_hex=str(tx.get("input", "0x")),
            max_fee_per_gas=gas_price_wei,
            max_priority_fee_per_gas=gas_price_wei,
        )
        total += cast_l1_fee_wei(rpc_url, raw_hex)
    return total


def parse_forge_simulation(stdout: str) -> tuple[int, Path]:
    gas_match = FORGE_TOTAL_GAS_RE.search(stdout)
    path_match = FORGE_TX_PATH_RE.search(stdout)
    if not gas_match:
        raise RuntimeError("could not parse `Estimated total gas used for script` from forge output")
    if not path_match:
        raise RuntimeError("could not parse dry-run transaction file path from forge output")
    gas_units = int(gas_match.group(1).replace(",", ""))
    tx_path = Path(path_match.group(1).strip())
    return gas_units, tx_path


def default_testnet_env(chain_id: int) -> dict[str, str]:
    return {
        "EXPECTED_CHAIN_ID": str(chain_id),
        "OZ_UNSAFE_SKIP_ALL_CHECKS": "1",
        "SEQUENCER_FEED": "0x0000000000000000000000000000000000000000",
        "ADMIN": DEFAULT_SENDER,
        "TREASURY": DEFAULT_TREASURY,
        "WORKER": DEFAULT_WORKER,
        "DEFAULT_SETTLEMENT_FEE_BPS": "100",
        "MAX_SWITCH_FEE_BPS": "200",
        "MAX_OUTCOMES": "8",
        "ORACLE_MAX_DELAY_SECONDS": "3600",
        "ORACLE_MAX_CONFIDENCE_BPS": "500",
        "DEPLOY_FAUCET": "1",
        "MAINNET_CHAIN_ID": str(BASE_MAINNET_CHAIN_ID),
    }


def default_production_env(chain_id: int) -> dict[str, str]:
    return {
        "EXPECTED_CHAIN_ID": str(chain_id),
        "OZ_UNSAFE_SKIP_ALL_CHECKS": "1",
        "STAKE_TOKEN": DEFAULT_STAKE_TOKEN,
        "SEQUENCER_FEED": "0x0000000000000000000000000000000000000000",
        "ADMIN": DEFAULT_SENDER,
        "TREASURY": DEFAULT_TREASURY,
        "WORKER": DEFAULT_WORKER,
        "DEFAULT_SETTLEMENT_FEE_BPS": "100",
        "MAX_SWITCH_FEE_BPS": "200",
        "MAX_OUTCOMES": "8",
        "ORACLE_MAX_DELAY_SECONDS": "3600",
        "ORACLE_MAX_CONFIDENCE_BPS": "500",
    }


def simulate_deploy(
    *,
    label: str,
    script_ref: str,
    env_overrides: dict[str, str],
    rpc_url: str,
    chain_id: int,
    gas_price_wei: int,
    fallback_gas_units: int,
) -> DeployEstimate:
    notes: list[str] = []
    if not shutil.which("forge"):
        notes.append("forge not found; using snapshot/fallback execution gas")
        exec_fee = fallback_gas_units * gas_price_wei
        return DeployEstimate(
            label=label,
            gas_units=fallback_gas_units,
            execution_fee_wei=exec_fee,
            l1_data_fee_wei=0,
            total_fee_wei=exec_fee,
            tx_count=0,
            gas_source="snapshot/fallback",
            fee_mode="execution_only",
            simulation_ok=False,
            notes=notes,
        )

    env = os.environ.copy()
    env.update(env_overrides)
    cmd = [
        "forge",
        "script",
        script_ref,
        "--rpc-url",
        rpc_url,
        "--ffi",
        "--sender",
        DEFAULT_SENDER,
        "-vv",
    ]
    proc = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        err = proc.stderr.strip() or proc.stdout.strip() or "forge script failed"
        notes.append(f"forge dry-run failed: {err}")
        exec_fee = fallback_gas_units * gas_price_wei
        return DeployEstimate(
            label=label,
            gas_units=fallback_gas_units,
            execution_fee_wei=exec_fee,
            l1_data_fee_wei=0,
            total_fee_wei=exec_fee,
            tx_count=0,
            gas_source="snapshot/fallback",
            fee_mode="execution_only",
            simulation_ok=False,
            notes=notes,
        )

    gas_units, tx_path = parse_forge_simulation(proc.stdout)
    txs = read_broadcast_transactions(tx_path)
    l1_data_fee_wei = 0
    fee_mode = "execution_only"
    try:
        l1_data_fee_wei = estimate_l1_fees_for_transactions(rpc_url, chain_id, txs, gas_price_wei)
        fee_mode = "execution_plus_l1_data"
    except Exception as e:
        notes.append(f"L1 data fee pricing failed: {e}")

    execution_fee_wei = gas_units * gas_price_wei
    return DeployEstimate(
        label=label,
        gas_units=gas_units,
        execution_fee_wei=execution_fee_wei,
        l1_data_fee_wei=l1_data_fee_wei,
        total_fee_wei=execution_fee_wei + l1_data_fee_wei,
        tx_count=len(txs),
        gas_source="forge-fork",
        fee_mode=fee_mode,
        simulation_ok=True,
        notes=notes,
    )


def abi_u64(value: int) -> bytes:
    return value.to_bytes(32, "big")


def abi_u256(value: int) -> bytes:
    return value.to_bytes(32, "big")


def abi_bytes32(value: bytes) -> bytes:
    if len(value) != 32:
        raise ValueError("bytes32 argument must be 32 bytes")
    return value


def sample_template_id() -> bytes:
    return bytes.fromhex("11" * 32)


def make_manual_calldata() -> dict[str, str]:
    template = abi_bytes32(sample_template_id())
    epoch = abi_u64(1)
    open_at = abi_u64(1_700_000_000)
    lock_at = abi_u64(1_700_003_600)
    resolve_at = abi_u64(1_700_007_200)
    return {
        "open": "0x" + (OPEN_EPOCH_SELECTOR + template + epoch + open_at + lock_at + resolve_at).hex(),
        "lock": "0x" + (LOCK_EPOCH_SELECTOR + template + epoch).hex(),
        "resolve": "0x" + (RESOLVE_EPOCH_SELECTOR + template + epoch).hex(),
        "claim": "0x" + (CLAIM_SELECTOR + template + epoch).hex(),
    }


def make_rolling_calldata() -> dict[str, str]:
    template = abi_bytes32(sample_template_id())
    return {
        "genesis_start": "0x" + (EXECUTE_ROLLING_SELECTOR + template).hex(),
        "genesis_lock": "0x" + (EXECUTE_ROLLING_SELECTOR + template).hex(),
        "tick": "0x" + (EXECUTE_ROLLING_SELECTOR + template).hex(),
    }


def fee_breakdown_for_call_series(
    *,
    rpc_url: str,
    chain_id: int,
    gas_price_wei: int,
    gas_limits: list[int],
    calldatas: list[str],
) -> tuple[int, str]:
    try:
        total = 0
        for nonce, (gas_limit, calldata) in enumerate(zip(gas_limits, calldatas)):
            raw_hex = build_unsigned_eip1559_tx(
                chain_id=chain_id,
                nonce=nonce,
                gas_limit=gas_limit,
                to=TARGET_PROXY_PLACEHOLDER,
                value=0,
                data_hex=calldata,
                max_fee_per_gas=gas_price_wei,
                max_priority_fee_per_gas=gas_price_wei,
            )
            total += cast_l1_fee_wei(rpc_url, raw_hex)
        return total, "execution_plus_l1_data"
    except Exception:
        return 0, "execution_only"


def pack_fee_breakdown(bd: FeeBreakdown, eth_usd: Decimal) -> dict[str, object]:
    execution_eth = eth_from_wei(bd.execution_fee_wei)
    l1_eth = eth_from_wei(bd.l1_data_fee_wei)
    total_eth = eth_from_wei(bd.total_fee_wei)
    return {
        "gas_units": bd.gas_units,
        "tx_count": bd.tx_count,
        "fee_mode": bd.fee_mode,
        "l1_priced": bd.l1_priced,
        "execution_fee_wei": str(bd.execution_fee_wei),
        "l1_data_fee_wei": str(bd.l1_data_fee_wei),
        "total_fee_wei": str(bd.total_fee_wei),
        "execution_eth": str(execution_eth),
        "l1_data_eth": str(l1_eth),
        "total_eth": str(total_eth),
        "total_usd": str(usd_from_eth(total_eth, eth_usd)),
    }


def deploy_estimate_payload(dep: DeployEstimate, eth_usd: Decimal) -> dict[str, object]:
    execution_eth = eth_from_wei(dep.execution_fee_wei)
    l1_eth = eth_from_wei(dep.l1_data_fee_wei)
    total_eth = eth_from_wei(dep.total_fee_wei)
    return {
        "label": dep.label,
        "gas_units": dep.gas_units,
        "tx_count": dep.tx_count,
        "gas_source": dep.gas_source,
        "fee_mode": dep.fee_mode,
        "simulation_ok": dep.simulation_ok,
        "notes": dep.notes,
        "execution_fee_wei": str(dep.execution_fee_wei),
        "l1_data_fee_wei": str(dep.l1_data_fee_wei),
        "total_fee_wei": str(dep.total_fee_wei),
        "execution_eth": str(execution_eth),
        "l1_data_eth": str(l1_eth),
        "total_eth": str(total_eth),
        "total_usd": str(usd_from_eth(total_eth, eth_usd)),
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--snapshot", type=Path, default=DEFAULT_SNAPSHOT, help="Path to Foundry .gas-snapshot")
    p.add_argument("--rpc-url", default=env_rpc_url(), help="Base Sepolia RPC used for live gas and deploy simulation")
    p.add_argument("--gas-price-gwei", type=Decimal, default=None)
    p.add_argument("--eth-price-usd", type=Decimal, default=None)
    p.add_argument("--multiplier", type=Decimal, default=Decimal("1.15"), help="Safety multiplier on snapshot execution gas")
    p.add_argument(
        "--tx-overhead-gas",
        type=int,
        default=0,
        help="Extra gas per tx added on top of execution gas (e.g. 21000 intrinsic)",
    )
    p.add_argument("--json", action="store_true")
    p.add_argument("--no-deploy-sim", action="store_true", help="Skip forge fork dry-runs for deploy cost")
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

    chain_id = BASE_SEPOLIA_CHAIN_ID
    chain_id_source = "default"
    try:
        chain_id = cast_chain_id(args.rpc_url)
        chain_id_source = "rpc"
    except Exception as e:
        warn(f"could not read chain id from RPC ({e}); assuming Base Sepolia chain id {BASE_SEPOLIA_CHAIN_ID}")

    gas_price_wei: int
    gas_price_source = "override"
    if args.gas_price_gwei is not None:
        gas_price_wei = int(args.gas_price_gwei * Decimal(10**9))
    else:
        try:
            gas_price_wei = cast_gas_price_wei(args.rpc_url)
            gas_price_source = "rpc (cast gas-price)"
        except Exception as e:
            warn(f"could not read gas price from RPC ({e}); using 0.01 gwei placeholder")
            gas_price_wei = 10_000_000
            gas_price_source = "placeholder"

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
                warn(f"ETH price fetch failed ({e}); using 3000 USD")
                eth_usd = Decimal("3000")
                eth_source = "fallback"

    m = args.multiplier
    oh = max(0, args.tx_overhead_gas)

    def eff_gas_units(base_gas: int, tx_count: int = 0) -> int:
        exec_part = int(Decimal(base_gas) * m)
        return exec_part + tx_count * oh

    def build_breakdown(units: int, tx_count: int, l1_data_fee_wei: int, fee_mode: str) -> FeeBreakdown:
        execution_fee_wei = units * gas_price_wei
        return FeeBreakdown(
            gas_units=units,
            execution_fee_wei=execution_fee_wei,
            l1_data_fee_wei=l1_data_fee_wei,
            total_fee_wei=execution_fee_wei + l1_data_fee_wei,
            tx_count=tx_count,
            fee_mode=fee_mode,
            l1_priced=l1_data_fee_wei > 0,
        )

    manual_epochs_per_day = Decimal(os.environ.get("MANUAL_EPOCHS_PER_DAY", "1"))
    rolling_interval = Decimal(os.environ.get("ROLLING_INTERVAL_SECONDS", "3600"))
    rolling_templates = Decimal(os.environ.get("ROLLING_TEMPLATES", "1"))
    manual_templates = Decimal(os.environ.get("MANUAL_TEMPLATES", "1"))

    manual_calldata = make_manual_calldata()
    rolling_calldata = make_rolling_calldata()

    mt_open = gas["manual_open_epoch_cold"]
    mt_lock_t = gas["manual_lock_epoch_threshold"]
    mt_res_t = gas["manual_resolve_epoch_threshold"]
    mt_lock_d = gas["manual_lock_epoch_direction"]
    mt_res_d = gas["manual_resolve_epoch_direction"]
    keeper_t_units = eff_gas_units(mt_open + mt_lock_t + mt_res_t, 3)
    keeper_d_units = eff_gas_units(mt_open + mt_lock_d + mt_res_d, 3)
    claim_units = eff_gas_units(gas["user_claim_after_resolve"], 1)

    keeper_t_l1, keeper_t_fee_mode = fee_breakdown_for_call_series(
        rpc_url=args.rpc_url,
        chain_id=chain_id,
        gas_price_wei=gas_price_wei,
        gas_limits=[eff_gas_units(mt_open, 1), eff_gas_units(mt_lock_t, 1), eff_gas_units(mt_res_t, 1)],
        calldatas=[manual_calldata["open"], manual_calldata["lock"], manual_calldata["resolve"]],
    )
    keeper_d_l1, keeper_d_fee_mode = fee_breakdown_for_call_series(
        rpc_url=args.rpc_url,
        chain_id=chain_id,
        gas_price_wei=gas_price_wei,
        gas_limits=[eff_gas_units(mt_open, 1), eff_gas_units(mt_lock_d, 1), eff_gas_units(mt_res_d, 1)],
        calldatas=[manual_calldata["open"], manual_calldata["lock"], manual_calldata["resolve"]],
    )
    claim_l1, claim_fee_mode = fee_breakdown_for_call_series(
        rpc_url=args.rpc_url,
        chain_id=chain_id,
        gas_price_wei=gas_price_wei,
        gas_limits=[claim_units],
        calldatas=[manual_calldata["claim"]],
    )

    manual_threshold = build_breakdown(keeper_t_units, 3, keeper_t_l1, keeper_t_fee_mode)
    manual_direction = build_breakdown(keeper_d_units, 3, keeper_d_l1, keeper_d_fee_mode)
    manual_claim = build_breakdown(claim_units, 1, claim_l1, claim_fee_mode)
    manual_threshold_full = build_breakdown(
        keeper_t_units + claim_units,
        4,
        keeper_t_l1 + claim_l1,
        "execution_plus_l1_data" if keeper_t_l1 or claim_l1 else "execution_only",
    )
    manual_direction_full = build_breakdown(
        keeper_d_units + claim_units,
        4,
        keeper_d_l1 + claim_l1,
        "execution_plus_l1_data" if keeper_d_l1 or claim_l1 else "execution_only",
    )

    rolling_bootstrap_units = eff_gas_units(gas["rolling_genesis_start"] + gas["rolling_genesis_lock"], 2)
    rolling_tick_units = eff_gas_units(gas["rolling_execute_one_tick"], 1)
    rolling_bootstrap_l1, rolling_bootstrap_fee_mode = fee_breakdown_for_call_series(
        rpc_url=args.rpc_url,
        chain_id=chain_id,
        gas_price_wei=gas_price_wei,
        gas_limits=[eff_gas_units(gas["rolling_genesis_start"], 1), eff_gas_units(gas["rolling_genesis_lock"], 1)],
        calldatas=[rolling_calldata["genesis_start"], rolling_calldata["genesis_lock"]],
    )
    rolling_tick_l1, rolling_tick_fee_mode = fee_breakdown_for_call_series(
        rpc_url=args.rpc_url,
        chain_id=chain_id,
        gas_price_wei=gas_price_wei,
        gas_limits=[rolling_tick_units],
        calldatas=[rolling_calldata["tick"]],
    )
    rolling_bootstrap = build_breakdown(rolling_bootstrap_units, 2, rolling_bootstrap_l1, rolling_bootstrap_fee_mode)
    rolling_tick = build_breakdown(rolling_tick_units, 1, rolling_tick_l1, rolling_tick_fee_mode)

    rolling_ticks_per_day = Decimal(86400) / rolling_interval
    rolling_day_steady_units = int(rolling_ticks_per_day * Decimal(rolling_tick_units) * rolling_templates)
    rolling_day_steady_l1 = int(rolling_ticks_per_day * Decimal(rolling_tick_l1) * rolling_templates)
    manual_day_t_units = int(manual_epochs_per_day * Decimal(keeper_t_units) * manual_templates)
    manual_day_d_units = int(manual_epochs_per_day * Decimal(keeper_d_units) * manual_templates)
    manual_day_t_l1 = int(manual_epochs_per_day * Decimal(keeper_t_l1) * manual_templates)
    manual_day_d_l1 = int(manual_epochs_per_day * Decimal(keeper_d_l1) * manual_templates)

    rolling_first_day = build_breakdown(
        rolling_bootstrap_units + rolling_day_steady_units,
        2 + int(rolling_ticks_per_day),
        rolling_bootstrap_l1 + rolling_day_steady_l1,
        "execution_plus_l1_data" if rolling_bootstrap_l1 or rolling_day_steady_l1 else "execution_only",
    )
    rolling_steady = build_breakdown(
        rolling_day_steady_units,
        int(rolling_ticks_per_day),
        rolling_day_steady_l1,
        "execution_plus_l1_data" if rolling_day_steady_l1 else "execution_only",
    )
    manual_threshold_daily = build_breakdown(
        manual_day_t_units,
        int(manual_epochs_per_day * manual_templates * 3),
        manual_day_t_l1,
        "execution_plus_l1_data" if manual_day_t_l1 else "execution_only",
    )
    manual_direction_daily = build_breakdown(
        manual_day_d_units,
        int(manual_epochs_per_day * manual_templates * 3),
        manual_day_d_l1,
        "execution_plus_l1_data" if manual_day_d_l1 else "execution_only",
    )

    deploy_estimates: dict[str, DeployEstimate] = {}
    if args.no_deploy_sim:
        for key, label in [
            ("deploy_production", "Production (production script)"),
            ("deploy_testnet_with_faucet", "Testnet + faucet (test script)"),
        ]:
            units = eff_gas_units(gas[key], 0)
            exec_fee = units * gas_price_wei
            deploy_estimates[key] = DeployEstimate(
                label=label,
                gas_units=units,
                execution_fee_wei=exec_fee,
                l1_data_fee_wei=0,
                total_fee_wei=exec_fee,
                tx_count=0,
                gas_source="snapshot/fallback",
                fee_mode="execution_only",
                simulation_ok=False,
                notes=["deploy simulation disabled via --no-deploy-sim"],
            )
    else:
        deploy_estimates["deploy_production"] = simulate_deploy(
            label="Production (production script)",
            script_ref="script/production/DeployProduction.s.sol:DeployProduction",
            env_overrides=default_production_env(chain_id),
            rpc_url=args.rpc_url,
            chain_id=chain_id,
            gas_price_wei=gas_price_wei,
            fallback_gas_units=eff_gas_units(gas["deploy_production"], 0),
        )
        deploy_estimates["deploy_testnet_with_faucet"] = simulate_deploy(
            label="Testnet + faucet (test script)",
            script_ref="script/test/DeployTestnet.s.sol:DeployTestnet",
            env_overrides=default_testnet_env(chain_id),
            rpc_url=args.rpc_url,
            chain_id=chain_id,
            gas_price_wei=gas_price_wei,
            fallback_gas_units=eff_gas_units(gas["deploy_testnet_with_faucet"], 0),
        )

    deploy_estimates["deploy_testnet_no_faucet"] = DeployEstimate(
        label="Testnet no faucet (snapshot baseline)",
        gas_units=eff_gas_units(gas["deploy_testnet_no_faucet"], 0),
        execution_fee_wei=eff_gas_units(gas["deploy_testnet_no_faucet"], 0) * gas_price_wei,
        l1_data_fee_wei=0,
        total_fee_wei=eff_gas_units(gas["deploy_testnet_no_faucet"], 0) * gas_price_wei,
        tx_count=0,
        gas_source="snapshot/fallback",
        fee_mode="execution_only",
        simulation_ok=False,
        notes=["retained as snapshot baseline only; live simulation uses faucet path to avoid external token env"],
    )
    deploy_estimates["deploy_local"] = DeployEstimate(
        label="Local / Anvil script",
        gas_units=eff_gas_units(gas["deploy_local"], 0),
        execution_fee_wei=eff_gas_units(gas["deploy_local"], 0) * gas_price_wei,
        l1_data_fee_wei=0,
        total_fee_wei=eff_gas_units(gas["deploy_local"], 0) * gas_price_wei,
        tx_count=0,
        gas_source="snapshot/fallback",
        fee_mode="execution_only",
        simulation_ok=False,
        notes=["local baseline only"],
    )

    snap_hits = sum(1 for v in from_snap.values() if v)
    snap_total = len(from_snap)

    if args.json:
        payload = {
            "snapshot_path": str(args.snapshot),
            "snapshot_keys_resolved": f"{snap_hits}/{snap_total}",
            "rpc_url": args.rpc_url,
            "chain_id": chain_id,
            "chain_id_source": chain_id_source,
            "gas_price_wei": str(gas_price_wei),
            "gas_price_source": gas_price_source,
            "eth_usd": str(eth_usd),
            "eth_price_source": eth_source,
            "multiplier": str(m),
            "tx_overhead_gas_per_tx": oh,
            "deploy_simulation_enabled": not args.no_deploy_sim,
            "defaults": {
                "sender": DEFAULT_SENDER,
                "treasury": DEFAULT_TREASURY,
                "worker": DEFAULT_WORKER,
                "production_stake_token": DEFAULT_STAKE_TOKEN,
                "testnet_uses_faucet": True,
                "gas_price_oracle": BASE_GAS_PRICE_ORACLE,
            },
            "gas_table_raw": gas,
            "from_snapshot": from_snap,
            "deploy": {key: deploy_estimate_payload(dep, eth_usd) for key, dep in deploy_estimates.items()},
            "manual_per_epoch": {
                "threshold_keeper_3tx": pack_fee_breakdown(manual_threshold, eth_usd),
                "direction_keeper_3tx": pack_fee_breakdown(manual_direction, eth_usd),
                "user_claim_1tx": pack_fee_breakdown(manual_claim, eth_usd),
                "threshold_full_with_one_claim": pack_fee_breakdown(manual_threshold_full, eth_usd),
                "direction_full_with_one_claim": pack_fee_breakdown(manual_direction_full, eth_usd),
            },
            "rolling": {
                "bootstrap_2tx": pack_fee_breakdown(rolling_bootstrap, eth_usd),
                "steady_tick_1tx": pack_fee_breakdown(rolling_tick, eth_usd),
                "first_day_steady_ticks_only": pack_fee_breakdown(rolling_steady, eth_usd),
                "first_day_bootstrap_plus_ticks": pack_fee_breakdown(rolling_first_day, eth_usd),
            },
            "projected_keeper_daily": {
                "manual_threshold": pack_fee_breakdown(manual_threshold_daily, eth_usd),
                "manual_direction": pack_fee_breakdown(manual_direction_daily, eth_usd),
                "rolling_steady": pack_fee_breakdown(rolling_steady, eth_usd),
                "rolling_first_day_bootstrap_plus_ticks": pack_fee_breakdown(rolling_first_day, eth_usd),
            },
        }
        print(json.dumps(payload, indent=2))
        return 0

    def fee_cols(total_wei: int) -> tuple[str, str]:
        eth = eth_from_wei(total_wei)
        return fmt_eth(eth), fmt_usd(usd_from_eth(eth, eth_usd))

    print(term.bold(term.cyan(" MarketEngine — live Base Sepolia cost estimate ")))
    print(
        term.dim(
            f"Snapshot: {args.snapshot}  |  {snap_hits}/{snap_total} gas figures from file "
            f"(rest: embedded fallback)  |  mult=x{m}  |  tx overhead: +{oh} gas/tx"
        )
    )
    print(
        term.dim(
            f"RPC: {args.rpc_url}  |  chain id: {chain_id} ({chain_id_source})  |  "
            f"Gas price: {Decimal(gas_price_wei) / Decimal(10**9):.6f} gwei ({gas_price_source})  |  "
            f"ETH/USD: {eth_usd:.2f} ({eth_source})"
        )
    )

    prod_eth, prod_usd = fee_cols(deploy_estimates["deploy_production"].total_fee_wei)
    test_eth, test_usd = fee_cols(deploy_estimates["deploy_testnet_with_faucet"].total_fee_wei)
    mt_eth, mt_usd = fee_cols(manual_threshold.total_fee_wei)
    md_eth, md_usd = fee_cols(manual_direction.total_fee_wei)
    rb_eth, rb_usd = fee_cols(rolling_bootstrap.total_fee_wei)
    rt_eth, rt_usd = fee_cols(rolling_tick.total_fee_wei)
    print_table(
        term,
        "At-a-glance: headline costs (live L2 pricing)",
        ["Item", "Gas", "ETH", "USD"],
        [
            ["Production deploy", fmt_int(deploy_estimates["deploy_production"].gas_units), prod_eth, prod_usd],
            ["Testnet deploy (+ faucet)", fmt_int(deploy_estimates["deploy_testnet_with_faucet"].gas_units), test_eth, test_usd],
            ["Manual keeper / epoch (threshold)", fmt_int(manual_threshold.gas_units), mt_eth, mt_usd],
            ["Manual keeper / epoch (direction)", fmt_int(manual_direction.gas_units), md_eth, md_usd],
            ["Rolling bootstrap (once / template)", fmt_int(rolling_bootstrap.gas_units), rb_eth, rb_usd],
            ["Rolling steady tick (each interval)", fmt_int(rolling_tick.gas_units), rt_eth, rt_usd],
        ],
        ["left", "right", "right", "right"],
        total_row_indices={0, 1},
    )

    deploy_rows: list[list[str]] = []
    for key in ["deploy_production", "deploy_testnet_with_faucet", "deploy_testnet_no_faucet", "deploy_local"]:
        dep = deploy_estimates[key]
        exec_eth = fmt_eth(eth_from_wei(dep.execution_fee_wei))
        l1_eth = fmt_eth(eth_from_wei(dep.l1_data_fee_wei))
        total_eth, total_usd = fee_cols(dep.total_fee_wei)
        deploy_rows.append(
            [
                dep.label,
                fmt_int(dep.gas_units),
                str(dep.tx_count),
                exec_eth,
                l1_eth,
                total_eth,
                total_usd,
                dep.gas_source,
            ]
        )
    print_table(
        term,
        "One-time deployment (simulation on Base Sepolia when available)",
        ["Scenario", "Gas", "txs", "Exec ETH", "L1 ETH", "Total ETH", "USD", "src"],
        deploy_rows,
        ["left", "right", "right", "right", "right", "right", "right", "right"],
        total_row_indices={0, 1},
    )

    def keeper_row(label: str, bd: FeeBreakdown, base_gas: int, txs: int) -> list[str]:
        total_eth, total_usd = fee_cols(bd.total_fee_wei)
        return [
            label,
            fmt_int(base_gas),
            str(txs),
            fmt_int(bd.gas_units),
            fmt_eth(eth_from_wei(bd.execution_fee_wei)),
            fmt_eth(eth_from_wei(bd.l1_data_fee_wei)),
            total_eth,
            total_usd,
        ]

    print_table(
        term,
        "Manual markets — per epoch (live Base Sepolia pricing)",
        ["Line item", "Gas snap", "txs", "Gas eff.", "Exec ETH", "L1 ETH", "Total ETH", "USD"],
        [
            keeper_row("Total keeper (threshold)", manual_threshold, mt_open + mt_lock_t + mt_res_t, 3),
            keeper_row("Total keeper (direction)", manual_direction, mt_open + mt_lock_d + mt_res_d, 3),
            keeper_row("User claim (after resolve)", manual_claim, gas["user_claim_after_resolve"], 1),
            keeper_row(
                "Full cycle + 1 claimer (threshold)",
                manual_threshold_full,
                mt_open + mt_lock_t + mt_res_t + gas["user_claim_after_resolve"],
                4,
            ),
            keeper_row(
                "Full cycle + 1 claimer (direction)",
                manual_direction_full,
                mt_open + mt_lock_d + mt_res_d + gas["user_claim_after_resolve"],
                4,
            ),
        ],
        ["left", "right", "right", "right", "right", "right", "right", "right"],
        total_row_indices={0, 1, 3, 4},
    )

    print_table(
        term,
        "Rolling markets — bootstrap & steady tick (live Base Sepolia pricing)",
        ["Line item", "Gas snap", "txs", "Gas eff.", "Exec ETH", "L1 ETH", "Total ETH", "USD"],
        [
            keeper_row(
                "Bootstrap total",
                rolling_bootstrap,
                gas["rolling_genesis_start"] + gas["rolling_genesis_lock"],
                2,
            ),
            keeper_row("executeRollingRound (steady tick)", rolling_tick, gas["rolling_execute_one_tick"], 1),
        ],
        ["left", "right", "right", "right", "right", "right", "right", "right"],
        total_row_indices={0},
    )

    threshold_day_eth, threshold_day_usd = fee_cols(manual_threshold_daily.total_fee_wei)
    direction_day_eth, direction_day_usd = fee_cols(manual_direction_daily.total_fee_wei)
    rolling_day_eth, rolling_day_usd = fee_cols(rolling_steady.total_fee_wei)
    rolling_first_day_eth, rolling_first_day_usd = fee_cols(rolling_first_day.total_fee_wei)
    print_table(
        term,
        "Projected keeper opex (daily / weekly / ~30-day)",
        ["Scenario", "Gas/day", "ETH/day", "USD/day", "USD/wk", "USD (~30d)"],
        [
            [
                "Manual keeper (threshold) all templates",
                fmt_int(manual_threshold_daily.gas_units),
                threshold_day_eth,
                threshold_day_usd,
                fmt_usd(usd_from_eth(eth_from_wei(manual_threshold_daily.total_fee_wei) * 7, eth_usd)),
                fmt_usd(usd_from_eth(eth_from_wei(manual_threshold_daily.total_fee_wei) * 30, eth_usd)),
            ],
            [
                "Manual keeper (direction) all templates",
                fmt_int(manual_direction_daily.gas_units),
                direction_day_eth,
                direction_day_usd,
                fmt_usd(usd_from_eth(eth_from_wei(manual_direction_daily.total_fee_wei) * 7, eth_usd)),
                fmt_usd(usd_from_eth(eth_from_wei(manual_direction_daily.total_fee_wei) * 30, eth_usd)),
            ],
            [
                "Rolling steady (ticks only) all templates",
                fmt_int(rolling_steady.gas_units),
                rolling_day_eth,
                rolling_day_usd,
                fmt_usd(usd_from_eth(eth_from_wei(rolling_steady.total_fee_wei) * 7, eth_usd)),
                fmt_usd(usd_from_eth(eth_from_wei(rolling_steady.total_fee_wei) * 30, eth_usd)),
            ],
            [
                "Rolling 1st day (bootstrap + that day's ticks)",
                fmt_int(rolling_first_day.gas_units),
                rolling_first_day_eth,
                rolling_first_day_usd,
                "-",
                "-",
            ],
        ],
        ["left", "right", "right", "right", "right", "right"],
        total_row_indices={3},
    )

    notes_rows = [
        ["Default deploy target", "Base Sepolia for both production-path and testnet-path simulations"],
        [
            "Deploy env handling (no secrets)",
            "the estimator injects safe defaults into `forge script` dry-runs (no --broadcast, no private key needed)",
        ],
        ["Production dry-run stake token", f"{DEFAULT_STAKE_TOKEN} (Base WETH predeploy used as a safe stand-in)"],
        ["Testnet dry-run token mode", "DEPLOY_FAUCET=1 (deploys demo token + faucet, so no external STAKE_TOKEN needed)"],
        ["L2 fee model", "execution gas × live Base Sepolia gas price"],
        ["L1 fee model", "OP Stack GasPriceOracle.getL1Fee(bytes) (L1 data publishing fee component)"],
        ["Deploy gas source", "forge-fork dry-run when available; otherwise snapshot/fallback repriced with live fees"],
        ["Maintenance gas source", "execution gas comes from `.gas-snapshot` tests; fees are priced live"],
        [
            "MANUAL_EPOCHS_PER_DAY",
            f"{manual_epochs_per_day} (manual epochs/day; each epoch is 3 keeper txs: openEpoch → lockEpoch → resolveEpoch)",
        ],
        ["MANUAL_TEMPLATES", f"{manual_templates} (how many manual market templates you run)"],
        [
            "ROLLING_INTERVAL_SECONDS",
            f"{int(rolling_interval)} (seconds between rolling ticks; ticks/day = 86400 / interval)",
        ],
        ["ROLLING_TEMPLATES", f"{rolling_templates} (how many rolling market templates you run)"],
        ["Rolling ticks / day (per template)", f"{int(rolling_ticks_per_day)} (derived: 86400/{int(rolling_interval)})"],
        [
            "Example (high activity)",
            "MANUAL_EPOCHS_PER_DAY=50 ROLLING_INTERVAL_SECONDS=1800 ROLLING_TEMPLATES=2 (50 manual epochs/day; 48 rolling ticks/day/template; 2 rolling templates)",
        ],
    ]
    print_table(term, "Assumptions & limits", ["Field", "Value"], notes_rows, ["left", "left"])

    print()
    print(term.dim("Deploy src: forge-fork = live Base Sepolia dry-run, snapshot/fallback = local gas baseline repriced with live fee data."))
    print(term.dim("Maintenance gas units come from `.gas-snapshot`; the Base Sepolia execution and OP Stack L1 data fees are priced live."))
    print(term.dim("Refresh execution baselines with: forge snapshot --match-contract 'DeploymentScriptExecutionTest|EpochGasTest|MarketEngineRollingTest'"))

    all_notes = [note for dep in deploy_estimates.values() for note in dep.notes]
    if all_notes:
        print()
        print(term.bold(term.yellow("Notes")))
        for note in all_notes:
            print(f"- {note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
