Oracle Adapter / Price Feed

ChainlinkAdapter is a price oracle adapter that wraps Chainlink's AggregatorV3Interface to provide normalized price data (scaled to 8 decimals) for a MarketEngine. It implements both IPriceOracle and IPriceOracleWithRoundId interfaces, supports L2 sequencer uptime gating, enforces staleness checks, round completeness validation, and allows the owner to pre-configure feed decimals to avoid extra runtime oracle calls.

Show less
Access Control
ownable


Privileged Roles
1
Owner (Ownable2Step)

External Calls
1
AggregatorV3Interface (Chainlink Price Feed)
2
AggregatorV3Interface (Chainlink Sequencer Uptime Feed)

External Systems
1
Chainlink Oracle Network
2
L2 Sequencer (Arbitrum/Optimism)

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


high Severity
2
1

ChainlinkAdapter.sol
Arbitrary Feed Address Injection via Unvalidated feedId — Malicious Price Oracle Attack
The `getNormalizedPrice` and `getNormalizedPriceWithRoundId` functions decode the `feedId` parameter directly into a Chainlink proxy address and call `latestRoundData()` on it without any whitelist or registry validation. Any caller can supply a `feedId` that encodes an attacker-controlled contract address. That contract can implement `AggregatorV3Interface.latestRoundData()` to return crafted values (positive answer, recent `updatedAt`, valid `roundId`/`answeredInRound`) that pass all on-chain checks, injecting a completely fabricated price into the MarketEngine. While the functions are `view` and cannot directly drain funds themselves, the MarketEngine consumes the returned `priceE8` to make settlement, liquidation, or position-sizing decisions. A malicious feed that returns an extreme price (e.g., 1 wei or 1e18 * 1e8) could cause catastrophic mispricing: positions opened at manipulated prices, incorrect liquidations, or protocol insolvency. The attack is especially dangerous because: 1. No whitelist exists — any address can be used as a feed. 2. The `FeedDecimalsNotConfigured` revert is the only gate, but the attacker can pre-configure decimals if they also control the owner key, or the owner may have already configured decimals for a legitimate feed that the attacker re-uses with a different malicious contract at the same address (impossible on mainnet but possible on testnets or after a selfdestruct/CREATE2 redeployment). 3. On L2s, the sequencer check is the only other gate, but it only validates the sequencer feed, not the price feed address.


Hide Details
Impact
An attacker can inject arbitrary price data into the MarketEngine by supplying a feedId encoding a malicious contract. This can cause incorrect settlement prices, wrongful liquidations, or protocol insolvency depending on how the MarketEngine uses the returned price. The attack is permissionless and requires no special privileges.
Scenario
// Attacker deploys a malicious Chainlink feed
contract MaliciousFeed {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        // Return a manipulated price: 1 USD (1e8) when real price is 50,000 USD
        return (1, 1e8, block.timestamp, block.timestamp, 1);
    }
}

// Attacker encodes the malicious feed address as feedId
bytes32 maliciousFeedId = bytes32(uint256(uint160(address(maliciousFeed))));

// Owner must have configured decimals for this feedId — but if the attacker
// can front-run or if the owner misconfigures, the call succeeds:
// chainlinkAdapter.getNormalizedPrice(maliciousFeedId, 3600, 0);
// Returns priceE8 = 1e8 (1 USD) instead of the real 50,000 USD price
Step-by-step:
1. Attacker deploys `MaliciousFeed` implementing `AggregatorV3Interface`.
2. Attacker encodes its address as `feedId = bytes32(uint256(uint160(maliciousFeedAddr)))`.
3. If owner has configured decimals for this feedId (or attacker tricks owner), `getNormalizedPrice(maliciousFeedId, ...)` returns the crafted price.
4. MarketEngine uses this price for settlement/liquidation decisions.
Affected code
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64)
external
view
override
returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8)
{
uint256 tNow = block.timestamp;
_checkSequencer(tNow);

address feedAddr = address(uint160(uint256(feedId)));
if (feedAddr == address(0)) revert InvalidFeedAddress();

AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);

(uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
// ... validations ...
}
Proposed fix
Implement a feed whitelist that requires owner approval before a feedId can be queried:
mapping(bytes32 => bool) public approvedFeeds;

function approveFeed(bytes32 feedId) external onlyOwner {
    if (feedId == bytes32(0)) revert InvalidFeedAddress();
    approvedFeeds[feedId] = true;
    emit FeedApproved(feedId);
}

function revokeFeed(bytes32 feedId) external onlyOwner {
    approvedFeeds[feedId] = false;
    emit FeedRevoked(feedId);
}

// In getNormalizedPrice and getNormalizedPriceWithRoundId:
if (!approvedFeeds[feedId]) revert FeedNotApproved(feedId);
Alternatively, combine `setFeedDecimals` with feed approval so that configuring decimals implicitly whitelists the feed. Also consider validating that `feedAddr.code.length > 0` before calling `latestRoundData()` to prevent calls to EOAs.
2

ChainlinkAdapter.sol
Incorrect Decimal Configuration Causes Silent Catastrophic Mispricing
The `setFeedDecimals` function allows the owner to configure any `decimals_` value (0–18) for a feed without cross-validating against the actual Chainlink feed's `decimals()` return value. If the owner misconfigures decimals — even by a single digit — the `_normalizeToE8` function will scale prices by the wrong factor, producing prices that are off by orders of magnitude. For example: - Real feed: 8 decimals (e.g., BTC/USD Chainlink feed) - Misconfigured as: 18 decimals - Effect: `_normalizeToE8` divides by `10^10`, making a $50,000 BTC price appear as $0.000005 Or conversely: - Real feed: 18 decimals - Misconfigured as: 8 decimals - Effect: multiplies by `10^10`, making a $1 price appear as $10,000,000,000 This misconfiguration can be accidental (typo) or malicious (compromised owner key). There is no on-chain validation, no timelock, and no way for the MarketEngine to detect the error. The `FeedDecimalsConfigured` event is emitted but off-chain monitoring may not catch the error before it causes damage. Furthermore, the owner can update decimals at any time without restriction, meaning a previously correct configuration can be changed to an incorrect one mid-operation.


Hide Details
Impact
Incorrect decimal configuration causes all price reads for the affected feed to return prices scaled by the wrong factor (up to 10^18 off). This can cause the MarketEngine to make catastrophically wrong settlement, liquidation, or position-sizing decisions, potentially leading to protocol insolvency or mass wrongful liquidations.
Scenario
Step-by-step:
1. Owner calls `setFeedDecimals(btcUsdFeedId, 18)` instead of `setFeedDecimals(btcUsdFeedId, 8)` (typo or compromise).
2. BTC/USD Chainlink feed returns `answer = 5_000_000_000_000` (50,000 USD with 8 decimals).
3. `_normalizeToE8(5_000_000_000_000, 18)` divides by `10^10` = returns `500` (i.e., $0.000005 in e8 terms).
4. MarketEngine sees BTC price as $0.000005 instead of $50,000.
5. All BTC-collateralized positions appear massively over-collateralized; liquidations fail; protocol accumulates bad debt.
Affected code
function setFeedDecimals(bytes32 feedId, uint8 decimals_) external onlyOwner {
if (feedId == bytes32(0)) revert InvalidFeedAddress();
if (decimals_ > 18) revert UnsupportedFeedDecimals(decimals_);
_feedDecimals[feedId] = FeedDecimalsConfig({decimals: decimals_, configured: true});
emit FeedDecimalsConfigured(feedId, decimals_);
}
Proposed fix
Auto-fetch decimals from the live feed during configuration, or at minimum cross-validate:
function setFeedDecimals(bytes32 feedId, uint8 decimals_) external onlyOwner {
    if (feedId == bytes32(0)) revert InvalidFeedAddress();
    if (decimals_ > 18) revert UnsupportedFeedDecimals(decimals_);
    
    // Cross-validate against live feed
    address feedAddr = address(uint160(uint256(feedId)));
    require(feedAddr != address(0), "Invalid feed address");
    uint8 liveDec = AggregatorV3Interface(feedAddr).decimals();
    require(liveDec == decimals_, "Decimals mismatch with live feed");
    
    _feedDecimals[feedId] = FeedDecimalsConfig({decimals: decimals_, configured: true});
    emit FeedDecimalsConfigured(feedId, decimals_);
}


Alternatively, auto-fetch and store decimals directly:
function setFeedDecimals(bytes32 feedId) external onlyOwner {
    address feedAddr = address(uint160(uint256(feedId)));
    if (feedAddr == address(0)) revert InvalidFeedAddress();
    uint8 liveDec = AggregatorV3Interface(feedAddr).decimals();
    if (liveDec > 18) revert UnsupportedFeedDecimals(liveDec);
    _feedDecimals[feedId] = FeedDecimalsConfig({decimals: liveDec, configured: true});
    emit FeedDecimalsConfigured(feedId, liveDec);
}
Additionally, consider adding a timelock for decimal changes and emitting both old and new values in the event.

medium Severity
2
1

ChainlinkAdapter.sol
No Mechanism to Remove or Disable a Feed — Permanent DoS Risk for Deprecated Feeds
The `setFeedDecimals` function can configure feed decimals but there is no mechanism to: 1. Remove a feed configuration (set `configured = false`) 2. Disable a feed (prevent price queries for a specific feedId) 3. Pause the entire adapter If a Chainlink feed is deprecated, compromised, or needs to be disabled urgently, the owner has no way to prevent the MarketEngine from querying it. The only option would be to deploy a new adapter contract and update the MarketEngine's oracle reference, which may be a slow governance process. Additionally, if a feed starts returning invalid data that passes all current checks (e.g., a feed that returns a valid-looking but manipulated price), there is no emergency circuit breaker to halt price reads for that specific feed. This is particularly concerning given that the `setFeedDecimals` function can be used to reconfigure decimals, but setting decimals to an incorrect value as a "disable" mechanism would cause mispricing rather than a clean revert.


Hide Details
Impact
If a Chainlink feed is compromised or deprecated, the owner cannot quickly disable it without deploying a new adapter. This could allow a compromised feed to continue providing manipulated prices to the MarketEngine during the time it takes to deploy and configure a replacement.
Scenario
Step-by-step:
1. Chainlink feed at address X is compromised and starts returning manipulated prices.
2. Owner wants to disable the feed immediately.
3. No `disableFeed` or `removeFeedDecimals` function exists.
4. Owner cannot set `configured = false` — only `setFeedDecimals` exists which always sets `configured = true`.
5. MarketEngine continues to query the compromised feed until a new adapter is deployed and configured.
Affected code
function setFeedDecimals(bytes32 feedId, uint8 decimals_) external onlyOwner {
if (feedId == bytes32(0)) revert InvalidFeedAddress();
if (decimals_ > 18) revert UnsupportedFeedDecimals(decimals_);
_feedDecimals[feedId] = FeedDecimalsConfig({decimals: decimals_, configured: true});
emit FeedDecimalsConfigured(feedId, decimals_);
}
Proposed fix
Add a feed disable/removal function:
function removeFeedDecimals(bytes32 feedId) external onlyOwner {
    if (feedId == bytes32(0)) revert InvalidFeedAddress();
    delete _feedDecimals[feedId];
    emit FeedDecimalsRemoved(feedId);
}


This sets `configured = false` (via `delete`), causing subsequent price queries for this feedId to revert with `FeedDecimalsNotConfigured`, effectively disabling the feed.

Additionally, consider adding a global pause mechanism:
bool public paused;

function setPaused(bool paused_) external onlyOwner {
    paused = paused_;
    emit PausedStateChanged(paused_);
}

// In getNormalizedPrice and getNormalizedPriceWithRoundId:
if (paused) revert AdapterPaused();
2

ChainlinkAdapter.sol
Sequencer Feed Staleness Not Validated — Stale Sequencer Status Could Bypass Downtime Detection
The `_checkSequencer` function calls `sequencerFeed.latestRoundData()` to check if the L2 sequencer is up, but it does NOT validate the freshness of the sequencer feed's own data. If the sequencer uptime feed itself becomes stale (e.g., Chainlink stops updating it), the function will use outdated sequencer status data. Specifically, the function checks: - `answer != 0` → sequencer down - `startedAt == 0` → invalid - `startedAt > tNow` → invalid - `timeSinceUp <= GRACE_PERIOD_SECONDS` → in grace period But it does NOT check: - Whether the sequencer feed's `updatedAt` is recent (i.e., the sequencer feed itself is not stale) - Whether `answeredInRound >= roundId` for the sequencer feed (round completeness) If the sequencer feed stops updating (e.g., Chainlink network issue), the last known status ("up") would be used indefinitely, even if the actual sequencer has gone down since the last update. This could allow price reads during actual sequencer downtime.


Hide Details
Impact
If the Chainlink sequencer uptime feed becomes stale, the adapter will continue to report the last known sequencer status ("up") even if the actual sequencer has gone down. This could allow price reads during actual L2 sequencer downtime, potentially using stale prices from before the outage.
Scenario
Step-by-step:
1. L2 sequencer goes down at time T.
2. Chainlink sequencer uptime feed fails to update (also experiencing issues).
3. Last sequencer feed update was at T-1 hour, reporting `answer = 0` (up).
4. `_checkSequencer` reads stale data: `answer = 0` (up), `startedAt = T - 2 hours`.
5. `timeSinceUp = tNow - (T - 2 hours) > 3600` → grace period check passes.
6. Price reads proceed despite actual sequencer being down.
7. Stale prices from before the outage are used for settlement.
Affected code
function _checkSequencer(uint256 tNow) internal view {
if (address(sequencerFeed) == address(0)) return;

// slither-disable-next-line unused-return -- sequencer metadata slots unused; answer and startedAt drive grace
(, int256 answer, uint256 startedAt,,) = sequencerFeed.latestRoundData();

if (answer != 0) revert SequencerDown();
if (startedAt == 0) revert InvalidSequencerRoundData();
if (startedAt > tNow) revert InvalidSequencerRoundData();

// Match Chainlink's L2 sequencer example: wait until strictly after the grace window.
uint256 timeSinceUp = tNow - startedAt;
if (timeSinceUp <= GRACE_PERIOD_SECONDS) {
revert SequencerInGracePeriod(startedAt, startedAt + GRACE_PERIOD_SECONDS);
}
}
Proposed fix
Add staleness validation for the sequencer feed itself:
uint256 public constant SEQUENCER_FEED_MAX_AGE = 3600; // 1 hour

function _checkSequencer(uint256 tNow) internal view {
    if (address(sequencerFeed) == address(0)) return;

    (uint80 seqRoundId, int256 answer, uint256 startedAt, uint256 seqUpdatedAt, uint80 seqAnsweredInRound) 
        = sequencerFeed.latestRoundData();

    // Validate sequencer feed round completeness
    if (seqAnsweredInRound < seqRoundId) revert InvalidSequencerRoundData();
    
    // Validate sequencer feed freshness
    if (seqUpdatedAt == 0 || tNow - seqUpdatedAt > SEQUENCER_FEED_MAX_AGE) {
        revert InvalidSequencerRoundData();
    }

    if (answer != 0) revert SequencerDown();
    if (startedAt == 0) revert InvalidSequencerRoundData();
    if (startedAt > tNow) revert InvalidSequencerRoundData();

    uint256 timeSinceUp = tNow - startedAt;
    if (timeSinceUp <= GRACE_PERIOD_SECONDS) {
        revert SequencerInGracePeriod(startedAt, startedAt + GRACE_PERIOD_SECONDS);
    }
}

low Severity
4
1

ChainlinkAdapter.sol
uint64 Truncation of publishTime for Timestamps Beyond Year 2554
In both `getNormalizedPrice` and `getNormalizedPriceWithRoundId`, the `updatedAt` value returned by Chainlink's `latestRoundData()` is a `uint256` that is silently cast to `uint64` for the `publishTime` return value: ```solidity publishTime = uint64(updatedAt); ``` `uint64` max is `18446744073709551615`, which corresponds to approximately year 584,942,417,355 — far beyond any practical concern for the timestamp itself. However, the real risk is different: a **buggy or malicious Chainlink feed** could return an `updatedAt` value that is very large (e.g., `type(uint256).max` or any value > `type(uint64).max`). The existing check `if (updatedAt > tNow) revert StalePriceFeed(...)` would catch values larger than `block.timestamp` (which is always < `type(uint64).max` for centuries). So in practice, any `updatedAt` that passes the staleness check will also fit in `uint64`. However, there is a subtle edge case: if `updatedAt` is between `tNow - maxAgeSeconds` and `tNow`, it passes the staleness check. Since `block.timestamp` is currently ~1.7 billion (well within uint64), this is safe. But the cast is undocumented and relies on an implicit invariant (block.timestamp < uint64.max) that could theoretically break in extreme edge cases or on non-standard chains. More importantly, the `publishTime` returned as `uint64` is used by the MarketEngine for monotonicity enforcement. If two different feeds return the same `publishTime` due to truncation artifacts, monotonicity checks could be incorrectly satisfied or violated.


Hide Details
Impact
Low practical risk for current timestamps, but the silent truncation could cause incorrect publishTime values if a feed returns an unexpectedly large updatedAt. This could break monotonicity enforcement in the MarketEngine or cause incorrect freshness comparisons in consuming contracts.
Scenario
Step-by-step (theoretical):
1. A buggy Chainlink feed returns `updatedAt = type(uint64).max + 1` (i.e., `18446744073709551616`).
2. The check `updatedAt > tNow` passes (since `tNow` is ~1.7e9, much less than `type(uint64).max + 1`).
3. The check `tNow - updatedAt > maxAgeSeconds` would underflow in Solidity 0.8.x and revert — actually this is caught.
4. Wait — `updatedAt > tNow` would be true for `updatedAt = type(uint64).max + 1`, so it would revert with `StalePriceFeed`. The cast truncation is thus unreachable for values > tNow.

The actual risk is more subtle: values between `type(uint64).max` and `type(uint256).max` that are also <= `tNow` are impossible since `tNow < type(uint64).max`. So the truncation is safe in practice but the code relies on an implicit invariant.
Affected code
// forge-lint: disable-next-line(unsafe-typecast) -- stale check ensures updatedAt is recent vs block time
publishTime = uint64(updatedAt);
Proposed fix
Add an explicit bounds check before the cast to make the invariant explicit and protect against future edge cases:
if (updatedAt > type(uint64).max) revert InvalidPrice(); // Defensive: updatedAt cannot exceed uint64 max
publishTime = uint64(updatedAt);
This makes the safety invariant explicit and protects against non-standard chain behavior or future timestamp edge cases.
2

ChainlinkAdapter.sol
Precision Loss in _normalizeToE8 When Downscaling from Higher Decimals
The `_normalizeToE8` function uses integer division (truncation toward zero) when downscaling a price from higher decimals to 8 decimals: ```solidity if (decimals_ > TARGET_DECIMALS) { uint256 down = 10 ** uint256(decimals_ - TARGET_DECIMALS); return answer / int256(down); } ``` For example, if a feed has 18 decimals and returns `answer = 1_999_999_999` (representing $19.99999999 in 18-decimal terms), the normalization divides by `10^10`, yielding `0` instead of `1` (representing $0.00000001). This systematic truncation always rounds down, never up, creating a consistent underpricing bias. For feeds with decimals only slightly above 8 (e.g., 9 decimals), the precision loss is 1 decimal place (factor of 10). For feeds with 18 decimals, the loss is 10 decimal places. While Chainlink typically uses 8 decimals for USD pairs, some feeds (e.g., ETH/ETH, token/ETH pairs) use 18 decimals, making this a real concern. The truncation is systematic and always favors underpricing, which could be exploited in protocols where lower prices benefit certain parties (e.g., borrowers in lending protocols, or option buyers).


Hide Details
Impact
Systematic underpricing of assets from feeds with decimals > 8. The magnitude depends on the decimal difference: up to 10 decimal places of precision loss for 18-decimal feeds. In financial protocols, this could cause incorrect collateral valuations, wrong liquidation thresholds, or exploitable price discrepancies.
Scenario
// Feed with 18 decimals returns answer = 1_999_999_999_999_999_999 (≈ 2.0 in 18-decimal terms)
// Expected normalized price (8 decimals): 200_000_000 (2.0 USD)
// Actual: 1_999_999_999_999_999_999 / 10^10 = 199_999_999 (1.99999999 USD)
// Difference: 0.00000001 USD — small but systematic

// Extreme case: answer = 9_999_999_999 (just below 10^10)
// Expected: 1 (0.00000001 USD)
// Actual: 9_999_999_999 / 10^10 = 0 — complete loss of value!
Affected code
function _normalizeToE8(int256 answer, uint8 decimals_) internal pure returns (int256) {
if (decimals_ > 18) revert UnsupportedFeedDecimals(decimals_);
if (decimals_ == TARGET_DECIMALS) {
return answer;
}
if (decimals_ > TARGET_DECIMALS) {
uint256 down = 10 ** uint256(decimals_ - TARGET_DECIMALS);
// forge-lint: disable-next-line(unsafe-typecast) -- 10**n fits int256 for usual feed decimals
return answer / int256(down);
}
uint256 up = 10 ** uint256(TARGET_DECIMALS - decimals_);
// forge-lint: disable-next-line(unsafe-typecast) -- same; bounded by decimals delta
return answer * int256(up);
}
Proposed fix
Consider rounding to nearest instead of truncating, or document the truncation behavior explicitly:
if (decimals_ > TARGET_DECIMALS) {
    uint256 down = 10 ** uint256(decimals_ - TARGET_DECIMALS);
    int256 divisor = int256(down);
    // Round half-up for positive prices
    int256 remainder = answer % divisor;
    int256 result = answer / divisor;
    if (remainder * 2 >= divisor) result += 1; // round up
    return result;
}
Alternatively, document that truncation is intentional and that feeds with decimals significantly above 8 should not be used with this adapter. Add a NatSpec comment explaining the precision loss.
3

ChainlinkAdapter.sol
No Validation That feedId Encodes a Contract Address (Call to EOA or Non-Existent Address)
When `getNormalizedPrice` or `getNormalizedPriceWithRoundId` is called, the `feedId` is decoded to an address and `latestRoundData()` is called on it without checking whether the address contains contract code: ```solidity address feedAddr = address(uint160(uint256(feedId))); if (feedAddr == address(0)) revert InvalidFeedAddress(); AggregatorV3Interface feed = AggregatorV3Interface(feedAddr); (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData(); ``` As documented in the Solidity docs and the unsafe-low-level-call vulnerability context: low-level calls to non-existent contracts (EOAs or addresses with no code) always succeed and return empty data. However, since `AggregatorV3Interface.latestRoundData()` is called as a high-level call (not low-level), Solidity will check for code existence via `extcodesize` and revert if the address has no code. The actual risk here is more subtle: if `feedAddr` is a contract that does NOT implement `latestRoundData()` but has a fallback function, the call may succeed and return unexpected data. The ABI decoder would then attempt to decode the returned bytes as `(uint80, int256, uint256, uint256, uint80)`, which could succeed with garbage values if the fallback returns enough bytes, or revert with a decode error. More practically: if a Chainlink feed is deprecated and its proxy is self-destructed or replaced, the feedId could point to an EOA or empty address, causing unexpected reverts rather than graceful error handling.


Hide Details
Impact
If a feed address becomes an EOA or empty address (e.g., after a Chainlink feed migration), price queries will revert with an opaque error rather than a meaningful error message. This could cause DoS of the MarketEngine for affected feeds. Additionally, a contract with a fallback that returns crafted bytes could potentially pass the ABI decode step with garbage values.
Scenario
Step-by-step:
1. Chainlink deprecates a feed and the proxy address is no longer a contract (or points to a new contract without `latestRoundData`).
2. `feedId` still encodes the old address.
3. `feed.latestRoundData()` reverts with a low-level error (no code at address).
4. MarketEngine's `try/catch` around the oracle call (if any) catches a generic revert instead of a typed error.
5. Price queries for this feed are permanently DoS'd until the owner reconfigures.
Affected code
address feedAddr = address(uint160(uint256(feedId)));
if (feedAddr == address(0)) revert InvalidFeedAddress();

AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);

// slither-disable-next-line unused-return -- third tuple slot is round scoped startedAt; staleness uses updatedAt
(uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
Proposed fix
Add an `extcodesize` check before calling `latestRoundData()`:
address feedAddr = address(uint160(uint256(feedId)));
if (feedAddr == address(0)) revert InvalidFeedAddress();
if (feedAddr.code.length == 0) revert InvalidFeedAddress(); // Ensure it's a contract

AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);
This provides a clearer error message and prevents calls to EOAs. Combined with a feed whitelist (recommended in finding #1), this provides defense in depth.
4

ChainlinkAdapter.sol
Missing Round Completeness Check for Sequencer Feed
The `_checkSequencer` function validates the L2 sequencer uptime feed but does not check `answeredInRound >= roundId` for the sequencer feed itself, unlike the price feed validation which does enforce this: ```solidity // Price feed: checks round completeness if (answeredInRound < roundId) revert RoundNotComplete(roundId, answeredInRound); // Sequencer feed: does NOT check round completeness (, int256 answer, uint256 startedAt,,) = sequencerFeed.latestRoundData(); // answeredInRound is silently discarded ``` If the sequencer feed has an incomplete round (where `answeredInRound < roundId`), the returned `answer` may not be finalized for that round. This is the same issue that the price feed check is designed to prevent, but it's not applied consistently to the sequencer feed. While Chainlink's sequencer uptime feeds are generally reliable, applying the same round completeness check to the sequencer feed would be consistent with the contract's own security model.


Hide Details
Impact
Low risk in practice, but an incomplete sequencer feed round could theoretically return an incorrect `answer` value, potentially causing the sequencer to appear up when it's down (or vice versa). This is inconsistent with the contract's own security model for price feeds.
Scenario
Step-by-step:
1. Sequencer feed has an incomplete round: `roundId = 5`, `answeredInRound = 4`.
2. `answer` returned may be from round 4, not round 5.
3. If round 5 was supposed to report sequencer down but round 4 reported up, the stale answer is used.
4. `_checkSequencer` passes despite sequencer being down.
Affected code
// slither-disable-next-line unused-return -- sequencer metadata slots unused; answer and startedAt drive grace
(, int256 answer, uint256 startedAt,,) = sequencerFeed.latestRoundData();
Proposed fix
Apply the same round completeness check to the sequencer feed:
function _checkSequencer(uint256 tNow) internal view {
    if (address(sequencerFeed) == address(0)) return;

    (uint80 seqRoundId, int256 answer, uint256 startedAt,, uint80 seqAnsweredInRound) 
        = sequencerFeed.latestRoundData();

    // Apply same round completeness check as price feeds
    if (seqAnsweredInRound < seqRoundId) revert InvalidSequencerRoundData();
    
    if (answer != 0) revert SequencerDown();
    if (startedAt == 0) revert InvalidSequencerRoundData();
    if (startedAt > tNow) revert InvalidSequencerRoundData();

    uint256 timeSinceUp = tNow - startedAt;
    if (timeSinceUp <= GRACE_PERIOD_SECONDS) {
        revert SequencerInGracePeriod(startedAt, startedAt + GRACE_PERIOD_SECONDS);
    }
}

gas Severity
1
1

ChainlinkAdapter.sol
Gas Optimization: Cache _feedDecimals Lookup Could Be Avoided With Auto-Fetch Pattern
The `_feedDecimals` mapping lookup in `getNormalizedPrice` and `getNormalizedPriceWithRoundId` requires a storage read (SLOAD) on every price query. While this was designed to avoid an extra external call to `feed.decimals()`, the current design requires the owner to pre-configure decimals, adding operational complexity and risk. Additionally, the `FeedDecimalsConfig` struct uses a `bool configured` field alongside `uint8 decimals`. In Solidity, a struct with `uint8` and `bool` is packed into a single storage slot, but the `bool` field adds complexity. A simpler approach would be to use a sentinel value (e.g., `decimals == 255` means not configured) to avoid the extra boolean field. The current struct packing: - `uint8 decimals` (1 byte) - `bool configured` (1 byte) - Total: 2 bytes in 1 storage slot (efficient) This is already efficient, but the sentinel value approach would simplify the code.


Hide Details
Impact
Minor gas inefficiency. No security impact.
Scenario
Not applicable — this is a gas optimization suggestion.
Affected code
struct FeedDecimalsConfig {
uint8 decimals;
bool configured;
}

mapping(bytes32 => FeedDecimalsConfig) internal _feedDecimals;
Proposed fix
Use a sentinel value to eliminate the `bool configured` field:
// Use type(uint8).max (255) as sentinel for "not configured"
// Valid decimals are 0-18, so 255 is a safe sentinel
mapping(bytes32 => uint8) internal _feedDecimals; // 255 = not configured

function setFeedDecimals(bytes32 feedId, uint8 decimals_) external onlyOwner {
    if (feedId == bytes32(0)) revert InvalidFeedAddress();
    if (decimals_ > 18) revert UnsupportedFeedDecimals(decimals_);
    _feedDecimals[feedId] = decimals_;
    emit FeedDecimalsConfigured(feedId, decimals_);
}

// In price query:
uint8 dec = _feedDecimals[feedId];
if (dec == type(uint8).max) revert FeedDecimalsNotConfigured(feedId); // default mapping value is 0, not 255!
Note: This approach has a flaw — the default value of a `uint8` mapping is `0`, not `255`, so a feed with 0 decimals would appear unconfigured. The current struct approach with `bool configured` is actually correct. The recommendation is to keep the current approach but document why the struct is used.

informational Severity
5
1

ChainlinkAdapter.sol
Duplicate Code Between getNormalizedPrice and getNormalizedPriceWithRoundId — Maintenance Risk
The `getNormalizedPrice` and `getNormalizedPriceWithRoundId` functions contain nearly identical logic (sequencer check, feed address decoding, `latestRoundData()` call, all validations, decimal normalization). The only difference is that `getNormalizedPriceWithRoundId` also returns `roundId`. This duplication creates a maintenance risk: if a bug is found in one function (e.g., a missing validation), it must be fixed in both. Historical audits have found cases where security fixes were applied to one copy of duplicated code but not the other, leaving the second copy vulnerable. For example, if a new validation is added to `getNormalizedPrice` (e.g., checking `updatedAt > type(uint64).max`), it must also be manually added to `getNormalizedPriceWithRoundId`. The current codebase already shows this pattern — both functions are identical except for the `roundId` return value.


Hide Details
Impact
No immediate security impact, but creates a maintenance risk where future bug fixes or security patches may be applied to only one of the two functions, leaving the other vulnerable.
Scenario
Not applicable — this is a code quality issue.
Affected code
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64)
external view override
returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8)
{
// ... ~30 lines of logic ...
}

function getNormalizedPriceWithRoundId(bytes32 feedId, uint64 maxAgeSeconds, uint64)
external view override
returns (uint80 roundId, int256 priceE8, uint64 publishTime, uint256 confidenceE8)
{
// ... identical ~30 lines of logic ...
}
Proposed fix
Refactor the shared logic into an internal function:
struct PriceData {
    uint80 roundId;
    int256 priceE8;
    uint64 publishTime;
    uint256 confidenceE8;
}

function _fetchAndValidatePrice(
    bytes32 feedId,
    uint64 maxAgeSeconds
) internal view returns (PriceData memory data) {
    uint256 tNow = block.timestamp;
    _checkSequencer(tNow);

    address feedAddr = address(uint160(uint256(feedId)));
    if (feedAddr == address(0)) revert InvalidFeedAddress();

    AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);
    int256 answer;
    uint256 updatedAt;
    uint80 answeredInRound;
    (data.roundId, answer,, updatedAt, answeredInRound) = feed.latestRoundData();

    if (answeredInRound < data.roundId) revert RoundNotComplete(data.roundId, answeredInRound);
    if (answer <= 0) revert InvalidPrice();
    if (updatedAt == 0) revert InvalidPrice();
    if (updatedAt > tNow) revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), tNow);
    if (tNow - updatedAt > uint256(maxAgeSeconds)) revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), tNow);

    FeedDecimalsConfig memory cfg = _feedDecimals[feedId];
    if (!cfg.configured) revert FeedDecimalsNotConfigured(feedId);
    data.priceE8 = _normalizeToE8(answer, cfg.decimals);
    data.publishTime = uint64(updatedAt);
    data.confidenceE8 = 0;
}

function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64)
    external view override
    returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8)
{
    PriceData memory d = _fetchAndValidatePrice(feedId, maxAgeSeconds);
    return (d.priceE8, d.publishTime, d.confidenceE8);
}

function getNormalizedPriceWithRoundId(bytes32 feedId, uint64 maxAgeSeconds, uint64)
    external view override
    returns (uint80 roundId, int256 priceE8, uint64 publishTime, uint256 confidenceE8)
{
    PriceData memory d = _fetchAndValidatePrice(feedId, maxAgeSeconds);
    return (d.roundId, d.priceE8, d.publishTime, d.confidenceE8);
}
2

ChainlinkAdapter.sol
Sequencer Grace Period Check Uses Strict Inequality — Edge Case at Exact Grace Period Boundary
The sequencer grace period check uses `<=` (less than or equal to) to enforce the grace period: ```solidity uint256 timeSinceUp = tNow - startedAt; if (timeSinceUp <= GRACE_PERIOD_SECONDS) { revert SequencerInGracePeriod(startedAt, startedAt + GRACE_PERIOD_SECONDS); } ``` This means the contract reverts when `timeSinceUp == GRACE_PERIOD_SECONDS` (exactly 3600 seconds), and only allows price reads when `timeSinceUp > GRACE_PERIOD_SECONDS` (strictly greater than 3600 seconds). This is actually the correct and safe behavior per Chainlink's guidance ("wait until strictly after the grace window"). However, the comment says "wait until strictly after the grace window" which is correctly implemented. The issue is that the `SequencerInGracePeriod` error includes `gracePeriodEndsAt = startedAt + GRACE_PERIOD_SECONDS`, but the actual end of the grace period (when reads are allowed) is `startedAt + GRACE_PERIOD_SECONDS + 1 second`. This off-by-one in the error message could mislead off-chain systems that use `gracePeriodEndsAt` to schedule retry attempts — they would retry at exactly `gracePeriodEndsAt` and still get a revert, causing an unnecessary extra retry cycle. This is a minor informational issue but could cause confusion in off-chain monitoring and retry logic.


Hide Details
Impact
Off-chain systems that use the `gracePeriodEndsAt` value from the `SequencerInGracePeriod` error to schedule retry attempts will retry one second too early and receive another revert. This causes minor operational inefficiency but no security impact.
Scenario
Step-by-step:
1. Sequencer comes back up at `startedAt = T`.
2. At `tNow = T + 3600`, `timeSinceUp = 3600 <= 3600`, so revert with `SequencerInGracePeriod(T, T + 3600)`.
3. Off-chain system sees `gracePeriodEndsAt = T + 3600` and retries at `tNow = T + 3600`.
4. Still reverts because `timeSinceUp = 3600 <= 3600`.
5. System must retry at `T + 3601` for success.
Affected code
uint256 timeSinceUp = tNow - startedAt;
if (timeSinceUp <= GRACE_PERIOD_SECONDS) {
revert SequencerInGracePeriod(startedAt, startedAt + GRACE_PERIOD_SECONDS);
}
Proposed fix
Update the error to report the actual timestamp when reads will succeed:
uint256 timeSinceUp = tNow - startedAt;
if (timeSinceUp <= GRACE_PERIOD_SECONDS) {
    // gracePeriodEndsAt + 1 is when reads will succeed (strictly after grace window)
    revert SequencerInGracePeriod(startedAt, startedAt + GRACE_PERIOD_SECONDS + 1);
}


Or alternatively, change the check to `<` and keep the error as-is:
if (timeSinceUp < GRACE_PERIOD_SECONDS) {
    revert SequencerInGracePeriod(startedAt, startedAt + GRACE_PERIOD_SECONDS);
}
Note: changing to `<` would allow reads at exactly `T + 3600`, which may be slightly less conservative than Chainlink's guidance.
3

ChainlinkAdapter.sol
No Event Emitted When Feed Decimals Are Reconfigured — Missing Old Value in Event
The `FeedDecimalsConfigured` event only emits the new `decimals` value, not the previous value: ```solidity event FeedDecimalsConfigured(bytes32 indexed feedId, uint8 decimals); ``` When `setFeedDecimals` is called to update an existing configuration, the event does not include the old decimals value. This makes it difficult for off-chain monitoring systems to detect potentially malicious or accidental reconfiguration, as they cannot determine what the previous value was without querying historical state. Additionally, there is no distinction in the event between an initial configuration and a reconfiguration, making it harder to audit the history of decimal changes.


Hide Details
Impact
Off-chain monitoring systems cannot easily detect decimal reconfiguration attacks or accidental misconfigurations without querying historical blockchain state. This reduces the effectiveness of security monitoring.
Scenario
Not applicable — this is a code quality/monitoring issue.
Affected code
event FeedDecimalsConfigured(bytes32 indexed feedId, uint8 decimals);

function setFeedDecimals(bytes32 feedId, uint8 decimals_) external onlyOwner {
if (feedId == bytes32(0)) revert InvalidFeedAddress();
if (decimals_ > 18) revert UnsupportedFeedDecimals(decimals_);
_feedDecimals[feedId] = FeedDecimalsConfig({decimals: decimals_, configured: true});
emit FeedDecimalsConfigured(feedId, decimals_);
}
Proposed fix
Update the event to include the old decimals value and whether this is an initial configuration or update:
event FeedDecimalsConfigured(
    bytes32 indexed feedId,
    uint8 oldDecimals,
    uint8 newDecimals,
    bool wasConfigured
);

function setFeedDecimals(bytes32 feedId, uint8 decimals_) external onlyOwner {
    if (feedId == bytes32(0)) revert InvalidFeedAddress();
    if (decimals_ > 18) revert UnsupportedFeedDecimals(decimals_);
    FeedDecimalsConfig memory oldCfg = _feedDecimals[feedId];
    _feedDecimals[feedId] = FeedDecimalsConfig({decimals: decimals_, configured: true});
    emit FeedDecimalsConfigured(feedId, oldCfg.decimals, decimals_, oldCfg.configured);
}
4

ChainlinkAdapter.sol
Redundant Staleness Check — Double Validation of updatedAt > tNow
In both `getNormalizedPrice` and `getNormalizedPriceWithRoundId`, there are two separate checks that together validate staleness, but the first check (`updatedAt > tNow`) is actually a subset of the second check (`tNow - updatedAt > maxAgeSeconds`) when `maxAgeSeconds` is reasonable: ```solidity if (updatedAt > tNow) revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), tNow); if (tNow - updatedAt > uint256(maxAgeSeconds)) { revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), tNow); } ``` The first check (`updatedAt > tNow`) is necessary to prevent underflow in the subtraction `tNow - updatedAt`. However, in Solidity 0.8.x, this subtraction would revert automatically due to built-in overflow protection if `updatedAt > tNow`. So the explicit check is redundant from a safety perspective (though it provides a more meaningful error message). More importantly, the error type used for `updatedAt > tNow` is `StalePriceFeed`, which is semantically incorrect — a future timestamp is not a "stale" price, it's an "invalid" or "future" price. This could confuse off-chain systems that parse error types to determine the cause of a revert.


Hide Details
Impact
Minor: incorrect error type for future timestamps could confuse off-chain monitoring. No security impact.
Scenario
Not applicable — this is a code quality issue.
Affected code
if (updatedAt > tNow) revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), tNow);

if (tNow - updatedAt > uint256(maxAgeSeconds)) {
revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), tNow);
}
Proposed fix
Use a distinct error for future timestamps:
error FutureTimestamp(uint256 updatedAt, uint256 blockTs);

// In the validation section:
if (updatedAt > tNow) revert FutureTimestamp(updatedAt, tNow);
if (tNow - updatedAt > uint256(maxAgeSeconds)) {
    revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), tNow);
}
This provides clearer error semantics for off-chain systems.
5

IPriceOracle.sol
IPriceOracle Interface Does Not Enforce nowTs Ignorance — Future Adapter Implementations May Be Vulnerable
The `IPriceOracle` interface defines `nowTs` as an ABI-compatibility parameter that production adapters MUST ignore, but this constraint is only documented in NatSpec comments — it is not enforced at the interface level. Future adapter implementations could accidentally use `nowTs` for staleness checks, allowing callers to bypass freshness validation by supplying a fake timestamp. The `ChainlinkAdapter` correctly ignores `nowTs`, but the interface design creates a footgun for future implementors. Any new adapter that uses `nowTs` for staleness would allow attackers to pass stale prices as fresh by supplying `nowTs = block.timestamp` while the actual oracle data is stale. This is a protocol-level design risk that affects the security of the entire oracle system, not just the current adapter.


Hide Details
Impact
Future adapter implementations that use `nowTs` for staleness checks would allow attackers to bypass freshness validation, potentially using stale prices for settlement or liquidation decisions. This is a systemic risk to the protocol's oracle security model.
Scenario
// Vulnerable future adapter (hypothetical)
contract VulnerableAdapter is IPriceOracle {
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external view returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8)
    {
        // BUG: Uses caller-supplied nowTs instead of block.timestamp
        uint256 tNow = uint256(nowTs); // WRONG!
        // ... staleness check uses tNow ...
        if (tNow - updatedAt > maxAgeSeconds) revert StalePriceFeed(...);
        // Attacker passes nowTs = block.timestamp + 1 year to bypass staleness
    }
}
Affected code
// From IPriceOracle.sol:
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
external
view
returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);
Proposed fix
Consider removing `nowTs` from the interface entirely and using a different mechanism for test compatibility (e.g., a separate mock interface or a test-only override). If `nowTs` must remain for ABI compatibility, add a stronger warning in the interface:
/// @param nowTs MUST be ignored by production adapters. This parameter exists ONLY for
/// ABI compatibility with test mocks. Production adapters MUST use block.timestamp for
/// all freshness and staleness checks. Failure to ignore this parameter creates a
/// critical security vulnerability allowing staleness bypass.
/// @custom:security-critical Adapters MUST NOT use this parameter for any time-based check.
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
    external
    view
    returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);
Alternatively, consider a separate test interface that extends `IPriceOracle` with `nowTs` support, keeping the production interface clean.