// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployProduction} from "../../script/production/DeployProduction.s.sol";
import {DeployTestnet} from "../../script/test/DeployTestnet.s.sol";
import {UpgradeProduction} from "../../script/production/UpgradeProduction.s.sol";
import {UpgradeTestnet} from "../../script/test/UpgradeTestnet.s.sol";

contract DeploymentScriptGuardsTest is Test {
    function test_deployProduction_revertsOnWrongChain() external {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid + 1));

        DeployProduction script = new DeployProduction();
        vm.expectRevert("wrong chain");
        script.run();
    }

    function test_deployTestnet_revertsOnWrongChain() external {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid + 1));

        DeployTestnet script = new DeployTestnet();
        vm.expectRevert("wrong chain");
        script.run();
    }

    function test_deployTestnet_faucetForbiddenOnMainnet() external {
        vm.chainId(1);
        vm.setEnv("EXPECTED_CHAIN_ID", "1");
        vm.setEnv("MAINNET_CHAIN_ID", "1");
        vm.setEnv("DEPLOY_FAUCET", "1");
        vm.setEnv("SEQUENCER_FEED", "0x0000000000000000000000000000000000000000");
        vm.setEnv("ADMIN", "0x0000000000000000000000000000000000000001");
        vm.setEnv("TREASURY", "0x0000000000000000000000000000000000000002");
        vm.setEnv("WORKER", "0x0000000000000000000000000000000000000003");
        vm.setEnv("DEFAULT_SETTLEMENT_FEE_BPS", "100");
        vm.setEnv("MAX_SWITCH_FEE_BPS", "200");
        vm.setEnv("MAX_OUTCOMES", "8");
        vm.setEnv("ORACLE_MAX_DELAY_SECONDS", "3600");
        vm.setEnv("ORACLE_MAX_CONFIDENCE_BPS", "0");

        DeployTestnet script = new DeployTestnet();
        vm.expectRevert("faucet forbidden on mainnet");
        script.run();
    }

    function test_upgradeProduction_revertsOnWrongChain() external {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid + 1));

        UpgradeProduction script = new UpgradeProduction();
        vm.expectRevert("wrong chain");
        script.run();
    }

    function test_upgradeTestnet_revertsOnWrongChain() external {
        vm.setEnv("EXPECTED_CHAIN_ID", vm.toString(block.chainid + 1));

        UpgradeTestnet script = new UpgradeTestnet();
        vm.expectRevert("wrong chain");
        script.run();
    }
}
