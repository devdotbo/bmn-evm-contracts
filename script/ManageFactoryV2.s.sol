// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";

/**
 * @title ManageFactoryV2
 * @notice Post-deployment management script for CrossChainEscrowFactory v2.1.0
 * @dev Provides utilities for managing resolvers, pausing, and other admin functions
 */
contract ManageFactoryV2 is Script {
    
    function run() external {
        // Get factory address from environment
        address factoryAddress = vm.envAddress("FACTORY_V2_ADDRESS");
        
        // Get action from environment
        string memory action = vm.envString("ACTION");
        
        console.log("==============================================");
        console.log("Managing CrossChainEscrowFactory v2.1.0");
        console.log("==============================================");
        console.log("Factory Address:", factoryAddress);
        console.log("Action:", action);
        console.log("Chain ID:", block.chainid);
        
        CrossChainEscrowFactory factory = CrossChainEscrowFactory(factoryAddress);
        
        // Get deployer (owner) credentials
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Verify ownership
        require(factory.owner() == deployer, "Not the factory owner");
        
        // Execute action
        if (keccak256(bytes(action)) == keccak256(bytes("add-resolver"))) {
            addResolver(factory, deployerPrivateKey);
        } else if (keccak256(bytes(action)) == keccak256(bytes("remove-resolver"))) {
            removeResolver(factory, deployerPrivateKey);
        } else if (keccak256(bytes(action)) == keccak256(bytes("pause"))) {
            pauseFactory(factory, deployerPrivateKey);
        } else if (keccak256(bytes(action)) == keccak256(bytes("unpause"))) {
            unpauseFactory(factory, deployerPrivateKey);
        } else if (keccak256(bytes(action)) == keccak256(bytes("transfer-ownership"))) {
            transferOwnership(factory, deployerPrivateKey);
        } else if (keccak256(bytes(action)) == keccak256(bytes("list-resolvers"))) {
            listResolvers(factory);
        } else if (keccak256(bytes(action)) == keccak256(bytes("status"))) {
            showStatus(factory);
        } else {
            revert("Unknown action. Valid actions: add-resolver, remove-resolver, pause, unpause, transfer-ownership, list-resolvers, status");
        }
    }
    
    function addResolver(CrossChainEscrowFactory factory, uint256 ownerKey) internal {
        address resolver = vm.envAddress("RESOLVER_ADDRESS");
        console.log("\n[ADD RESOLVER]");
        console.log("Adding resolver:", resolver);
        
        vm.startBroadcast(ownerKey);
        
        // Check if already whitelisted
        if (factory.whitelistedResolvers(resolver)) {
            console.log("[WARNING] Resolver already whitelisted");
        } else {
            factory.addResolverToWhitelist(resolver);
            console.log("[OK] Resolver added to whitelist");
        }
        
        vm.stopBroadcast();
        
        // Verify
        require(factory.whitelistedResolvers(resolver), "Failed to add resolver");
        console.log("[VERIFIED] Resolver is now whitelisted");
        console.log("Total resolvers:", factory.resolverCount());
    }
    
    function removeResolver(CrossChainEscrowFactory factory, uint256 ownerKey) internal {
        address resolver = vm.envAddress("RESOLVER_ADDRESS");
        console.log("\n[REMOVE RESOLVER]");
        console.log("Removing resolver:", resolver);
        
        vm.startBroadcast(ownerKey);
        
        // Check if whitelisted
        if (!factory.whitelistedResolvers(resolver)) {
            console.log("[WARNING] Resolver not whitelisted");
        } else {
            factory.removeResolverFromWhitelist(resolver);
            console.log("[OK] Resolver removed from whitelist");
        }
        
        vm.stopBroadcast();
        
        // Verify
        require(!factory.whitelistedResolvers(resolver), "Failed to remove resolver");
        console.log("[VERIFIED] Resolver is no longer whitelisted");
        console.log("Total resolvers:", factory.resolverCount());
    }
    
    function pauseFactory(CrossChainEscrowFactory factory, uint256 ownerKey) internal {
        console.log("\n[PAUSE FACTORY]");
        
        if (factory.emergencyPaused()) {
            console.log("[WARNING] Factory already paused");
            return;
        }
        
        vm.startBroadcast(ownerKey);
        factory.pause();
        vm.stopBroadcast();
        
        require(factory.emergencyPaused(), "Failed to pause");
        console.log("[OK] Factory is now PAUSED");
        console.log("[CRITICAL] No new escrows can be created");
    }
    
    function unpauseFactory(CrossChainEscrowFactory factory, uint256 ownerKey) internal {
        console.log("\n[UNPAUSE FACTORY]");
        
        if (!factory.emergencyPaused()) {
            console.log("[WARNING] Factory not paused");
            return;
        }
        
        vm.startBroadcast(ownerKey);
        factory.unpause();
        vm.stopBroadcast();
        
        require(!factory.emergencyPaused(), "Failed to unpause");
        console.log("[OK] Factory is now ACTIVE");
        console.log("Protocol operations resumed");
    }
    
    function transferOwnership(CrossChainEscrowFactory factory, uint256 ownerKey) internal {
        address newOwner = vm.envAddress("NEW_OWNER");
        console.log("\n[TRANSFER OWNERSHIP]");
        console.log("Current owner:", factory.owner());
        console.log("New owner:", newOwner);
        
        console.log("\n[WARNING] This action is IRREVERSIBLE");
        console.log("Make sure the new owner address is correct!");
        
        vm.startBroadcast(ownerKey);
        factory.transferFactoryOwnership(newOwner);
        vm.stopBroadcast();
        
        console.log("[OK] Ownership transfer initiated");
        console.log("New owner must accept ownership to complete transfer");
    }
    
    function listResolvers(CrossChainEscrowFactory factory) internal view {
        console.log("\n[RESOLVER LIST]");
        console.log("Total whitelisted resolvers:", factory.resolverCount());
        
        // Check known resolvers
        console.log("\nKnown Resolvers:");
        
        // Check initial resolver
        bool isBobWhitelisted = factory.whitelistedResolvers(Constants.BOB_RESOLVER);
        console.log("- Bob (Initial):", Constants.BOB_RESOLVER);
        console.log("  Status:", isBobWhitelisted ? "WHITELISTED" : "NOT WHITELISTED");
        
        // Check owner
        bool isOwnerWhitelisted = factory.whitelistedResolvers(factory.owner());
        console.log("- Owner:", factory.owner());
        console.log("  Status:", isOwnerWhitelisted ? "WHITELISTED" : "NOT WHITELISTED");
    }
    
    function showStatus(CrossChainEscrowFactory factory) internal view {
        console.log("\n[FACTORY STATUS]");
        console.log("==============================================");
        console.log("Version:", factory.VERSION());
        console.log("Owner:", factory.owner());
        console.log("Emergency Paused:", factory.emergencyPaused() ? "YES [CRITICAL]" : "NO");
        console.log("Resolver Count:", factory.resolverCount());
        
        // Get metrics
        (uint256 totalVolume, uint256 successfulSwaps, uint256 failedSwaps, uint256 avgCompletionTime) = factory.globalMetrics();
        
        console.log("\n[METRICS]");
        console.log("Total Volume:", totalVolume);
        console.log("Successful Swaps:", successfulSwaps);
        console.log("Failed Swaps:", failedSwaps);
        console.log("Avg Completion Time:", avgCompletionTime, "seconds");
        
        if (successfulSwaps + failedSwaps > 0) {
            uint256 successRate = (successfulSwaps * 100) / (successfulSwaps + failedSwaps);
            console.log("Success Rate:", successRate, "%");
        }
        
        console.log("==============================================");
    }
}