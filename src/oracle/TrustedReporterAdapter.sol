// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IEventOracle} from "../interfaces/IEventOracle.sol";

/// @title TrustedReporterAdapter
/// @notice EIP-712–signed lock and resolve samples from a single whitelisted reporter key.
/// @dev **Trust / centralization:** One `trustedReporter` key attests all payloads for this adapter. Key compromise
///      or unavailability affects every template that points here; on-chain there is no quorum or fallback—only
///      `owner` rotation (`setTrustedReporter`) and engine-level pause / template governance. Stronger guarantees
///      (threshold signatures, timelocked rotation, dispute games) require a different oracle module or upgrade.
contract TrustedReporterAdapter is IEventOracle, EIP712, Ownable2Step {
    bytes32 private constant LOCK_CLAIM_TYPEHASH = keccak256(
        "LockClaim(bytes32 marketId,int256 valueE8,uint64 observedAt,bytes32 dataSourceHash,uint256 nonce,uint256 reporterEpoch)"
    );
    bytes32 private constant RESOLVE_CLAIM_TYPEHASH = keccak256(
        "ResolveClaim(bytes32 marketId,int256 valueE8,uint64 observedAt,bytes32 dataSourceHash,uint256 nonce,uint256 reporterEpoch)"
    );
    bytes32 private constant OHLC_CLAIM_TYPEHASH = keccak256(
        "OhlcClaim(bytes32 marketId,int256 highE8,int256 lowE8,int256 closeE8,uint64 observedAt,bytes32 dataSourceHash,uint256 nonce,uint256 reporterEpoch)"
    );

    uint256 public constant MIN_MAX_SIGNATURE_AGE = 60;
    uint256 public constant MAX_MAX_SIGNATURE_AGE = 48 hours;

    address public trustedReporter;
    uint256 public maxSignatureAgeSeconds;
    uint256 public reporterEpoch;

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
    mapping(bytes32 marketId => uint256 nonce) private _lockNonces;
    mapping(bytes32 marketId => uint256 nonce) private _resolveNonces;
    mapping(bytes32 marketId => uint256 nonce) private _ohlcNonces;

    event TrustedReporterUpdated(address indexed previousReporter, address indexed newReporter);
    event MaxSignatureAgeUpdated(uint256 previousSeconds, uint256 newSeconds);
    event LockSampleCleared(bytes32 indexed marketId);
    event ResolveResultCleared(bytes32 indexed marketId);
    event OhlcResultCleared(bytes32 indexed marketId);

    error ZeroAddress();
    error AlreadyResolved();
    error LockAlreadyWritten();
    error InvalidReporterSignature();
    error SignatureTooOld();
    error ObservedAtInFuture();
    error MaxAgeOutOfRange();
    error InvalidOhlc();

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
        unchecked {
            ++reporterEpoch;
        }
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
        if (_ohlcSamples[marketId].written) revert AlreadyResolved();
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
        if (_resolveSamples[marketId].written) revert AlreadyResolved();
        OhlcSample storage s = _ohlcSamples[marketId];
        if (s.written) revert AlreadyResolved();
        if (observedAt > block.timestamp) revert ObservedAtInFuture();
        unchecked {
            if (block.timestamp - uint256(observedAt) > maxSignatureAgeSeconds) revert SignatureTooOld();
        }
        if (highE8 < lowE8 || closeE8 < lowE8 || closeE8 > highE8) revert InvalidOhlc();
        bytes32 structHash = _ohlcStructHash(marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash);
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
        unchecked {
            ++_lockNonces[marketId];
        }
        emit LockSampleCleared(marketId);
    }

    /// @notice Owner can clear a resolve sample before the engine consumes it (mis-post recovery).
    function clearResolveResult(bytes32 marketId) external onlyOwner {
        delete _resolveSamples[marketId];
        unchecked {
            ++_resolveNonces[marketId];
            ++_ohlcNonces[marketId];
        }
        emit ResolveResultCleared(marketId);
    }

    /// @notice Owner can clear an OHLC result before the engine consumes it (mis-post recovery).
    /// @dev Clearing OHLC restores the ability to post a scalar resolve result for the same marketId.
    function clearOhlcResult(bytes32 marketId) external onlyOwner {
        delete _ohlcSamples[marketId];
        unchecked {
            ++_resolveNonces[marketId];
            ++_ohlcNonces[marketId];
        }
        emit OhlcResultCleared(marketId);
    }

    /// @dev OHLC and scalar resolve are mutually exclusive: posting one forbids the other for the same `marketId`.
    /// When OHLC exists, `getResult` returns its close; otherwise the signed resolve value.
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
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    LOCK_CLAIM_TYPEHASH,
                    marketId,
                    valueE8,
                    observedAt,
                    dataSourceHash,
                    _lockNonces[marketId],
                    reporterEpoch
                )
            )
        );
    }

    /// @notice EIP-712 digest the trusted reporter signs for `postResolveResult`.
    function hashResolveClaim(bytes32 marketId, int256 valueE8, uint64 observedAt, bytes32 dataSourceHash)
        external
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    RESOLVE_CLAIM_TYPEHASH,
                    marketId,
                    valueE8,
                    observedAt,
                    dataSourceHash,
                    _resolveNonces[marketId],
                    reporterEpoch
                )
            )
        );
    }

    /// @notice EIP-712 digest the trusted reporter signs for `postOhlcResult`.
    function hashOhlcClaim(
        bytes32 marketId,
        int256 highE8,
        int256 lowE8,
        int256 closeE8,
        uint64 observedAt,
        bytes32 dataSourceHash
    ) external view returns (bytes32) {
        return _hashTypedDataV4(_ohlcStructHash(marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash));
    }

    function lockClaimNonce(bytes32 marketId) external view returns (uint256) {
        return _lockNonces[marketId];
    }

    function resolveClaimNonce(bytes32 marketId) external view returns (uint256) {
        return _resolveNonces[marketId];
    }

    function ohlcClaimNonce(bytes32 marketId) external view returns (uint256) {
        return _ohlcNonces[marketId];
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
            keccak256(
                abi.encode(
                    typeHash,
                    marketId,
                    valueE8,
                    observedAt,
                    dataSourceHash,
                    _claimNonce(typeHash, marketId),
                    reporterEpoch
                )
            );
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recoverCalldata(digest, signature);
        if (signer != trustedReporter) revert InvalidReporterSignature();

        dest.valueE8 = valueE8;
        dest.observedAt = observedAt;
        dest.written = true;
        dest.dataSourceHash = dataSourceHash;
    }

    function _ohlcStructHash(
        bytes32 marketId,
        int256 highE8,
        int256 lowE8,
        int256 closeE8,
        uint64 observedAt,
        bytes32 dataSourceHash
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                OHLC_CLAIM_TYPEHASH,
                marketId,
                highE8,
                lowE8,
                closeE8,
                observedAt,
                dataSourceHash,
                _ohlcNonces[marketId],
                reporterEpoch
            )
        );
    }

    function _claimNonce(bytes32 typeHash, bytes32 marketId) private view returns (uint256) {
        if (typeHash == LOCK_CLAIM_TYPEHASH) return _lockNonces[marketId];
        if (typeHash == RESOLVE_CLAIM_TYPEHASH) return _resolveNonces[marketId];
        if (typeHash == OHLC_CLAIM_TYPEHASH) return _ohlcNonces[marketId];
        return 0;
    }
}
