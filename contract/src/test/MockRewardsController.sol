// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRewardsController} from "../yield/interfaces/IRewardsController.sol";

/// @notice Minimal rewards controller for tests: transfers pre-funded reward tokens to `to`.
contract MockRewardsController is IRewardsController {
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;

    constructor(address rewardToken_) {
        rewardToken = IERC20(rewardToken_);
    }

    function seed(uint256 amount) external {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function claimAllRewards(address[] calldata assets, address to)
        external
        override
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        assets;
        uint256 bal = rewardToken.balanceOf(address(this));
        rewardsList = new address[](1);
        claimedAmounts = new uint256[](1);
        rewardsList[0] = address(rewardToken);
        claimedAmounts[0] = bal;
        if (bal > 0) {
            rewardToken.safeTransfer(to, bal);
        }
    }

    function getAllUserRewards(address[] calldata assets, address user)
        external
        view
        override
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        assets;
        user;
        rewardsList = new address[](1);
        claimedAmounts = new uint256[](1);
        rewardsList[0] = address(rewardToken);
        claimedAmounts[0] = rewardToken.balanceOf(address(this));
    }
}
