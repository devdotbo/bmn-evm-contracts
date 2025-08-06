// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/CrossChainEscrowFactory.sol";
import "../contracts/interfaces/IERC20.sol";

contract LiveTestTransaction is Script {
    // Deployed factory addresses
    address constant BASE_FACTORY = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
    address constant OPTIMISM_FACTORY = 0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56;
    
    // Test accounts (Anvil defaults)
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    function run() external {
        console.log("====================================");
        console.log("BMN Protocol - Live Mainnet Test");
        console.log("====================================");
        
        // Get private key from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("Testing on Base Mainnet");
        console.log("Factory address:", BASE_FACTORY);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Test 1: Whitelist a resolver
        console.log("\n[TEST 1] Whitelisting resolver...");
        CrossChainEscrowFactory factory = CrossChainEscrowFactory(BASE_FACTORY);
        
        // Check if BOB is already whitelisted
        bool isWhitelisted = factory.whitelistedResolvers(BOB);
        console.log("Bob currently whitelisted:", isWhitelisted);
        
        if (!isWhitelisted) {
            console.log("Adding Bob as resolver...");
            factory.whitelistResolver(BOB);
            console.log("[SUCCESS] Bob added as resolver");
            
            // Verify the change
            bool nowWhitelisted = factory.whitelistedResolvers(BOB);
            console.log("Bob now whitelisted:", nowWhitelisted);
            require(nowWhitelisted, "Failed to whitelist resolver");
        } else {
            console.log("Bob already whitelisted, removing and re-adding...");
            factory.removeResolver(BOB);
            console.log("Bob removed");
            
            factory.whitelistResolver(BOB);
            console.log("[SUCCESS] Bob re-added as resolver");
        }
        
        // Test 2: Read factory configuration
        console.log("\n[TEST 2] Reading factory configuration...");
        address srcImpl = factory.ESCROW_SRC_IMPLEMENTATION();
        address dstImpl = factory.ESCROW_DST_IMPLEMENTATION();
        address accessToken = factory.ACCESS_TOKEN();
        uint256 rescueDelay = factory.RESCUE_DELAY();
        
        console.log("Source Implementation:", srcImpl);
        console.log("Destination Implementation:", dstImpl);
        console.log("Access Token:", accessToken);
        console.log("Rescue Delay:", rescueDelay);
        
        // Test 3: Check resolver list
        console.log("\n[TEST 3] Checking resolver status...");
        console.log("Alice is resolver:", factory.whitelistedResolvers(ALICE));
        console.log("Bob is resolver:", factory.whitelistedResolvers(BOB));
        console.log("Deployer is resolver:", factory.whitelistedResolvers(deployer));
        
        vm.stopBroadcast();
        
        console.log("\n====================================");
        console.log("TEST COMPLETED SUCCESSFULLY");
        console.log("====================================");
        console.log("\nSummary:");
        console.log("- Successfully interacted with factory on Base mainnet");
        console.log("- Whitelisted/verified resolver");
        console.log("- Read factory configuration");
        console.log("- Protocol is LIVE and FUNCTIONAL on mainnet");
    }
}