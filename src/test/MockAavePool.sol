// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPoolAaveV3, ReserveConfigurationMap} from "../yield/interfaces/IPoolAaveV3.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockAToken} from "./MockAToken.sol";

contract MockAavePool is IPoolAaveV3 {
    using SafeERC20 for IERC20;

    IERC20 public immutable STAKE_TOKEN;
    MockAToken public immutable A_TOKEN;

    uint16 public yieldBps;
    bool public revertWithdraw;

    /// @dev Ray liquidity index; mock aToken balance = scaled * index /1e27 when using scaled mock.
    uint256 public liquidityIndexRay = 1e27;
    bool public reserveActive = true;
    bool public reserveFrozen;
    bool public reservePaused;

    error WithdrawReverted();

    constructor(address stakeToken_, address aToken_) {
        STAKE_TOKEN = IERC20(stakeToken_);
        A_TOKEN = MockAToken(aToken_);
    }

    function setYieldBps(uint16 bps) external {
        yieldBps = bps;
    }

    function setRevertWithdraw(bool v) external {
        revertWithdraw = v;
    }

    function setLiquidityIndexRay(uint256 idx) external {
        liquidityIndexRay = idx;
    }

    function setReserveFlags(bool active, bool frozen, bool paused) external {
        reserveActive = active;
        reserveFrozen = frozen;
        reservePaused = paused;
    }

    function getReserveNormalizedIncome(address asset) external view override returns (uint256) {
        if (asset != address(STAKE_TOKEN)) revert("bad-asset");
        return liquidityIndexRay;
    }

    function getConfiguration(address asset) external view override returns (ReserveConfigurationMap memory) {
        if (asset != address(STAKE_TOKEN)) revert("bad-asset");
        uint256 data;
        if (reserveActive) data |= (1 << 56);
        if (reserveFrozen) data |= (1 << 57);
        if (reservePaused) data |= (1 << 60);
        return ReserveConfigurationMap({data: data});
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external override {
        if (asset != address(STAKE_TOKEN)) revert("bad-asset");
        STAKE_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        A_TOKEN.mint(onBehalfOf, amount);
    }

    function withdraw(address asset, uint256 amount, address to) external override returns (uint256 withdrawn) {
        if (revertWithdraw) revert WithdrawReverted();
        if (asset != address(STAKE_TOKEN)) revert("bad-asset");

        // Burn aToken shares from caller (router).
        A_TOKEN.burn(msg.sender, amount);

        uint256 y = (amount * uint256(yieldBps)) / 10_000;
        // Ensure pool has yield to pay.
        MockERC20(address(STAKE_TOKEN)).mint(address(this), y);

        STAKE_TOKEN.safeTransfer(to, amount + y);
        return amount + y;
    }
}

