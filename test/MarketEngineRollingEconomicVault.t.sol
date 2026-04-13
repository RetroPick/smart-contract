// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketEngineBase} from "./MarketEngineBase.t.sol";

/// @notice Vault accounting vs ERC20 balance after rolling tick.
contract MarketEngineRollingEconomicVaultTest is MarketEngineBase {
    uint64 internal constant INTER = 100;

    function test_rolling_vaults_match_token_after_ticks() public {
        vm.startPrank(admin);
        engine.upsertTemplate(_directionRollingTemplate("vault", INTER, 10));
        bytes32 tid = _tid("vault");
        engine.initializeMarket(tid);
        vm.stopPrank();

        uint64 t0 = 810_000;
        vm.warp(t0);
        vm.prank(worker);
        engine.genesisStartRolling(tid);

        token.mint(address(this), 1e24);
        token.approve(address(engine), type(uint256).max);
        vm.warp(t0 + 50);
        engine.depositToSide(tid, 1, 0, 200e18);

        vm.warp(t0 + INTER);
        oracle.set(feed, 100e8, t0 + INTER, 0);
        vm.prank(worker);
        engine.genesisLockRolling(tid);

        vm.warp(t0 + INTER + 50);
        engine.depositToSide(tid, 2, 0, 333e18);

        vm.warp(t0 + 2 * INTER);
        oracle.set(feed, 105e8, t0 + 2 * INTER, 0);
        vm.prank(worker);
        engine.executeRollingRound(tid);

        (uint256 a, uint256 c, uint256 f) = engine.getVaultBalances(tid);
        assertEq(a + c + f, token.balanceOf(address(engine)));
    }
}
