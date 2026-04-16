// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAToken is ERC20 {
    constructor() ERC20("MockAToken", "maTKN") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /// @dev Mock: treat balance as scaled units when liquidity index is 1 RAY (tests).
    function scaledBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user);
    }
}

