// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TrustedReporterAdapter} from "../../src/oracle/TrustedReporterAdapter.sol";

/// @notice Exploit PoC tests for TrustedReporterAdapter security vulnerabilities:
///   M1 — clearOhlcResult missing, leaving stale OHLC data blocking scalar resolves
contract TrustedReporterAdapterSecurity is Test {
    TrustedReporterAdapter internal adapter;

    uint256 internal constant REPORTER_PK = 0xDEAD1;
    address internal reporter;
    address internal owner = address(0xABCDEF1234567890);

    bytes32 internal constant MARKET_ID = keccak256("eth-ohlc-market");
    bytes32 internal constant DS = keccak256("binance-eth");

    function setUp() public {
        reporter = vm.addr(REPORTER_PK);
        vm.prank(owner);
        adapter = new TrustedReporterAdapter(reporter, owner, 3600);
    }

    // ─── M1: clearOhlcResult ────────────────────────────────────────────────

    /// @notice After fix: clearOhlcResult exists, clears OHLC data, and emits event.
    function test_clearOhlcResult_existsAndWorks() public {
        uint64 t = uint64(block.timestamp);
        _postOhlc(MARKET_ID, 1900e8, 1800e8, 1850e8, t);

        // Confirm postResolveResult is blocked by OHLC (AlreadyResolved)
        bytes memory sig = _signResolve(MARKET_ID, 1850e8, t, DS);
        vm.expectRevert();
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, sig);

        // After fix: clearOhlcResult should succeed
        vm.prank(owner);
        adapter.clearOhlcResult(MARKET_ID);

        // Now postResolveResult should succeed
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, sig);
        (, bool resolved) = adapter.getResult(MARKET_ID);
        assertTrue(resolved, "Scalar resolve should succeed after clearing OHLC");
    }

    /// @notice clearOhlcResult is owner-only.
    function test_clearOhlcResult_onlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        adapter.clearOhlcResult(MARKET_ID);
    }

    /// @notice Non-owner cannot clear any result.
    function test_clearResolveResult_onlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        adapter.clearResolveResult(MARKET_ID);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    function _postOhlc(bytes32 marketId, int256 high, int256 low, int256 close, uint64 observedAt) internal {
        bytes32 digest = adapter.hashOhlcClaim(marketId, high, low, close, observedAt, DS);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(REPORTER_PK, digest);
        adapter.postOhlcResult(marketId, high, low, close, observedAt, DS, abi.encodePacked(r, s, v));
    }

    function _signResolve(bytes32 marketId, int256 valueE8, uint64 observedAt, bytes32 ds)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = adapter.hashResolveClaim(marketId, valueE8, observedAt, ds);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(REPORTER_PK, digest);
        return abi.encodePacked(r, s, v);
    }
}
