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
        
        require(factoryAddress != address(0), "Set UPGRADED_FACTORY env var");
        
        // Verify chain
        string memory chainName = block.chainid == BASE_CHAIN_ID ? "Base" : 
                                  block.chainid == ETHERLINK_CHAIN_ID ? "Etherlink" : "Unknown";
        
        // Check factory has code
        require(factoryAddress.code.length > 0, "No code at factory address");
        
        // Get implementation addresses
        CrossChainEscrowFactory factory = CrossChainEscrowFactory(payable(factoryAddress));
        address srcImpl = factory.ESCROW_SRC_IMPLEMENTATION();
        address dstImpl = factory.ESCROW_DST_IMPLEMENTATION();
        
        // Verify implementations have code
        require(srcImpl.code.length > 0, "SRC implementation missing");
        require(dstImpl.code.length > 0, "DST implementation missing");
        
        // All checks passed
    }
    
    function _getEventTopic(string memory signature) private pure returns (bytes32) {
        return keccak256(bytes(signature));
    }
}