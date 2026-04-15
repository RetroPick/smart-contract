// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkAdapter} from "../../src/adapters/ChainlinkAdapter.sol";
import {MockAggregatorV3} from "../../src/test/MockAggregatorV3.sol";
import {MockSequencerFeed} from "../../src/test/MockSequencerFeed.sol";

contract ChainlinkAdapterTest is Test {
    MockSequencerFeed internal seq;
    MockAggregatorV3 internal feed;
    ChainlinkAdapter internal adapter;
    bytes32 internal feedId;

    function setUp() public {
        vm.warp(10_000_000);
        seq = new MockSequencerFeed();
        feed = new MockAggregatorV3(8, int256(45_000 * 1e8));
        adapter = new ChainlinkAdapter(address(seq));
        feedId = bytes32(uint256(uint160(address(feed))));
    }

    function test_happy_path_e8() public view {
        (int256 price,, uint256 conf) = adapter.getNormalizedPrice(feedId, 86_400, uint64(block.timestamp));
        assertEq(price, int256(45_000 * 1e8));
        assertEq(conf, 0);
    }

    function test_L1_skips_sequencer() public {
        MockAggregatorV3 f = new MockAggregatorV3(8, 100e8);
        bytes32 id = bytes32(uint256(uint160(address(f))));
        ChainlinkAdapter l1 = new ChainlinkAdapter(address(0));
        (int256 p,,) = l1.getNormalizedPrice(id, 86_400, 0);
        assertEq(p, 100e8);
    }

    function test_revert_zero_feed_address() public {
        vm.expectRevert(ChainlinkAdapter.InvalidFeedAddress.selector);
        adapter.getNormalizedPrice(bytes32(0), 86_400, 0);
    }

    function test_revert_stale() public {
        feed.makeStale(90_001);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkAdapter.StalePriceFeed.selector,
                uint256(10_000_000 - 90_001),
                uint256(86_400),
                uint256(10_000_000)
            )
        );
        adapter.getNormalizedPrice(feedId, 86_400, uint64(block.timestamp));
    }

    function test_revert_sequencer_down() public {
        seq.setDown();
        vm.expectRevert(ChainlinkAdapter.SequencerDown.selector);
        adapter.getNormalizedPrice(feedId, 86_400, 0);
    }

    function test_revert_sequencer_grace_period() public {
        seq.setRecoveringInGracePeriod();
        uint256 started = block.timestamp - 30;
        vm.expectRevert(
            abi.encodeWithSelector(ChainlinkAdapter.SequencerInGracePeriod.selector, started, started + 3600)
        );
        adapter.getNormalizedPrice(feedId, 86_400, 0);
    }

    function test_revert_sequencer_zero_started_at_while_up() public {
        seq.setUpWithZeroStartedAt();
        vm.expectRevert(ChainlinkAdapter.InvalidSequencerRoundData.selector);
        adapter.getNormalizedPrice(feedId, 86_400, 0);
    }

    function test_revert_incomplete_round() public {
        feed.makeIncompleteRound();
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.RoundNotComplete.selector, uint80(2), uint80(1)));
        adapter.getNormalizedPrice(feedId, 86_400, 0);
    }

    function test_revert_zero_price() public {
        feed.setAnswer(0);
        vm.expectRevert(ChainlinkAdapter.InvalidPrice.selector);
        adapter.getNormalizedPrice(feedId, 86_400, 0);
    }

    function test_normalize_18_decimals() public {
        MockAggregatorV3 f18 = new MockAggregatorV3(18, int256(1e18));
        bytes32 id18 = bytes32(uint256(uint160(address(f18))));
        (int256 price,,) = adapter.getNormalizedPrice(id18, 86_400, 0);
        assertEq(price, 1e8);
    }

    function test_normalize_decimals_below_8_scales_up() public {
        MockAggregatorV3 f6 = new MockAggregatorV3(6, int256(123_456_789));
        bytes32 id6 = bytes32(uint256(uint160(address(f6))));
        (int256 price,,) = adapter.getNormalizedPrice(id6, 86_400, 0);
        assertEq(price, int256(12_345_678_900));
    }

    function test_revert_unsupported_decimals_over_18() public {
        MockAggregatorV3 f19 = new MockAggregatorV3(19, int256(1e19));
        bytes32 id19 = bytes32(uint256(uint160(address(f19))));
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.UnsupportedFeedDecimals.selector, uint8(19)));
        adapter.getNormalizedPrice(id19, 86_400, 0);
    }

    function test_feedId_round_trip() public view {
        address a = address(feed);
        assertEq(adapter.feedIdToAddress(adapter.addressToFeedId(a)), a);
    }

    function test_getNormalizedPriceWithRoundId_matches_feed_round_data() public view {
        (uint80 roundId, int256 priceE8, uint64 publishTime, uint256 conf) =
            adapter.getNormalizedPriceWithRoundId(feedId, 86_400, uint64(block.timestamp));
        assertEq(roundId, 1);
        assertEq(priceE8, int256(45_000 * 1e8));
        assertEq(publishTime, uint64(block.timestamp));
        assertEq(conf, 0);
    }
}
