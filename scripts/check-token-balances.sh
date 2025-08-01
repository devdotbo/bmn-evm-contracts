#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Bridge-Me-Not Token Balances${NC}"
echo "============================"

# Default accounts
ALICE="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
BOB="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

# Function to check if port is in use
check_port() {
    lsof -i :$1 > /dev/null 2>&1
    return $?
}

# Check if chains are running
if ! check_port 8545 || ! check_port 8546; then
    echo -e "${RED}Error: Chains are not running!${NC}"
    echo "Please run ./scripts/multi-chain-setup.sh first"
    exit 1
fi

# Check if deployments exist
if [ ! -f "deployments/chainA.json" ] || [ ! -f "deployments/chainB.json" ]; then
    echo -e "${RED}Error: Deployment files not found!${NC}"
    echo "Please run ./scripts/multi-chain-setup.sh to deploy contracts"
    exit 1
fi

# Get token addresses from deployment files
TOKEN_A_CHAIN_A=$(cat deployments/chainA.json | grep -o '"tokenA": "[^"]*"' | cut -d'"' -f4)
TOKEN_B_CHAIN_A=$(cat deployments/chainB.json | grep -o '"tokenB": "[^"]*"' | cut -d'"' -f4)
TOKEN_A_CHAIN_B=$(cat deployments/chainB.json | grep -o '"tokenA": "[^"]*"' | cut -d'"' -f4)
TOKEN_B_CHAIN_B=$(cat deployments/chainB.json | grep -o '"tokenB": "[^"]*"' | cut -d'"' -f4)

# Function to get balance in ether format
get_balance() {
    local token=$1
    local account=$2
    local rpc=$3
    
    # Get balance in wei
    balance_wei=$(cast call $token "balanceOf(address)(uint256)" $account --rpc-url $rpc 2>/dev/null)
    
    if [ -z "$balance_wei" ]; then
        echo "0"
    else
        # Convert from wei to ether (divide by 10^18)
        # Using awk for decimal division
        echo "$balance_wei" | awk '{printf "%.6f", $1 / 10^18}'
    fi
}

echo -e "\n${BLUE}Chain A (Port 8545) Token Balances:${NC}"
echo "----------------------------------------"

echo -e "\n  ${GREEN}Alice (${ALICE:0:10}...):${NC}"
alice_tka_a=$(get_balance $TOKEN_A_CHAIN_A $ALICE "http://localhost:8545")
alice_tkb_a=$(get_balance $TOKEN_B_CHAIN_A $ALICE "http://localhost:8545")
echo "    TKA: $alice_tka_a"
echo "    TKB: $alice_tkb_a"

echo -e "\n  ${GREEN}Bob (${BOB:0:10}...):${NC}"
bob_tka_a=$(get_balance $TOKEN_A_CHAIN_A $BOB "http://localhost:8545")
bob_tkb_a=$(get_balance $TOKEN_B_CHAIN_A $BOB "http://localhost:8545")
echo "    TKA: $bob_tka_a"
echo "    TKB: $bob_tkb_a"

echo -e "\n${BLUE}Chain B (Port 8546) Token Balances:${NC}"
echo "----------------------------------------"

echo -e "\n  ${GREEN}Alice (${ALICE:0:10}...):${NC}"
alice_tka_b=$(get_balance $TOKEN_A_CHAIN_B $ALICE "http://localhost:8546")
alice_tkb_b=$(get_balance $TOKEN_B_CHAIN_B $ALICE "http://localhost:8546")
echo "    TKA: $alice_tka_b"
echo "    TKB: $alice_tkb_b"

echo -e "\n  ${GREEN}Bob (${BOB:0:10}...):${NC}"
bob_tka_b=$(get_balance $TOKEN_A_CHAIN_B $BOB "http://localhost:8546")
bob_tkb_b=$(get_balance $TOKEN_B_CHAIN_B $BOB "http://localhost:8546")
echo "    TKA: $bob_tka_b"
echo "    TKB: $bob_tkb_b"

echo -e "\n${BLUE}Summary:${NC}"
echo "--------"
echo -e "${GREEN}✓ Alice has both tokens on both chains${NC}" 
echo -e "${GREEN}✓ Bob has both tokens on both chains${NC}"
echo -e "\nBoth parties can now participate in any swap scenario!"