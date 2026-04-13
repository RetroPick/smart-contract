// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPriceOracleWithRoundId} from "../interfaces/IPriceOracleWithRoundId.sol";

/// @title ChainlinkAdapter
/// @notice `IPriceOracle` implementation over Chainlink `AggregatorV3Interface` (push oracle).
/// @dev
/// NOTES: feedId encoding
/// `MarketEngine` stores the oracle feed as `bytes32 feedId` to keep templates generic.
/// This adapter interprets `feedId` as the Chainlink proxy address encoded as:
/// `bytes32(uint256(uint160(proxyAddress)))`.
///
/// Helpers:
/// - `feedIdToAddress(feedId)` decodes to `address(uint160(uint256(feedId)))`
/// - `addressToFeedId(addr)` encodes to `bytes32(uint256(uint160(addr)))`
///
/// NOTES: Freshness model
/// Uses Chainlink `latestRoundData()` and treats `updatedAt` as `publishTime`. Freshness is enforced by:
/// `block.timestamp - updatedAt <= maxAgeSeconds`.
///
/// NOTES: Round completeness
/// Enforces `answeredInRound >= roundId` to ensure the returned answer is complete for that round.
///
/// NOTES: L2 sequencer uptime gating
/// L2 deployments must pass a sequencer uptime feed; use `address(0)` on L1 to skip checks.
/// Sequencer grace behavior follows Chainlink guidance: `GRACE_PERIOD_SECONDS=3600` and reverts until strictly after.
/// See: `https://docs.chain.link/data-feeds/l2-sequencer-feeds`.
contract ChainlinkAdapter is IPriceOracle, IPriceOracleWithRoundId {
    /// @notice Seconds to wait after sequencer reports “up” before trusting price feeds (answer == 0).
    uint256 public constant GRACE_PERIOD_SECONDS = 3600;

    uint8 internal constant TARGET_DECIMALS = 8;

    /// forge-lint: disable-next-item(screaming-snake-case-immutable) -- public getter name is API-stable
    AggregatorV3Interface public immutable sequencerFeed;

    error SequencerDown();
    /// @dev Sequencer feed returned `startedAt == 0` while reporting up; would bypass grace semantics.
    error InvalidSequencerRoundData();
    error SequencerInGracePeriod(uint256 startedAt, uint256 gracePeriodEndsAt);
    error StalePriceFeed(uint256 updatedAt, uint256 maxAge, uint256 blockTs);
    error InvalidPrice();
    error RoundNotComplete(uint80 roundId, uint80 answeredInRound);
    error InvalidFeedAddress();
    error UnsupportedFeedDecimals(uint8 decimals);

    /// @param sequencerFeed_ L2 sequencer uptime proxy, or `address(0)` on L1.
    constructor(address sequencerFeed_) {
        sequencerFeed = AggregatorV3Interface(sequencerFeed_);
    }

    /// @inheritdoc IPriceOracle
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64)
        external
        view
        override
        returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8)
    {
        _checkSequencer();

        address feedAddr = address(uint160(uint256(feedId)));
        if (feedAddr == address(0)) revert InvalidFeedAddress();

        AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);

        // slither-disable-next-line unused-return -- third tuple slot is round scoped startedAt; staleness uses updatedAt
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();

        if (answeredInRound < roundId) revert RoundNotComplete(roundId, answeredInRound);
        if (answer <= 0) revert InvalidPrice();
        if (updatedAt == 0) revert InvalidPrice();

        if (block.timestamp - updatedAt > uint256(maxAgeSeconds)) {
            revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), block.timestamp);
        }

        uint8 d = feed.decimals();
        priceE8 = _normalizeToE8(answer, d);
        // forge-lint: disable-next-line(unsafe-typecast) -- stale check ensures updatedAt is recent vs block time
        publishTime = uint64(updatedAt);
        confidenceE8 = 0;
    }

    /// @inheritdoc IPriceOracleWithRoundId
    function getNormalizedPriceWithRoundId(bytes32 feedId, uint64 maxAgeSeconds, uint64)
        external
        view
        override
        returns (uint80 roundId, int256 priceE8, uint64 publishTime, uint256 confidenceE8)
    {
        _checkSequencer();

        address feedAddr = address(uint160(uint256(feedId)));
        if (feedAddr == address(0)) revert InvalidFeedAddress();

        AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);

        int256 answer;
        uint256 updatedAt;
        uint80 answeredInRound;
        // slither-disable-next-line unused-return -- third tuple slot is round scoped startedAt; staleness uses updatedAt
        (roundId, answer,, updatedAt, answeredInRound) = feed.latestRoundData();

        if (answeredInRound < roundId) revert RoundNotComplete(roundId, answeredInRound);
        if (answer <= 0) revert InvalidPrice();
        if (updatedAt == 0) revert InvalidPrice();

        if (block.timestamp - updatedAt > uint256(maxAgeSeconds)) {
            revert StalePriceFeed(updatedAt, uint256(maxAgeSeconds), block.timestamp);
        }

        uint8 d = feed.decimals();
        priceE8 = _normalizeToE8(answer, d);
        // forge-lint: disable-next-line(unsafe-typecast) -- stale check ensures updatedAt is recent vs block time
        publishTime = uint64(updatedAt);
        confidenceE8 = 0;
    }

    /// @dev Chainlink L2 pattern: answer 1 = sequencer down; answer 0 = up, then enforce post-recovery grace.
    function _checkSequencer() internal view {
        if (address(sequencerFeed) == address(0)) return;

        // slither-disable-next-line unused-return -- sequencer metadata slots unused; answer and startedAt drive grace
        (, int256 answer, uint256 startedAt,,) = sequencerFeed.latestRoundData();

        if (answer != 0) revert SequencerDown();
        if (startedAt == 0) revert InvalidSequencerRoundData();

        // Match Chainlink’s L2 sequencer example: wait until strictly after the grace window.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_SECONDS) {
            revert SequencerInGracePeriod(startedAt, startedAt + GRACE_PERIOD_SECONDS);
        }
    }

    /// @dev Scales Chainlink `answer` to 8 decimals. Assumes typical positive price feeds.
    function _normalizeToE8(int256 answer, uint8 decimals_) internal pure returns (int256) {
        // Defensive bound: Chainlink feeds are expected to have small decimals (commonly 8).
        // This also avoids exponentiation overflow/DoS if a misconfigured feed returns extreme values.
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

    /// @notice Decode `feedId` bytes32 to the Chainlink proxy address.
    function feedIdToAddress(bytes32 feedId) external pure returns (address) {
        return address(uint160(uint256(feedId)));
    }

    /// @notice Encode a Chainlink proxy address as `feedId`.
    function addressToFeedId(address feedAddress) external pure returns (bytes32) {
        return bytes32(uint256(uint160(feedAddress)));
    }
}
