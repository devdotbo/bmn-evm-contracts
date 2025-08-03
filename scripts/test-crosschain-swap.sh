#!/bin/bash
# Test cross-chain atomic swap with newly deployed CrossChainEscrowFactory

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'  
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
source .env

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cross-Chain Atomic Swap Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Contract addresses (same on both chains)
FACTORY="0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa"
BMN_TOKEN="0x8287CD2aC7E227D9D927F998EB600a0683a832A1"

echo "Contract Addresses:"
echo "  CrossChainEscrowFactory: $FACTORY"  
echo "  BMN Token: $BMN_TOKEN"
echo ""

# Check initial balances
echo -e "${YELLOW}=== Initial Balances ===${NC}"
echo -n "Alice BMN on Base: "
cast call $BMN_TOKEN "balanceOf(address)" $ALICE --rpc-url $BASE_RPC_URL | xargs -I {} echo "scale=6; {} / 1000000" | bc
echo -n "Alice BMN on Etherlink: "
cast call $BMN_TOKEN "balanceOf(address)" $ALICE --rpc-url $ETHERLINK_RPC_URL | xargs -I {} echo "scale=6; {} / 1000000" | bc
echo -n "Bob BMN on Base: "
cast call $BMN_TOKEN "balanceOf(address)" $BOB_RESOLVER --rpc-url $BASE_RPC_URL | xargs -I {} echo "scale=6; {} / 1000000" | bc
echo -n "Bob BMN on Etherlink: "
cast call $BMN_TOKEN "balanceOf(address)" $BOB_RESOLVER --rpc-url $ETHERLINK_RPC_URL | xargs -I {} echo "scale=6; {} / 1000000" | bc
echo ""

# Test flow
echo -e "${BLUE}Test Flow: Alice (Base) swaps 10 BMN for Bob's 10 BMN (Etherlink)${NC}"
echo ""

# Step 1: Create source escrow on Base
echo -e "${YELLOW}Step 1: Creating source escrow on Base...${NC}"
source .env && ACTION=create-src forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --private-key $ALICE_PRIVATE_KEY \
    -vvv || {
    echo -e "${RED}Failed to create source escrow${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}✓ Source escrow created${NC}"
echo ""

# Step 2: Create destination escrow on Etherlink
echo -e "${YELLOW}Step 2: Creating destination escrow on Etherlink...${NC}"
source .env && ACTION=create-dst forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $ETHERLINK_RPC_URL \
    --broadcast \
    --private-key $RESOLVER_PRIVATE_KEY \
    -vvv || {
    echo -e "${RED}Failed to create destination escrow${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}✓ Destination escrow created${NC}"
echo ""

# Step 3: Alice withdraws from destination (reveals secret)
echo -e "${YELLOW}Step 3: Alice withdrawing from destination escrow (revealing secret)...${NC}"
source .env && ACTION=withdraw-dst forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $ETHERLINK_RPC_URL \
    --broadcast \
    --private-key $ALICE_PRIVATE_KEY \
    -vvv || {
    echo -e "${RED}Failed to withdraw from destination${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}✓ Alice withdrew from destination${NC}"
echo ""

# Step 4: Bob withdraws from source using revealed secret
echo -e "${YELLOW}Step 4: Bob withdrawing from source escrow...${NC}"
source .env && ACTION=withdraw-src forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --private-key $RESOLVER_PRIVATE_KEY \
    -vvv || {
    echo -e "${RED}Failed to withdraw from source${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}✓ Bob withdrew from source${NC}"
echo ""

# Check final balances
echo -e "${YELLOW}=== Final Balances ===${NC}"
echo -n "Alice BMN on Base: "
cast call $BMN_TOKEN "balanceOf(address)" $ALICE --rpc-url $BASE_RPC_URL | xargs -I {} echo "scale=6; {} / 1000000" | bc
echo -n "Alice BMN on Etherlink: "
cast call $BMN_TOKEN "balanceOf(address)" $ALICE --rpc-url $ETHERLINK_RPC_URL | xargs -I {} echo "scale=6; {} / 1000000" | bc
echo -n "Bob BMN on Base: "
cast call $BMN_TOKEN "balanceOf(address)" $BOB_RESOLVER --rpc-url $BASE_RPC_URL | xargs -I {} echo "scale=6; {} / 1000000" | bc
echo -n "Bob BMN on Etherlink: "
cast call $BMN_TOKEN "balanceOf(address)" $BOB_RESOLVER --rpc-url $ETHERLINK_RPC_URL | xargs -I {} echo "scale=6; {} / 1000000" | bc

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cross-Chain Swap Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

# Clean up state file
rm -f deployments/crosschain-swap-state.json