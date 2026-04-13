// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IYieldRouterV2} from "../interfaces/IYieldRouterV2.sol";
import {IMarketEngine} from "../engine/IMarketEngine.sol";

/// @dev Malicious yield router: on `depositScaled` / `withdrawScaled`, optionally reenters the engine via
/// `depositToSideFor` (requires `isDepositExecutor[address(this)]`). For security tests only.
contract MockYieldRouterReentrant is IYieldRouterV2 {
    address public immutable ENGINE;

    bool public reenterOnDepositScaled;
    bool public reenterOnWithdrawScaled;

    address public reenterBeneficiary;
    bytes32 public reenterTemplateId;
    uint64 public reenterEpochId;
    uint8 public reenterOutcome;
    uint256 public reenterAmount;

    error OnlyEngine();

    constructor(address engine_) {
        ENGINE = engine_;
    }

    function setReenterDeposit(bool on) external {
        reenterOnDepositScaled = on;
    }

    function setReenterWithdraw(bool on) external {
        reenterOnWithdrawScaled = on;
    }

    function setReenterDepositForParams(address beneficiary, bytes32 tid, uint64 eid, uint8 outcome, uint256 amt)
        external
    {
        reenterBeneficiary = beneficiary;
        reenterTemplateId = tid;
        reenterEpochId = eid;
        reenterOutcome = outcome;
        reenterAmount = amt;
    }

    modifier onlyEngine() {
        if (msg.sender != ENGINE) revert OnlyEngine();
        _;
    }

    function deposit(bytes32, uint256) external pure override {
        revert();
    }

    function withdraw(bytes32, uint256) external pure override returns (uint256) {
        revert();
    }

    function balanceOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function emergencyWithdraw(bytes32) external pure override returns (uint256) {
        revert();
    }

    function depositScaled(bytes32 templateId, uint256) external override onlyEngine returns (uint256) {
        if (reenterOnDepositScaled) {
            reenterOnDepositScaled = false;
            IMarketEngine(ENGINE).depositToSideFor(
                reenterBeneficiary, templateId, reenterEpochId, reenterOutcome, reenterAmount
            );
        }
        return 0;
    }

    function withdrawScaled(bytes32 templateId, uint256) external override onlyEngine returns (uint256) {
        if (reenterOnWithdrawScaled) {
            reenterOnWithdrawScaled = false;
            IMarketEngine(ENGINE).depositToSideFor(
                reenterBeneficiary, templateId, reenterEpochId, reenterOutcome, reenterAmount
            );
        }
        return 0;
    }

    function currentValueOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function claimLmRewards(bytes32)
        external
        pure
        override
        returns (address[] memory rewardsList, uint256[] memory amounts)
    {
        return (new address[](0), new uint256[](0));
    }

    function pendingLmRewards(bytes32)
        external
        pure
        override
        returns (address[] memory tokens, uint256[] memory pending)
    {
        return (new address[](0), new uint256[](0));
    }

    function setTemplateYieldPath(bytes32, IYieldRouterV2.YieldPath) external pure override {}

    function getTemplateYieldPath(bytes32) external pure override returns (IYieldRouterV2.YieldPath) {
        return IYieldRouterV2.YieldPath.AToken;
    }

    function globalScaledBalance() external pure override returns (uint256) {
        return 0;
    }

    function principalOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function scaledPrincipalOf(bytes32) external pure override returns (uint256) {
        return 0;
    }

    function stataSharesOf(bytes32) external pure override returns (uint256) {
        return 0;
    }
}
