#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Live Cross-Chain Atomic Swap${NC}"
echo -e "${BLUE}========================================${NC}"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

# Check if chains are running
if ! nc -z localhost 8545 || ! nc -z localhost 8546; then
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

# Clean up previous test state
rm -f deployments/test-state.json

# Step 1: Create order on Chain A
echo -e "\n${BLUE}Step 1: Creating order on Chain A...${NC}"
ACTION=create-order forge script script/LiveTestChains.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --slow \
    -vvv 2>&1 | grep -v "Warning: Multi chain deployment is still under development" \
    | grep -v "Error: IO error: not a terminal" \
    | grep -v "Warning: EIP-3855" || true

if [ ! -f "deployments/test-state.json" ]; then
    echo -e "${RED}Failed to create order!${NC}"
    exit 1
fi

# Step 2: Create source escrow on Chain A
echo -e "\n${BLUE}Step 2: Creating source escrow on Chain A...${NC}"
ACTION=create-src-escrow forge script script/LiveTestChains.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --slow \
    -vvv 2>&1 | grep -v "Warning: Multi chain deployment is still under development" \
    | grep -v "Error: IO error: not a terminal" \
    | grep -v "Warning: EIP-3855" \
    | grep -v "contains a transaction to .* which does not contain any code" || true

# Step 3: Create destination escrow on Chain B
echo -e "\n${BLUE}Step 3: Creating destination escrow on Chain B...${NC}"
ACTION=create-dst-escrow forge script script/LiveTestChains.s.sol \
    --rpc-url http://localhost:8546 \
    --broadcast \
    --slow \
    -vvv 2>&1 | grep -v "Warning: Multi chain deployment is still under development" \
    | grep -v "Error: IO error: not a terminal" \
    | grep -v "Warning: EIP-3855" || true

# Step 4: Withdraw from source escrow on Chain A
echo -e "\n${BLUE}Step 4: Withdrawing from source escrow on Chain A...${NC}"
ACTION=withdraw-src forge script script/LiveTestChains.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --slow \
    -vvv 2>&1 | grep -v "Warning: Multi chain deployment is still under development" \
    | grep -v "Error: IO error: not a terminal" \
    | grep -v "Warning: EIP-3855" || true

# Step 5: Withdraw from destination escrow on Chain B
echo -e "\n${BLUE}Step 5: Withdrawing from destination escrow on Chain B...${NC}"
ACTION=withdraw-dst forge script script/LiveTestChains.s.sol \
    --rpc-url http://localhost:8546 \
    --broadcast \
    --slow \
    -vvv 2>&1 | grep -v "Warning: Multi chain deployment is still under development" \
    | grep -v "Error: IO error: not a terminal" \
    | grep -v "Warning: EIP-3855" || true

# Check final balances
echo -e "\n${BLUE}Checking final balances...${NC}"
echo -e "\n${YELLOW}Chain A balances:${NC}"
ACTION=check-balances forge script script/LiveTestChains.s.sol \
    --rpc-url http://localhost:8545 2>&1 | grep -E "(Alice|Bob|Token)" || true

echo -e "\n${YELLOW}Chain B balances:${NC}"
ACTION=check-balances forge script script/LiveTestChains.s.sol \
    --rpc-url http://localhost:8546 2>&1 | grep -E "(Alice|Bob|Token)" || true

echo -e "\n${GREEN}✓ Live cross-chain atomic swap test completed!${NC}"
echo -e "${GREEN}Check the balances above to verify the swap was successful.${NC}"