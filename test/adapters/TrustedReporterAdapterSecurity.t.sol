// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TrustedReporterAdapter} from "../../src/oracle/TrustedReporterAdapter.sol";

/// @notice Exploit PoC tests for TrustedReporterAdapter security vulnerabilities:
///   M1 — clearOhlcResult missing, leaving stale OHLC data blocking scalar resolves
contract TrustedReporterAdapterSecurity is Test {
    TrustedReporterAdapter internal adapter;

    uint256 internal constant REPORTER_PK = 0xDEAD1;
    uint256 internal constant REPORTER_PK_2 = 0xDEAD2;
    address internal reporter;
    address internal reporter2;
    address internal owner = address(0xABCDEF1234567890);

    bytes32 internal constant MARKET_ID = keccak256("eth-ohlc-market");
    bytes32 internal constant DS = keccak256("binance-eth");

    function setUp() public {
        reporter = vm.addr(REPORTER_PK);
        reporter2 = vm.addr(REPORTER_PK_2);
        vm.prank(owner);
        adapter = new TrustedReporterAdapter(reporter, owner, 3600);
    }

    // ─── M1: clearOhlcResult ────────────────────────────────────────────────

    /// @notice After fix: clearOhlcResult exists, clears OHLC data, and emits event.
    function test_clearOhlcResult_existsAndWorks() public {
        uint64 t = uint64(block.timestamp);
        _postOhlc(MARKET_ID, 1900e8, 1800e8, 1850e8, t);

        // Confirm postResolveResult is blocked by OHLC (AlreadyResolved)
        bytes memory staleSig = _signResolve(MARKET_ID, 1850e8, t, DS);
        vm.expectRevert();
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleSig);

        // After fix: clearOhlcResult should succeed
        vm.prank(owner);
        adapter.clearOhlcResult(MARKET_ID);

        // The old scalar signature must no longer be replayable after the clear.
        vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleSig);

        // Now postResolveResult should succeed
        bytes memory correctedSig = _signResolve(MARKET_ID, 1860e8, t, DS);
        adapter.postResolveResult(MARKET_ID, 1860e8, t, DS, correctedSig);
        (, bool resolved) = adapter.getResult(MARKET_ID);
        assertTrue(resolved, "Scalar resolve should succeed after clearing OHLC");
    }

    /// @notice clearOhlcResult is owner-only.
    function test_clearOhlcResult_onlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        adapter.clearOhlcResult(MARKET_ID);
    }

    function test_clearLockSample_emitsEvent() public {
        uint64 t = uint64(block.timestamp);
        bytes memory sig = _signLock(MARKET_ID, 1800e8, t, DS);
        adapter.postLockSample(MARKET_ID, 1800e8, t, DS, sig);

        vm.expectEmit(true, true, true, true);
        emit TrustedReporterAdapter.LockSampleCleared(MARKET_ID);

        vm.prank(owner);
        adapter.clearLockSample(MARKET_ID);

        (, , bool written) = adapter.getLockSample(MARKET_ID);
        assertFalse(written, "lock sample should be cleared");
    }

    function test_clearResolveResult_emitsEvent() public {
        uint64 t = uint64(block.timestamp);
        bytes memory sig = _signResolve(MARKET_ID, 1850e8, t, DS);
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, sig);

        vm.expectEmit(true, true, true, true);
        emit TrustedReporterAdapter.ResolveResultCleared(MARKET_ID);

        vm.prank(owner);
        adapter.clearResolveResult(MARKET_ID);

        (, bool resolved) = adapter.getResult(MARKET_ID);
        assertFalse(resolved, "resolve result should be cleared");
    }

    /// @notice Non-owner cannot clear any result.
    function test_clearResolveResult_onlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        adapter.clearResolveResult(MARKET_ID);
    }

    function test_clearResolveResult_invalidates_old_signature_and_allows_corrected_repost() public {
        uint64 t = uint64(block.timestamp);
        bytes memory staleSig = _signResolve(MARKET_ID, 1850e8, t, DS);
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleSig);

        vm.prank(owner);
        adapter.clearResolveResult(MARKET_ID);

        vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleSig);

        bytes memory correctedSig = _signResolve(MARKET_ID, 1860e8, t, DS);
        adapter.postResolveResult(MARKET_ID, 1860e8, t, DS, correctedSig);

        (int256 result, bool resolved) = adapter.getResult(MARKET_ID);
        assertTrue(resolved, "corrected resolve should succeed");
        assertEq(result, 1860e8, "stale resolve replay should be invalidated after clear");
    }

    function test_clearResolveResult_invalidates_stale_ohlc_signature_of_alternate_resolution_path() public {
        uint64 t = uint64(block.timestamp);
        bytes memory staleResolveSig = _signResolve(MARKET_ID, 1850e8, t, DS);
        bytes memory staleOhlcSig = _signOhlc(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS);
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleResolveSig);

        vm.prank(owner);
        adapter.clearResolveResult(MARKET_ID);

        vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
        adapter.postOhlcResult(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS, staleOhlcSig);

        bytes memory correctedOhlcSig = _signOhlc(MARKET_ID, 1910e8, 1805e8, 1860e8, t, DS);
        adapter.postOhlcResult(MARKET_ID, 1910e8, 1805e8, 1860e8, t, DS, correctedOhlcSig);

        (int256 highE8, int256 lowE8, int256 closeE8,, bool written) = adapter.getOhlcResult(MARKET_ID);
        assertTrue(written, "corrected ohlc should succeed after resolve clear");
        assertEq(highE8, 1910e8);
        assertEq(lowE8, 1805e8);
        assertEq(closeE8, 1860e8);
    }

    function test_clearLockSample_invalidates_old_signature_and_allows_corrected_repost() public {
        uint64 t = uint64(block.timestamp);
        bytes memory staleSig = _signLock(MARKET_ID, 1800e8, t, DS);
        adapter.postLockSample(MARKET_ID, 1800e8, t, DS, staleSig);

        vm.prank(owner);
        adapter.clearLockSample(MARKET_ID);

        vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
        adapter.postLockSample(MARKET_ID, 1800e8, t, DS, staleSig);

        bytes memory correctedSig = _signLock(MARKET_ID, 1810e8, t, DS);
        adapter.postLockSample(MARKET_ID, 1810e8, t, DS, correctedSig);

        (int256 valueE8,, bool written) = adapter.getLockSample(MARKET_ID);
        assertTrue(written, "corrected lock should succeed");
        assertEq(valueE8, 1810e8, "stale lock replay should be invalidated after clear");
    }

    function test_clearOhlcResult_invalidates_old_signature_and_allows_corrected_repost() public {
        uint64 t = uint64(block.timestamp);
        bytes memory staleSig = _signOhlc(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS);
        adapter.postOhlcResult(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS, staleSig);

        vm.prank(owner);
        adapter.clearOhlcResult(MARKET_ID);

        vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
        adapter.postOhlcResult(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS, staleSig);

        bytes memory correctedSig = _signOhlc(MARKET_ID, 1910e8, 1805e8, 1860e8, t, DS);
        adapter.postOhlcResult(MARKET_ID, 1910e8, 1805e8, 1860e8, t, DS, correctedSig);

        (int256 highE8, int256 lowE8, int256 closeE8,, bool written) = adapter.getOhlcResult(MARKET_ID);
        assertTrue(written, "corrected ohlc should succeed");
        assertEq(highE8, 1910e8);
        assertEq(lowE8, 1805e8);
        assertEq(closeE8, 1860e8);
    }

    function test_clearOhlcResult_invalidates_stale_scalar_signature_of_alternate_resolution_path() public {
        uint64 t = uint64(block.timestamp);
        bytes memory staleResolveSig = _signResolve(MARKET_ID, 1850e8, t, DS);
        bytes memory staleOhlcSig = _signOhlc(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS);
        adapter.postOhlcResult(MARKET_ID, 1900e8, 1800e8, 1850e8, t, DS, staleOhlcSig);

        vm.prank(owner);
        adapter.clearOhlcResult(MARKET_ID);

        vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleResolveSig);

        bytes memory correctedResolveSig = _signResolve(MARKET_ID, 1860e8, t, DS);
        adapter.postResolveResult(MARKET_ID, 1860e8, t, DS, correctedResolveSig);

        (int256 result, bool resolved) = adapter.getResult(MARKET_ID);
        assertTrue(resolved, "corrected resolve should succeed after ohlc clear");
        assertEq(result, 1860e8, "stale resolve replay should be invalidated after ohlc clear");
    }

    function test_reporter_rotation_back_to_previous_reporter_does_not_revive_old_signatures() public {
        uint64 t = uint64(block.timestamp);
        bytes memory staleResolveSig = _signResolve(MARKET_ID, 1850e8, t, DS);

        vm.startPrank(owner);
        adapter.setTrustedReporter(reporter2);
        adapter.setTrustedReporter(reporter);
        vm.stopPrank();

        vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
        adapter.postResolveResult(MARKET_ID, 1850e8, t, DS, staleResolveSig);

        bytes memory freshResolveSig = _signResolve(MARKET_ID, 1860e8, t, DS);
        adapter.postResolveResult(MARKET_ID, 1860e8, t, DS, freshResolveSig);

        (int256 result, bool resolved) = adapter.getResult(MARKET_ID);
        assertTrue(resolved, "fresh signature after rotation should succeed");
        assertEq(result, 1860e8, "old signatures must not revive after rotating back");
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

    function _signLock(bytes32 marketId, int256 valueE8, uint64 observedAt, bytes32 ds)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = adapter.hashLockClaim(marketId, valueE8, observedAt, ds);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(REPORTER_PK, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signOhlc(bytes32 marketId, int256 highE8, int256 lowE8, int256 closeE8, uint64 observedAt, bytes32 ds)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = adapter.hashOhlcClaim(marketId, highE8, lowE8, closeE8, observedAt, ds);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(REPORTER_PK, digest);
        return abi.encodePacked(r, s, v);
    }
}
