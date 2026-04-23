DeFi Protocol Interfaces (Oracle + Yield Router)

This contract suite defines a set of interfaces for a prediction market / structured product protocol called 'RetroPick'. The interfaces cover: (1) IEventOracle - a trusted reporter oracle for settling non-price-feed markets using signed payloads; (2) IPriceOracle - a chain-agnostic normalized price oracle surface; (3) IPriceOracleWithRoundId - an optional extension for Chainlink-style round-ID-aware price oracles; (4) IYieldRouter - a pluggable yield backend for deploying and withdrawing stake tokens into yield sources; (5) IYieldRouterV2 - an enhanced yield router with scaled aToken accounting, ERC-4626 Stata path support, and liquidity mining reward sweeps. Together, these interfaces form the oracle and yield infrastructure layer for a MarketEngine that manages prediction market epochs.

Show less
Access Control
custom


Privileged Roles
1
trusted reporter/submitter (IEventOracle)
2
MarketEngine (caller of IYieldRouter/IYieldRouterV2)
3
oracle admin (implicit)

External Calls
1
MarketEngine / MarketEngineState
2
Chainlink AggregatorV3Interface
3
Aave aToken / LendingPool
4
StataToken (ERC-4626 wrapper)
5
Aave Rewards Controller

External Systems
1
Oracle (Chainlink)
2
Oracle (Trusted Reporter / Off-chain Signer)
3
DeFi Protocol (Aave)

View Call Graph
Scan results
Ask anything about your scan...

Chat with

Audie
Audie


critical Severity
3
1

IEventOracle.sol
Unexpected ecrecover Null Address Vulnerability in Event Oracle Signature Verification
The IEventOracle interface relies on signed payloads submitted by a trusted reporter. If the implementation uses ecrecover for signature verification without checking that the recovered address is non-zero, an attacker can craft a signature with an invalid v value (any value other than 27 or 28) to make ecrecover return address(0). If the trustedReporter storage variable is uninitialized (address(0)) — which can happen during contract initialization, after an upgrade, or due to a misconfiguration — the check `signer == trustedReporter` would pass with both being address(0), allowing anyone to post arbitrary results for any market.


Hide Details
Impact
An attacker can settle any prediction market with an arbitrary result by submitting a crafted signature that causes ecrecover to return address(0), provided the trustedReporter is uninitialized or set to address(0). This would allow the attacker to manipulate market outcomes and steal funds from losing positions. Even if trustedReporter is properly set, the lack of a zero-address check on the recovered signer is a dangerous pattern that could be exploited in edge cases.
Scenario
1. Deploy EventOracle implementation contract.
2. If trustedReporter is not set during initialization (address(0) by default).
3. Attacker calls postResult(marketId, result, observedAt, dataSourceHash, v=29, r=someBytes32, s=someBytes32).
4. ecrecover returns address(0) due to invalid v value.
5. Check: address(0) == trustedReporter (address(0)) passes.
6. Market is settled with attacker-chosen result.
7. Attacker collects winnings from all positions on the wrong side.
// Attacker contract
contract Exploit {
    IEventOracle oracle;
    
    function exploit(bytes32 marketId) external {
        // v=29 causes ecrecover to return address(0)
        oracle.postResult(marketId, 1, uint64(block.timestamp), bytes32(0), 29, bytes32(0), bytes32(0));
    }
}
Affected code
/// @notice Resolve scalar for settlement (checkpoint B).
function getResult(bytes32 marketId) external view returns (int256 result, bool resolved);

// Implied implementation pattern in postResult:
// address signer = ecrecover(hash, v, r, s);
// require(signer == trustedReporter); // VULNERABLE if trustedReporter == address(0)
Proposed fix
Always validate that the recovered signer address is non-zero before comparing with the trusted reporter:
function postResult(
    bytes32 marketId,
    int256 result,
    uint64 observedAt,
    bytes32 dataSourceHash,
    uint8 v,
    bytes32 r,
    bytes32 s
) external {
    bytes32 digest = _buildDigest(marketId, result, observedAt, dataSourceHash);
    address signer = ecrecover(digest, v, r, s);
    
    // CRITICAL: Always check for zero address
    require(signer != address(0), "Invalid signature: zero address recovered");
    require(signer == trustedReporter, "Unauthorized reporter");
    require(!resolved[marketId], "Market already resolved");
    
    // Store result
    results[marketId] = ResultData(result, observedAt, dataSourceHash, true);
    emit ResultPosted(marketId, result, observedAt, dataSourceHash, msg.sender);
}


Alternatively, use OpenZeppelin's ECDSA library which handles this check internally:
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
address signer = ECDSA.recover(digest, v, r, s); // Reverts on address(0)
2

IYieldRouter.sol
Insufficient Access Control on IYieldRouter State-Changing Functions
The IYieldRouter and IYieldRouterV2 interfaces define critical state-changing functions (deposit, withdraw, emergencyWithdraw, depositScaled, withdrawScaled, setTemplateYieldPath, claimLmRewards) without specifying any access control requirements in the interface definition. The interface provides no mechanism to enforce that only the authorized MarketEngine can call these functions. If implementations fail to properly restrict these functions, any external address could call deposit() to manipulate yield accounting, withdraw() to drain funds attributed to any templateId, emergencyWithdraw() to extract all assets, or setTemplateYieldPath() to change yield routing for active templates.


Hide Details
Impact
If access control is not properly implemented: (1) Any attacker can call withdraw(templateId, principalAmount) to drain yield-bearing assets from any template, stealing user funds. (2) An attacker can call deposit() with a templateId they don't own to inflate their attribution, then withdraw more than their fair share. (3) emergencyWithdraw() can be called by anyone to extract all assets for a template. (4) setTemplateYieldPath() can be called to switch active templates to an unconfigured StataToken path, causing DoS or accounting errors.
Scenario
// Attacker contract
contract YieldRouterAttacker {
    IYieldRouter router;
    address stakeToken;
    
    constructor(address _router, address _stakeToken) {
        router = IYieldRouter(_router);
        stakeToken = _stakeToken;
    }
    
    function drainTemplate(bytes32 templateId) external {
        // If no access control, attacker can withdraw all funds
        // First check balance
        uint256 balance = router.balanceOf(templateId);
        
        // Withdraw all principal (grossAmount includes yield)
        uint256 grossAmount = router.withdraw(templateId, balance);
        
        // Transfer drained funds to attacker
        IERC20(stakeToken).transfer(msg.sender, grossAmount);
    }
    
    function emergencyDrain(bytes32 templateId) external {
        // Emergency withdraw bypasses normal accounting
        uint256 grossAmount = router.emergencyWithdraw(templateId);
        IERC20(stakeToken).transfer(msg.sender, grossAmount);
    }
}
Affected code
function deposit(bytes32 templateId, uint256 amount) external;
function withdraw(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);
function emergencyWithdraw(bytes32 templateId) external returns (uint256 grossAmount);
function depositScaled(bytes32 templateId, uint256 amount) external returns (uint256 attributionUnits);
function withdrawScaled(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);
function setTemplateYieldPath(bytes32 templateId, YieldPath path) external;
Proposed fix
Implementations must enforce strict access control on all state-changing functions. The interface should be accompanied by a clear specification that implementations MUST restrict these functions:
contract YieldRouterImpl is IYieldRouter {
    address public immutable marketEngine;
    address public owner;
    
    modifier onlyEngine() {
        require(msg.sender == marketEngine, "Only MarketEngine");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    function deposit(bytes32 templateId, uint256 amount) external override onlyEngine {
        // implementation
    }
    
    function withdraw(bytes32 templateId, uint256 principalAmount) 
        external override onlyEngine returns (uint256 grossAmount) {
        // implementation
    }
    
    function emergencyWithdraw(bytes32 templateId) 
        external override onlyEngine returns (uint256 grossAmount) {
        // implementation
    }
    
    // setTemplateYieldPath should be owner-only, not engine-callable
    function setTemplateYieldPath(bytes32 templateId, IYieldRouterV2.YieldPath path) 
        external override onlyOwner {
        // implementation
    }
}
Consider adding NatSpec documentation to the interface explicitly stating access control requirements for each function.
3

IEventOracle.sol
Centralized Trusted Reporter Single Point of Failure in IEventOracle
The IEventOracle interface is designed around a single trusted reporter model where one address (or a small set) submits signed payloads to settle prediction markets. The interface provides no mechanism for dispute resolution, result challenges, or fallback settlement. If the trusted reporter is compromised (private key theft), becomes unavailable (reporter goes offline), or acts maliciously (submits incorrect results), there is no on-chain recourse. The getDataSource function explicitly returns empty strings ('Full URI is not stored on-chain'), making off-chain verification difficult. Markets could be permanently stuck in an unresolved state or settled with fraudulent results.


Hide Details
Impact
1. Reporter compromise: Attacker who steals reporter's private key can settle all active markets with arbitrary results, stealing all staked funds. 2. Reporter unavailability: If reporter goes offline, all active markets are permanently stuck in unresolved state, locking user funds indefinitely. 3. Malicious reporter: Reporter can selectively settle markets to maximize their own profit or that of colluding parties. 4. No dispute mechanism: Users have no on-chain way to challenge incorrect results, even with clear evidence of manipulation.
Scenario
Scenario - Reporter Key Compromise:
1. Attacker obtains trusted reporter's private key (phishing, server breach, etc.).
2. Attacker identifies all active markets with large stakes.
3. Attacker places maximum bets on the winning side of each market.
4. Attacker submits signed payloads settling all markets in their favor.
5. Attacker collects all staked funds from losing positions.
6. Total loss = sum of all staked funds across all active markets.

Scenario - Reporter Unavailability:
1. Reporter's infrastructure goes offline (DDoS, server failure, etc.).
2. All active markets reach their settlement time but cannot be resolved.
3. User funds are locked in the MarketEngine indefinitely.
4. No fallback mechanism exists to resolve markets or return funds.
Affected code
/// @notice Full URI is not stored on-chain; returns empty. Index `ResultPosted` + backend for audit.
function getDataSource(bytes32 marketId) external view returns (string memory);

/// @notice Resolve scalar for settlement (checkpoint B).
function getResult(bytes32 marketId) external view returns (int256 result, bool resolved);

event ResultPosted(
bytes32 indexed marketId,
int256 result,
uint64 observedAt,
bytes32 dataSourceHash,
address indexed submittedBy
);
Proposed fix
Implement a multi-layered oracle security model:
interface IEventOracleV2 {
    // Multi-sig or threshold signature support
    function postResultMultiSig(
        bytes32 marketId,
        int256 result,
        uint64 observedAt,
        bytes32 dataSourceHash,
        bytes[] calldata signatures // Multiple reporter signatures
    ) external;
    
    // Dispute window
    function disputeResult(bytes32 marketId, bytes calldata evidence) external;
    
    // Fallback resolution after timeout
    function resolveByTimeout(bytes32 marketId) external;
    
    // Emergency pause
    function pauseMarket(bytes32 marketId) external;
}
Additional recommendations:
1. Use a multi-sig scheme requiring M-of-N reporter signatures
2. Implement a dispute window (e.g., 24-48 hours) during which results can be challenged
3. Store data source URIs on-chain or use IPFS content hashes for verifiability
4. Implement a fallback resolution mechanism (e.g., UMA optimistic oracle) for disputed markets
5. Add an emergency fund recovery mechanism for stuck markets
6. Consider using decentralized oracle networks (Chainlink Functions, UMA, API3) for event resolution

high Severity
5
1

IEventOracle.sol
Missing Signature Replay Protection in IEventOracle Signed Payload Settlement
The IEventOracle interface defines events (ResultPosted, LockSamplePosted, OhlcPosted) that include marketId, result/value, observedAt, dataSourceHash, and submittedBy — but critically, the interface does not expose or mandate any nonce, chainId, or contract address binding in the signed payload structure. The events and getter functions (getResult, getLockSample, getOhlcResult) do not include any replay-protection fields. If the implementation uses ecrecover-based signature verification without binding the signature to a specific chainId and contract address, a valid signature from one chain or contract deployment can be replayed on another chain or a redeployed contract. Additionally, if marketId uniqueness is not enforced per-chain, a signature for one market epoch could potentially be replayed for another market with the same marketId on a different chain.


Hide Details
Impact
An attacker who obtains a valid signed payload for one chain or contract deployment can replay it on another chain or redeployed contract instance, causing fraudulent market settlement. This could result in incorrect payouts to users, theft of funds, or manipulation of prediction market outcomes across chains. In a multi-chain deployment scenario, a result posted on chain A could be replayed on chain B to settle a market with a different intended outcome.
Scenario
1. Trusted reporter signs a payload for marketId=0xABC on Ethereum mainnet with result=1 (team A wins).
2. The same protocol is deployed on Polygon with the same contract address (via CREATE2) or a different address.
3. Attacker takes the signed payload and submits it to the Polygon deployment.
4. If the implementation does not include chainId in the signed hash, the signature verifies successfully.
5. The market on Polygon is settled with result=1 even though the intended result on Polygon was result=0.
6. Attacker who bet on team A on Polygon collects winnings fraudulently.

Additionally, if the same marketId can be reused across epochs (e.g., after a contract upgrade), a previously used signature could re-settle a new market.
Affected code
event ResultPosted(
bytes32 indexed marketId,
int256 result,
uint64 observedAt,
bytes32 dataSourceHash,
address indexed submittedBy
);

event LockSamplePosted(
bytes32 indexed marketId,
int256 valueE8,
uint64 observedAt,
bytes32 dataSourceHash,
address indexed submittedBy
);

event OhlcPosted(
bytes32 indexed marketId,
int256 highE8,
int256 lowE8,
int256 closeE8,
uint64 observedAt,
bytes32 dataSourceHash,
address indexed submittedBy
);
Proposed fix
Ensure the implementation uses EIP-712 structured signing that includes:
1. `chainId` - to prevent cross-chain replay
2. Contract address (`verifyingContract`) - to prevent cross-contract replay
3. A unique nonce or the marketId itself as a one-time-use identifier
4. Mark marketIds as settled after first use to prevent re-settlement
// EIP-712 domain separator
bytes32 public DOMAIN_SEPARATOR = keccak256(abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes("EventOracle")),
    keccak256(bytes("1")),
    block.chainid,
    address(this)
));

// Typed hash for result payload
bytes32 public constant RESULT_TYPEHASH = keccak256(
    "ResultPayload(bytes32 marketId,int256 result,uint64 observedAt,bytes32 dataSourceHash)"
);

// In postResult implementation:
require(!resolved[marketId], "Already settled");
bytes32 structHash = keccak256(abi.encode(RESULT_TYPEHASH, marketId, result, observedAt, dataSourceHash));
bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
address signer = ecrecover(digest, v, r, s);
require(signer != address(0) && signer == trustedReporter, "Invalid signature");
resolved[marketId] = true;
2

IEventOracle.sol
Signature Malleability in Event Oracle Signed Payload Verification
The IEventOracle interface uses signed payloads for market settlement. If the implementation uses raw ecrecover without enforcing that the s value of the signature is in the lower half of the curve order (s <= secp256k1n/2), an attacker can compute a second valid signature (r, -s mod n) from any valid signature without knowing the private key. This is the signature malleability vulnerability. If the implementation tracks used signatures by their (v, r, s) tuple to prevent replay, the malleable signature would bypass this check since it's a different tuple that still recovers to the same signer address.


Hide Details
Impact
If the implementation tracks replay protection by signature bytes rather than by marketId, an attacker can compute a malleable signature from a valid one and re-submit a result for the same market. This could allow double-settlement of a market or bypassing of signature-based replay protection. The impact is particularly severe if the oracle allows result updates (overwriting a previous result), as an attacker could change the settlement outcome after the fact.
Scenario
1. Trusted reporter submits valid signature (v, r, s) for marketId=0xABC with result=1.
2. Implementation marks signature as used: signatureUsed[keccak256(v,r,s)] = true.
3. Attacker computes malleable signature: v' = v, r' = r, s' = secp256k1n - s.
4. Attacker submits (v', r', s') for the same marketId with result=0.
5. signatureUsed check passes because keccak256(v',r',s') != keccak256(v,r,s).
6. ecrecover(hash, v', r', s') returns the same signer address.
7. Market result is overwritten to 0, changing the settlement outcome.
Affected code
event ResultPosted(
bytes32 indexed marketId,
int256 result,
uint64 observedAt,
bytes32 dataSourceHash,
address indexed submittedBy
);

// Implied implementation:
// require(!signatureUsed[keccak256(abi.encodePacked(v, r, s))], "Signature already used");
// address signer = ecrecover(hash, v, r, s);
// signatureUsed[keccak256(abi.encodePacked(v, r, s))] = true;
Proposed fix
Use OpenZeppelin's ECDSA library which enforces low-s normalization and prevents signature malleability:
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// ECDSA.recover enforces s <= secp256k1n/2 and v in {27, 28}
address signer = ECDSA.recover(digest, signature);


Additionally, track replay protection by marketId rather than by signature bytes:
// Track by marketId, not by signature
require(!resolved[marketId], "Market already resolved");
// ... verify signature ...
resolved[marketId] = true; // Prevent any future settlement of this market
This ensures that even if a malleable signature is crafted, the marketId-based check prevents re-settlement.
3

IPriceOracle.sol
Caller-Supplied nowTs Parameter Enables Freshness Check Bypass in IPriceOracle
The IPriceOracle.getNormalizedPrice and IPriceOracleWithRoundId.getNormalizedPriceWithRoundId interfaces accept a caller-supplied nowTs parameter described as 'Caller-supplied time reference (primarily for mocks/tests)'. The documentation states 'production adapters may ignore nowTs and use block.timestamp'. However, if a production adapter implementation incorrectly uses the caller-supplied nowTs for freshness validation (checking publishTime + maxAgeSeconds >= nowTs), an attacker can pass a manipulated nowTs value to bypass the freshness check and use stale oracle prices. This is a design-level vulnerability where the interface itself creates a dangerous pattern that could be misimplemented.


Hide Details
Impact
If a production adapter uses caller-supplied nowTs for freshness validation, an attacker can: (1) Pass nowTs = publishTime to make any stale price appear fresh (age = 0). (2) Use a price from hours or days ago to manipulate market settlement. (3) Exploit price discrepancies between the stale price and current market price to profit from prediction markets. This could lead to systematic mispricing of all markets using the affected oracle adapter.
Scenario
// Vulnerable adapter implementation (incorrect)
contract VulnerableChainlinkAdapter is IPriceOracle {
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
        external view returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8) {
        
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(address(uint160(uint256(feedId)))).latestRoundData();
        
        // BUG: Using caller-supplied nowTs instead of block.timestamp
        require(nowTs - updatedAt <= maxAgeSeconds, "Stale price");
        
        return (answer, uint64(updatedAt), 0);
    }
}

// Attacker exploits stale price
contract Attacker {
    IPriceOracle oracle;
    
    function exploitStalePriceCheck(bytes32 feedId, uint64 maxAgeSeconds) external {
        // Get the actual publish time of the stale price
        (, , , uint256 updatedAt, ) = AggregatorV3Interface(address(uint160(uint256(feedId)))).latestRoundData();
        
        // Pass nowTs = updatedAt to make stale price appear fresh (age = 0)
        (int256 stalePrice,,) = oracle.getNormalizedPrice(feedId, maxAgeSeconds, uint64(updatedAt));
        
        // Use stale price to manipulate market settlement
    }
}
Affected code
/// @param nowTs Caller-supplied time reference (primarily for mocks/tests).
/// @return priceE8 Normalized price scaled to 8 decimals.
/// @return publishTime Oracle update timestamp used for freshness/monotonicity.
/// @return confidenceE8 Optional confidence band scaled to e8 (0 if unsupported).
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
external
view
returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);

function getNormalizedPriceWithRoundId(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
external
view
returns (uint80 roundId, int256 priceE8, uint64 publishTime, uint256 confidenceE8);
Proposed fix
Remove the nowTs parameter from production interfaces or clearly separate test and production interfaces. Production adapters should always use block.timestamp:
// Option 1: Remove nowTs from production interface
interface IPriceOracleProduction {
    function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds)
        external view returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);
}

// Option 2: If nowTs must be kept, validate it in the adapter
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
    external view returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8) {
    
    // Always use block.timestamp for freshness, ignore nowTs in production
    uint64 effectiveNow = uint64(block.timestamp);
    
    (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
    require(effectiveNow - updatedAt <= maxAgeSeconds, "Stale price");
    
    return (normalizePrice(answer), uint64(updatedAt), 0);
}
Add explicit NatSpec documentation warning that production implementations MUST use block.timestamp and MUST NOT use the caller-supplied nowTs for security-critical freshness checks.
4

IYieldRouter.sol
Yield Router Withdrawal Return Value Trust Without Balance Verification
The IYieldRouter.withdraw and IYieldRouterV2.withdrawScaled functions return a grossAmount value representing the actual tokens transferred to the MarketEngine. However, the interface design creates a trust assumption: the MarketEngine is expected to trust the returned grossAmount without independently verifying the actual token balance change. If a malicious or buggy router implementation returns an inflated grossAmount without actually transferring the corresponding tokens, the MarketEngine would distribute more funds to winners than it actually received, leading to insolvency. This is particularly dangerous because the interface explicitly states 'Implementations must transfer stakeToken to the engine' as a doc comment rather than an enforced invariant.


Hide Details
Impact
If the router returns an inflated grossAmount: (1) MarketEngine distributes more tokens to winners than it received, creating an insolvency condition. (2) Later withdrawals by other users fail due to insufficient balance. (3) In the worst case, a malicious router upgrade could drain the MarketEngine by reporting inflated returns. (4) Even with a non-malicious bug, accounting errors could cause systematic underpayment or overpayment to users.
Scenario
// Malicious router implementation
contract MaliciousYieldRouter is IYieldRouter {
    IERC20 stakeToken;
    address engine;
    
    function withdraw(bytes32 templateId, uint256 principalAmount) 
        external returns (uint256 grossAmount) {
        
        // Only transfer 50% of the actual amount
        uint256 actualAmount = principalAmount / 2;
        stakeToken.transfer(engine, actualAmount);
        
        // But report 100% + yield to inflate accounting
        return principalAmount * 110 / 100; // Report 110% of principal
    }
}

// Vulnerable MarketEngine pattern
contract VulnerableMarketEngine {
    function resolveEpoch(bytes32 templateId, uint256 principal) external {
        // Trusts return value without verification
        uint256 grossAmount = yieldRouter.withdraw(templateId, principal);
        
        // Distributes based on reported grossAmount, not actual balance
        distributeToWinners(grossAmount); // VULNERABLE: may distribute more than received
    }
}
Affected code
/// @notice Withdraw `principalAmount` (plus any accrued yield) to the engine.
/// @dev Called by `MarketEngine` during epoch resolution. Implementations must transfer stakeToken to the engine.
/// @return grossAmount Actual stakeToken amount returned to the engine (principal + yield, if any).
function withdraw(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);

/// @notice Emergency: withdraw all yield-bearing assets attributable to `templateId` to the engine.
/// @dev Intended for pause/recovery flows.
function emergencyWithdraw(bytes32 templateId) external returns (uint256 grossAmount);
Proposed fix
The MarketEngine should verify actual token balance changes rather than trusting return values:
contract SecureMarketEngine {
    IERC20 stakeToken;
    IYieldRouter yieldRouter;
    
    function resolveEpoch(bytes32 templateId, uint256 principal) external {
        // Record balance before withdrawal
        uint256 balanceBefore = stakeToken.balanceOf(address(this));
        
        // Call router withdrawal
        uint256 reportedGrossAmount = yieldRouter.withdraw(templateId, principal);
        
        // Verify actual balance change
        uint256 balanceAfter = stakeToken.balanceOf(address(this));
        uint256 actualReceived = balanceAfter - balanceBefore;
        
        // Use actual received amount, not reported amount
        require(actualReceived >= principal, "Router returned less than principal");
        
        // Optionally emit discrepancy event if reportedGrossAmount != actualReceived
        if (reportedGrossAmount != actualReceived) {
            emit YieldDiscrepancy(templateId, reportedGrossAmount, actualReceived);
        }
        
        // Distribute based on actual received amount
        distributeToWinners(actualReceived);
    }
}
5

IYieldRouterV2.sol
Missing Access Control on setTemplateYieldPath Allows Unauthorized Yield Path Changes
The IYieldRouterV2.setTemplateYieldPath function allows changing the yield path (AToken vs StataToken) for a template. The interface provides no specification of who is authorized to call this function. If this function is callable by anyone (or by the MarketEngine without additional governance controls), an attacker or malicious operator could switch an active template's yield path mid-epoch. Switching from AToken to StataToken (or vice versa) while a template has active deposits could cause accounting inconsistencies, as the scaled balance tracking differs between paths.


Hide Details
Impact
1. An unauthorized caller can switch a template's yield path mid-epoch, causing accounting inconsistencies between deposited AToken shares and expected StataToken shares. 2. If switched to StataToken when stataToken is not configured, all subsequent deposits/withdrawals for that template will revert, causing DoS. 3. Switching paths could cause the proportional slice calculation in withdrawScaled to use incorrect accounting units, leading to over or under-payment. 4. In the worst case, switching paths could allow an attacker to extract more yield than they are entitled to.
Scenario
1. Template T1 has 1000 USDC deposited via AToken path, earning Aave yield.
2. Attacker calls setTemplateYieldPath(T1, YieldPath.StataToken).
3. If stataToken is not configured, all future deposits/withdrawals for T1 revert.
4. Users' funds are locked in the AToken position but the router expects StataToken accounting.
5. emergencyWithdraw may also fail if it uses the wrong path.
6. Users cannot recover their funds without admin intervention.
Affected code
/// @dev Per-template path; default is AToken. StataToken requires `stataToken` configured on the router.
function setTemplateYieldPath(bytes32 templateId, YieldPath path) external;

enum YieldPath {
AToken,
StataToken
}
Proposed fix
Restrict setTemplateYieldPath to a privileged role and add guards against mid-epoch path changes:
contract YieldRouterV2Impl is IYieldRouterV2 {
    address public owner;
    address public marketEngine;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    function setTemplateYieldPath(bytes32 templateId, YieldPath path) 
        external override onlyOwner {
        
        // Prevent changing path if template has active deposits
        require(principalOf(templateId) == 0, "Cannot change path with active deposits");
        
        // Validate StataToken is configured before switching to it
        if (path == YieldPath.StataToken) {
            require(stataToken != address(0), "StataToken not configured");
        }
        
        templateYieldPath[templateId] = path;
        emit TemplateYieldPathSet(templateId, path);
    }
}
Add a timelock for path changes to allow users to exit before the change takes effect.

medium Severity
6
1

IYieldRouterV2.sol
Precision Loss in IYieldRouterV2 Proportional Slice Calculation for withdrawScaled
The IYieldRouterV2.withdrawScaled function computes a 'proportional slice' of the yield position based on principalAmount vs. total principal. This calculation inherently involves integer division which truncates remainders. For example, if a template has totalPrincipal=1000 and totalScaledBalance=1100 (10% yield), and a user withdraws principalAmount=1, the calculation would be: slice = 1 * 1100 / 1000 = 1 (truncated from 1.1). The user loses 0.1 tokens of yield. Over many small withdrawals, this precision loss accumulates and the 'dust' yield remains locked in the router. More critically, if the calculation is done in the wrong order (division before multiplication), the precision loss is amplified.


Hide Details
Impact
1. Users systematically receive slightly less than their fair share of yield due to truncation. 2. Accumulated precision loss creates 'dust' yield that remains locked in the router and cannot be withdrawn. 3. In adversarial scenarios, an attacker could exploit the rounding direction to extract slightly more than their fair share through carefully timed withdrawals. 4. For large-scale protocols with many small positions, the total precision loss could be significant.
Scenario
// Precision loss demonstration
// Template state: principal=1000, scaledBalance=1100 (10% yield)
// User A withdraws principalAmount=1:
//   grossAmount = 1 * 1100 / 1000 = 1 (truncated, should be 1.1)
//   User A loses 0.1 tokens

// After 1000 such withdrawals:
//   Total withdrawn principal = 1000
//   Total grossAmount paid = 1000 (should be 1100)
//   Locked dust = 100 tokens (10% of yield)

// Amplified precision loss with wrong order:
// grossAmount = (principalAmount / totalPrincipal) * totalScaledBalance
// = (1 / 1000) * 1100
// = 0 * 1100 = 0  // Complete loss!

// Correct order (multiplication before division):
// grossAmount = principalAmount * totalScaledBalance / totalPrincipal
// = 1 * 1100 / 1000 = 1 (still truncated but minimal loss)
Affected code
/// @notice Withdraw underlying for `templateId` against `principalAmount` of tracked principal (proportional slice).
/// @return grossAmount Underlying received by the engine (principal slice + yield on that slice).
function withdrawScaled(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);

function principalOf(bytes32 templateId) external view returns (uint256);
function scaledPrincipalOf(bytes32 templateId) external view returns (uint256);
function stataSharesOf(bytes32 templateId) external view returns (uint256);
Proposed fix
Use mulDiv with appropriate rounding direction and consider using a fixed-point math library:
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

function withdrawScaled(bytes32 templateId, uint256 principalAmount) 
    external returns (uint256 grossAmount) {
    
    uint256 totalPrincipal = principalOf(templateId);
    uint256 totalScaledBalance = scaledPrincipalOf(templateId);
    
    require(totalPrincipal > 0, "No principal");
    require(principalAmount <= totalPrincipal, "Exceeds principal");
    
    // Use mulDiv to avoid precision loss and overflow
    // Round DOWN for user withdrawals (conservative, protects protocol)
    grossAmount = Math.mulDiv(principalAmount, totalScaledBalance, totalPrincipal, Math.Rounding.Floor);
    
    // Update accounting
    // ...
    
    return grossAmount;
}

// For the last withdrawal, use remaining balance to avoid dust:
function withdrawAllScaled(bytes32 templateId) external returns (uint256 grossAmount) {
    // Return entire remaining balance to avoid dust accumulation
    grossAmount = currentValueOf(templateId);
    // ...
}
Additionally, implement a dust collection mechanism for the protocol to periodically sweep accumulated precision-loss dust.
2

IPriceOracleWithRoundId.sol
Missing Monotonicity Enforcement for Oracle Round IDs Allows Stale Price Injection
The IPriceOracleWithRoundId interface is described as an 'optional extension' that 'allows engines to enforce monotonic oracle progression'. However, since it's optional and the engine 'should treat this interface as optional and fall back to IPriceOracle.getNormalizedPrice when not implemented', there is no guarantee that round ID monotonicity is actually enforced. If the engine falls back to the base IPriceOracle interface, it loses the ability to detect when a Chainlink oracle has been updated with a lower round ID (which can happen during oracle migrations or in edge cases). An attacker who can influence which oracle interface is used (e.g., by triggering a fallback) could cause the engine to accept stale prices.


Hide Details
Impact
Without enforced round ID monotonicity: (1) An attacker could exploit Chainlink oracle phase transitions where round IDs reset, causing the engine to accept a price from a previous phase as 'current'. (2) During oracle migrations, stale prices from the old aggregator could be injected. (3) The optional nature of the interface means security-critical monotonicity checks may be silently skipped in production deployments. (4) Market settlement could be based on incorrect prices, leading to wrong payouts.
Scenario
1. MarketEngine is configured with a Chainlink adapter that implements IPriceOracleWithRoundId.
2. Chainlink migrates to a new aggregator (phase change), resetting round IDs from 0.
3. Engine checks: newRoundId > lastRoundId. New round ID is 1, last stored is 100000.
4. Check fails, engine falls back to IPriceOracle.getNormalizedPrice (no round ID check).
5. Attacker exploits the window where the new aggregator has a stale/manipulated price.
6. Engine accepts the stale price for market settlement.
7. Attacker profits from the price discrepancy.
Affected code
/// @title IPriceOracleWithRoundId
/// @notice Optional extension for `IPriceOracle` implementations that can expose oracle round IDs.
/// @dev
/// Intended for Chainlink `AggregatorV3Interface` adapters. Engines should treat this interface as optional
/// and fall back to `IPriceOracle.getNormalizedPrice` when not implemented.
///
/// `roundId` allows engines to enforce monotonic oracle progression (e.g., strict increase per template or per feed)
function getNormalizedPriceWithRoundId(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
external
view
returns (uint80 roundId, int256 priceE8, uint64 publishTime, uint256 confidenceE8);
Proposed fix
Make round ID monotonicity enforcement mandatory rather than optional, or implement a robust fallback:
// In MarketEngine - enforce round ID check when available
function _getOraclePrice(bytes32 feedId, uint64 maxAgeSeconds) internal returns (int256 priceE8) {
    // Try to get price with round ID for monotonicity enforcement
    try IPriceOracleWithRoundId(address(priceOracle)).getNormalizedPriceWithRoundId(
        feedId, maxAgeSeconds, uint64(block.timestamp)
    ) returns (uint80 roundId, int256 price, uint64 publishTime, uint256 confidence) {
        // Enforce strict monotonicity
        require(roundId > lastRoundId[feedId], "Non-monotonic round ID");
        lastRoundId[feedId] = roundId;
        return price;
    } catch {
        // Fallback: only use if round ID interface not available
        // Log that monotonicity cannot be enforced
        emit MonotonicityCheckSkipped(feedId);
        (int256 price,,) = priceOracle.getNormalizedPrice(feedId, maxAgeSeconds, uint64(block.timestamp));
        return price;
    }
}
For production deployments, require that all price oracle adapters implement IPriceOracleWithRoundId and make the fallback to base IPriceOracle an explicit configuration choice with appropriate warnings.
3

IEventOracle.sol
MarketId Collision Risk Due to Unspecified positionKey Hash Construction
The IEventOracle interface states that 'marketId MUST match MarketEngineState.positionKey(templateId, epochId)'. However, the interface does not define or enforce the hash construction method for positionKey. If different components of the system use different hash constructions (e.g., keccak256(abi.encode(templateId, epochId)) vs keccak256(abi.encodePacked(templateId, epochId))), marketId collisions could occur. With abi.encodePacked, different (templateId, epochId) pairs can produce the same hash due to the lack of length encoding. For example, (0xAB, 0xCD) and (0xA, 0xBCD) would produce the same packed encoding.


Hide Details
Impact
If marketId collisions occur: (1) Settlement data for one market could overwrite or be confused with another market's data. (2) A market that has already been settled could have its result overwritten by a collision with a new market. (3) Users in the colliding market would receive incorrect payouts. (4) An attacker who can control templateId or epochId values might deliberately craft collisions to manipulate settlement.
Scenario
// Collision example with abi.encodePacked
// templateId = bytes32(0x1234) (padded: 0x0000...1234)
// epochId = bytes32(0x5678) (padded: 0x0000...5678)
// positionKey = keccak256(abi.encodePacked(templateId, epochId))

// Different inputs that could produce same packed encoding:
// If templateId and epochId are variable-length types:
// ("12", "345678") vs ("123", "45678") - same packed bytes

// With bytes32 types, collision is harder but still possible
// if the construction is not standardized across components

// Example of inconsistent construction:
bytes32 marketId1 = keccak256(abi.encode(templateId, epochId));      // Safe
bytes32 marketId2 = keccak256(abi.encodePacked(templateId, epochId)); // Potentially unsafe
// marketId1 != marketId2 for same inputs - inconsistency causes bugs
Affected code
/// @dev `marketId` MUST match `MarketEngineState.positionKey(templateId, epochId)`.
interface IEventOracle {
event ResultPosted(
bytes32 indexed marketId,
...
);

function getResult(bytes32 marketId) external view returns (int256 result, bool resolved);
function getLockSample(bytes32 marketId) external view returns (int256 valueE8, uint64 observedAt, bool written);
function getOhlcResult(bytes32 marketId) external view returns (int256 highE8, int256 lowE8, int256 closeE8, uint64 observedAt, bool written);
}
Proposed fix
Standardize the marketId construction in the interface documentation and enforce it:
/// @dev `marketId` MUST be computed as:
/// `keccak256(abi.encode(templateId, epochId))`
/// where templateId and epochId are bytes32 values.
/// NEVER use abi.encodePacked for hash construction to avoid collision attacks.
interface IEventOracle {
    // Add a helper function to compute marketId
    function computeMarketId(bytes32 templateId, bytes32 epochId) 
        external pure returns (bytes32 marketId);
}

// Implementation:
function computeMarketId(bytes32 templateId, bytes32 epochId) 
    external pure returns (bytes32) {
    return keccak256(abi.encode(templateId, epochId));
}
Always use `abi.encode` (not `abi.encodePacked`) for hash construction when combining multiple dynamic or fixed-size values to prevent hash collisions.
4

IPriceOracle.sol
Negative Price Values Not Validated in IPriceOracle and IEventOracle
Both IPriceOracle (priceE8 as int256) and IEventOracle (valueE8, highE8, lowE8, closeE8 as int256) use signed integers for price/value representation. The interfaces do not specify validation requirements for negative values. For asset prices, negative values are economically meaningless and could cause severe issues in the MarketEngine's settlement logic. For example, if a Chainlink feed returns a negative price (which can happen with certain feed configurations or during oracle errors), and the adapter does not validate this, the engine could settle markets with negative prices, leading to incorrect payouts or arithmetic underflows in downstream calculations.


Hide Details
Impact
1. Negative priceE8 values could cause arithmetic underflows or incorrect comparisons in the MarketEngine's settlement logic. 2. For OHLC data, a negative lowE8 or highE8 could cause incorrect range calculations. 3. If the engine uses int256 arithmetic without checking for negative values, an attacker who can influence oracle data could trigger unexpected behavior. 4. Chainlink has historically returned negative prices for certain feeds during anomalous conditions.
Scenario
// Scenario: Chainlink returns negative price during oracle error
// Vulnerable adapter:
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
    external view returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8) {
    
    (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
    // No negative price check!
    return (answer, uint64(updatedAt), 0);
}

// MarketEngine settlement with negative price:
function settleMarket(bytes32 marketId) external {
    (int256 lockPrice,,) = oracle.getLockSample(marketId);
    (int256 settlePrice,,) = oracle.getLockSample(marketId); // simplified
    
    // If lockPrice is negative, this comparison is meaningless
    bool priceWentUp = settlePrice > lockPrice; // Could be wrong with negative values
    
    // Arithmetic with negative price could underflow
    int256 priceDiff = settlePrice - lockPrice; // Could be very large negative number
    uint256 payout = uint256(priceDiff); // OVERFLOW if priceDiff is negative!
}
Affected code
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
external
view
returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);

function getOhlcResult(bytes32 marketId)
external
view
returns (int256 highE8, int256 lowE8, int256 closeE8, uint64 observedAt, bool written);

function getLockSample(bytes32 marketId)
external
view
returns (int256 valueE8, uint64 observedAt, bool written);
Proposed fix
Add explicit validation for non-negative prices in oracle adapters and the MarketEngine:
// In IPriceOracle adapter implementation:
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
    external view returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8) {
    
    (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
    
    // Validate price is positive
    require(answer > 0, "Invalid price: non-positive");
    
    // Check freshness
    require(block.timestamp - updatedAt <= maxAgeSeconds, "Stale price");
    
    return (answer, uint64(updatedAt), 0);
}

// In IEventOracle implementation for OHLC:
function postOhlc(..., int256 highE8, int256 lowE8, int256 closeE8, ...) external {
    require(highE8 > 0 && lowE8 > 0 && closeE8 > 0, "Invalid OHLC: non-positive values");
    require(highE8 >= lowE8, "Invalid OHLC: high < low");
    require(closeE8 >= lowE8 && closeE8 <= highE8, "Invalid OHLC: close out of range");
    // ...
}
5

IYieldRouterV2.sol
IYieldRouterV2 Interface Inherits IYieldRouter Creating Dual Withdrawal Path Confusion
IYieldRouterV2 inherits from IYieldRouter, meaning implementations must provide both the original withdraw() and the new withdrawScaled() functions. These two functions have different semantics: withdraw() returns 'principal + yield' while withdrawScaled() returns 'proportional slice of yield position'. If the MarketEngine calls the wrong function (e.g., calls withdraw() on a V2 router that uses scaled accounting), the accounting could be incorrect. The interface does not specify whether withdraw() should be deprecated in V2 or how it should behave when scaled accounting is active. This creates ambiguity that could lead to double-withdrawal vulnerabilities or accounting inconsistencies.


Hide Details
Impact
1. If MarketEngine calls both withdraw() and withdrawScaled() for the same templateId, double-withdrawal could occur, draining more funds than deposited. 2. If the V2 implementation's withdraw() doesn't properly account for scaled balances, it could return incorrect amounts. 3. The ambiguity between deposit()/depositScaled() and withdraw()/withdrawScaled() creates integration complexity that increases the likelihood of bugs in the MarketEngine. 4. emergencyWithdraw() inherited from V1 may not correctly handle scaled accounting in V2 implementations.
Scenario
// Scenario: MarketEngine accidentally calls both withdraw paths
contract VulnerableMarketEngine {
    IYieldRouterV2 router;
    
    function resolveEpoch(bytes32 templateId, uint256 principal) external {
        // Bug: calls both V1 and V2 withdrawal
        uint256 amount1 = router.withdraw(templateId, principal);     // V1 path
        uint256 amount2 = router.withdrawScaled(templateId, principal); // V2 path
        
        // Double withdrawal! Router may have sent 2x the funds
        distributeToWinners(amount1 + amount2);
    }
}

// Or: V2 implementation's withdraw() doesn't update scaled accounting
contract BuggyYieldRouterV2 is IYieldRouterV2 {
    function withdraw(bytes32 templateId, uint256 principalAmount) 
        external returns (uint256 grossAmount) {
        // V1 implementation: doesn't update scaledPrincipal
        // scaledPrincipalOf(templateId) is now stale
        return _withdrawFromAave(principalAmount);
    }
    
    function withdrawScaled(bytes32 templateId, uint256 principalAmount)
        external returns (uint256 grossAmount) {
        // Uses stale scaledPrincipal from previous withdraw() call
        // Returns incorrect proportional slice
        uint256 scaledPrincipal = scaledPrincipalOf(templateId); // STALE!
        return _computeProportionalSlice(scaledPrincipal, principalAmount);
    }
}
Affected code
interface IYieldRouterV2 is IYieldRouter {
// Inherits:
// function withdraw(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);
// function emergencyWithdraw(bytes32 templateId) external returns (uint256 grossAmount);

// New V2 functions:
function withdrawScaled(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);
function depositScaled(bytes32 templateId, uint256 amount) external returns (uint256 attributionUnits);
}
Proposed fix
Clearly separate V1 and V2 interfaces without inheritance, or explicitly deprecate V1 functions in V2:
interface IYieldRouterV2 is IYieldRouter {
    // Explicitly document that V1 functions delegate to V2 in implementations
    
    /// @notice DEPRECATED in V2: Use withdrawScaled() instead.
    /// @dev V2 implementations MUST implement this as:
    ///      return withdrawScaled(templateId, principalAmount);
    /// @inheritdoc IYieldRouter
    // function withdraw(...) - inherited, must delegate to withdrawScaled
    
    /// @notice V2 scaled withdrawal - use this instead of withdraw() for V2 routers.
    function withdrawScaled(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);
}

// In V2 implementation:
function withdraw(bytes32 templateId, uint256 principalAmount) 
    external override returns (uint256 grossAmount) {
    // Delegate to scaled implementation to maintain consistent accounting
    return withdrawScaled(templateId, principalAmount);
}
Add a version() function to the interface so the MarketEngine can detect which version it's interacting with and use the appropriate withdrawal path.
6

IYieldRouterV2.sol
IYieldRouterV2.claimLmRewards Reward Token Distribution Not Specified
The IYieldRouterV2.claimLmRewards function claims liquidity-mining rewards for a templateId and returns lists of reward tokens and amounts. However, the interface does not specify where the claimed rewards are sent (to the engine, to a treasury, to users, etc.) or how they should be distributed among users of the template. If rewards are sent to the router contract itself without a distribution mechanism, they could be permanently locked. If sent to the MarketEngine without proper accounting, they may not be distributed to the correct users.


Hide Details
Impact
1. If reward tokens are sent to the router without a distribution mechanism, they are permanently locked. 2. If rewards are sent to the MarketEngine but not accounted for in settlement calculations, users who staked during the reward period do not receive their fair share. 3. An attacker who can call claimLmRewards() could trigger reward distribution at a time that benefits them (e.g., just before they withdraw, claiming rewards that should belong to other users). 4. Reward token addresses are not validated - if a malicious reward token is added by Aave governance, it could be used for reentrancy attacks.
Scenario
// Scenario: Reward token reentrancy
// Aave adds a malicious ERC-777 token as a reward
contract MaliciousRewardToken {
    IYieldRouterV2 router;
    
    // ERC-777 tokensReceived hook
    function tokensReceived(address, address, address, uint256, bytes calldata, bytes calldata) external {
        // Reenter router during reward claim
        router.claimLmRewards(targetTemplateId);
        // Or reenter withdrawScaled to drain funds
        router.withdrawScaled(targetTemplateId, largeAmount);
    }
}

// Scenario: Reward front-running
// 1. Large rewards accumulate for templateId T1
// 2. Attacker deposits large amount into T1 just before claiming
// 3. Attacker calls claimLmRewards(T1)
// 4. Attacker receives disproportionate share of rewards
// 5. Attacker withdraws immediately after
Affected code
/// @notice Claim liquidity-mining rewards for aToken (no-op if rewards controller is zero).
function claimLmRewards(bytes32 templateId)
external
returns (address[] memory rewardsList, uint256[] memory amounts);

/// @notice Pending LM rewards view (may be gas-heavy).
function pendingLmRewards(bytes32 templateId)
external
view
returns (address[] memory tokens, uint256[] memory pending);
Proposed fix
Specify reward distribution semantics in the interface and implement safeguards:
interface IYieldRouterV2 is IYieldRouter {
    /// @notice Claim LM rewards and transfer to designated recipient.
    /// @dev Rewards are transferred to `rewardRecipient` (typically a treasury or distribution contract).
    ///      Caller must be authorized (MarketEngine or owner).
    /// @param templateId Template to claim rewards for.
    /// @param rewardRecipient Address to receive claimed reward tokens.
    function claimLmRewards(bytes32 templateId, address rewardRecipient)
        external
        returns (address[] memory rewardsList, uint256[] memory amounts);
}

// Implementation with reentrancy guard:
function claimLmRewards(bytes32 templateId, address rewardRecipient)
    external nonReentrant onlyEngine
    returns (address[] memory rewardsList, uint256[] memory amounts) {
    
    require(rewardRecipient != address(0), "Invalid recipient");
    
    // Claim from Aave rewards controller
    (rewardsList, amounts) = rewardsController.claimAllRewards(
        aTokens, rewardRecipient // Send directly to recipient, not to router
    );
    
    emit LmRewardsClaimed(templateId, rewardRecipient, rewardsList, amounts);
}

low Severity
4
1

IEventOracle.sol
Missing Data Source URI On-Chain Creates Unverifiable Settlement Claims
The IEventOracle interface explicitly states 'Full URI is not stored on-chain; returns empty. Index ResultPosted + backend for audit.' The getDataSource() function always returns an empty string. Only the keccak256 hash of the data source (dataSourceHash) is stored. This means that while the hash can be used to verify a known URI, there is no way to discover the original URI from on-chain data alone. Users must rely on off-chain indexers and backend systems to audit settlement data. If the backend is unavailable or the data source is taken down, the settlement becomes unverifiable, undermining the trustlessness of the protocol.


Hide Details
Impact
1. Users cannot independently verify settlement data without access to off-chain infrastructure. 2. If the backend goes offline or data sources are removed, historical settlements become unauditable. 3. The protocol's trustlessness is compromised - users must trust the operator's backend rather than the blockchain. 4. In a dispute scenario, there is no on-chain evidence to challenge a fraudulent settlement. 5. Regulatory compliance may be affected if audit trails are not fully on-chain.
Scenario
Scenario:
1. Market is settled with result=1 (team A wins) via a signed payload.
2. dataSourceHash = keccak256('https://api.example.com/results/game123') is stored on-chain.
3. Users suspect the result is incorrect.
4. Users call getDataSource(marketId) - returns empty string.
5. Users must query off-chain indexer to find the original URI.
6. If the API endpoint is taken down or returns different data, users cannot verify the settlement.
7. No on-chain dispute mechanism exists to challenge the result.
Affected code
/// @notice Full URI is not stored on-chain; returns empty. Index `ResultPosted` + backend for audit.
function getDataSource(bytes32 marketId) external view returns (string memory);

/// @notice `keccak256(bytes(utf8Source))` from the signed resolve payload.
function getResolveDataSourceHash(bytes32 marketId) external view returns (bytes32);
Proposed fix
Store data source URIs on-chain or use content-addressed storage (IPFS) for verifiability:
// Option 1: Store URI on-chain (higher gas cost)
function postResult(
    bytes32 marketId,
    int256 result,
    uint64 observedAt,
    string calldata dataSourceUri, // Store full URI
    uint8 v, bytes32 r, bytes32 s
) external {
    bytes32 dataSourceHash = keccak256(bytes(dataSourceUri));
    // ... verify signature includes dataSourceHash ...
    results[marketId] = ResultData(result, observedAt, dataSourceHash, dataSourceUri, true);
}

// Option 2: Use IPFS content hash (verifiable without storing full URI)
// dataSourceHash = IPFS CID encoded as bytes32
// Anyone can retrieve the data from IPFS using the CID

// Option 3: Emit full URI in event (cheaper than storage, still indexable)
event ResultPosted(
    bytes32 indexed marketId,
    int256 result,
    uint64 observedAt,
    bytes32 dataSourceHash,
    string dataSourceUri, // Include in event for discoverability
    address indexed submittedBy
);
At minimum, update the interface to emit the full URI in events so it's permanently recorded on-chain and discoverable without a backend.
2

IPriceOracle.sol
Timestamp Dependence in Oracle Freshness Checks Enables Miner Manipulation
Both IPriceOracle (maxAgeSeconds freshness check) and IEventOracle (observedAt timestamp) rely on block.timestamp for time-based validation. While the Ethereum PoS merge has reduced miner timestamp manipulation risk, validators can still manipulate block.timestamp within a ~12-second window. For tight freshness windows (e.g., maxAgeSeconds = 60 seconds), a validator could manipulate the timestamp to make a stale price appear fresh or to prevent a fresh price from being accepted. The observedAt field in IEventOracle is an off-chain timestamp that could be set to any value by the trusted reporter, creating additional timestamp manipulation risk.


Hide Details
Impact
1. A validator could manipulate block.timestamp to make a stale Chainlink price appear fresh, allowing settlement with outdated price data. 2. The observedAt field in IEventOracle is an off-chain timestamp with no on-chain validation - a malicious reporter could set it to any value. 3. For markets with tight settlement windows, timestamp manipulation could prevent legitimate settlements or enable illegitimate ones. 4. The combination of caller-supplied nowTs and block.timestamp creates multiple attack surfaces for timestamp manipulation.
Scenario
1. Chainlink price was last updated at T=1000 (100 seconds ago).
2. maxAgeSeconds = 120 seconds.
3. Current block.timestamp = T=1100 (price age = 100 seconds, within window).
4. Validator manipulates block.timestamp to T=1130 (price age = 130 seconds, outside window).
5. Freshness check fails: 1130 - 1000 = 130 > 120.
6. Market settlement is blocked, causing DoS for the settlement transaction.
7. Alternatively, validator sets timestamp to T=1080 to make a price from T=960 appear fresh.
Affected code
/// @param maxAgeSeconds Maximum allowed age of oracle publish time.
/// @param nowTs Caller-supplied time reference (primarily for mocks/tests).
function getNormalizedPrice(bytes32 feedId, uint64 maxAgeSeconds, uint64 nowTs)
external
view
returns (int256 priceE8, uint64 publishTime, uint256 confidenceE8);

/// @notice Wall-clock style observation time committed in the signed resolve payload.
function getResolveObservedAt(bytes32 marketId) external view returns (uint64);
Proposed fix
Use conservative freshness windows that are significantly larger than the validator timestamp manipulation window (~12 seconds):
// Minimum recommended maxAgeSeconds for production
uint64 constant MIN_MAX_AGE_SECONDS = 300; // 5 minutes minimum

// In MarketEngine:
function _validateMaxAge(uint64 maxAgeSeconds) internal pure {
    require(maxAgeSeconds >= MIN_MAX_AGE_SECONDS, "Freshness window too tight");
}

// For observedAt in IEventOracle, validate it's within a reasonable range:
function postResult(
    bytes32 marketId,
    int256 result,
    uint64 observedAt,
    ...
) external {
    // Validate observedAt is not in the future and not too old
    require(observedAt <= block.timestamp + 60, "observedAt too far in future");
    require(block.timestamp - observedAt <= MAX_OBSERVATION_AGE, "observedAt too old");
    // ...
}
For critical settlement timestamps, consider using block numbers as an additional reference point alongside timestamps.
3

IYieldRouterV2.sol
Missing Interface Version Identifier Prevents Safe Upgrades and Integration
Neither IYieldRouter nor IYieldRouterV2 (nor the oracle interfaces) include a version identifier or ERC-165 supportsInterface() mechanism. The MarketEngine cannot programmatically determine which version of the yield router it's interacting with. This creates risks during upgrades: if the router is upgraded from V1 to V2, the engine cannot detect the change and may continue calling V1 functions (withdraw instead of withdrawScaled), leading to incorrect accounting. Additionally, without ERC-165 support, the engine cannot safely check whether IPriceOracleWithRoundId is supported before calling getNormalizedPriceWithRoundId.


Hide Details
Impact
1. MarketEngine cannot safely detect router version, leading to potential use of wrong withdrawal path. 2. Without ERC-165, the engine must use try/catch for IPriceOracleWithRoundId detection, which is gas-inefficient and error-prone. 3. During protocol upgrades, the engine may interact with a V2 router using V1 semantics, causing accounting errors. 4. Third-party integrators cannot programmatically determine interface compatibility.
Scenario
// MarketEngine trying to detect V2 router without version identifier
contract MarketEngine {
    IYieldRouter router;
    
    function deposit(bytes32 templateId, uint256 amount) external {
        // No way to know if router is V1 or V2
        // Must use try/catch which is gas-inefficient
        try IYieldRouterV2(address(router)).depositScaled(templateId, amount) 
            returns (uint256 units) {
            // V2 path
        } catch {
            // V1 path - but this could mask real errors!
            router.deposit(templateId, amount);
        }
    }
}
Affected code
interface IYieldRouter {
function deposit(bytes32 templateId, uint256 amount) external;
function withdraw(bytes32 templateId, uint256 principalAmount) external returns (uint256 grossAmount);
function balanceOf(bytes32 templateId) external view returns (uint256);
function emergencyWithdraw(bytes32 templateId) external returns (uint256 grossAmount);
}

interface IYieldRouterV2 is IYieldRouter {
// No version() or supportsInterface() function
function depositScaled(bytes32 templateId, uint256 amount) external returns (uint256 attributionUnits);
// ...
}
Proposed fix
Add ERC-165 support and version identifiers to all interfaces:
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IYieldRouter is IERC165 {
    // bytes4(keccak256('deposit(bytes32,uint256)')) ^ ... = 0xXXXXXXXX
    bytes4 constant INTERFACE_ID = 0xXXXXXXXX;
    
    function version() external pure returns (uint256);
    // ... existing functions
}

interface IYieldRouterV2 is IYieldRouter {
    bytes4 constant INTERFACE_ID_V2 = 0xYYYYYYYY;
    // ... V2 functions
}

// In MarketEngine:
function _isV2Router(address routerAddr) internal view returns (bool) {
    return IERC165(routerAddr).supportsInterface(IYieldRouterV2.INTERFACE_ID_V2);
}

function deposit(bytes32 templateId, uint256 amount) external {
    if (_isV2Router(address(router))) {
        IYieldRouterV2(address(router)).depositScaled(templateId, amount);
    } else {
        router.deposit(templateId, amount);
    }
}
4

IYieldRouterV2.sol
IYieldRouterV2 globalScaledBalance Invariant Not Enforced by Interface
IYieldRouterV2 exposes globalScaledBalance() which should equal the sum of all per-template scaledPrincipalOf() values. However, the interface provides no mechanism to enforce this invariant. If the implementation has a bug where individual template accounting diverges from the global balance (e.g., due to rounding errors, failed transactions, or direct Aave interactions), the invariant could be violated. This could lead to situations where the sum of all template withdrawals exceeds the actual global balance, causing the last withdrawers to receive less than expected or for withdrawals to fail entirely.


Hide Details
Impact
1. If globalScaledBalance < sum(scaledPrincipalOf), the last templates to withdraw will receive less than expected or withdrawals will fail. 2. If globalScaledBalance > sum(scaledPrincipalOf), there are unaccounted funds in the router that could be extracted by an attacker. 3. Rounding errors in scaled accounting accumulate over time, gradually diverging the invariant. 4. Direct Aave interactions (e.g., someone sending aTokens directly to the router) could inflate globalScaledBalance without updating per-template accounting.
Scenario
// Invariant violation scenario:
// 1. Template T1 deposits 1000 USDC, scaledPrincipal = 950 (scaled units)
// 2. Template T2 deposits 1000 USDC, scaledPrincipal = 950 (scaled units)
// 3. globalScaledBalance = 1900
// 4. Someone sends 100 aUSDC directly to router (donation attack)
// 5. globalScaledBalance = 2000 (updated by Aave balance)
// 6. But sum(scaledPrincipalOf) = 1900 (not updated)
// 7. 100 scaled units are unaccounted - could be extracted

// Or rounding error accumulation:
// 1000 deposits of 1 wei each, each rounded down by 1 unit
// sum(scaledPrincipalOf) = 1000 * (scaledUnit - 1) = globalScaledBalance - 1000
// Last withdrawer gets 1000 units less than expected
Affected code
function globalScaledBalance() external view returns (uint256);
function principalOf(bytes32 templateId) external view returns (uint256);
function scaledPrincipalOf(bytes32 templateId) external view returns (uint256);
function stataSharesOf(bytes32 templateId) external view returns (uint256);

// Invariant that should hold but is not enforced:
// sum(scaledPrincipalOf(templateId) for all templateIds) == globalScaledBalance()
Proposed fix
Add invariant checks and implement a reconciliation mechanism:
contract YieldRouterV2Impl is IYieldRouterV2 {
    bytes32[] public allTemplateIds;
    
    // Invariant check function
    function checkInvariant() public view returns (bool) {
        uint256 sumScaled = 0;
        for (uint256 i = 0; i < allTemplateIds.length; i++) {
            sumScaled += scaledPrincipalOf(allTemplateIds[i]);
        }
        return sumScaled <= globalScaledBalance(); // Allow for yield accumulation
    }
    
    // Reconciliation: distribute excess to a treasury
    function reconcile() external onlyOwner {
        uint256 sumScaled = _sumAllScaledPrincipals();
        uint256 global = globalScaledBalance();
        if (global > sumScaled) {
            uint256 excess = global - sumScaled;
            // Transfer excess to treasury
            _transferScaledToTreasury(excess);
        }
    }
    
    // Add assertion in withdrawScaled
    function withdrawScaled(bytes32 templateId, uint256 principalAmount)
        external returns (uint256 grossAmount) {
        // ... withdrawal logic ...
        
        // Post-condition check
        assert(scaledPrincipalOf(templateId) <= globalScaledBalance());
    }
}