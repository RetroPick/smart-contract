// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenFaucet} from "../../src/test/faucet/TokenFaucet.sol";

contract TokenFaucetTest is Test {
    bytes32 private constant REQUEST_TYPEHASH =
        keccak256("MintRequest(address recipient,uint256 amount,uint256 nonce,uint64 deadline)");

    function test_request_mints_and_enforces_cooldown() public {
        TokenFaucet.FaucetConfig memory cfg = TokenFaucet.FaucetConfig({cooldownSeconds: 3600, maxMintAmount: 1000e18});
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
        TokenFaucet.FaucetConfig memory cfg = TokenFaucet.FaucetConfig({cooldownSeconds: 1, maxMintAmount: 10e18});
        TokenFaucet faucet = new TokenFaucet("Demo", "D", cfg);

        vm.expectRevert(abi.encodeWithSelector(TokenFaucet.AmountTooLarge.selector, 11e18, 10e18));
        faucet.request(11e18);
    }

    function test_requestWithSig_mints_for_recipient_via_relayer() public {
        TokenFaucet.FaucetConfig memory cfg = TokenFaucet.FaucetConfig({cooldownSeconds: 3600, maxMintAmount: 1000e18});
        TokenFaucet faucet = new TokenFaucet("Demo USD", "dUSD", cfg);

        uint256 userPk = 0xA11CE;
        address user = vm.addr(userPk);
        address relayer = makeAddr("relayer");
        uint64 deadline = uint64(block.timestamp + 1 days);
        uint256 amount = 250e18;

        bytes memory sig = _signMintRequest(faucet, userPk, user, amount, deadline);

        vm.prank(relayer);
        faucet.requestWithSig(user, amount, deadline, sig);

        assertEq(faucet.token().balanceOf(user), amount);
        assertEq(faucet.nonces(user), 1);

        vm.prank(relayer);
        vm.expectRevert(TokenFaucet.InvalidSignature.selector);
        faucet.requestWithSig(user, amount, deadline, sig);
    }

    function test_requestWithSig_reverts_on_expired_deadline() public {
        TokenFaucet.FaucetConfig memory cfg = TokenFaucet.FaucetConfig({cooldownSeconds: 3600, maxMintAmount: 1000e18});
        TokenFaucet faucet = new TokenFaucet("Demo USD", "dUSD", cfg);

        uint256 userPk = 0xB0B;
        address user = vm.addr(userPk);
        uint64 deadline = uint64(block.timestamp);
        bytes memory sig = _signMintRequest(faucet, userPk, user, 100e18, deadline);

        vm.warp(block.timestamp + 1);
        vm.expectRevert(abi.encodeWithSelector(TokenFaucet.ExpiredSignature.selector, deadline));
        faucet.requestWithSig(user, 100e18, deadline, sig);
    }

    function _signMintRequest(TokenFaucet faucet, uint256 userPk, address user, uint256 amount, uint64 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeparator(address(faucet)),
                keccak256(abi.encode(REQUEST_TYPEHASH, user, amount, 0, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _domainSeparator(address faucet) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("TokenFaucet")),
                keccak256(bytes("1")),
                block.chainid,
                faucet
            )
        );
    }
}
