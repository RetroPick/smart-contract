// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldRouterV2} from "../../src/yield/YieldRouterV2.sol";
import {MockERC20} from "../../src/test/MockERC20.sol";
import {MockAavePool} from "../../src/test/MockAavePool.sol";
import {MockAToken} from "../../src/test/MockAToken.sol";

/// @notice Exploit PoC tests for YieldRouterV2 security vulnerabilities:
///   H4 — rescueToken allows draining STATA_TOKEN shares
///   H5 — emergencyWithdraw callable by owner, bypassing engine access control
contract YieldRouterV2Security is Test {
    YieldRouterV2 internal router;

    MockERC20 internal stakeToken;
    MockAavePool internal aavePool;
    MockAToken internal aToken;
    MockERC20 internal stataToken;

    address internal engine = address(0xE9177E);
    address internal owner = address(0xABCDEF1234567890);
    address internal attacker = address(0xA77AC4);

    function setUp() public {
        stakeToken = new MockERC20();
        aToken = new MockAToken();
        aavePool = new MockAavePool(address(stakeToken), address(aToken));
        stataToken = new MockERC20();

        vm.prank(owner);
        router = new YieldRouterV2(
            address(stakeToken),
            address(aavePool),
            address(aToken),
            address(0), // no rewards controller
            address(stataToken),
            engine
        );
    }

    // ─── H4: rescueToken cannot drain STATA_TOKEN ────────────────────────────

    /// @notice After fix: rescueToken(stataToken) must revert.
    function test_rescueToken_cannotDrainStataToken() public {
        stataToken.mint(address(router), 1000e18);

        vm.prank(owner);
        vm.expectRevert();
        router.rescueToken(address(stataToken), attacker, 1000e18);

        assertEq(stataToken.balanceOf(attacker), 0, "Attacker must not receive stata shares");
    }

    /// @notice Stray tokens (not protected) can still be rescued.
    function test_rescueToken_allowsStrayTokens() public {
        MockERC20 stray = new MockERC20();
        stray.mint(address(router), 500e18);

        vm.prank(owner);
        router.rescueToken(address(stray), owner, 500e18);

        assertEq(stray.balanceOf(owner), 500e18);
    }

    /// @notice rescueToken still blocks A_TOKEN.
    function test_rescueToken_blocksAToken() public {
        vm.prank(owner);
        vm.expectRevert();
        router.rescueToken(address(aToken), attacker, 1);
    }

    /// @notice rescueToken still blocks STAKE_TOKEN.
    function test_rescueToken_blocksStakeToken() public {
        vm.prank(owner);
        vm.expectRevert();
        router.rescueToken(address(stakeToken), attacker, 1);
    }

    // ─── H5: emergencyWithdraw is engine-only ────────────────────────────────

    /// @notice After fix: owner cannot call emergencyWithdraw.
    function test_emergencyWithdraw_ownerReverts() public {
        bytes32 tid = keccak256("template-1");

        vm.prank(owner);
        vm.expectRevert();
        router.emergencyWithdraw(tid);
    }

    /// @notice Engine can still call emergencyWithdraw after the fix.
    function test_emergencyWithdraw_engineSucceeds() public {
        bytes32 tid = keccak256("template-1");

        vm.prank(engine);
        uint256 gross = router.emergencyWithdraw(tid);
        assertEq(gross, 0, "No principal: grossAmount should be 0");
    }

    /// @notice Random caller cannot call emergencyWithdraw.
    function test_emergencyWithdraw_randomCallerReverts() public {
        bytes32 tid = keccak256("template-1");

        vm.prank(attacker);
        vm.expectRevert();
        router.emergencyWithdraw(tid);
    }
}
