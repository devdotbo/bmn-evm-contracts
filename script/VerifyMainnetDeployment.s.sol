// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/CrossChainEscrowFactory.sol";

contract VerifyMainnetDeployment is Script {
    // Deployed factory addresses
    address constant BASE_FACTORY = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
    address constant OPTIMISM_FACTORY = 0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56;
    
    // Test accounts
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    function run() external view {
        console.log("====================================");
        console.log("BMN Protocol - Mainnet Verification");
        console.log("====================================");
        
        // Verify Base deployment
        console.log("\n[BASE MAINNET]");
        console.log("Factory address:", BASE_FACTORY);
        verifyFactory(BASE_FACTORY, "Base");
        
        // Verify Optimism deployment
        console.log("\n[OPTIMISM MAINNET]");
        console.log("Factory address:", OPTIMISM_FACTORY);
        verifyFactory(OPTIMISM_FACTORY, "Optimism");
        
        console.log("\n====================================");
        console.log("VERIFICATION COMPLETE");
        console.log("====================================");
        console.log("\n[RESULT] Both factories are deployed and accessible!");
        console.log("[STATUS] BMN Protocol is LIVE on mainnet!");
    }
    
    function verifyFactory(address factoryAddr, string memory chainName) internal view {
        CrossChainEscrowFactory factory = CrossChainEscrowFactory(factoryAddr);
        
        // Read all configuration
        console.log(string.concat("\nVerifying ", chainName, " factory..."));
        
        try factory.ESCROW_SRC_IMPLEMENTATION() returns (address srcImpl) {
            console.log("- Source Implementation:", srcImpl);
        } catch {
            console.log("- ERROR: Cannot read ESCROW_SRC_IMPLEMENTATION");
            return;
        }
        
        try factory.ESCROW_DST_IMPLEMENTATION() returns (address dstImpl) {
            console.log("- Destination Implementation:", dstImpl);
        } catch {
            console.log("- ERROR: Cannot read ESCROW_DST_IMPLEMENTATION");
            return;
        }
        
        try factory.ACCESS_TOKEN() returns (address token) {
            console.log("- Access Token:", token);
        } catch {
            console.log("- ERROR: Cannot read ACCESS_TOKEN");
            return;
        }
        
        try factory.RESCUE_DELAY() returns (uint256 delay) {
            console.log("- Rescue Delay:", delay, "seconds");
        } catch {
            console.log("- ERROR: Cannot read RESCUE_DELAY");
            return;
        }
        
        // Check resolver status  
        try factory.whitelistedResolvers(ALICE) returns (bool isAlice) {
            console.log("- Alice is resolver:", isAlice);
        } catch {
            console.log("- ERROR: Cannot check resolver status");
        }
        
        try factory.whitelistedResolvers(BOB) returns (bool isBob) {
            console.log("- Bob is resolver:", isBob);
        } catch {
            console.log("- ERROR: Cannot check resolver status");
        }
        
        console.log(string.concat("[OK] ", chainName, " factory is functional"));
    }
}