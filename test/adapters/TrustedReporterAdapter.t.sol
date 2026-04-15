// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TrustedReporterAdapter} from "../../src/oracle/TrustedReporterAdapter.sol";

contract TrustedReporterAdapterTest is Test {
    TrustedReporterAdapter internal adapter;

    uint256 internal constant REPORTER_PK = 0xA11CE;
    address internal reporter;
    address internal owner = address(0xBEEF);

    bytes32 internal constant MARKET = keccak256("market");

    function setUp() public {
        reporter = vm.addr(REPORTER_PK);
        adapter = new TrustedReporterAdapter(reporter, owner, 1 hours);
    }

    function _signResolve(bytes32 marketId, int256 valueE8, uint64 observedAt, bytes32 dataSourceHash)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = adapter.hashResolveClaim(marketId, valueE8, observedAt, dataSourceHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(REPORTER_PK, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signLock(bytes32 marketId, int256 valueE8, uint64 observedAt, bytes32 dataSourceHash)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = adapter.hashLockClaim(marketId, valueE8, observedAt, dataSourceHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(REPORTER_PK, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_postResolve_happyPath() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("https://example.com/source");
        bytes memory sig = _signResolve(MARKET, 50_000e8, t, ds);

        adapter.postResolveResult(MARKET, 50_000e8, t, ds, sig);

        (int256 r, bool ok) = adapter.getResult(MARKET);
        assertTrue(ok);
        assertEq(r, 50_000e8);
        assertEq(adapter.getResolveObservedAt(MARKET), t);
        assertEq(adapter.getResolveDataSourceHash(MARKET), ds);
    }

    function test_postLock_happyPath() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("lock-src");
        bytes memory sig = _signLock(MARKET, 100e8, t, ds);

        adapter.postLockSample(MARKET, 100e8, t, ds, sig);

        (int256 v, uint64 ot, bool w) = adapter.getLockSample(MARKET);
        assertTrue(w);
        assertEq(v, 100e8);
        assertEq(ot, t);
        assertEq(adapter.getLockDataSourceHash(MARKET), ds);
    }

    function test_RevertWhen_doubleResolve() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("x");
        bytes memory sig = _signResolve(MARKET, 1, t, ds);
        adapter.postResolveResult(MARKET, 1, t, ds, sig);

        vm.expectRevert(TrustedReporterAdapter.AlreadyResolved.selector);
        adapter.postResolveResult(MARKET, 2, t, ds, sig);
    }

    function test_RevertWhen_doubleLock() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("x");
        bytes memory sig = _signLock(MARKET, 1, t, ds);
        adapter.postLockSample(MARKET, 1, t, ds, sig);

        vm.expectRevert(TrustedReporterAdapter.LockAlreadyWritten.selector);
        adapter.postLockSample(MARKET, 2, t, ds, sig);
    }

    function test_RevertWhen_wrongSigner() public {
        uint256 otherPk = 0xB0B;
        bytes32 digest = adapter.hashResolveClaim(MARKET, 1, uint64(block.timestamp), bytes32(uint256(1)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert(TrustedReporterAdapter.InvalidReporterSignature.selector);
        adapter.postResolveResult(MARKET, 1, uint64(block.timestamp), bytes32(uint256(1)), sig);
    }

    function test_RevertWhen_signatureTooOld() public {
        vm.warp(10_000_000);
        uint64 oldT = uint64(block.timestamp - 2 hours);
        bytes32 ds = keccak256("x");
        bytes memory sig = _signResolve(MARKET, 1, oldT, ds);

        vm.expectRevert(TrustedReporterAdapter.SignatureTooOld.selector);
        adapter.postResolveResult(MARKET, 1, oldT, ds, sig);
    }

    function test_RevertWhen_observedAtFuture() public {
        uint64 future = uint64(block.timestamp + 1);
        bytes32 ds = keccak256("x");
        bytes memory sig = _signResolve(MARKET, 1, future, ds);

        vm.expectRevert(TrustedReporterAdapter.ObservedAtInFuture.selector);
        adapter.postResolveResult(MARKET, 1, future, ds, sig);
    }

    function test_owner_clearResolve() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("x");
        bytes memory sig = _signResolve(MARKET, 1, t, ds);
        adapter.postResolveResult(MARKET, 1, t, ds, sig);

        vm.prank(owner);
        adapter.clearResolveResult(MARKET);

        (, bool ok) = adapter.getResult(MARKET);
        assertFalse(ok);
    }

    function test_setTrustedReporter() public {
        address newRep = address(0x1234);
        vm.prank(owner);
        adapter.setTrustedReporter(newRep);
        assertEq(adapter.trustedReporter(), newRep);
    }
}
