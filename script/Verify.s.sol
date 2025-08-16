// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";

/**
 * @title Verify
 * @notice Script to verify contracts on block explorers
 * @dev Run after deployment to verify contracts on Etherscan/Basescan
 * 
 * Usage:
 * FACTORY_ADDRESS=0x... forge script script/Verify.s.sol --rpc-url $BASE_RPC_URL
 */
contract Verify is Script {
    
    function run() external view {
        // Get factory address from environment or use a default for instructions
        address factoryAddress;
        try vm.envAddress("FACTORY_ADDRESS") returns (address addr) {
            factoryAddress = addr;
        } catch {
            factoryAddress = address(0);
        }
        
        console.log("Contract Verification Commands");
        console.log("==============================");
        console.log("");
        
        if (factoryAddress != address(0)) {
            console.log("Factory to verify:", factoryAddress);
            console.log("");
        }
        
        if (block.chainid == 8453) {
            console.log("Base (Chain 8453) Verification:");
            console.log("");
            _printVerificationCommands("base", "$BASESCAN_API_KEY", "$BASE_RPC_URL", factoryAddress);
            
        } else if (block.chainid == 10) {
            console.log("Optimism (Chain 10) Verification:");
            console.log("");
            _printVerificationCommands("optimism", "$OPTIMISM_ETHERSCAN_API_KEY", "$OPTIMISM_RPC_URL", factoryAddress);
            
        } else {
            console.log("Chain ID:", block.chainid);
            console.log("This script supports Base (8453) and Optimism (10)");
        }
    }
    
    function _printVerificationCommands(
        string memory chain,
        string memory apiKeyVar,
        string memory rpcUrlVar,
        address factoryAddress
    ) internal pure {
        console.log("1. Verify Factory:");
        console.log("forge verify-contract --watch \\");
        console.log(string.concat("  --chain ", chain, " \\"));
        if (factoryAddress != address(0)) {
            console.log("  %s \\", factoryAddress);
        } else {
            console.log("  <FACTORY_ADDRESS> \\");
        }
        console.log("  contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address)\" <SRC_IMPL> <DST_IMPL> <OWNER>) \\");
        console.log(string.concat("  --etherscan-api-key ", apiKeyVar));
        console.log("");
        
        console.log("2. Get implementation addresses from factory:");
        if (factoryAddress != address(0)) {
            console.log("cast call %s \"ESCROW_SRC_IMPLEMENTATION()\" --rpc-url %s", factoryAddress, rpcUrlVar);
            console.log("cast call %s \"ESCROW_DST_IMPLEMENTATION()\" --rpc-url %s", factoryAddress, rpcUrlVar);
        } else {
            console.log(string.concat("cast call <FACTORY_ADDRESS> \"ESCROW_SRC_IMPLEMENTATION()\" --rpc-url ", rpcUrlVar));
            console.log(string.concat("cast call <FACTORY_ADDRESS> \"ESCROW_DST_IMPLEMENTATION()\" --rpc-url ", rpcUrlVar));
        }
        console.log("");
        console.log("3. Verify implementations using the addresses from step 2");
        console.log("");
        console.log("Note: Replace placeholders with actual addresses");
    }
}