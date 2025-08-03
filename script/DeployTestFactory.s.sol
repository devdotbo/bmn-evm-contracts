// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";

/**
 * @title DeployTestFactory
 * @notice Script to deploy TestEscrowFactory on mainnet for testing purposes
 * @dev WARNING: TestEscrowFactory bypasses security checks - use only for testing
 */
contract DeployTestFactory is Script {
    // Mainnet Chain IDs
    uint256 constant BASE_MAINNET_CHAIN_ID = 8453;
    uint256 constant ETHERLINK_MAINNET_CHAIN_ID = 42793;

    function run() external {
        uint256 chainId = block.chainid;
        
        console.log("========================================");
        console.log("Deploying TestEscrowFactory on chain", chainId);
        console.log("========================================");
        console.log("");
        
        // Load existing deployment data
        string memory deploymentFile;
        if (chainId == BASE_MAINNET_CHAIN_ID) {
            deploymentFile = "deployments/baseMainnet.json";
        } else if (chainId == ETHERLINK_MAINNET_CHAIN_ID) {
            deploymentFile = "deployments/etherlinkMainnet.json";
        } else {
            revert("Unsupported chain ID");
        }
        
        string memory deploymentJson = vm.readFile(deploymentFile);
        
        // Parse required addresses
        address limitOrderProtocol = vm.parseJsonAddress(deploymentJson, ".contracts.limitOrderProtocol");
        address feeToken = vm.parseJsonAddress(deploymentJson, ".contracts.feeToken");
        address accessToken = vm.parseJsonAddress(deploymentJson, ".contracts.accessToken");
        address deployer = vm.parseJsonAddress(deploymentJson, ".accounts.deployer");
        
        console.log("Using existing deployment:");
        console.log("  LimitOrderProtocol:", limitOrderProtocol);
        console.log("  FeeToken:", feeToken);
        console.log("  AccessToken:", accessToken);
        console.log("  Deployer:", deployer);
        console.log("");
        
        // Get deployer private key
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerKey);
        require(deployerAddress == deployer, "Deployer address mismatch");
        
        vm.startBroadcast(deployerKey);
        
        // Deploy TestEscrowFactory
        TestEscrowFactory testFactory = new TestEscrowFactory(
            limitOrderProtocol,
            IERC20(feeToken),
            IERC20(accessToken),
            deployer, // owner
            604800,   // 7 days rescue delay for source
            604800    // 7 days rescue delay for destination
        );
        
        console.log("TestEscrowFactory deployed at:", address(testFactory));
        
        // Update deployment file with test factory
        string memory updatedJson = string.concat(
            '{\n',
            '  "chainId": ', vm.toString(chainId), ',\n',
            '  "contracts": {\n',
            '    "factory": "', vm.toString(address(testFactory)), '",\n',
            '    "limitOrderProtocol": "', vm.toString(limitOrderProtocol), '",\n',
            '    "tokenA": "', vm.toString(vm.parseJsonAddress(deploymentJson, ".contracts.tokenA")), '",\n',
            '    "tokenB": "', vm.toString(vm.parseJsonAddress(deploymentJson, ".contracts.tokenB")), '",\n',
            '    "accessToken": "', vm.toString(accessToken), '",\n',
            '    "feeToken": "', vm.toString(feeToken), '",\n',
            '    "originalFactory": "', vm.toString(vm.parseJsonAddress(deploymentJson, ".contracts.factory")), '"\n',
            '  },\n',
            '  "accounts": {\n',
            '    "deployer": "', vm.toString(deployer), '",\n',
            '    "alice": "', vm.toString(vm.parseJsonAddress(deploymentJson, ".accounts.alice")), '",\n',
            '    "bob": "', vm.toString(vm.parseJsonAddress(deploymentJson, ".accounts.bob")), '"\n',
            '  }\n',
            '}'
        );
        
        // Save updated deployment
        string memory testDeploymentFile;
        if (chainId == BASE_MAINNET_CHAIN_ID) {
            testDeploymentFile = "deployments/baseMainnetTest.json";
        } else {
            testDeploymentFile = "deployments/etherlinkMainnetTest.json";
        }
        
        vm.writeFile(testDeploymentFile, updatedJson);
        console.log("\nTest deployment data saved to:", testDeploymentFile);
        console.log("\nWARNING: TestEscrowFactory bypasses security checks!");
        console.log("DO NOT use this factory in production!");
        
        vm.stopBroadcast();
    }
}