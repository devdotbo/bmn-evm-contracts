#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Cross-Chain Atomic Swap${NC}"
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

# Run the test script
echo -e "\n${BLUE}Running cross-chain test script...${NC}"
forge script script/TestLiveChains.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --slow \
    -vvv

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Cross-chain atomic swap test completed successfully!${NC}"
    
    # Optional: Check final balances
    echo -e "\n${BLUE}Checking final balances...${NC}"
    ./scripts/check-deployment.sh | grep -E "(Alice|Bob|Token)"
else
    echo -e "\n${RED}✗ Test failed!${NC}"
    exit 1
fi