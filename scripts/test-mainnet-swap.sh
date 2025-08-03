#!/bin/bash
# Test cross-chain swap on mainnet (Base + Etherlink)

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
source .env

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Mainnet Cross-Chain Swap Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if deployment files exist
if [ ! -f "deployments/baseMainnet.json" ] || [ ! -f "deployments/etherlinkMainnet.json" ]; then
    echo -e "${RED}Error: Deployment files not found${NC}"
    echo "Please run deployment script first: ./scripts/deploy-unified.sh base && ./scripts/deploy-unified.sh etherlink"
    exit 1
fi

# Extract contract addresses
FACTORY_BASE=$(jq -r '.contracts.factory' deployments/baseMainnet.json)
FACTORY_ETHERLINK=$(jq -r '.contracts.factory' deployments/etherlinkMainnet.json)
LOP_BASE=$(jq -r '.contracts.limitOrderProtocol' deployments/baseMainnet.json)
LOP_ETHERLINK=$(jq -r '.contracts.limitOrderProtocol' deployments/etherlinkMainnet.json)
TOKEN_A=$(jq -r '.contracts.tokenA' deployments/baseMainnet.json)
TOKEN_B=$(jq -r '.contracts.tokenB' deployments/etherlinkMainnet.json)
ACCESS_TOKEN=$(jq -r '.contracts.accessToken' deployments/baseMainnet.json)
FEE_TOKEN=$(jq -r '.contracts.feeToken' deployments/baseMainnet.json)

echo "Contract Addresses:"
echo "  Factory (both chains): $FACTORY_BASE"
echo "  LOP (both chains): $LOP_BASE"
echo "  Token A (Base): $TOKEN_A"
echo "  Token B (Etherlink): $TOKEN_B"
echo ""

# Check initial balances
echo -e "${YELLOW}=== Initial Balances ===${NC}"
echo -n "Alice TKA on Base: "
cast call $TOKEN_A "balanceOf(address)" $ALICE --rpc-url $CHAIN_A_RPC_URL | xargs -I {} cast --from-wei {}
echo -n "Alice TKB on Etherlink: "
cast call $TOKEN_B "balanceOf(address)" $ALICE --rpc-url $CHAIN_B_RPC_URL | xargs -I {} cast --from-wei {}
echo -n "Bob TKA on Base: "
cast call $TOKEN_A "balanceOf(address)" $BOB_RESOLVER --rpc-url $CHAIN_A_RPC_URL | xargs -I {} cast --from-wei {}
echo -n "Bob TKB on Etherlink: "
cast call $TOKEN_B "balanceOf(address)" $BOB_RESOLVER --rpc-url $CHAIN_B_RPC_URL | xargs -I {} cast --from-wei {}
echo ""

# Test parameters
AMOUNT_TKA="10"  # Alice swaps 10 TKA
AMOUNT_TKB="10"  # For 10 TKB
SAFETY_DEPOSIT="1"  # 1 TKB safety deposit

echo -e "${BLUE}Test: Alice swaps ${AMOUNT_TKA} TKA for ${AMOUNT_TKB} TKB${NC}"
echo ""

# Step 1: Run the cross-chain swap test script
echo -e "${YELLOW}Running cross-chain swap test...${NC}"
echo "This will:"
echo "1. Create order on Base (Alice wants to swap TKA for TKB)"
echo "2. Create source escrow on Base"
echo "3. Deploy destination escrow on Etherlink" 
echo "4. Execute atomic swap"
echo ""

# Run the test using Forge script
forge script script/LiveTestMainnet.s.sol \
    --rpc-url $CHAIN_A_RPC_URL \
    --broadcast \
    -vvv \
    --sig "run()" || {
        echo -e "${RED}Test failed!${NC}"
        exit 1
    }

echo ""
echo -e "${YELLOW}=== Final Balances ===${NC}"
echo -n "Alice TKA on Base: "
cast call $TOKEN_A "balanceOf(address)" $ALICE --rpc-url $CHAIN_A_RPC_URL | xargs -I {} cast --from-wei {}
echo -n "Alice TKB on Etherlink: "
cast call $TOKEN_B "balanceOf(address)" $ALICE --rpc-url $CHAIN_B_RPC_URL | xargs -I {} cast --from-wei {}
echo -n "Bob TKA on Base: "
cast call $TOKEN_A "balanceOf(address)" $BOB_RESOLVER --rpc-url $CHAIN_A_RPC_URL | xargs -I {} cast --from-wei {}
echo -n "Bob TKB on Etherlink: "
cast call $TOKEN_B "balanceOf(address)" $BOB_RESOLVER --rpc-url $CHAIN_B_RPC_URL | xargs -I {} cast --from-wei {}

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Mainnet Cross-Chain Swap Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"