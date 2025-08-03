// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CrossChainResolver } from "../contracts/CrossChainResolver.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";

/**
 * @title DeployResolver
 * @notice Deploy the 1inch-style CrossChainResolver on mainnet
 */
contract DeployResolver is Script {
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("Deploying CrossChainResolver...");
        console.log("Deployer:", deployer);
        
        // Get factory address based on chain
        address factory;
        string memory chainName;
        
        uint256 chainId = block.chainid;
        if (chainId == 8453) {
            // Base mainnet
            factory = 0xEa27F5F45076323b7D7070Bf3Edc908403e7D4e5; // From baseMainnet.json
            chainName = "Base";
        } else if (chainId == 42793) {
            // Etherlink mainnet
            factory = 0x6b3E1410513DcC0874E367CbD79Ee3448D6478C9; // From etherlinkMainnet.json  
            chainName = "Etherlink";
        } else {
            revert("Unsupported chain");
        }
        
        console.log("Chain:", chainName);
        console.log("Factory:", factory);
        
        vm.startBroadcast(deployerKey);
        
        // Deploy resolver
        CrossChainResolver resolver = new CrossChainResolver(IEscrowFactory(factory));
        address resolverAddress = address(resolver);
        
        console.log("CrossChainResolver deployed at:", resolverAddress);
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory json = "deployment";
        vm.serializeAddress(json, "resolver", resolverAddress);
        vm.serializeAddress(json, "factory", factory);
        vm.serializeUint(json, "chainId", chainId);
        vm.serializeString(json, "chainName", chainName);
        vm.serializeAddress(json, "deployer", deployer);
        string memory output = vm.serializeUint(json, "timestamp", block.timestamp);
        
        string memory filename = string.concat("deployments/resolver-", chainName, ".json");
        vm.writeJson(output, filename);
        
        console.log("\n=== Deployment Complete ===");
        console.log("Resolver:", resolverAddress);
        console.log("Saved to:", filename);
        console.log("\nNext steps:");
        console.log("1. Deploy on the other chain");
        console.log("2. Configure resolver permissions");
        console.log("3. Test with initiateSwap()");
    }
}