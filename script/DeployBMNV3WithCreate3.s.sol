// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV3 } from "../contracts/BMNAccessTokenV3.sol";
import { CREATE3Factory } from "zeframlou-create3-factory/CREATE3Factory.sol";

/**
 * @title DeployBMNV3WithCreate3
 * @notice Deploy BMN Access Token V3 using CREATE3 for deterministic cross-chain addresses
 * @dev Deploys both the CREATE3 factory (if needed) and the BMN token
 */
contract DeployBMNV3WithCreate3 is Script {
    // CREATE3 Factory address (if already deployed)
    // ZeframLou's factory is deployed at: 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf on many chains
    address constant EXISTING_CREATE3_FACTORY = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
    
    // Salt for deterministic deployment
    bytes32 constant BMN_SALT = keccak256("BMN_ACCESS_TOKEN_V3_MAINNET_2025");
    
    // Expected addresses (will be calculated)
    address public expectedFactoryAddress;
    address public expectedTokenAddress;
    
    function run() external {
        // Get deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== BMN V3 CREATE3 Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check if CREATE3 factory exists
        CREATE3Factory factory;
        uint256 factoryCodeSize;
        assembly {
            factoryCodeSize := extcodesize(EXISTING_CREATE3_FACTORY)
        }
        
        if (factoryCodeSize > 0) {
            console.log("Using existing CREATE3 factory at:", EXISTING_CREATE3_FACTORY);
            factory = CREATE3Factory(EXISTING_CREATE3_FACTORY);
        } else {
            console.log("Deploying new CREATE3 factory...");
            factory = new CREATE3Factory();
            console.log("CREATE3 factory deployed at:", address(factory));
        }
        
        // Calculate expected token address
        expectedTokenAddress = factory.getDeployed(deployer, BMN_SALT);
        console.log("Expected BMN V3 address:", expectedTokenAddress);
        console.log("");
        
        // Check if token already deployed
        uint256 tokenCodeSize;
        assembly {
            tokenCodeSize := extcodesize(expectedTokenAddress)
        }
        
        if (tokenCodeSize > 0) {
            console.log("BMN V3 already deployed at expected address");
            BMNAccessTokenV3 existingToken = BMNAccessTokenV3(expectedTokenAddress);
            console.log("Name:", existingToken.name());
            console.log("Symbol:", existingToken.symbol());
            console.log("Owner:", existingToken.owner());
            console.log("Total Supply:", existingToken.totalSupply() / 10**18, "BMN");
        } else {
            // Deploy BMN V3 token
            console.log("Deploying BMN V3 token...");
            
            bytes memory tokenBytecode = abi.encodePacked(
                type(BMNAccessTokenV3).creationCode,
                abi.encode(deployer) // constructor argument: owner
            );
            
            address deployedToken = factory.deploy(BMN_SALT, tokenBytecode);
            
            require(deployedToken == expectedTokenAddress, "Deployed address mismatch!");
            
            console.log("BMN V3 deployed at:", deployedToken);
            console.log("");
            
            // Initialize the token
            BMNAccessTokenV3 token = BMNAccessTokenV3(deployedToken);
            
            // Mint initial supply of 10 million tokens
            console.log("Minting initial supply...");
            token.mintInitialSupply();
            
            console.log("Initial supply minted: 10,000,000 BMN");
            console.log("Token owner:", token.owner());
            console.log("Owner balance:", token.balanceOf(deployer) / 10**18, "BMN");
        }
        
        vm.stopBroadcast();
        
        // Save deployment info
        saveDeploymentInfo(address(factory), expectedTokenAddress);
        
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Factory address:", address(factory));
        console.log("Token address:", expectedTokenAddress);
        console.log("");
        console.log("Next steps:");
        console.log("1. Verify the contract on block explorer");
        console.log("2. Deploy on other chains with same salt for same address");
        console.log("3. Update protocol configuration with new token address");
    }
    
    function saveDeploymentInfo(address factory, address token) internal {
        string memory chainName = getChainName();
        string memory deploymentPath = string(abi.encodePacked(
            "./deployments/",
            chainName,
            "-bmn-v3-create3.json"
        ));
        
        string memory json = "deployment";
        vm.serializeAddress(json, "factory", factory);
        vm.serializeAddress(json, "token", token);
        vm.serializeBytes32(json, "salt", BMN_SALT);
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeUint(json, "timestamp", block.timestamp);
        string memory output = vm.serializeAddress(json, "deployer", vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY")));
        
        vm.writeJson(output, deploymentPath);
        console.log("Deployment info saved to:", deploymentPath);
    }
    
    function getChainName() internal view returns (string memory) {
        if (block.chainid == 1) return "mainnet";
        if (block.chainid == 8453) return "base";
        if (block.chainid == 42793) return "etherlink";
        if (block.chainid == 84532) return "base-sepolia";
        if (block.chainid == 128123) return "etherlink-testnet";
        if (block.chainid == 31337) return "local";
        return "unknown";
    }
}