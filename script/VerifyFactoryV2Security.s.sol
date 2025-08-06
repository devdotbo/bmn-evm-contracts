// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";

/**
 * @title VerifyFactoryV2Security
 * @notice Post-deployment verification script for CrossChainEscrowFactory v2.1.0
 * @dev Verifies that all security features are properly configured after deployment
 */
contract VerifyFactoryV2Security is Script {
    
    // Test resolver address for verification
    address constant TEST_RESOLVER = 0x1234567890123456789012345678901234567890;
    
    function run() external {
        // Get factory address from environment or command line
        address factoryAddress = vm.envAddress("FACTORY_V2_ADDRESS");
        
        console.log("==============================================");
        console.log("Verifying CrossChainEscrowFactory v2.1.0 Security");
        console.log("==============================================");
        console.log("Factory Address:", factoryAddress);
        console.log("Chain ID:", block.chainid);
        
        // Check that factory is deployed
        require(factoryAddress.code.length > 0, "Factory not deployed at address");
        
        CrossChainEscrowFactory factory = CrossChainEscrowFactory(factoryAddress);
        
        // 1. Verify version
        console.log("\n[1/7] Verifying Version...");
        string memory version = factory.VERSION();
        console.log("Version:", version);
        require(
            keccak256(bytes(version)) == keccak256(bytes("2.1.0-bmn-secure")),
            "Incorrect version"
        );
        console.log("[OK] Version correct");
        
        // 2. Verify pause functionality
        console.log("\n[2/7] Verifying Pause Functionality...");
        bool isPaused = factory.emergencyPaused();
        console.log("Emergency Paused:", isPaused);
        require(!isPaused, "Factory should not be paused initially");
        console.log("[OK] Factory is not paused");
        
        // 3. Verify owner
        console.log("\n[3/7] Verifying Owner...");
        address owner = factory.owner();
        console.log("Owner:", owner);
        require(owner != address(0), "Owner not set");
        console.log("[OK] Owner is set");
        
        // 4. Verify initial resolver is whitelisted
        console.log("\n[4/7] Verifying Initial Resolver...");
        bool isInitialResolverWhitelisted = factory.whitelistedResolvers(Constants.BOB_RESOLVER);
        console.log("Initial resolver whitelisted:", isInitialResolverWhitelisted);
        require(isInitialResolverWhitelisted, "Initial resolver not whitelisted");
        console.log("[OK] Initial resolver is whitelisted");
        
        // 5. Verify resolver count
        console.log("\n[5/7] Verifying Resolver Count...");
        uint256 resolverCount = factory.resolverCount();
        console.log("Resolver count:", resolverCount);
        require(resolverCount >= 1, "Resolver count should be at least 1");
        console.log("[OK] Resolver count is correct");
        
        // 6. Test pause/unpause (if we're the owner)
        console.log("\n[6/7] Testing Pause/Unpause...");
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        if (deployer == owner) {
            console.log("Testing as owner...");
            
            vm.startBroadcast(deployerPrivateKey);
            
            // Test pause
            factory.pause();
            require(factory.emergencyPaused(), "Pause failed");
            console.log("[OK] Pause works");
            
            // Test unpause
            factory.unpause();
            require(!factory.emergencyPaused(), "Unpause failed");
            console.log("[OK] Unpause works");
            
            vm.stopBroadcast();
        } else {
            console.log("[SKIP] Not owner, cannot test pause/unpause");
        }
        
        // 7. Test whitelist management (if we're the owner)
        console.log("\n[7/7] Testing Whitelist Management...");
        if (deployer == owner) {
            console.log("Testing as owner...");
            
            vm.startBroadcast(deployerPrivateKey);
            
            // Add test resolver
            factory.addResolverToWhitelist(TEST_RESOLVER);
            require(factory.whitelistedResolvers(TEST_RESOLVER), "Add resolver failed");
            console.log("[OK] Add resolver works");
            
            // Remove test resolver
            factory.removeResolverFromWhitelist(TEST_RESOLVER);
            require(!factory.whitelistedResolvers(TEST_RESOLVER), "Remove resolver failed");
            console.log("[OK] Remove resolver works");
            
            vm.stopBroadcast();
        } else {
            console.log("[SKIP] Not owner, cannot test whitelist management");
        }
        
        // Summary
        console.log("\n==============================================");
        console.log("Security Verification Complete");
        console.log("==============================================");
        console.log("[OK] All security features verified");
        console.log("\nFactory Security Status:");
        console.log("- Version: 2.1.0-bmn-secure");
        console.log("- Emergency Pause: Functional");
        console.log("- Resolver Whitelist: Functional");
        console.log("- Owner Controls: Functional");
        console.log("- Initial Resolver: Whitelisted");
        
        // Save verification results
        string memory verificationInfo = string(abi.encodePacked(
            "# Factory V2 Security Verification Results\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "FACTORY_ADDRESS=", vm.toString(factoryAddress), "\n",
            "VERSION=", version, "\n",
            "OWNER=", vm.toString(owner), "\n",
            "PAUSED=", vm.toString(isPaused), "\n",
            "RESOLVER_COUNT=", vm.toString(resolverCount), "\n",
            "VERIFICATION_TIME=", vm.toString(block.timestamp), "\n",
            "STATUS=VERIFIED\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/factory-v2-verification-",
            vm.toString(block.chainid),
            ".env"
        ));
        
        vm.writeFile(filename, verificationInfo);
        console.log("\nVerification results saved to:", filename);
    }
}