// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev ERC-20 that calls a registered hook after transfer to the hook target.
///      Simulates ERC-777 `tokensReceived` hooks to test CEI-violation reentrancy.
contract MockCallbackERC20 is ERC20 {
    address public hookTarget;
    bytes public hookData;
    bool public hookActive;

    constructor() ERC20("MockCallback", "MCB") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @dev Register a call to `target` with `data` when tokens land at `target`.
    function setTransferHook(address target, bytes calldata data) external {
        hookTarget = target;
        hookData = data;
        hookActive = true;
    }

    function clearHook() external {
        hookActive = false;
    }

    /// @dev Overrides transfer to inject hook callback when sending to hookTarget.
    ///      Hook fires AFTER the balance update but the caller's state may still be mid-execution.
    function transfer(address to, uint256 amount) public override returns (bool result) {
        result = super.transfer(to, amount);
        if (hookActive && to == hookTarget) {
            hookActive = false; // one-shot: prevent recursive re-hook
            // solhint-disable-next-line avoid-low-level-calls
            (bool ok,) = hookTarget.call(hookData);
            require(ok, "MockCallbackERC20: hook failed");
        }
    }
}
