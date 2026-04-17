// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IEventOracle
/// @notice Trusted reporter path: signed payloads settle non–price-feed markets into oracle checkpoints.
/// @dev `marketId` MUST equal `MarketEngineState.positionKey(templateId, epochId)`, i.e.
///      `keccak256(abi.encodePacked(templateId, epochId))` with `templateId` as `bytes32` and `epochId` as `uint64`.
///      Do not substitute `abi.encode` or other encodings (off-chain signers, indexers, and adapters must match exactly).
///
///      **Signed values (`int256` e8 fields):** Meaning (sign, range, OHLC invariants) is **market-type / domain** specific.
///      Implementations SHOULD validate reporter payloads against the product’s rules (e.g. spot ranges expect
///      non-negative prices where applicable); this interface does not fix one global sign policy for all markets.
///      Implementations that verify ECDSA signatures MUST NOT use raw `ecrecover` without rejecting
///      `address(0)` (e.g. use OpenZeppelin `ECDSA.recover`), and MUST NOT allow `trustedReporter == address(0)`.
///
///      **Trust model (centralized reporter):** This interface intentionally models a **single** authorized
///      signing key (or one logical reporter) attesting lock/resolve/OHLC payloads. It does **not** define
///      on-chain multi-sig, dispute windows, challenge games, timeout fallbacks, or emergency unwind. Those
///      require separate interfaces, governance, or off-chain/upgrade processes. Protocol risk includes:
///      compromised reporter key (arbitrary signed results), reporter downtime (markets may not resolve until
///      posting resumes), and insider misbehavior. Mitigations are **operational** (key custody, HSM, monitoring,
///      redundancy) and **product** (future stronger oracle modules, UMA/Chainlink-style layers, pausing markets
///      at the engine/governance level)—not enforced by `IEventOracle` itself.
///
///      **Data availability / audit trail:** `getDataSource` may return empty by design (gas). On-chain binding is
///      `dataSourceHash` (and timestamps) inside the signed payload; **recovering the preimage URI requires an
///      off-chain archive** (indexer, subgraph, IPFS pin, legal hold, etc.). If that archive disappears, historical
///      human-readable provenance can be lost even though the hash remains. Products needing stronger discoverability
///      MAY extend adapters (e.g. include a URI string in EIP-712 typed data and emit it—accepting higher gas) or
///      treat `dataSourceHash` as a self-describing CID per project convention.
///
///      **Timestamps:** `block.timestamp` used in adapters is bound to consensus clock (small skew on PoS). Tight
///      `maxAgeSeconds` / signature-age windows increase fragility to skew and missed ticks—**prefer conservative margins**
///      over chain-seconds. Reporter `observedAt` is **signed** and bounded in implementations (e.g. future / max-age checks),
///      but remains a trusted-reporter field, not a trustless clock.
///
///      **Replay & malleability (implementations):** Conformant adapters MUST bind signatures with EIP-712 so the
///      domain includes `chainId` and `verifyingContract` (cross-chain / cross-deployment replay resistance), MUST
///      use OpenZeppelin `ECDSA.recover` (low-`s` / invalid-signature handling; do not track replay by raw `(v,r,s)`),
///      and MUST treat each `marketId` as write-once for lock/resolve/OHLC slots so payloads cannot re-arm a settled market.
interface IEventOracle {
    event ResultPosted(
        bytes32 indexed marketId,
        int256 result,
        uint64 observedAt,
        bytes32 dataSourceHash,
        address indexed submittedBy
    );

    event LockSamplePosted(
        bytes32 indexed marketId,
        int256 valueE8,
        uint64 observedAt,
        bytes32 dataSourceHash,
        address indexed submittedBy
    );
    event OhlcPosted(
        bytes32 indexed marketId,
        int256 highE8,
        int256 lowE8,
        int256 closeE8,
        uint64 observedAt,
        bytes32 dataSourceHash,
        address indexed submittedBy
    );

    /// @notice Resolve scalar for settlement (checkpoint B).
    /// @dev When unresolved, engine must not treat as final; once resolved, value reflects reporter-attested path only.
    function getResult(bytes32 marketId) external view returns (int256 result, bool resolved);

    /// @notice Wall-clock style observation time committed in the signed resolve payload.
    function getResolveObservedAt(bytes32 marketId) external view returns (uint64);

    /// @notice `keccak256(bytes(utf8Source))` from the signed resolve payload.
    function getResolveDataSourceHash(bytes32 marketId) external view returns (bytes32);

    /// @notice Full URI is not stored on-chain; may return empty. Index `ResultPosted` + backend for audit.
    /// @dev Intentional gas/indexing tradeoff: bind integrity to `getResolveDataSourceHash` + events, not on-chain strings.
    ///      Callers auditing settlements SHOULD retain off-chain preimage↔hash mappings; the chain alone cannot resurrect an unknown URI from a bare hash.
    function getDataSource(bytes32 marketId) external view returns (string memory);

    /// @notice Lock-time sample for Direction markets (checkpoint A).
    function getLockSample(bytes32 marketId)
        external
        view
        returns (int256 valueE8, uint64 observedAt, bool written);

    function getOhlcResult(bytes32 marketId)
        external
        view
        returns (int256 highE8, int256 lowE8, int256 closeE8, uint64 observedAt, bool written);
}
