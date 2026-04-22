// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockFeeOnTransferERC20 is ERC20 {
    uint16 public immutable feeBps;

    constructor(uint16 feeBps_) ERC20("MockFeeOnTransfer", "mFOT") {
        feeBps = feeBps_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0) || feeBps == 0) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = (value * uint256(feeBps)) / 10_000;
        uint256 net = value - fee;
        if (fee > 0) {
            super._update(from, address(0), fee);
        }
        super._update(from, to, net);
    }
}
