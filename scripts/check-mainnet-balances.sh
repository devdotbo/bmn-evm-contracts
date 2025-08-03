#!/bin/bash
# Check BMN balances on mainnet

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'  
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
source .env

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Mainnet BMN Balance Check${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Contract addresses
BMN_TOKEN="0x8287CD2aC7E227D9D927F998EB600a0683a832A1"  # BMN V1 with 18 decimals
FACTORY="0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa"    # CrossChainEscrowFactory

echo "Deployed Contracts:"
echo "  BMN Token: $BMN_TOKEN"
echo "  CrossChainEscrowFactory: $FACTORY"
echo ""

# Check balances
echo -e "${YELLOW}=== BMN Token Balances ===${NC}"
echo -n "Alice on Base: "
BALANCE=$(cast call $BMN_TOKEN "balanceOf(address)" $ALICE --rpc-url $BASE_RPC_URL)
cast --to-unit $BALANCE ether

echo -n "Alice on Etherlink: "
BALANCE=$(cast call $BMN_TOKEN "balanceOf(address)" $ALICE --rpc-url $ETHERLINK_RPC_URL)
cast --to-unit $BALANCE ether

echo -n "Bob on Base: "
BALANCE=$(cast call $BMN_TOKEN "balanceOf(address)" $BOB_RESOLVER --rpc-url $BASE_RPC_URL)
cast --to-unit $BALANCE ether

echo -n "Bob on Etherlink: "
BALANCE=$(cast call $BMN_TOKEN "balanceOf(address)" $BOB_RESOLVER --rpc-url $ETHERLINK_RPC_URL)
cast --to-unit $BALANCE ether

echo ""
echo -e "${YELLOW}=== ETH Balances (for gas) ===${NC}"
echo -n "Alice on Base: "
cast balance $ALICE --rpc-url $BASE_RPC_URL --ether

echo -n "Alice on Etherlink: "
cast balance $ALICE --rpc-url $ETHERLINK_RPC_URL --ether

echo -n "Bob on Base: "
cast balance $BOB_RESOLVER --rpc-url $BASE_RPC_URL --ether

echo -n "Bob on Etherlink: "
cast balance $BOB_RESOLVER --rpc-url $ETHERLINK_RPC_URL --ether

echo ""
echo -e "${BLUE}Note: To perform atomic swaps, you need to:${NC}"
echo -e "${BLUE}1. Create orders through 1inch Limit Order Protocol${NC}"
echo -e "${BLUE}2. The CrossChainEscrowFactory will create source escrows via postInteraction${NC}"
echo -e "${BLUE}3. Destination escrows can be created directly with createDstEscrow${NC}"