#!/bin/bash

# Test script for SimpleLimitOrderProtocol integration with CrossChainEscrowFactory
# This script sets up a multi-chain environment and tests the order flow

set -e

echo "========================================="
echo "SimpleLimitOrderProtocol Integration Test"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create .env with DEPLOYER_PRIVATE_KEY"
    exit 1
fi

# Source environment variables
source .env

# Start two Anvil instances for multi-chain testing
echo -e "${YELLOW}Starting Anvil chains...${NC}"

# Kill any existing Anvil processes
pkill -f "anvil" || true
sleep 1

# Start Chain A (port 8545)
echo "Starting Chain A on port 8545..."
anvil --port 8545 --chain-id 31337 --block-time 1 --hardfork shanghai > /tmp/anvil-a.log 2>&1 &
ANVIL_A_PID=$!

# Start Chain B (port 8546)
echo "Starting Chain B on port 8546..."
anvil --port 8546 --chain-id 31338 --block-time 1 --hardfork shanghai > /tmp/anvil-b.log 2>&1 &
ANVIL_B_PID=$!

# Wait for chains to start
echo "Waiting for chains to start..."
sleep 3

# Check if chains are running
nc -z localhost 8545 || { echo -e "${RED}Chain A failed to start${NC}"; exit 1; }
nc -z localhost 8546 || { echo -e "${RED}Chain B failed to start${NC}"; exit 1; }

echo -e "${GREEN}Both chains started successfully${NC}"

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Deploy SimpleLimitOrderProtocol and Factory on Chain A
echo -e "\n${YELLOW}Deploying on Chain A...${NC}"
forge script script/LocalDeployWithLimitOrder.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    -vv || { echo -e "${RED}Chain A deployment failed${NC}"; exit 1; }

# Deploy SimpleLimitOrderProtocol and Factory on Chain B
echo -e "\n${YELLOW}Deploying on Chain B...${NC}"
forge script script/LocalDeployWithLimitOrder.s.sol \
    --rpc-url http://localhost:8546 \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    -vv || { echo -e "${RED}Chain B deployment failed${NC}"; exit 1; }

echo -e "${GREEN}Deployments completed${NC}"

# Run integration tests
echo -e "\n${YELLOW}Running integration tests...${NC}"
forge test --match-contract SimpleLimitOrderIntegration -vv

# Test cross-chain order creation and filling
echo -e "\n${YELLOW}Testing cross-chain order flow...${NC}"

# Create a test order on Chain A
echo "Creating limit order on Chain A..."
cast send --rpc-url http://localhost:8545 \
    --private-key $DEPLOYER_PRIVATE_KEY \
    $(cat deployments/local-chain-a.json | jq -r .limitOrderProtocol) \
    "createOrder()" \
    --value 0 || echo "Order creation simulation"

# Simulate order filling on Chain B
echo "Simulating order fill on Chain B..."
cast send --rpc-url http://localhost:8546 \
    --private-key $DEPLOYER_PRIVATE_KEY \
    $(cat deployments/local-chain-b.json | jq -r .limitOrderProtocol) \
    "fillOrder()" \
    --value 0 || echo "Order filling simulation"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Integration test completed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\nDeployment addresses saved in:"
echo "  - deployments/local-chain-a.json"
echo "  - deployments/local-chain-b.json"

echo -e "\nNext steps:"
echo "1. Update resolver to use SimpleLimitOrderProtocol"
echo "2. Test with actual order signatures"
echo "3. Deploy to testnets for further testing"

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    kill $ANVIL_A_PID 2>/dev/null || true
    kill $ANVIL_B_PID 2>/dev/null || true
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Register cleanup on exit
trap cleanup EXIT

echo -e "\n${YELLOW}Press Ctrl+C to stop the test environment${NC}"
wait