// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";

/**
 * @title VerifyFactoryUpgrade
 * @notice Verification script to check the deployed upgraded factory
 * @dev Run this after deployment to verify the factory is working correctly
 */
contract VerifyFactoryUpgrade is Script {
    // Chain configuration
    uint256 constant BASE_CHAIN_ID = 8453;
    uint256 constant ETHERLINK_CHAIN_ID = 128123;
    
    function run() external view {
        // Get factory address from environment or use predicted address
        address factoryAddress = vm.envOr("UPGRADED_FACTORY", address(0));
        
        if (factoryAddress == address(0)) {
            console.log("Please set UPGRADED_FACTORY environment variable");
            console.log("Example: UPGRADED_FACTORY=0x... forge script script/VerifyFactoryUpgrade.s.sol");
            return;
        }
        
        console.log("Verifying Upgraded Factory");
        console.log("=========================");
        console.log("Factory Address:", factoryAddress);
        console.log("Chain ID:", block.chainid);
        
        string memory chainName = block.chainid == BASE_CHAIN_ID ? "Base" : 
                                 block.chainid == ETHERLINK_CHAIN_ID ? "Etherlink" : "Unknown";
        console.log("Chain Name:", chainName);
        
        // Check factory exists
        if (factoryAddress.code.length == 0) {
            console.log("[ERROR] No code at factory address");
            return;
        }
        console.log("[OK] Factory has code");
        
        // Cast to factory interface
        CrossChainEscrowFactory factory = CrossChainEscrowFactory(factoryAddress);
        
        // Verify implementations
        address srcImpl = address(factory.ESCROW_SRC_IMPLEMENTATION());
        address dstImpl = address(factory.ESCROW_DST_IMPLEMENTATION());
        
        console.log("\nImplementations:");
        console.log("SRC Implementation:", srcImpl);
        console.log("DST Implementation:", dstImpl);
        
        // Check implementations have code
        if (srcImpl.code.length == 0) {
            console.log("[ERROR] SRC implementation has no code");
        } else {
            console.log("[OK] SRC implementation has code");
        }
        
        if (dstImpl.code.length == 0) {
            console.log("[ERROR] DST implementation has no code");
        } else {
            console.log("[OK] DST implementation has code");
        }
        
        // Check event signatures
        console.log("\nEvent Signatures:");
        console.log("SrcEscrowCreated topic:", _getEventTopic("SrcEscrowCreated(address,IBaseEscrow.Immutables,IEscrowFactory.DstImmutablesComplement)"));
        console.log("DstEscrowCreated topic:", _getEventTopic("DstEscrowCreated(address,bytes32,IEscrowFactory.Address)"));
        
        // Verify owner and configuration
        try factory.owner() returns (address owner) {
            console.log("\nFactory owner:", owner);
        } catch {
            console.log("\n[INFO] Factory does not expose owner (expected for production)");
        }
        
        console.log("\n[OK] Factory verification complete");
        console.log("\nNext steps:");
        console.log("1. Create a test order to verify event emission");
        console.log("2. Check event logs contain escrow address as first indexed parameter");
        console.log("3. Update indexer to use this factory address");
    }
    
    function _getEventTopic(string memory signature) private pure returns (bytes32) {
        return keccak256(bytes(signature));
    }
}