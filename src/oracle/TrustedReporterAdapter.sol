// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IEventOracle} from "../interfaces/IEventOracle.sol";

/// @title TrustedReporterAdapter
/// @notice EIP-712–signed lock and resolve samples from a single whitelisted reporter key.
contract TrustedReporterAdapter is IEventOracle, EIP712, Ownable2Step {
    bytes32 private constant LOCK_CLAIM_TYPEHASH = keccak256(
        "LockClaim(bytes32 marketId,int256 valueE8,uint64 observedAt,bytes32 dataSourceHash)"
    );
    bytes32 private constant RESOLVE_CLAIM_TYPEHASH = keccak256(
        "ResolveClaim(bytes32 marketId,int256 valueE8,uint64 observedAt,bytes32 dataSourceHash)"
    );
    bytes32 private constant OHLC_CLAIM_TYPEHASH = keccak256(
        "OhlcClaim(bytes32 marketId,int256 highE8,int256 lowE8,int256 closeE8,uint64 observedAt,bytes32 dataSourceHash)"
    );

    uint256 public constant MIN_MAX_SIGNATURE_AGE = 60;
    uint256 public constant MAX_MAX_SIGNATURE_AGE = 48 hours;

    address public trustedReporter;
    uint256 public maxSignatureAgeSeconds;

    struct Sample {
        int256 valueE8;
        uint64 observedAt;
        bool written;
        bytes32 dataSourceHash;
    }

    struct OhlcSample {
        int256 highE8;
        int256 lowE8;
        int256 closeE8;
        uint64 observedAt;
        bool written;
        bytes32 dataSourceHash;
    }

    mapping(bytes32 marketId => Sample) private _lockSamples;
    mapping(bytes32 marketId => Sample) private _resolveSamples;
    mapping(bytes32 marketId => OhlcSample) private _ohlcSamples;

    event TrustedReporterUpdated(address indexed previousReporter, address indexed newReporter);
    event MaxSignatureAgeUpdated(uint256 previousSeconds, uint256 newSeconds);

    error ZeroAddress();
    error AlreadyResolved();
    error LockAlreadyWritten();
    error InvalidReporterSignature();
    error SignatureTooOld();
    error ObservedAtInFuture();
    error MaxAgeOutOfRange();

    constructor(address initialReporter, address initialOwner, uint256 initialMaxSignatureAgeSeconds)
        EIP712("RetroPickTrustedReporter", "1")
        Ownable(initialOwner)
    {
        if (initialReporter == address(0) || initialOwner == address(0)) revert ZeroAddress();
        trustedReporter = initialReporter;
        _setMaxSignatureAge(initialMaxSignatureAgeSeconds);
    }

    function setTrustedReporter(address newReporter) external onlyOwner {
        if (newReporter == address(0)) revert ZeroAddress();
        emit TrustedReporterUpdated(trustedReporter, newReporter);
        trustedReporter = newReporter;
    }

    function setMaxSignatureAgeSeconds(uint256 newMax) external onlyOwner {
        _setMaxSignatureAge(newMax);
    }

    function postLockSample(
        bytes32 marketId,
        int256 valueE8,
        uint64 observedAt,
        bytes32 dataSourceHash,
        bytes calldata signature
    ) external {
        Sample storage s = _lockSamples[marketId];
        if (s.written) revert LockAlreadyWritten();
        _verifyAndStoreSample(LOCK_CLAIM_TYPEHASH, s, marketId, valueE8, observedAt, dataSourceHash, signature);
        emit LockSamplePosted(marketId, valueE8, observedAt, dataSourceHash, _msgSender());
    }

    function postResolveResult(
        bytes32 marketId,
        int256 valueE8,
        uint64 observedAt,
        bytes32 dataSourceHash,
        bytes calldata signature
    ) external {
        Sample storage s = _resolveSamples[marketId];
        if (s.written) revert AlreadyResolved();
        _verifyAndStoreSample(RESOLVE_CLAIM_TYPEHASH, s, marketId, valueE8, observedAt, dataSourceHash, signature);
        emit ResultPosted(marketId, valueE8, observedAt, dataSourceHash, _msgSender());
    }

    function postOhlcResult(
        bytes32 marketId,
        int256 highE8,
        int256 lowE8,
        int256 closeE8,
        uint64 observedAt,
        bytes32 dataSourceHash,
        bytes calldata signature
    ) external {
        OhlcSample storage s = _ohlcSamples[marketId];
        if (s.written) revert AlreadyResolved();
        if (observedAt > block.timestamp) revert ObservedAtInFuture();
        unchecked {
            if (block.timestamp - uint256(observedAt) > maxSignatureAgeSeconds) revert SignatureTooOld();
        }
        bytes32 structHash =
            keccak256(abi.encode(OHLC_CLAIM_TYPEHASH, marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash));
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recoverCalldata(digest, signature);
        if (signer != trustedReporter) revert InvalidReporterSignature();
        s.highE8 = highE8;
        s.lowE8 = lowE8;
        s.closeE8 = closeE8;
        s.observedAt = observedAt;
        s.written = true;
        s.dataSourceHash = dataSourceHash;
        emit OhlcPosted(marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash, _msgSender());
    }

    /// @notice Owner can clear a lock sample before the engine consumes it (mis-post recovery).
    function clearLockSample(bytes32 marketId) external onlyOwner {
        delete _lockSamples[marketId];
    }

    /// @notice Owner can clear a resolve sample before the engine consumes it (mis-post recovery).
    function clearResolveResult(bytes32 marketId) external onlyOwner {
        delete _resolveSamples[marketId];
    }

    function getResult(bytes32 marketId) external view override returns (int256 result, bool resolved) {
        OhlcSample storage ohlc = _ohlcSamples[marketId];
        if (ohlc.written) return (ohlc.closeE8, true);
        Sample storage s = _resolveSamples[marketId];
        return (s.valueE8, s.written);
    }

    function getResolveObservedAt(bytes32 marketId) external view override returns (uint64) {
        OhlcSample storage ohlc = _ohlcSamples[marketId];
        if (ohlc.written) return ohlc.observedAt;
        return _resolveSamples[marketId].observedAt;
    }

    function getResolveDataSourceHash(bytes32 marketId) external view override returns (bytes32) {
        OhlcSample storage ohlc = _ohlcSamples[marketId];
        if (ohlc.written) return ohlc.dataSourceHash;
        return _resolveSamples[marketId].dataSourceHash;
    }

    function getDataSource(bytes32) external pure override returns (string memory) {
        return "";
    }

    /// @notice EIP-712 digest the trusted reporter signs for `postLockSample`.
    function hashLockClaim(bytes32 marketId, int256 valueE8, uint64 observedAt, bytes32 dataSourceHash)
        external
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(LOCK_CLAIM_TYPEHASH, marketId, valueE8, observedAt, dataSourceHash)));
    }

    /// @notice EIP-712 digest the trusted reporter signs for `postResolveResult`.
    function hashResolveClaim(bytes32 marketId, int256 valueE8, uint64 observedAt, bytes32 dataSourceHash)
        external
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(abi.encode(RESOLVE_CLAIM_TYPEHASH, marketId, valueE8, observedAt, dataSourceHash))
        );
    }

    function getLockSample(bytes32 marketId)
        external
        view
        override
        returns (int256 valueE8, uint64 observedAt, bool written)
    {
        Sample storage s = _lockSamples[marketId];
        return (s.valueE8, s.observedAt, s.written);
    }

    function getLockDataSourceHash(bytes32 marketId) external view returns (bytes32) {
        return _lockSamples[marketId].dataSourceHash;
    }

    function getOhlcResult(bytes32 marketId)
        external
        view
        override
        returns (int256 highE8, int256 lowE8, int256 closeE8, uint64 observedAt, bool written)
    {
        OhlcSample storage s = _ohlcSamples[marketId];
        return (s.highE8, s.lowE8, s.closeE8, s.observedAt, s.written);
    }

    function _setMaxSignatureAge(uint256 newMax) private {
        if (newMax < MIN_MAX_SIGNATURE_AGE || newMax > MAX_MAX_SIGNATURE_AGE) revert MaxAgeOutOfRange();
        emit MaxSignatureAgeUpdated(maxSignatureAgeSeconds, newMax);
        maxSignatureAgeSeconds = newMax;
    }

    function _verifyAndStoreSample(
        bytes32 typeHash,
        Sample storage dest,
        bytes32 marketId,
        int256 valueE8,
        uint64 observedAt,
        bytes32 dataSourceHash,
        bytes calldata signature
    ) private {
        uint256 maxAge = maxSignatureAgeSeconds;
        if (observedAt > block.timestamp) revert ObservedAtInFuture();
        unchecked {
            if (block.timestamp - uint256(observedAt) > maxAge) revert SignatureTooOld();
        }

        bytes32 structHash =
            keccak256(abi.encode(typeHash, marketId, valueE8, observedAt, dataSourceHash));
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recoverCalldata(digest, signature);
        if (signer != trustedReporter) revert InvalidReporterSignature();

        dest.valueE8 = valueE8;
        dest.observedAt = observedAt;
        dest.written = true;
        dest.dataSourceHash = dataSourceHash;
    }
}
