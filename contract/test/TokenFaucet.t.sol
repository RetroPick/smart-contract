// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenFaucet} from "../src/test/faucet/TokenFaucet.sol";

contract TokenFaucetTest is Test {
    function test_request_mints_and_enforces_cooldown() public {
        TokenFaucet.FaucetConfig memory cfg = TokenFaucet.FaucetConfig({
            cooldownSeconds: 3600,
            maxMintAmount: 1000e18
        });
        TokenFaucet faucet = new TokenFaucet("Demo USD", "dUSD", cfg);

        address user = address(0xBEEF);
        vm.prank(user);
        faucet.request(100e18);

        assertEq(faucet.token().balanceOf(user), 100e18);

        vm.prank(user);
        vm.expectRevert(); // Cooldown(nextAt)
        faucet.request(1e18);

        vm.warp(block.timestamp + 3600);
        vm.prank(user);
        faucet.request(1e18);
        assertEq(faucet.token().balanceOf(user), 101e18);
    }

    function test_request_reverts_above_cap() public {
        TokenFaucet.FaucetConfig memory cfg = TokenFaucet.FaucetConfig({
            cooldownSeconds: 1,
            maxMintAmount: 10e18
        });
        TokenFaucet faucet = new TokenFaucet("Demo", "D", cfg);

        vm.expectRevert(abi.encodeWithSelector(TokenFaucet.AmountTooLarge.selector, 11e18, 10e18));
        faucet.request(11e18);
    }
}

