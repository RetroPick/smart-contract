// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
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

    function _signOhlc(
        bytes32 marketId,
        int256 highE8,
        int256 lowE8,
        int256 closeE8,
        uint64 observedAt,
        bytes32 dataSourceHash
    ) internal view returns (bytes memory) {
        bytes32 digest = adapter.hashOhlcClaim(marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash);
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

    function test_RevertWhen_ohlcAfterResolve() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("x");
        adapter.postResolveResult(MARKET, 50e8, t, ds, _signResolve(MARKET, 50e8, t, ds));
        bytes memory ohlcSig = _signOhlc(MARKET, 10e8, 5e8, 7e8, t, ds);
        vm.expectRevert(TrustedReporterAdapter.AlreadyResolved.selector);
        adapter.postOhlcResult(MARKET, 10e8, 5e8, 7e8, t, ds, ohlcSig);
    }

    function test_RevertWhen_resolveAfterOhlc() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("x");
        bytes memory ohlcSig = _signOhlc(MARKET, 10e8, 5e8, 7e8, t, ds);
        adapter.postOhlcResult(MARKET, 10e8, 5e8, 7e8, t, ds, ohlcSig);
        bytes memory resolveSig = _signResolve(MARKET, 99e8, t, ds);
        vm.expectRevert(TrustedReporterAdapter.AlreadyResolved.selector);
        adapter.postResolveResult(MARKET, 99e8, t, ds, resolveSig);
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

    /// @dev Attacker pattern: invalid `v` (not 27/28) makes `ecrecover` return `address(0)`. OZ ECDSA must revert,
    ///      not compare `(0 == trustedReporter)` — and this adapter forbids zero reporter at deploy.
    function test_RevertWhen_resolve_malformedSignature_invalidV_attackerCannotSpoof() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("attacker");
        bytes memory sig = abi.encodePacked(bytes32(0), bytes32(0), uint8(29));

        vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
        adapter.postResolveResult(MARKET, 999e8, t, ds, sig);
    }

    function test_RevertWhen_lock_malformedSignature_invalidV_attackerCannotSpoof() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("attacker");
        bytes memory sig = abi.encodePacked(bytes32(0), bytes32(0), uint8(29));

        vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
        adapter.postLockSample(MARKET, 1e8, t, ds, sig);
    }

    function test_RevertWhen_ohlc_malformedSignature_invalidV_attackerCannotSpoof() public {
        uint64 t = uint64(block.timestamp);
        bytes32 ds = keccak256("attacker");
        bytes memory sig = abi.encodePacked(bytes32(0), bytes32(0), uint8(29));

        vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
        adapter.postOhlcResult(MARKET, 1e8, 1e8, 1e8, t, ds, sig);
    }

    function test_RevertWhen_ohlc_high_below_low() public {
        uint64 t = uint64(block.timestamp);
        vm.expectRevert(TrustedReporterAdapter.InvalidOhlc.selector);
        adapter.postOhlcResult(MARKET, 1e8, 2e8, 1e8, t, bytes32(0), "");
    }

    function test_RevertWhen_ohlc_close_outside_range() public {
        uint64 t = uint64(block.timestamp);
        vm.expectRevert(TrustedReporterAdapter.InvalidOhlc.selector);
        adapter.postOhlcResult(MARKET, 10e8, 5e8, 2e8, t, bytes32(0), "");
    }

    function test_RevertWhen_constructor_zeroReporter() public {
        vm.expectRevert(TrustedReporterAdapter.ZeroAddress.selector);
        new TrustedReporterAdapter(address(0), owner, 1 hours);
    }

    function test_RevertWhen_setTrustedReporter_zeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(TrustedReporterAdapter.ZeroAddress.selector);
        adapter.setTrustedReporter(address(0));
    }
}
