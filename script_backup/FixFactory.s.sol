// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";

contract FixFactory is Script {
    function run() external {
        // Factory addresses
        address baseFactory = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
        address optimismFactory = 0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56;
        
        // Resolver address
        address resolver = 0xc18c3C96E20FaD1c656a5c4ed2F4f7871BD42be1;
        
        // Get deployer private key (owner)
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        console.log("\n========== FIXING FACTORY ON BASE ==========");
        
        // Start broadcasting transactions as owner
        vm.createSelectFork("https://base.llamarpc.com");
        vm.startBroadcast(deployerPrivateKey);
        
        SimplifiedEscrowFactory factory = SimplifiedEscrowFactory(baseFactory);
        
        // Check current state
        console.log("Factory owner: %s", factory.owner());
        console.log("Resolver currently whitelisted: %s", factory.whitelistedResolvers(resolver));
        
        // Add resolver to whitelist
        if (!factory.whitelistedResolvers(resolver)) {
            console.log("Adding resolver to whitelist...");
            factory.addResolver(resolver);
            console.log("Resolver added successfully!");
        } else {
            console.log("Resolver already whitelisted");
        }
        
        // Verify
        console.log("Resolver now whitelisted: %s", factory.whitelistedResolvers(resolver));
        console.log("Resolver count: %s", factory.resolverCount());
        
        vm.stopBroadcast();
        
        console.log("\n========== FIXING FACTORY ON OPTIMISM ==========");
        
        // Switch to Optimism
        vm.createSelectFork("https://mainnet.optimism.io");
        vm.startBroadcast(deployerPrivateKey);
        
        factory = SimplifiedEscrowFactory(optimismFactory);
        
        // Check current state
        console.log("Factory owner: %s", factory.owner());
        console.log("Resolver currently whitelisted: %s", factory.whitelistedResolvers(resolver));
        
        // Add resolver to whitelist
        if (!factory.whitelistedResolvers(resolver)) {
            console.log("Adding resolver to whitelist...");
            factory.addResolver(resolver);
            console.log("Resolver added successfully!");
        } else {
            console.log("Resolver already whitelisted");
        }
        
        // Verify
        console.log("Resolver now whitelisted: %s", factory.whitelistedResolvers(resolver));
        console.log("Resolver count: %s", factory.resolverCount());
        
        vm.stopBroadcast();
        
        console.log("\n========== FACTORY FIXED! ==========");
        console.log("Resolver %s is now whitelisted on both chains", resolver);
        console.log("Ready to execute atomic swaps!");
    }
}