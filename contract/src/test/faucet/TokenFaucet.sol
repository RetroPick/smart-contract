// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../MockERC20.sol";

/// @title TokenFaucet
/// @notice Testnet-only faucet that mints a demo ERC20 to callers with per-address cooldown.
/// @dev
/// - Deploy on testnets/devnets only. NOT intended for mainnet.
/// - Constructor deploys a new `MockERC20` test token.
/// - Minting is rate-limited by `lastMintAt[msg.sender]` and `config.cooldownSeconds`.
/// - Max mint amount per request is capped by `config.maxMintAmount`.
/// - Intended for demos/UIs that need a faucet token for interacting with `MarketEngine`.
contract TokenFaucet {
    error Cooldown(uint64 nextAt);
    error AmountTooLarge(uint256 amount, uint256 maxAmount);
    error ZeroAmount();

    struct FaucetConfig {
        uint64 cooldownSeconds;
        uint256 maxMintAmount;
    }

    FaucetConfig public config;

    MockERC20 public immutable TOKEN;

    mapping(address => uint64) public lastMintAt;

    event Minted(address indexed to, uint256 amount);

    /// @notice Backwards-compatible getter for the faucet token.
    function token() external view returns (MockERC20) {
        return TOKEN;
    }

    /// @notice Create a faucet and deploy its mintable token.
    /// @param name Unused, kept for backwards-compatible constructor shape.
    /// @param symbol Unused, kept for backwards-compatible constructor shape.
    /// @param cfg Faucet configuration (cooldown + max amount).
    constructor(string memory name, string memory symbol, FaucetConfig memory cfg) {
        name;
        symbol;
        config = cfg;
        TOKEN = new MockERC20();
    }

    /// @notice Request `amount` tokens from the faucet.
    /// @dev Reverts if called before cooldown expires or if `amount` exceeds `maxMintAmount`.
    function request(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        FaucetConfig memory cfg = config;
        if (amount > cfg.maxMintAmount) revert AmountTooLarge(amount, cfg.maxMintAmount);

        uint64 nowTs = uint64(block.timestamp);
        uint64 prev = lastMintAt[msg.sender];
        if (prev != 0) {
            uint64 nextAt = prev + cfg.cooldownSeconds;
            if (nowTs < nextAt) revert Cooldown(nextAt);
        }

        lastMintAt[msg.sender] = nowTs;
        TOKEN.mint(msg.sender, amount);
        emit Minted(msg.sender, amount);
    }
}

