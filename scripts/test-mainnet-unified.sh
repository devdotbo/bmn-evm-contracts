#!/bin/bash

# Unified Mainnet E2E Test Script for Bridge-Me-Not
# Tests BMN token swaps between Base and Etherlink mainnets

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONTRACTS_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
RESOLVER_DIR="$( cd "$CONTRACTS_DIR/../bmn-evm-resolver" && pwd )"

# Test parameters
BMN_TOKEN="0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e"
ALICE="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
BOB="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
DEPLOYER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
SWAP_AMOUNT="10" # 10 BMN tokens
MIN_BALANCE="15" # Need 15 BMN (10 for swap + 1 safety deposit + buffer)

# Test direction (can be changed)
TEST_DIRECTION=${1:-"forward"} # forward: Base->Etherlink, reverse: Etherlink->Base

echo -e "${BLUE}=== Bridge-Me-Not Unified Mainnet Test ===${NC}"
echo -e "Testing BMN token swaps on mainnet"
echo -e "Direction: ${YELLOW}$TEST_DIRECTION${NC}"
echo ""

# Function to check BMN balance
check_balance() {
    local chain=$1
    local address=$2
    local rpc_var="${chain}_RPC_URL"
    local rpc_url="${!rpc_var}"
    
    balance=$(cast call $BMN_TOKEN "balanceOf(address)(uint256)" $address --rpc-url $rpc_url 2>/dev/null || echo "0")
    echo "$balance"
}

# Function to format balance
format_balance() {
    local balance=$1
    if [ "$balance" = "0" ]; then
        echo "0"
    else
        # Convert wei to BMN (18 decimals)
        echo $(echo "scale=2; $balance / 1000000000000000000" | bc)
    fi
}

# Load environment
echo -e "${YELLOW}Loading environment...${NC}"
cd $CONTRACTS_DIR
source .env

# Check deployments
echo -e "\n${YELLOW}Checking deployments...${NC}"
if [ ! -f "deployments/mainnet-deployment-final-2025-08-03_03-07-57_UTC.json" ]; then
    echo -e "${RED}Error: Mainnet deployments not found${NC}"
    echo "Please run: forge script script/MainnetDeploy.s.sol --broadcast"
    exit 1
fi

BASE_FACTORY=$(jq -r '.base_mainnet.factory' deployments/mainnet-deployment-final-2025-08-03_03-07-57_UTC.json)
ETHERLINK_FACTORY=$(jq -r '.etherlink_mainnet.factory' deployments/mainnet-deployment-final-2025-08-03_03-07-57_UTC.json)
echo -e "Base Factory: $BASE_FACTORY"
echo -e "Etherlink Factory: $ETHERLINK_FACTORY"

# Check balances
echo -e "\n${YELLOW}Checking BMN balances...${NC}"
ALICE_BASE=$(check_balance "BASE" $ALICE)
ALICE_ETHERLINK=$(check_balance "ETHERLINK" $ALICE)
BOB_BASE=$(check_balance "BASE" $BOB)
BOB_ETHERLINK=$(check_balance "ETHERLINK" $BOB)

echo -e "Alice:"
echo -e "  Base: $(format_balance $ALICE_BASE) BMN"
echo -e "  Etherlink: $(format_balance $ALICE_ETHERLINK) BMN"
echo -e "Bob (Resolver):"
echo -e "  Base: $(format_balance $BOB_BASE) BMN"
echo -e "  Etherlink: $(format_balance $BOB_ETHERLINK) BMN"

# Determine source and destination based on direction
if [ "$TEST_DIRECTION" = "forward" ]; then
    SRC_CHAIN="BASE"
    DST_CHAIN="ETHERLINK"
    SRC_CHAIN_ID="8453"
    DST_CHAIN_ID="42793"
    ALICE_SRC_BALANCE=$ALICE_BASE
    BOB_DST_BALANCE=$BOB_ETHERLINK
else
    SRC_CHAIN="ETHERLINK"
    DST_CHAIN="BASE"
    SRC_CHAIN_ID="42793"
    DST_CHAIN_ID="8453"
    ALICE_SRC_BALANCE=$ALICE_ETHERLINK
    BOB_DST_BALANCE=$BOB_BASE
fi

echo -e "\n${YELLOW}Test Configuration:${NC}"
echo -e "Source: $SRC_CHAIN (Chain $SRC_CHAIN_ID)"
echo -e "Destination: $DST_CHAIN (Chain $DST_CHAIN_ID)"

# Check if minting is needed
MIN_BALANCE_WEI=$(echo "$MIN_BALANCE * 1000000000000000000" | bc)
NEED_MINT=false

if [ $(echo "$ALICE_SRC_BALANCE < $MIN_BALANCE_WEI" | bc) -eq 1 ]; then
    echo -e "\n${YELLOW}Alice needs BMN on $SRC_CHAIN${NC}"
    NEED_MINT=true
fi

if [ $(echo "$BOB_DST_BALANCE < $MIN_BALANCE_WEI" | bc) -eq 1 ]; then
    echo -e "${YELLOW}Bob needs BMN on $DST_CHAIN${NC}"
    NEED_MINT=true
fi

# Mint tokens if needed
if [ "$NEED_MINT" = true ]; then
    echo -e "\n${YELLOW}Minting BMN tokens...${NC}"
    
    # Create minting script
    cat > script/MintForTest.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBMNToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function owner() external view returns (address);
}

contract MintForTest is Script {
    address constant BMN_TOKEN = 0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e;
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant MINT_AMOUNT = 100 ether; // 100 BMN

    function run() external {
        string memory chain = vm.envString("TARGET_CHAIN");
        address target = vm.envAddress("TARGET_ADDRESS");
        
        console.log("Minting on chain:", chain);
        console.log("Target address:", target);
        
        vm.startBroadcast();
        
        IBMNToken bmn = IBMNToken(BMN_TOKEN);
        
        // Check current balance
        uint256 currentBalance = bmn.balanceOf(target);
        console.log("Current balance:", currentBalance);
        
        if (currentBalance < 15 ether) {
            console.log("Minting", MINT_AMOUNT, "BMN to", target);
            bmn.mint(target, MINT_AMOUNT);
            console.log("New balance:", bmn.balanceOf(target));
        } else {
            console.log("Sufficient balance, skipping mint");
        }
        
        vm.stopBroadcast();
    }
}
EOF

    # Mint for Alice on source chain if needed
    if [ $(echo "$ALICE_SRC_BALANCE < $MIN_BALANCE_WEI" | bc) -eq 1 ]; then
        echo "Minting for Alice on $SRC_CHAIN..."
        SRC_RPC_VAR="${SRC_CHAIN}_RPC_URL"
        TARGET_CHAIN=$SRC_CHAIN TARGET_ADDRESS=$ALICE forge script script/MintForTest.s.sol --rpc-url ${!SRC_RPC_VAR} --broadcast --private-key $DEPLOYER_PRIVATE_KEY
    fi
    
    # Mint for Bob on destination chain if needed
    if [ $(echo "$BOB_DST_BALANCE < $MIN_BALANCE_WEI" | bc) -eq 1 ]; then
        echo "Minting for Bob on $DST_CHAIN..."
        DST_RPC_VAR="${DST_CHAIN}_RPC_URL"
        TARGET_CHAIN=$DST_CHAIN TARGET_ADDRESS=$BOB forge script script/MintForTest.s.sol --rpc-url ${!DST_RPC_VAR} --broadcast --private-key $DEPLOYER_PRIVATE_KEY
    fi
    
    # Re-check balances
    sleep 5
    echo -e "\n${YELLOW}Re-checking balances after minting...${NC}"
    ALICE_SRC_BALANCE=$(check_balance $SRC_CHAIN $ALICE)
    BOB_DST_BALANCE=$(check_balance $DST_CHAIN $BOB)
    echo -e "Alice on $SRC_CHAIN: $(format_balance $ALICE_SRC_BALANCE) BMN"
    echo -e "Bob on $DST_CHAIN: $(format_balance $BOB_DST_BALANCE) BMN"
fi

# Kill any existing resolver
echo -e "\n${YELLOW}Stopping any existing resolver...${NC}"
pkill -f "deno.*resolver/index.ts" || true
sleep 2

# Start resolver in background
echo -e "\n${YELLOW}Starting resolver...${NC}"
cd $RESOLVER_DIR
export NETWORK_MODE="mainnet"

# Create resolver log file
RESOLVER_LOG="$CONTRACTS_DIR/test-mainnet-resolver.log"
echo "Starting resolver at $(date)" > $RESOLVER_LOG

# Start resolver with proper chain configuration
if [ "$TEST_DIRECTION" = "reverse" ]; then
    # For reverse, we need to modify the resolver to swap chain order
    echo "Starting resolver for reverse direction (Etherlink -> Base)..."
    export REVERSE_CHAINS="true"
fi

deno run --allow-net --allow-read --allow-write --allow-env src/resolver/index.ts >> $RESOLVER_LOG 2>&1 &
RESOLVER_PID=$!
echo "Resolver started with PID: $RESOLVER_PID"
sleep 5

# Check if resolver is running
if ! ps -p $RESOLVER_PID > /dev/null; then
    echo -e "${RED}Resolver failed to start!${NC}"
    tail -20 $RESOLVER_LOG
    exit 1
fi

# Create swap order
echo -e "\n${YELLOW}Creating swap order...${NC}"
cd $RESOLVER_DIR

# Create order using Alice
if [ "$TEST_DIRECTION" = "forward" ]; then
    ORDER_SCRIPT="src/alice/create-mainnet-order.ts"
else
    ORDER_SCRIPT="src/alice/create-mainnet-order-reverse.ts"
fi

echo "Running order creation script: $ORDER_SCRIPT"
deno run --allow-net --allow-read --allow-write --allow-env $ORDER_SCRIPT

# Monitor swap execution
echo -e "\n${YELLOW}Monitoring swap execution...${NC}"
echo "Waiting for resolver to process the order..."

# Monitor for up to 5 minutes
TIMEOUT=300
ELAPSED=0
SWAP_COMPLETE=false

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Check resolver log for completion
    if grep -q "Swap completed successfully" $RESOLVER_LOG; then
        SWAP_COMPLETE=true
        break
    fi
    
    # Check for errors
    if grep -q "Error executing order" $RESOLVER_LOG; then
        echo -e "${RED}Swap execution failed!${NC}"
        tail -20 $RESOLVER_LOG
        break
    fi
    
    # Show progress
    if [ $((ELAPSED % 10)) -eq 0 ]; then
        echo -n "."
    fi
    
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

echo ""

# Final balance check
echo -e "\n${YELLOW}Final balance check...${NC}"
ALICE_BASE_FINAL=$(check_balance "BASE" $ALICE)
ALICE_ETHERLINK_FINAL=$(check_balance "ETHERLINK" $ALICE)
BOB_BASE_FINAL=$(check_balance "BASE" $BOB)
BOB_ETHERLINK_FINAL=$(check_balance "ETHERLINK" $BOB)

echo -e "Alice:"
echo -e "  Base: $(format_balance $ALICE_BASE) -> $(format_balance $ALICE_BASE_FINAL) BMN"
echo -e "  Etherlink: $(format_balance $ALICE_ETHERLINK) -> $(format_balance $ALICE_ETHERLINK_FINAL) BMN"
echo -e "Bob:"
echo -e "  Base: $(format_balance $BOB_BASE) -> $(format_balance $BOB_BASE_FINAL) BMN"
echo -e "  Etherlink: $(format_balance $BOB_ETHERLINK) -> $(format_balance $BOB_ETHERLINK_FINAL) BMN"

# Cleanup
echo -e "\n${YELLOW}Cleaning up...${NC}"
kill $RESOLVER_PID 2>/dev/null || true

# Show result
if [ "$SWAP_COMPLETE" = true ]; then
    echo -e "\n${GREEN}✅ Swap completed successfully!${NC}"
    echo -e "Check the resolver log for details: $RESOLVER_LOG"
else
    echo -e "\n${RED}❌ Swap did not complete${NC}"
    echo -e "Last 20 lines of resolver log:"
    tail -20 $RESOLVER_LOG
fi

# Save test results
RESULT_FILE="$CONTRACTS_DIR/test-mainnet-result-$(date +%Y%m%d-%H%M%S).json"
cat > $RESULT_FILE << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "direction": "$TEST_DIRECTION",
  "swap_amount": "$SWAP_AMOUNT",
  "completed": $SWAP_COMPLETE,
  "initial_balances": {
    "alice": {
      "base": "$ALICE_BASE",
      "etherlink": "$ALICE_ETHERLINK"
    },
    "bob": {
      "base": "$BOB_BASE",
      "etherlink": "$BOB_ETHERLINK"
    }
  },
  "final_balances": {
    "alice": {
      "base": "$ALICE_BASE_FINAL",
      "etherlink": "$ALICE_ETHERLINK_FINAL"
    },
    "bob": {
      "base": "$BOB_BASE_FINAL",
      "etherlink": "$BOB_ETHERLINK_FINAL"
    }
  }
}
EOF

echo -e "\nTest results saved to: $RESULT_FILE"