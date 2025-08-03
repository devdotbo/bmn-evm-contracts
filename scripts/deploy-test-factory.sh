#!/bin/bash
# Deploy TestEscrowFactory for testing on mainnet

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
source .env

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}TestEscrowFactory Deployment Script${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

NETWORK=${1:-""}

if [ -z "$NETWORK" ]; then
    echo -e "${RED}Error: Network parameter required${NC}"
    echo ""
    echo "Usage: $0 <network>"
    echo ""
    echo "Networks:"
    echo "  base      - Base mainnet"
    echo "  etherlink - Etherlink mainnet"
    exit 1
fi

# Set RPC URL based on network
case $NETWORK in
    "base")
        RPC_URL="$CHAIN_A_RPC_URL"
        CHAIN_NAME="Base Mainnet"
        ;;
    "etherlink")
        RPC_URL="$CHAIN_B_RPC_URL"
        CHAIN_NAME="Etherlink Mainnet"
        ;;
    *)
        echo -e "${RED}Unknown network: $NETWORK${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Deploying TestEscrowFactory to $CHAIN_NAME${NC}"
echo ""

# Check deployer balance
echo -n "Checking deployer balance... "
balance=$(cast balance $DEPLOYER --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
balance_ether=$(cast --from-wei "$balance" 2>/dev/null || echo "0")
echo "$balance_ether ETH"

if [ "$balance" = "0" ]; then
    echo -e "${RED}WARNING: Deployer has no balance on $CHAIN_NAME${NC}"
    echo "Deployer address: $DEPLOYER"
    echo "Please fund this address with ETH to continue"
    exit 1
fi

# Deploy TestEscrowFactory
echo -e "\n${YELLOW}Deploying TestEscrowFactory...${NC}"

forge script script/DeployTestFactory.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    -vvv

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${RED}WARNING: TestEscrowFactory is for testing only!${NC}"
echo -e "${RED}It bypasses security checks - DO NOT use in production!${NC}"