#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Bridge-Me-Not Deployment Status${NC}"
echo "================================"

# Function to check if port is in use
check_port() {
    lsof -i :$1 > /dev/null 2>&1
    return $?
}

# Check Chain A
echo -e "\n${BLUE}Chain A (1337) - Port 8545:${NC}"
if check_port 8545; then
    echo -e "  Status: ${GREEN}Running${NC}"
    if [ -f "deployments/chainA.json" ]; then
        echo -e "  Deployment: ${GREEN}Found${NC}"
        echo "  Contracts:"
        cat deployments/chainA.json | grep -E '"(factory|tokenA|tokenB)"' | sed 's/^/    /'
    else
        echo -e "  Deployment: ${YELLOW}Not found${NC}"
    fi
else
    echo -e "  Status: ${RED}Not running${NC}"
fi

# Check Chain B
echo -e "\n${BLUE}Chain B (1338) - Port 8546:${NC}"
if check_port 8546; then
    echo -e "  Status: ${GREEN}Running${NC}"
    if [ -f "deployments/chainB.json" ]; then
        echo -e "  Deployment: ${GREEN}Found${NC}"
        echo "  Contracts:"
        cat deployments/chainB.json | grep -E '"(factory|tokenA|tokenB)"' | sed 's/^/    /'
    else
        echo -e "  Deployment: ${YELLOW}Not found${NC}"
    fi
else
    echo -e "  Status: ${RED}Not running${NC}"
fi

# Check test accounts balances if chains are running
if check_port 8545 && check_port 8546; then
    echo -e "\n${BLUE}Test Account Balances:${NC}"
    
    ALICE="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    BOB="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
    
    # Check ETH balances
    echo -e "\n  ${BLUE}ETH Balances:${NC}"
    
    # Chain A ETH
    ALICE_ETH_A=$(cast balance $ALICE --rpc-url http://localhost:8545 2>/dev/null | sed 's/[^0-9]//g')
    BOB_ETH_A=$(cast balance $BOB --rpc-url http://localhost:8545 2>/dev/null | sed 's/[^0-9]//g')
    
    if [ ! -z "$ALICE_ETH_A" ]; then
        echo -e "    Chain A - Alice: ${GREEN}$(cast from-wei $ALICE_ETH_A) ETH${NC}"
        echo -e "    Chain A - Bob:   ${GREEN}$(cast from-wei $BOB_ETH_A) ETH${NC}"
    fi
    
    # Chain B ETH
    ALICE_ETH_B=$(cast balance $ALICE --rpc-url http://localhost:8546 2>/dev/null | sed 's/[^0-9]//g')
    BOB_ETH_B=$(cast balance $BOB --rpc-url http://localhost:8546 2>/dev/null | sed 's/[^0-9]//g')
    
    if [ ! -z "$ALICE_ETH_B" ]; then
        echo -e "    Chain B - Alice: ${GREEN}$(cast from-wei $ALICE_ETH_B) ETH${NC}"
        echo -e "    Chain B - Bob:   ${GREEN}$(cast from-wei $BOB_ETH_B) ETH${NC}"
    fi
    
    # Check token balances if deployments exist
    if [ -f "deployments/chainA.json" ] && [ -f "deployments/chainB.json" ]; then
        echo -e "\n  ${BLUE}Token Balances:${NC}"
        
        # Get token addresses
        TOKEN_A_CHAIN_A=$(cat deployments/chainA.json | grep -o '"tokenA": "[^"]*"' | cut -d'"' -f4)
        TOKEN_B_CHAIN_B=$(cat deployments/chainB.json | grep -o '"tokenB": "[^"]*"' | cut -d'"' -f4)
        
        if [ ! -z "$TOKEN_A_CHAIN_A" ]; then
            # Token A on Chain A
            ALICE_TKA=$(cast call $TOKEN_A_CHAIN_A "balanceOf(address)(uint256)" $ALICE --rpc-url http://localhost:8545 2>/dev/null)
            BOB_TKA=$(cast call $TOKEN_A_CHAIN_A "balanceOf(address)(uint256)" $BOB --rpc-url http://localhost:8545 2>/dev/null)
            
            if [ ! -z "$ALICE_TKA" ]; then
                echo -e "    Chain A - Alice TKA: ${GREEN}$(cast from-wei $ALICE_TKA)${NC}"
                echo -e "    Chain A - Bob TKA:   ${GREEN}$(cast from-wei $BOB_TKA)${NC}"
            fi
        fi
        
        if [ ! -z "$TOKEN_B_CHAIN_B" ]; then
            # Token B on Chain B
            ALICE_TKB=$(cast call $TOKEN_B_CHAIN_B "balanceOf(address)(uint256)" $ALICE --rpc-url http://localhost:8546 2>/dev/null)
            BOB_TKB=$(cast call $TOKEN_B_CHAIN_B "balanceOf(address)(uint256)" $BOB --rpc-url http://localhost:8546 2>/dev/null)
            
            if [ ! -z "$ALICE_TKB" ]; then
                echo -e "    Chain B - Alice TKB: ${GREEN}$(cast from-wei $ALICE_TKB)${NC}"
                echo -e "    Chain B - Bob TKB:   ${GREEN}$(cast from-wei $BOB_TKB)${NC}"
            fi
        fi
    fi
fi

# Check if resolver directory exists
echo -e "\n${BLUE}Resolver Project:${NC}"
if [ -d "../bmn-evm-resolver" ]; then
    echo -e "  Status: ${GREEN}Found${NC}"
    if [ -d "../bmn-evm-resolver/deployments" ]; then
        echo -e "  Deployments: ${GREEN}Copied${NC}"
    else
        echo -e "  Deployments: ${YELLOW}Not copied${NC}"
    fi
else
    echo -e "  Status: ${YELLOW}Not found${NC}"
fi

echo -e "\n${BLUE}Commands:${NC}"
echo "  Start chains: ./scripts/multi-chain-setup.sh"
echo "  Clean up:     ./scripts/cleanup.sh"
echo "  Fund accounts: ./scripts/fund-accounts.sh"