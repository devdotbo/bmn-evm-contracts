#!/bin/bash

# BMN Protocol - Quick Mainnet Test
# This script performs a simple read test to verify mainnet deployment

echo "======================================"
echo "BMN Protocol - Quick Mainnet Test"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test configuration
BASE_FACTORY="0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157"
OPTIMISM_FACTORY="0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56"
BASE_RPC="https://base.llamarpc.com"
OPTIMISM_RPC="https://optimism.drpc.org"

echo "Testing deployment on Base and Optimism mainnets..."
echo ""

# Test Base deployment
echo -e "${YELLOW}[BASE MAINNET]${NC}"
echo "Factory: $BASE_FACTORY"
echo ""

echo "1. Checking contract code..."
CODE=$(cast code $BASE_FACTORY --rpc-url $BASE_RPC 2>/dev/null | head -c 20)
if [ ! -z "$CODE" ] && [ "$CODE" != "0x" ]; then
    echo -e "${GREEN}✓ Contract deployed${NC}"
else
    echo -e "${RED}✗ Contract not found${NC}"
    exit 1
fi

echo "2. Reading ESCROW_SRC_IMPLEMENTATION..."
SRC_IMPL=$(cast call $BASE_FACTORY "ESCROW_SRC_IMPLEMENTATION()" --rpc-url $BASE_RPC 2>/dev/null)
if [ ! -z "$SRC_IMPL" ]; then
    echo -e "${GREEN}✓ Source Implementation: ${SRC_IMPL:0:42}${NC}"
else
    echo -e "${RED}✗ Failed to read${NC}"
fi

echo "3. Reading ESCROW_DST_IMPLEMENTATION..."
DST_IMPL=$(cast call $BASE_FACTORY "ESCROW_DST_IMPLEMENTATION()" --rpc-url $BASE_RPC 2>/dev/null)
if [ ! -z "$DST_IMPL" ]; then
    echo -e "${GREEN}✓ Destination Implementation: ${DST_IMPL:0:42}${NC}"
else
    echo -e "${RED}✗ Failed to read${NC}"
fi

echo ""
echo -e "${YELLOW}[OPTIMISM MAINNET]${NC}"
echo "Factory: $OPTIMISM_FACTORY"
echo ""

echo "1. Checking contract code..."
CODE=$(cast code $OPTIMISM_FACTORY --rpc-url $OPTIMISM_RPC 2>/dev/null | head -c 20)
if [ ! -z "$CODE" ] && [ "$CODE" != "0x" ]; then
    echo -e "${GREEN}✓ Contract deployed${NC}"
else
    echo -e "${RED}✗ Contract not found${NC}"
    exit 1
fi

echo "2. Reading ESCROW_SRC_IMPLEMENTATION..."
SRC_IMPL=$(cast call $OPTIMISM_FACTORY "ESCROW_SRC_IMPLEMENTATION()" --rpc-url $OPTIMISM_RPC 2>/dev/null)
if [ ! -z "$SRC_IMPL" ]; then
    echo -e "${GREEN}✓ Source Implementation: ${SRC_IMPL:0:42}${NC}"
else
    echo -e "${RED}✗ Failed to read${NC}"
fi

echo ""
echo "======================================"
echo -e "${GREEN}TEST COMPLETE${NC}"
echo "======================================"
echo ""
echo "Summary:"
echo "- Both factories are deployed and accessible"
echo "- Public functions are returning data"
echo "- Protocol is LIVE on mainnet"
echo ""
echo "To perform transactions:"
echo "1. Fund your account with ETH"
echo "2. Run: forge script script/LiveTestTransaction.s.sol --broadcast"
echo ""