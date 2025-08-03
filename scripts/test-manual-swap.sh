#!/bin/bash
# Manual test for cross-chain atomic swap using deployed contracts

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
echo -e "${GREEN}Manual Cross-Chain Atomic Swap Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Contract addresses
FACTORY="0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa"
BMN_TOKEN="0x8287CD2aC7E227D9D927F998EB600a0683a832A1"  # BMN V1 with 18 decimals

echo "Contract Addresses:"
echo "  CrossChainEscrowFactory: $FACTORY"  
echo "  BMN Token: $BMN_TOKEN"
echo ""

# Test parameters
SWAP_AMOUNT="10000000000000000000"  # 10 BMN (10e18)
SAFETY_DEPOSIT="1000000000000000000" # 1 BMN (1e18)

# Generate secret and hashlock
SECRET=$(cast keccak "atomic-swap-test-$(date +%s)")
HASHLOCK=$(cast keccak $SECRET)

echo "Swap Parameters:"
echo "  Amount: 10 BMN"
echo "  Safety Deposit: 1 BMN"
echo "  Secret: $SECRET"
echo "  Hashlock: $HASHLOCK"
echo ""

# Check initial balances
echo -e "${YELLOW}=== Initial Balances ===${NC}"
echo -n "Alice BMN on Base: "
BALANCE=$(cast call $BMN_TOKEN "balanceOf(address)" $ALICE --rpc-url $BASE_RPC_URL)
cast --to-unit $BALANCE ether
echo -n "Alice BMN on Etherlink: "
BALANCE=$(cast call $BMN_TOKEN "balanceOf(address)" $ALICE --rpc-url $ETHERLINK_RPC_URL)
cast --to-unit $BALANCE ether
echo -n "Bob BMN on Base: "
BALANCE=$(cast call $BMN_TOKEN "balanceOf(address)" $BOB_RESOLVER --rpc-url $BASE_RPC_URL)
cast --to-unit $BALANCE ether
echo -n "Bob BMN on Etherlink: "
BALANCE=$(cast call $BMN_TOKEN "balanceOf(address)" $BOB_RESOLVER --rpc-url $ETHERLINK_RPC_URL)
cast --to-unit $BALANCE ether
echo ""

echo -e "${BLUE}Since CrossChainEscrowFactory requires LimitOrderProtocol integration,${NC}"
echo -e "${BLUE}you'll need to create orders through the 1inch interface or API.${NC}"
echo ""
echo -e "${BLUE}For testing, you can:${NC}"
echo -e "${BLUE}1. Use the TestEscrowFactory if deployed (allows direct escrow creation)${NC}"
echo -e "${BLUE}2. Create orders through 1inch Limit Order Protocol${NC}"
echo -e "${BLUE}3. Deploy a custom test factory for manual testing${NC}"
echo ""

# Check if factory has createDstEscrow function (this should work)
echo -e "${YELLOW}Testing factory interface...${NC}"
echo -n "Can create destination escrows: "
cast call $FACTORY "createDstEscrow((bytes32,bytes32,uint160,uint160,uint160,uint256,uint256,uint256),uint256)" \
    "(0x0000000000000000000000000000000000000000000000000000000000000000,$HASHLOCK,$((0x$BOB_RESOLVER)),$((0x$ALICE)),$((0x$BMN_TOKEN)),$SWAP_AMOUNT,$SAFETY_DEPOSIT,0)" \
    0 \
    --rpc-url $ETHERLINK_RPC_URL 2>/dev/null && echo "Yes" || echo "No"

echo ""
echo -e "${YELLOW}For a complete test, deploy TestEscrowFactory or use the limit order protocol.${NC}"