#!/bin/bash
set -e

# Script to test CREATE2 fix on forked mainnets
# Usage: ./test-fork-create2-fix.sh [base|etherlink|both]

source .env

LOG_DIR="logs/fork-tests"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Testing CREATE2 fix on mainnet forks...${NC}"

test_on_fork() {
    local chain_name=$1
    local rpc_url=$2
    local deployment_file=$3
    local log_file="$LOG_DIR/${chain_name}_${TIMESTAMP}.log"
    
    echo -e "\n${YELLOW}Testing on $chain_name fork...${NC}"
    echo "RPC URL: $rpc_url"
    echo "Log file: $log_file"
    
    # Create and run the test script
    cat > script/TestFork_${chain_name}.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";

contract TestFork is Script {
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SAFETY_DEPOSIT = 0.0001 ether;
    
    function createTimelocks() internal pure returns (Timelocks) {
        uint256 packed = 0;
        packed |= uint256(uint32(0));
        packed |= uint256(uint32(300)) << 32;
        packed |= uint256(uint32(0)) << 64;
        packed |= uint256(uint32(1200)) << 96;
        packed |= uint256(uint32(900)) << 128;
        packed |= uint256(uint32(300)) << 160;
        packed |= uint256(uint32(0)) << 192;
        return Timelocks.wrap(packed);
    }
    
    function run() external {
        console.log("=== CREATE2 Fix Test on Fork ===");
        console.log("Chain:", CHAIN_NAME_PLACEHOLDER);
        console.log("Block number:", block.number);
        console.log("Timestamp:", block.timestamp);
        
        // Load deployment
        string memory json = vm.readFile("DEPLOYMENT_FILE_PLACEHOLDER");
        address tokenAddr = vm.parseJsonAddress(json, ".TOKEN_KEY_PLACEHOLDER");
        
        // Deploy new factory with fix
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("\nDeploying fixed factory...");
        vm.startBroadcast(deployerKey);
        
        TestEscrowFactory factory = new TestEscrowFactory(
            address(0),
            IERC20(tokenAddr),
            IERC20(tokenAddr),
            deployer,
            86400,
            86400
        );
        
        console.log("Fixed factory deployed at:", address(factory));
        console.log("Src implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("Dst implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        
        vm.stopBroadcast();
        
        // Test prediction vs deployment
        console.log("\n=== Testing Address Prediction ===");
        
        bytes32 hashlock = keccak256("test_secret_fork");
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: hashlock,
            maker: Address.wrap(uint160(deployer)),
            taker: Address.wrap(uint160(0x240E2588e35FB9D3D60B283B45108a49972FFFd8)),
            token: Address.wrap(uint160(tokenAddr)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
        
        // Get predictions
        address predictedSrc = factory.addressOfEscrowSrc(immutables);
        address predictedDst = factory.addressOfEscrowDst(immutables);
        
        console.log("\nPredicted addresses:");
        console.log("- Source escrow:", predictedSrc);
        console.log("- Dest escrow:", predictedDst);
        
        // Deploy source escrow
        vm.startBroadcast(deployerKey);
        
        // Deal tokens to deployer for testing
        vm.deal(deployer, 1 ether); // ETH for gas
        // Use pranking to get tokens from a whale address
        address whale = TOKEN_WHALE_PLACEHOLDER;
        vm.prank(whale);
        IERC20(tokenAddr).transfer(deployer, SWAP_AMOUNT * 2);
        IERC20(tokenAddr).approve(address(factory), SWAP_AMOUNT);
        
        address deployedSrc = factory.createSrcEscrowForTesting(immutables, SWAP_AMOUNT);
        console.log("\nDeployed source escrow:", deployedSrc);
        console.log("Matches prediction?", deployedSrc == predictedSrc);
        
        // Deploy destination escrow
        // Transfer tokens to factory
        IERC20(tokenAddr).transfer(address(factory), SWAP_AMOUNT);
        
        // Get src cancellation timestamp for createDstEscrow
        uint256 srcCancellationTimestamp = block.timestamp + uint256(immutables.timelocks.get(TimelocksLib.Stage.SrcCancellation));
        
        // createDstEscrow doesn't return address, we need to capture it from event
        vm.recordLogs();
        factory.createDstEscrow{value: SAFETY_DEPOSIT}(immutables, srcCancellationTimestamp);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        address deployedDst = address(0);
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("DstEscrowCreated(address,bytes32,address)")) {
                deployedDst = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }
        
        console.log("\nDeployed dest escrow:", deployedDst);
        console.log("Matches prediction?", deployedDst == predictedDst);
        
        vm.stopBroadcast();
        
        // Summary
        console.log("\n=== SUMMARY ===");
        if (deployedSrc == predictedSrc && deployedDst == predictedDst) {
            console.log("SUCCESS: All address predictions match!");
            console.log("The CREATE2 fix is working correctly.");
        } else {
            console.log("FAILURE: Address mismatch detected!");
            if (deployedSrc != predictedSrc) {
                console.log("- Source escrow mismatch");
            }
            if (deployedDst != predictedDst) {
                console.log("- Destination escrow mismatch");
            }
        }
        
        // Test validation
        console.log("\n=== Testing Escrow Validation ===");
        vm.startBroadcast(deployerKey);
        
        immutables.timelocks = immutables.timelocks.setDeployedAt(block.timestamp);
        
        try EscrowDst(deployedDst).withdraw(bytes32("test_secret_fork"), immutables) {
            console.log("SUCCESS: Withdraw validation passed!");
        } catch Error(string memory reason) {
            console.log("FAILED: Withdraw validation failed -", reason);
        } catch {
            console.log("FAILED: Withdraw validation failed with unknown error");
        }
        
        vm.stopBroadcast();
    }
}
EOF

    # Replace placeholders based on chain
    if [ "$chain_name" = "Base" ]; then
        sed -i '' 's/CHAIN_NAME_PLACEHOLDER/"Base Mainnet"/' script/TestFork_${chain_name}.s.sol
        sed -i '' 's|DEPLOYMENT_FILE_PLACEHOLDER|deployments/baseMainnetTest.json|' script/TestFork_${chain_name}.s.sol
        sed -i '' 's/TOKEN_KEY_PLACEHOLDER/TokenA/' script/TestFork_${chain_name}.s.sol
        sed -i '' 's/TOKEN_WHALE_PLACEHOLDER/0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5/' script/TestFork_${chain_name}.s.sol
    else
        sed -i '' 's/CHAIN_NAME_PLACEHOLDER/"Etherlink Mainnet"/' script/TestFork_${chain_name}.s.sol
        sed -i '' 's|DEPLOYMENT_FILE_PLACEHOLDER|deployments/etherlinkMainnetTest.json|' script/TestFork_${chain_name}.s.sol
        sed -i '' 's/TOKEN_KEY_PLACEHOLDER/TokenB/' script/TestFork_${chain_name}.s.sol
        sed -i '' 's/TOKEN_WHALE_PLACEHOLDER/0x240E2588e35FB9D3D60B283B45108a49972FFFd8/' script/TestFork_${chain_name}.s.sol
    fi
    
    # Run the test
    echo "Running fork test..."
    forge script script/TestFork_${chain_name}.s.sol --fork-url "$rpc_url" -vvv > "$log_file" 2>&1
    
    # Check result
    if grep -q "SUCCESS: All address predictions match!" "$log_file"; then
        echo -e "${GREEN}✓ Test passed on $chain_name!${NC}"
        grep -A5 "=== SUMMARY ===" "$log_file" | tail -n 6
    else
        echo -e "${RED}✗ Test failed on $chain_name!${NC}"
        grep -A10 "=== SUMMARY ===" "$log_file" | tail -n 11
    fi
    
    # Clean up
    rm script/TestFork_${chain_name}.s.sol
}

# Main execution
case "${1:-both}" in
    base)
        test_on_fork "Base" "$CHAIN_A_RPC_URL" "deployments/baseMainnetTest.json"
        ;;
    etherlink)
        test_on_fork "Etherlink" "$CHAIN_B_RPC_URL" "deployments/etherlinkMainnetTest.json"
        ;;
    both|*)
        test_on_fork "Base" "$CHAIN_A_RPC_URL" "deployments/baseMainnetTest.json"
        test_on_fork "Etherlink" "$CHAIN_B_RPC_URL" "deployments/etherlinkMainnetTest.json"
        ;;
esac

echo -e "\n${GREEN}Fork tests complete. Logs saved in $LOG_DIR${NC}"
echo "View logs with: ls -la $LOG_DIR/"