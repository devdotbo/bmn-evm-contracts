#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Wait for chains to be ready
echo -e "${BLUE}Waiting for chains to be ready...${NC}"
while ! nc -z localhost 8545 || ! nc -z localhost 8546; do
  sleep 1
  echo -n "."
done
echo -e " ${GREEN}Ready!${NC}"

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Deploy on Chain A
echo -e "\n${BLUE}Deploying contracts on Chain A...${NC}"
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast --slow

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment on Chain A failed!${NC}"
    exit 1
fi

# Deploy on Chain B
echo -e "\n${BLUE}Deploying contracts on Chain B...${NC}"
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8546 --broadcast --slow

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment on Chain B failed!${NC}"
    exit 1
fi

# Copy deployment files to resolver if it exists
if [ -d "../bmn-evm-resolver" ]; then
    echo -e "\n${BLUE}Copying deployment files to resolver...${NC}"
    cp -r deployments ../bmn-evm-resolver/
    echo -e "${GREEN}Deployment files copied${NC}"
fi

echo -e "\n${GREEN}=== Deployment Complete! ===${NC}"
echo -e "Chain A: ${GREEN}deployments/chainA.json${NC}"
echo -e "Chain B: ${GREEN}deployments/chainB.json${NC}"

# Show test accounts
echo -e "\nTest Accounts:"
echo -e "  Alice: ${BLUE}0x70997970C51812dc3A010C7d01b50e0d17dc79C8${NC}"
echo -e "  Bob:   ${BLUE}0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC${NC}"