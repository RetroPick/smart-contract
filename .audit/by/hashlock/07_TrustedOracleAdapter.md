Oracle Adapter / Trusted Reporter Oracle

TrustedReporterAdapter is an EIP-712-based oracle adapter that accepts signed payloads from a single whitelisted reporter key to settle non-price-feed markets. It stores three types of oracle data: lock samples (checkpoint A for Direction markets), scalar resolve results (checkpoint B for settlement), and OHLC (Open-High-Low-Close) results. The contract implements the IEventOracle interface and uses Ownable2Step for ownership management. The system is intentionally centralized around a single trusted reporter key, with operational mitigations rather than on-chain guarantees.

Show less
Access Control
role_based


Privileged Roles
1
owner (Ownable2Step)
2
trustedReporter (single signing key)

External Calls
1
OpenZeppelin EIP712
2
OpenZeppelin ECDSA
3
OpenZeppelin Ownable2Step
4
IEventOracle

External Systems
1
Off-chain Reporter / HSM
2
Market Engine (downstream consumer)
3
Block Timestamp (consensus clock)

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


critical Severity
1
1

TrustedReporterAdapter.sol
Centralized Single Trusted Reporter — Complete Oracle Compromise on Key Leak
The entire oracle system relies on a single `trustedReporter` address. If this private key is compromised, an attacker can post arbitrary signed results for any market without any on-chain defense mechanism. There is no quorum requirement, no dispute window, no challenge game, and no timeout fallback. The contract explicitly acknowledges this in its NatSpec, but the severity warrants explicit documentation as a finding. The attack surface includes: (1) direct key compromise, (2) compromised owner rotating to attacker key, (3) insider threat from the reporter operator. All three paths lead to complete oracle manipulation.


Hide Details
Impact
Complete compromise of all markets using this oracle adapter. An attacker with the reporter private key can: post arbitrary lock samples (manipulating direction market entry prices), post arbitrary resolve results (manipulating settlement values), post arbitrary OHLC data (manipulating range/direction market outcomes). This could drain the entire protocol's liquidity if markets are settled with attacker-controlled values.
Scenario
1. Attacker obtains `trustedReporter` private key (via phishing, infrastructure compromise, etc.).
2. Attacker signs malicious payloads for all active markets:
- For direction markets: set `valueE8` at lock to a value that makes all positions lose
- For resolve: set `valueE8` to a value that pays out only attacker-controlled positions
3. Attacker submits all malicious payloads in a single block.
4. All markets settle with attacker-controlled values.
5. Attacker claims all winning positions.
Affected code
address public trustedReporter;

// All post functions ultimately check:
if (signer != trustedReporter) revert InvalidReporterSignature();
Proposed fix
While the centralized model is acknowledged as intentional, implement operational mitigations:

1. **Multi-sig reporter**: Use a Gnosis Safe or similar multi-sig as the `trustedReporter` address, requiring M-of-N signatures.
2. **Threshold signatures**: Use threshold ECDSA (e.g., TSS) so no single party holds the full key.
3. **Rate limiting**: Add a per-block or per-period limit on how many markets can be settled.
4. **Pause mechanism**: Add an emergency pause that the owner (or a separate guardian) can trigger.
5. **Timelock on settlements**: Add a challenge window after posting before the engine can consume results.
// Example: Add pause mechanism
bool public paused;
modifier whenNotPaused() {
    require(!paused, "Oracle paused");
    _;
}
function pause() external onlyOwner { paused = true; }
function unpause() external onlyOwner { paused = false; }

high Severity
2
1

TrustedReporterAdapter.sol
Missing clearOhlcResult Function — Permanently Stuck Incorrect OHLC Settlement
The contract provides `clearLockSample` and `clearResolveResult` as owner-only recovery mechanisms for mis-posted data, but there is no equivalent `clearOhlcResult` function. Once an OHLC sample is written to `_ohlcSamples[marketId]`, it cannot be deleted or corrected by any on-chain mechanism. This is asymmetric with the other two settlement paths and creates a permanent, irrecoverable state if an incorrect OHLC payload is posted — even if the owner detects the error immediately. Furthermore, since OHLC and scalar resolve are mutually exclusive, a wrong OHLC posting also permanently blocks the correct scalar resolve path for that marketId.


Hide Details
Impact
If an incorrect OHLC result is posted (e.g., due to a reporter bug, data feed error, or compromised key), the market is permanently settled with wrong data. There is no on-chain recovery path. The downstream market engine will consume the incorrect `closeE8` value from `getResult()`, potentially causing incorrect settlement payouts for all participants in that market. This is especially severe because the scalar resolve path is also permanently blocked for the same marketId.
Scenario
1. Trusted reporter (or attacker with compromised key) calls `postOhlcResult(marketId, wrongHigh, wrongLow, wrongClose, observedAt, dataSourceHash, sig)` with incorrect values.
2. `_ohlcSamples[marketId].written` is set to `true`.
3. Owner detects the error and wants to correct it — but there is no `clearOhlcResult` function.
4. `postOhlcResult` reverts with `AlreadyResolved` on any retry.
5. `postResolveResult` also reverts with `AlreadyResolved` because `_ohlcSamples[marketId].written == true`.
6. `getResult(marketId)` permanently returns the wrong `closeE8` value.
7. Market engine settles all positions based on the incorrect value.
Affected code
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
// ... stores permanently with no clear path
s.written = true;
// ...
}
Proposed fix
Add a `clearOhlcResult` function consistent with the existing clear functions:
event OhlcResultCleared(bytes32 indexed marketId, address indexed clearedBy);

function clearOhlcResult(bytes32 marketId) external onlyOwner {
    emit OhlcResultCleared(marketId, msg.sender);
    delete _ohlcSamples[marketId];
}
Also add events to the existing `clearLockSample` and `clearResolveResult` functions for consistency and auditability.
2

TrustedReporterAdapter.sol
Immediate Trusted Reporter Rotation Without Timelock Enables Instant Oracle Manipulation
The `setTrustedReporter` function takes effect immediately with no timelock, delay, or multi-sig requirement. A compromised owner can atomically: (1) rotate `trustedReporter` to an attacker-controlled address, and (2) post malicious oracle results signed by the new key — all within a single block. There is no window for users, the market engine, or monitoring systems to detect and respond to the rotation before markets are settled with manipulated data. This is particularly dangerous because the owner role itself has no timelock (Ownable2Step only prevents accidental ownership transfer, not malicious immediate transfers).


Hide Details
Impact
A compromised owner can instantly rotate the trusted reporter to an attacker-controlled key and immediately post arbitrary oracle results for any market. This enables complete manipulation of all market settlements in a single transaction or block, with no on-chain defense mechanism. Combined with the fact that `clearResolveResult` emits no events, the attack can be partially obscured.
Scenario
// Attacker controls owner key
// Step 1: Rotate reporter to attacker-controlled address
oracle.setTrustedReporter(attackerReporterAddress);

// Step 2: Sign malicious payloads off-chain with attackerReporterKey
// Step 3: Post manipulated results for all active markets
oracle.postResolveResult(marketId1, manipulatedValue1, observedAt, dataSourceHash, maliciousSig1);
oracle.postResolveResult(marketId2, manipulatedValue2, observedAt, dataSourceHash, maliciousSig2);
// All markets now settled with attacker-controlled values
Affected code
function setTrustedReporter(address newReporter) external onlyOwner {
if (newReporter == address(0)) revert ZeroAddress();
emit TrustedReporterUpdated(trustedReporter, newReporter);
trustedReporter = newReporter;
}
Proposed fix
Implement a timelock on reporter rotation to provide a response window:
uint256 public constant REPORTER_ROTATION_DELAY = 24 hours;
bytes32 public pendingReporter;
uint256 public reporterRotationTime;

event TrustedReporterRotationScheduled(address indexed pendingReporter, uint256 effectiveAt);

function scheduleReporterRotation(address newReporter) external onlyOwner {
    if (newReporter == address(0)) revert ZeroAddress();
    pendingReporter = newReporter;
    reporterRotationTime = block.timestamp + REPORTER_ROTATION_DELAY;
    emit TrustedReporterRotationScheduled(newReporter, reporterRotationTime);
}

function executeReporterRotation() external onlyOwner {
    require(block.timestamp >= reporterRotationTime, "Timelock not expired");
    require(pendingReporter != address(0), "No pending rotation");
    emit TrustedReporterUpdated(trustedReporter, pendingReporter);
    trustedReporter = pendingReporter;
    pendingReporter = address(0);
    reporterRotationTime = 0;
}
Alternatively, require the owner to be a multi-sig with a sufficient threshold.

medium Severity
2
1

TrustedReporterAdapter.sol
No Events Emitted on clearLockSample and clearResolveResult — Silent State Manipulation
The `clearLockSample` and `clearResolveResult` functions delete oracle data without emitting any events. These are privileged owner operations that modify critical oracle state — specifically, they reset the `written` flag, allowing re-posting of data for a previously settled marketId. Without events, these operations are invisible to off-chain monitoring systems, indexers, and auditors. A compromised owner could silently clear a correct result and re-post a manipulated one, with no on-chain trace of the clearing action. This severely undermines the auditability of the oracle system.


Hide Details
Impact
A compromised or malicious owner can silently clear a correctly posted oracle result and replace it with a manipulated value. Off-chain monitoring systems cannot detect this action because no event is emitted. This breaks the audit trail for oracle settlements and enables a two-step attack: (1) clear the correct result, (2) post a manipulated result — all without any on-chain evidence of the clearing step.
Scenario
1. Correct resolve result is posted: `postResolveResult(marketId, correctValue, ...)` — emits `ResultPosted` event.
2. Compromised owner calls `clearResolveResult(marketId)` — NO event emitted, storage silently deleted.
3. Attacker (or compromised reporter) calls `postResolveResult(marketId, manipulatedValue, ...)` — emits `ResultPosted` event with wrong value.
4. Off-chain monitoring only sees two `ResultPosted` events but cannot distinguish the clearing action between them without deep storage diff analysis.
Affected code
function clearLockSample(bytes32 marketId) external onlyOwner {
delete _lockSamples[marketId];
}

function clearResolveResult(bytes32 marketId) external onlyOwner {
delete _resolveSamples[marketId];
}
Proposed fix
Add events to both clear functions:
event LockSampleCleared(bytes32 indexed marketId, address indexed clearedBy);
event ResolveResultCleared(bytes32 indexed marketId, address indexed clearedBy);

function clearLockSample(bytes32 marketId) external onlyOwner {
    emit LockSampleCleared(marketId, msg.sender);
    delete _lockSamples[marketId];
}

function clearResolveResult(bytes32 marketId) external onlyOwner {
    emit ResolveResultCleared(marketId, msg.sender);
    delete _resolveSamples[marketId];
}
2

TrustedReporterAdapter.sol
Owner Can Re-Settle Markets by Clearing and Re-Posting Oracle Results
The combination of `clearResolveResult` (and the missing `clearOhlcResult`) with the post functions creates a mechanism where the owner can effectively re-settle any market. The flow is: (1) a correct result is posted and consumed by the engine, (2) owner calls `clearResolveResult`, resetting `written = false`, (3) a new (potentially manipulated) result is posted. While this requires owner compromise, the design intent appears to be that clearing is only for pre-consumption correction, but there is no on-chain enforcement of this constraint — the contract does not check whether the engine has already consumed the oracle data before allowing a clear.


Hide Details
Impact
A compromised owner can manipulate already-settled markets by clearing and re-posting oracle results. If the market engine reads oracle data lazily (e.g., at claim time rather than at settlement time), users who haven't yet claimed their winnings could receive incorrect payouts based on the manipulated re-posted value. This is a post-settlement manipulation vector.
Scenario
1. Market settles: `postResolveResult(marketId, correctValue, ...)` — engine reads result, some users claim.
2. Compromised owner calls `clearResolveResult(marketId)` — silently resets written flag.
3. Compromised reporter posts: `postResolveResult(marketId, manipulatedValue, ...)` — new result stored.
4. Users who haven't claimed yet now receive payouts based on `manipulatedValue`.
5. No on-chain evidence of the clearing action (no event emitted).
Affected code
function clearResolveResult(bytes32 marketId) external onlyOwner {
delete _resolveSamples[marketId];
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
Proposed fix
1. Add events to clear functions (as noted in the separate finding).
2. Consider adding a `consumed` flag that the market engine sets when it reads the oracle result, and prevent clearing of consumed results:
mapping(bytes32 marketId => bool) public resolveConsumed;

function markResolveConsumed(bytes32 marketId) external onlyEngine {
    resolveConsumed[marketId] = true;
}

function clearResolveResult(bytes32 marketId) external onlyOwner {
    require(!resolveConsumed[marketId], "Already consumed by engine");
    emit ResolveResultCleared(marketId, msg.sender);
    delete _resolveSamples[marketId];
}
3. Alternatively, implement a timelock on clear operations to provide a response window.

low Severity
5
1

TrustedReporterAdapter.sol
Signature Age Validation Uses observedAt (Reporter-Attested) Rather Than Submission Timestamp
The signature age check validates `block.timestamp - uint256(observedAt) > maxSignatureAgeSeconds`, where `observedAt` is a value provided by the trusted reporter in the signed payload. This means the age window is measured from the reporter's claimed observation time, not from when the signature was actually created. A compromised or malicious reporter can set `observedAt` to `block.timestamp` at submission time (or any recent timestamp within the window), effectively making signatures that were created long ago appear fresh. The `maxSignatureAgeSeconds` window is intended to prevent stale data from being posted, but it can be bypassed by a reporter who sets `observedAt` to a recent value regardless of when the actual observation occurred.


Hide Details
Impact
A compromised reporter can post oracle data with an `observedAt` timestamp set to the current block time, regardless of when the actual market event occurred. This allows posting of fabricated or delayed data that appears fresh to the contract's age validation. The freshness check provides weaker guarantees than intended — it validates the reporter's claimed observation time, not the actual data freshness.
Scenario
1. Market event occurred at T=0 (e.g., price at lock time).
2. Compromised reporter waits until T=1000 (well past any reasonable observation window).
3. Reporter crafts a payload with `observedAt = block.timestamp` (current time) and arbitrary `valueE8`.
4. Reporter signs the payload with the trusted key.
5. `postResolveResult` is called — `observedAt` check passes because `block.timestamp - observedAt = 0`.
6. Stale/fabricated data is accepted as fresh.
Affected code
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
// ...
}
Proposed fix
This is an inherent limitation of the trusted reporter model — since the reporter controls `observedAt`, the age check only provides protection against accidentally stale signatures, not against a malicious reporter. The interface documentation acknowledges this. However, to improve the design:

1. Document clearly that `observedAt` is a trusted-reporter field and the age check is not a trustless freshness guarantee.
2. Consider adding a separate `signedAt` field (timestamp when the signature was created) that is also included in the EIP-712 struct, allowing the contract to validate both observation freshness and signature creation time.
3. For higher security, consider using a commit-reveal scheme or requiring the reporter to post a commitment before the event resolves.
2

TrustedReporterAdapter.sol
OHLC Validation Does Not Reject Negative Values for Price Markets
The `postOhlcResult` function validates OHLC invariants (`highE8 >= lowE8`, `lowE8 <= closeE8 <= highE8`) but does not validate that price values are non-negative for markets where prices should be positive (e.g., spot price markets). The interface documentation notes that sign/range validation is market-type specific and implementations SHOULD validate against product rules. The current implementation accepts negative `highE8`, `lowE8`, and `closeE8` values as long as the OHLC ordering invariant holds. A compromised reporter could post negative prices for spot markets, causing incorrect settlement calculations in the downstream engine.


Hide Details
Impact
For spot price markets, a compromised reporter can post negative OHLC values (e.g., `highE8 = -1, lowE8 = -100, closeE8 = -50`). The OHLC invariant check passes, but the downstream market engine receives negative prices. Depending on how the engine handles negative settlement values, this could cause incorrect payouts, integer underflows in settlement math, or unexpected behavior in direction market resolution.
Scenario
// Compromised reporter signs payload with negative prices
int256 highE8 = -1e8;   // -1.0 (negative price)
int256 lowE8 = -100e8;  // -100.0
int256 closeE8 = -50e8; // -50.0
// OHLC invariant: highE8 >= lowE8 (-1 >= -100 ✓), closeE8 in [lowE8, highE8] (-100 <= -50 <= -1 ✓)
// postOhlcResult accepts this — no negative value check
oracle.postOhlcResult(marketId, highE8, lowE8, closeE8, observedAt, dataSourceHash, sig);
// getResult returns closeE8 = -50e8 to the market engine
Affected code
function postOhlcResult(
bytes32 marketId,
int256 highE8,
int256 lowE8,
int256 closeE8,
uint64 observedAt,
bytes32 dataSourceHash,
bytes calldata signature
) external {
// ...
if (highE8 < lowE8 || closeE8 < lowE8 || closeE8 > highE8) revert InvalidOhlc();
// No check for negative values
// ...
}
Proposed fix
Add market-type-aware validation or at minimum a configurable non-negative price check for spot markets. Since the contract is a general adapter, consider adding an optional validation flag:
bool public requireNonNegativePrices;

function postOhlcResult(...) external {
    // ...
    if (highE8 < lowE8 || closeE8 < lowE8 || closeE8 > highE8) revert InvalidOhlc();
    if (requireNonNegativePrices && lowE8 < 0) revert InvalidOhlc();
    // ...
}
Alternatively, document clearly that negative values are valid for certain market types and ensure the downstream engine handles them correctly.
3

IEventOracle.sol
marketId Derivation Uses abi.encodePacked in Interface — Potential Integration Confusion
The `IEventOracle` interface documentation specifies that `marketId` MUST equal `keccak256(abi.encodePacked(templateId, epochId))` where `templateId` is `bytes32` and `epochId` is `uint64`. While fixed-size types (`bytes32` and `uint64`) do not create hash collision risk with `abi.encodePacked` (unlike variable-length types), the strict requirement to use `encodePacked` rather than `abi.encode` creates integration risk. If any off-chain system, indexer, or adapter uses `abi.encode` instead of `abi.encodePacked`, the computed `marketId` will differ, causing silent mismatches where oracle data is posted for the wrong marketId or queries return no data. The interface comment explicitly warns against this but the risk of integration error remains.


Hide Details
Impact
If an integration component (off-chain reporter, market engine, indexer) uses `abi.encode` instead of `abi.encodePacked` to compute `marketId`, oracle data will be posted to a different `marketId` than the engine queries. This would cause markets to appear unresolved (oracle returns `resolved = false`) even after the reporter has posted results, potentially blocking settlement and locking user funds.
Scenario
// Correct marketId computation (as specified)
bytes32 correctId = keccak256(abi.encodePacked(templateId, epochId));
// = keccak256(bytes32_value ++ uint64_value) = 40 bytes packed

// Incorrect computation (using abi.encode)
bytes32 wrongId = keccak256(abi.encode(templateId, epochId));
// = keccak256(bytes32_value ++ uint256_padded_epochId) = 64 bytes
// correctId != wrongId

// Reporter posts to correctId, engine queries wrongId -> getResult returns (0, false)
Affected code
/// @dev `marketId` MUST equal `MarketEngineState.positionKey(templateId, epochId)`, i.e.
/// `keccak256(abi.encodePacked(templateId, epochId))` with `templateId` as `bytes32` and `epochId` as `uint64`.
/// Do not substitute `abi.encode` or other encodings (off-chain signers, indexers, and adapters must match exactly).
Proposed fix
1. Add a `computeMarketId` utility function to the contract that implements the canonical derivation, ensuring all on-chain consumers use the same encoding:
function computeMarketId(bytes32 templateId, uint64 epochId) external pure returns (bytes32) {
    return keccak256(abi.encodePacked(templateId, epochId));
}
2. Add integration tests that verify `marketId` computation consistency between the oracle adapter, market engine, and off-chain reporter.
3. Consider using `abi.encode` with explicit type casting to make the encoding unambiguous, though this would require updating all existing integrations.
4

TrustedReporterAdapter.sol
Front-Running of Reporter Transactions — Griefing via Signature Replay
The `postLockSample`, `postResolveResult`, and `postOhlcResult` functions are callable by anyone who possesses a valid reporter signature. Since Ethereum transactions are publicly visible in the mempool, an attacker can observe a reporter's pending transaction, extract the signature and parameters, and front-run it with the same data. While the result is identical (same data gets stored), this creates a griefing vector: the reporter's transaction will revert (wasting gas) because the data was already written by the front-runner. More critically, if the reporter uses the same signature for retry logic, the front-runner can repeatedly grief the reporter's submissions.


Hide Details
Impact
While the oracle data itself is not corrupted (same values get stored), the `submittedBy` field in events will show the front-runner's address rather than the reporter's address. This corrupts the audit trail — `LockSamplePosted` and `ResultPosted` events will show an unauthorized address as `submittedBy`, making it appear that an unknown party submitted oracle data. This could trigger false alarms in monitoring systems and complicate forensic analysis.
Scenario
1. Reporter broadcasts `postResolveResult(marketId, value, observedAt, dataSourceHash, sig)` to mempool.
2. Attacker observes the transaction, extracts all parameters including `sig`.
3. Attacker submits the same call with higher gas price — front-runs the reporter.
4. `ResultPosted` event is emitted with `submittedBy = attacker_address`.
5. Reporter's transaction reverts with `AlreadyResolved`.
6. Monitoring systems see an unknown address submitting oracle data, triggering false alerts.
Affected code
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
Proposed fix
Restrict the post functions to only be callable by the `trustedReporter` address:
modifier onlyTrustedReporter() {
    require(msg.sender == trustedReporter, "Not trusted reporter");
    _;
}

function postLockSample(...) external onlyTrustedReporter {
    // ...
}

function postResolveResult(...) external onlyTrustedReporter {
    // ...
}

function postOhlcResult(...) external onlyTrustedReporter {
    // ...
}
This eliminates front-running and ensures `submittedBy` in events always reflects the actual reporter. The signature verification can be retained as defense-in-depth.
5

TrustedReporterAdapter.sol
maxSignatureAgeSeconds Can Be Set to Minimum 60 Seconds — Fragile Under Network Congestion
The `maxSignatureAgeSeconds` can be set as low as 60 seconds (`MIN_MAX_SIGNATURE_AGE = 60`). Under network congestion, high gas prices, or validator downtime, a reporter's transaction may not be included in a block within 60 seconds of the `observedAt` timestamp. This would cause valid signatures to be rejected with `SignatureTooOld`, blocking market settlement. The minimum of 60 seconds is particularly fragile on L2 networks with variable sequencer behavior or during Ethereum mainnet congestion events.


Hide Details
Impact
If `maxSignatureAgeSeconds` is set to 60 seconds and the network is congested, valid reporter signatures will be rejected. The reporter must re-sign with a new `observedAt` timestamp and resubmit. During this window, markets cannot be settled, potentially causing liveness failures. If the market has a hard settlement deadline, this could permanently prevent settlement.
Scenario
1. Owner sets `maxSignatureAgeSeconds = 60` (minimum allowed).
2. Reporter signs payload with `observedAt = T`.
3. Network congestion delays transaction inclusion until `T + 61 seconds`.
4. `block.timestamp - observedAt = 61 > 60 = maxSignatureAgeSeconds`.
5. Transaction reverts with `SignatureTooOld`.
6. Reporter must re-sign and resubmit, further delaying settlement.
Affected code
uint256 public constant MIN_MAX_SIGNATURE_AGE = 60;
uint256 public constant MAX_MAX_SIGNATURE_AGE = 48 hours;

function _setMaxSignatureAge(uint256 newMax) private {
if (newMax < MIN_MAX_SIGNATURE_AGE || newMax > MAX_MAX_SIGNATURE_AGE) revert MaxAgeOutOfRange();
emit MaxSignatureAgeUpdated(maxSignatureAgeSeconds, newMax);
maxSignatureAgeSeconds = newMax;
}
Proposed fix
Increase the minimum allowed value to a more conservative threshold:
uint256 public constant MIN_MAX_SIGNATURE_AGE = 5 minutes; // 300 seconds instead of 60
Also document in the interface that operators should use conservative values (e.g., 15-30 minutes) rather than the minimum. The interface documentation already recommends conservative margins — enforce this at the contract level.

gas Severity
2
1

TrustedReporterAdapter.sol
Gas Optimization: Redundant Storage Read in postResolveResult
In `postResolveResult`, the function first reads `_ohlcSamples[marketId].written` (a storage read), then reads `_resolveSamples[marketId]` into a storage pointer. The `_ohlcSamples` check requires loading the `OhlcSample` struct from storage to access the `written` field. Since `OhlcSample` is a larger struct (6 fields), this is more expensive than necessary. The check could be optimized by storing the `written` flag in a separate, cheaper mapping.


Hide Details
Impact
Slightly higher gas cost for `postResolveResult` due to loading the full `OhlcSample` struct slot to check the `written` boolean. In Solidity, struct fields are packed into storage slots, so `written` may share a slot with other fields, but the SLOAD still costs 2100 gas (cold) or 100 gas (warm) for the slot access.
Scenario
N/A — gas optimization only.
Affected code
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
// ...
}
Proposed fix
Consider using a separate `mapping(bytes32 => bool)` for the written flags to enable cheaper existence checks:
mapping(bytes32 marketId => bool) private _ohlcWritten;
mapping(bytes32 marketId => bool) private _resolveWritten;

function postResolveResult(...) external {
    if (_ohlcWritten[marketId]) revert AlreadyResolved();
    if (_resolveWritten[marketId]) revert AlreadyResolved();
    // ...
    _resolveWritten[marketId] = true;
    // store full sample
}
Alternatively, ensure the `written` field is in the first storage slot of each struct (which it currently is not — `valueE8` is first in `Sample` and `highE8` is first in `OhlcSample`).
2

TrustedReporterAdapter.sol
Gas Optimization: written Flag Placement in Struct Causes Inefficient Storage Packing
In the `Sample` struct, the `written` bool field is placed after `uint64 observedAt`, which means it shares a storage slot with `observedAt` (since `uint64` is 8 bytes and `bool` is 1 byte, they fit in the same 32-byte slot). However, `valueE8` (int256, 32 bytes) occupies its own slot, and `dataSourceHash` (bytes32, 32 bytes) occupies another. The struct layout results in 3 storage slots. In `OhlcSample`, the layout is even less optimal with `highE8`, `lowE8`, `closeE8` each taking a full slot, then `observedAt` + `written` sharing a slot, and `dataSourceHash` in another — 5 slots total. Reordering fields could potentially save gas on writes.


Hide Details
Impact
Minor gas inefficiency. The current layout is actually reasonable — `observedAt` and `written` share a slot. However, placing `written` first in the struct would allow cheaper existence checks (reading only the first slot to determine if data exists).
Scenario
N/A — gas optimization only.
Affected code
struct Sample {
int256 valueE8; // slot 0: 32 bytes
uint64 observedAt; // slot 1: 8 bytes
bool written; // slot 1: 1 byte (shares with observedAt)
bytes32 dataSourceHash; // slot 2: 32 bytes
}

struct OhlcSample {
int256 highE8; // slot 0
int256 lowE8; // slot 1
int256 closeE8; // slot 2
uint64 observedAt; // slot 3: 8 bytes
bool written; // slot 3: 1 byte
bytes32 dataSourceHash; // slot 4
}
Proposed fix
Reorder struct fields to place the most frequently read fields first:
struct Sample {
    bool written;        // slot 0: 1 byte
    uint64 observedAt;   // slot 0: 8 bytes (shares with written)
    // padding to slot boundary
    int256 valueE8;      // slot 1: 32 bytes
    bytes32 dataSourceHash; // slot 2: 32 bytes
}
This allows a single SLOAD to check `written` and `observedAt` together, which is the most common read pattern.

informational Severity
2
1

TrustedReporterAdapter.sol
Informational: getDataSource Always Returns Empty String — Breaks Interface Contract
The `getDataSource` function is defined in `IEventOracle` with the NatSpec `@notice Full URI is not stored on-chain; may return empty`. The implementation always returns an empty string (`return ""`). While this is documented as intentional, it means any caller relying on `getDataSource` for data provenance will always receive empty data. The interface documentation notes this is a gas/indexing tradeoff, but it creates a gap between the interface's implied capability and the actual implementation.


Hide Details
Impact
Callers of `getDataSource` will always receive an empty string, regardless of the `marketId`. If any downstream system relies on this function for data provenance or audit purposes, it will silently receive no data. This is a documentation/interface compliance issue rather than a security vulnerability.
Scenario
N/A — informational finding.
Affected code
function getDataSource(bytes32) external pure override returns (string memory) {
return "";
}
Proposed fix
Either:
1. Remove `getDataSource` from the interface if it's never intended to return meaningful data, or
2. Add a NatSpec comment to the implementation explicitly stating this is intentional:
/// @inheritdoc IEventOracle
/// @dev Intentionally returns empty string. Data source integrity is bound to
///      `getResolveDataSourceHash`. Callers MUST NOT rely on this function for
///      data provenance — use off-chain archives with the hash for verification.
function getDataSource(bytes32) external pure override returns (string memory) {
    return "";
}
2

TrustedReporterAdapter.sol
Informational: No Validation That observedAt Is Within Reasonable Historical Range
The contract validates that `observedAt` is not in the future (`observedAt > block.timestamp`) and not too old (`block.timestamp - observedAt > maxSignatureAgeSeconds`). However, there is no lower bound on how old `observedAt` can be relative to the market's expected event time. A reporter could post a lock sample with `observedAt` set to a timestamp from years ago (as long as it's within `maxSignatureAgeSeconds` of the current block), and the contract would accept it. This is mitigated by the `maxSignatureAgeSeconds` window, but the window can be up to 48 hours.


Hide Details
Impact
With `maxSignatureAgeSeconds = 48 hours`, a reporter could post data with `observedAt` up to 48 hours in the past. For markets with tight timing requirements (e.g., lock samples that must reflect the price at a specific moment), this window may be too large. However, this is a trusted reporter model, so the reporter is expected to post accurate timestamps.
Scenario
N/A — informational finding.
Affected code
if (observedAt > block.timestamp) revert ObservedAtInFuture();
unchecked {
if (block.timestamp - uint256(observedAt) > maxAge) revert SignatureTooOld();
}
Proposed fix
Document the expected `observedAt` range for each market type. Consider adding market-specific validation in a future version, or reducing `MAX_MAX_SIGNATURE_AGE` to a more conservative value (e.g., 4 hours) if 48 hours is unnecessarily large for the use case.