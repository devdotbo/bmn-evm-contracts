// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";

/**
 * @title VerifyContracts
 * @notice Script to verify v3.0.2 contracts on block explorers
 * @dev Run after deployment to verify contracts on Etherscan/Basescan
 * 
 * Usage:
 * forge script script/VerifyContracts.s.sol --rpc-url $BASE_RPC_URL
 */
contract VerifyContracts is Script {
    // v3.0.2 Production Addresses
    address constant FACTORY = 0xAbF126d74d6A438a028F33756C0dC21063F72E96;
    
    function run() external view {
        console.log("Contract Verification Commands for v3.0.2");
        console.log("==========================================");
        console.log("");
        
        if (block.chainid == 8453) {
            console.log("Base (Chain 8453) Verification:");
            console.log("");
            
            // Note: Implementation addresses are chain-specific and deployed by factory
            // You'll need to get these from the factory after deployment
            console.log("1. Verify Factory:");
            console.log("forge verify-contract --watch \\");
            console.log("  --chain base \\");
            console.log("  0xAbF126d74d6A438a028F33756C0dC21063F72E96 \\");
            console.log("  contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory \\");
            console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address)\" <SRC_IMPL> <DST_IMPL> <OWNER>) \\");
            console.log("  --etherscan-api-key $BASESCAN_API_KEY");
            console.log("");
            console.log("2. Get implementation addresses from factory:");
            console.log("cast call 0xAbF126d74d6A438a028F33756C0dC21063F72E96 \"ESCROW_SRC_IMPLEMENTATION()\" --rpc-url $BASE_RPC_URL");
            console.log("cast call 0xAbF126d74d6A438a028F33756C0dC21063F72E96 \"ESCROW_DST_IMPLEMENTATION()\" --rpc-url $BASE_RPC_URL");
            console.log("");
            console.log("3. Verify implementations using the addresses from step 2");
            
        } else if (block.chainid == 10) {
            console.log("Optimism (Chain 10) Verification:");
            console.log("");
            
            console.log("1. Verify Factory:");
            console.log("forge verify-contract --watch \\");
            console.log("  --chain optimism \\");
            console.log("  0xAbF126d74d6A438a028F33756C0dC21063F72E96 \\");
            console.log("  contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory \\");
            console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address)\" <SRC_IMPL> <DST_IMPL> <OWNER>) \\");
            console.log("  --etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY");
            console.log("");
            console.log("2. Get implementation addresses from factory:");
            console.log("cast call 0xAbF126d74d6A438a028F33756C0dC21063F72E96 \"ESCROW_SRC_IMPLEMENTATION()\" --rpc-url $OPTIMISM_RPC_URL");
            console.log("cast call 0xAbF126d74d6A438a028F33756C0dC21063F72E96 \"ESCROW_DST_IMPLEMENTATION()\" --rpc-url $OPTIMISM_RPC_URL");
            console.log("");
            console.log("3. Verify implementations using the addresses from step 2");
            
        } else {
            console.log("Unknown chain ID:", block.chainid);
            console.log("This script supports Base (8453) and Optimism (10)");
        }
        
        console.log("");
        console.log("Note: Replace <SRC_IMPL>, <DST_IMPL>, and <OWNER> with actual addresses");
        console.log("You can get these values using the cast commands shown above");
    }
}