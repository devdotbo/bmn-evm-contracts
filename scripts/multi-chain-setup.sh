#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if port is in use
check_port() {
    lsof -i :$1 > /dev/null 2>&1
    return $?
}

# Function to cleanup on exit
cleanup() {
    echo -e "\n${BLUE}Stopping chains...${NC}"
    if [ ! -z "$CHAIN_A_PID" ]; then
        kill $CHAIN_A_PID 2>/dev/null
        echo -e "${GREEN}Chain A stopped${NC}"
    fi
    if [ ! -z "$CHAIN_B_PID" ]; then
        kill $CHAIN_B_PID 2>/dev/null
        echo -e "${GREEN}Chain B stopped${NC}"
    fi
    exit 0
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Check if chains are already running
if check_port 8545; then
    echo -e "${RED}Error: Port 8545 is already in use. Is Chain A already running?${NC}"
    exit 1
fi

if check_port 8546; then
    echo -e "${RED}Error: Port 8546 is already in use. Is Chain B already running?${NC}"
    exit 1
fi

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Clear old logs
rm -f chain-a.log chain-b.log

echo -e "${BLUE}Bridge-Me-Not Multi-Chain Setup${NC}"
echo "================================"

# Start Chain A (Source)
echo -e "${BLUE}Starting Chain A on port 8545...${NC}"
anvil --port 8545 --chain-id 1337 --accounts 10 --balance 10000 > chain-a.log 2>&1 &
CHAIN_A_PID=$!

# Start Chain B (Destination)
echo -e "${BLUE}Starting Chain B on port 8546...${NC}"
anvil --port 8546 --chain-id 1338 --accounts 10 --balance 10000 > chain-b.log 2>&1 &
CHAIN_B_PID=$!

# Wait for chains to start
echo -n "Waiting for chains to start"
for i in {1..10}; do
    sleep 1
    echo -n "."
    if check_port 8545 && check_port 8546; then
        echo -e " ${GREEN}Ready!${NC}"
        break
    fi
done

if ! check_port 8545 || ! check_port 8546; then
    echo -e " ${RED}Failed!${NC}"
    echo -e "${RED}Chains failed to start. Check chain-a.log and chain-b.log for errors.${NC}"
    exit 1
fi

# Deploy on Chain A
echo -e "\n${BLUE}Deploying contracts on Chain A...${NC}"
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast --slow

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment on Chain A failed!${NC}"
    exit 1
fi

# Deploy on Chain B
echo -e "\n${BLUE}Deploying contracts on Chain B...${NC}"
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
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

echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
echo -e "Chain A (1337): ${GREEN}http://localhost:8545${NC}"
echo -e "Chain B (1338): ${GREEN}http://localhost:8546${NC}"
echo -e "Deployment info: ${GREEN}deployments/chainA.json & deployments/chainB.json${NC}"
echo -e "\nTest Accounts:"
echo -e "  Alice: ${BLUE}0x70997970C51812dc3A010C7d01b50e0d17dc79C8${NC}"
echo -e "  Bob:   ${BLUE}0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC${NC}"
echo -e "\n${BLUE}Press Ctrl+C to stop both chains${NC}"

# Wait for interrupt
wait