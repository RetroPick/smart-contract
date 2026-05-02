// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MockERC20} from "../MockERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/// @title TokenFaucet
/// @notice Testnet-only faucet that mints a demo ERC20 to callers with per-address cooldown.
/// @dev
/// - Deploy on testnets/devnets only. NOT intended for mainnet.
/// - Constructor deploys a new `MockERC20` test token.
/// - Minting is rate-limited by `lastMintAt[recipient]` and `config.cooldownSeconds`.
/// - Max mint amount per request is capped by `config.maxMintAmount`.
/// - Intended for demos/UIs that need a faucet token for interacting with `MarketEngine`.
/// - `requestWithSig` enables gasless relays: a user signs a mint authorization and any relayer can submit it.
contract TokenFaucet is EIP712 {
    error Cooldown(uint64 nextAt);
    error AmountTooLarge(uint256 amount, uint256 maxAmount);
    error ZeroAmount();
    error ZeroRecipient();
    error ExpiredSignature(uint64 deadline);
    error InvalidSignature();

    struct FaucetConfig {
        uint64 cooldownSeconds;
        uint256 maxMintAmount;
    }

    bytes32 private constant REQUEST_TYPEHASH =
        keccak256("MintRequest(address recipient,uint256 amount,uint256 nonce,uint64 deadline)");

    FaucetConfig public config;

    MockERC20 public immutable TOKEN;

    mapping(address => uint64) public lastMintAt;
    mapping(address => uint256) public nonces;

    event Minted(address indexed to, uint256 amount);

    /// @notice Backwards-compatible getter for the faucet token.
    function token() external view returns (MockERC20) {
        return TOKEN;
    }

    /// @notice Create a faucet and deploy its mintable token.
    /// @param name Unused, kept for backwards-compatible constructor shape.
    /// @param symbol Unused, kept for backwards-compatible constructor shape.
    /// @param cfg Faucet configuration (cooldown + max amount).
    constructor(string memory name, string memory symbol, FaucetConfig memory cfg) EIP712("TokenFaucet", "1") {
        name;
        symbol;
        config = cfg;
        TOKEN = new MockERC20();
    }

    /// @notice Request `amount` tokens from the faucet.
    /// @dev Reverts if called before cooldown expires or if `amount` exceeds `maxMintAmount`.
    function request(uint256 amount) external {
        _mintTo(msg.sender, amount);
    }

    /// @notice Request `amount` tokens for `recipient` using an offchain signature.
    /// @dev Any relayer can submit the signature. The recipient pays no gas.
    function requestWithSig(address recipient, uint256 amount, uint64 deadline, bytes calldata signature) external {
        if (recipient == address(0)) revert ZeroRecipient();
        if (block.timestamp > deadline) revert ExpiredSignature(deadline);

        uint256 nonce = nonces[recipient];
        bytes32 structHash =
            keccak256(abi.encode(REQUEST_TYPEHASH, recipient, amount, nonce, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        if (!SignatureChecker.isValidSignatureNow(recipient, digest, signature)) revert InvalidSignature();

        nonces[recipient] = nonce + 1;
        _mintTo(recipient, amount);
    }

    function _mintTo(address recipient, uint256 amount) internal {
        if (recipient == address(0)) revert ZeroRecipient();
        if (amount == 0) revert ZeroAmount();
        FaucetConfig memory cfg = config;
        if (amount > cfg.maxMintAmount) revert AmountTooLarge(amount, cfg.maxMintAmount);

        uint64 nowTs = uint64(block.timestamp);
        uint64 prev = lastMintAt[recipient];
        if (prev != 0) {
            uint64 nextAt = prev + cfg.cooldownSeconds;
            if (nowTs < nextAt) revert Cooldown(nextAt);
        }

        lastMintAt[recipient] = nowTs;
        TOKEN.mint(recipient, amount);
        emit Minted(recipient, amount);
    }
}
