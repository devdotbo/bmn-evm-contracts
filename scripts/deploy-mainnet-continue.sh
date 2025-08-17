#!/bin/bash

# Continue deployment to Optimism (Base already deployed)
# Usage: ./scripts/deploy-mainnet-continue.sh

set -e

echo "========================================="
echo "SimplifiedEscrowFactory Deployment (Continue)"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hardcoded configuration
LIMIT_ORDER_PROTOCOL="0x119c71D3BbAC22029622cbaEc24854d3D32D2828"  # 1inch v4 on all chains
RESCUE_DELAY=604800  # 7 days
USE_CREATE3=true
OPTIMISM_RPC_URL="https://mainnet.optimism.io"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}[ERROR] .env file not found!${NC}"
    exit 1
fi

# Source environment variables
source .env

# Validate required environment variables
if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo -e "${RED}[ERROR] DEPLOYER_PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo -e "${RED}[ERROR] ETHERSCAN_API_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$BOB_RESOLVER" ]; then
    echo -e "${RED}[ERROR] BOB_RESOLVER not set in .env${NC}"
    exit 1
fi

# Get deployer address
DEPLOYER_ADDRESS=$(cast wallet address $DEPLOYER_PRIVATE_KEY)
OWNER=$DEPLOYER_ADDRESS  # Owner is the deployer

echo "Configuration:"
echo "  Deployer/Owner: $DEPLOYER_ADDRESS"
echo "  Bob Resolver: $BOB_RESOLVER"
echo "  Limit Order Protocol: $LIMIT_ORDER_PROTOCOL"
echo "  Rescue Delay: $RESCUE_DELAY seconds (7 days)"
echo "  Using CREATE3: $USE_CREATE3"
echo ""

# Show Base deployment status
echo -e "${GREEN}Base deployment already complete:${NC}"
echo "  Factory: 0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3"
echo "  Bob Resolver: Already whitelisted"
echo "  Verified: ✅"
echo ""

echo -e "${YELLOW}Step 1: Building contracts...${NC}"
echo "------------------------------"
forge build

# Create deployments directory
mkdir -p deployments

# Deploy to Optimism
echo ""
echo -e "${YELLOW}Step 2: Deploying to Optimism mainnet (Chain ID: 10)...${NC}"
echo "--------------------------------------------------------"

# Set environment variables for the deployment script
export LIMIT_ORDER_PROTOCOL=$LIMIT_ORDER_PROTOCOL
export OWNER=$OWNER
export RESCUE_DELAY=$RESCUE_DELAY
export USE_CREATE3=$USE_CREATE3

# Deploy with CREATE3 and verify
forge script script/Deploy.s.sol:Deploy \
    --rpc-url $OPTIMISM_RPC_URL \
    --broadcast \
    --verify \
    --verifier etherscan \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --slow \
    -vvv

# Save deployment info and get factory address
echo ""
echo -e "${GREEN}Optimism deployment complete!${NC}"

# Extract factory address from broadcast file
BROADCAST_FILE="broadcast/Deploy.s.sol/10/run-latest.json"
if [ -f "$BROADCAST_FILE" ]; then
    OPTIMISM_FACTORY=$(jq -r '.transactions[] | select(.contractName == "SimplifiedEscrowFactory") | .contractAddress' $BROADCAST_FILE | head -1)
    if [ ! -z "$OPTIMISM_FACTORY" ] && [ "$OPTIMISM_FACTORY" != "null" ]; then
        echo "Factory deployed at: $OPTIMISM_FACTORY"
        echo "OPTIMISM_FACTORY=$OPTIMISM_FACTORY" > deployments/optimism-mainnet.env
        
        # Whitelist Bob resolver on Optimism
        echo ""
        echo -e "${YELLOW}Whitelisting Bob resolver on Optimism...${NC}"
        cast send $OPTIMISM_FACTORY \
            "addResolver(address)" \
            $BOB_RESOLVER \
            --rpc-url $OPTIMISM_RPC_URL \
            --private-key $DEPLOYER_PRIVATE_KEY
        echo -e "${GREEN}Bob resolver whitelisted on Optimism!${NC}"
    else
        echo -e "${RED}[WARNING] Could not extract Optimism factory address${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}Step 3: Deployment Summary...${NC}"
echo "------------------------------"

# Display deployment info
echo ""
echo "Base Mainnet:"
echo "BASE_FACTORY=0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3"
echo "Bob is Resolver: true (already whitelisted)"
echo "Verification: ✅ https://basescan.org/address/0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3#code"

if [ -f "deployments/optimism-mainnet.env" ]; then
    echo ""
    echo "Optimism Mainnet:"
    cat deployments/optimism-mainnet.env
    source deployments/optimism-mainnet.env
    echo "Resolver Count: $(cast call $OPTIMISM_FACTORY "resolverCount()(uint256)" --rpc-url $OPTIMISM_RPC_URL)"
    echo "Bob is Resolver: $(cast call $OPTIMISM_FACTORY "isResolver(address)(bool)" $BOB_RESOLVER --rpc-url $OPTIMISM_RPC_URL)"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "========================================="
echo ""
echo "Deployed Configuration:"
echo "  - Owner: $OWNER"
echo "  - Bob Resolver: $BOB_RESOLVER (whitelisted on both chains)"
echo "  - Limit Order Protocol: $LIMIT_ORDER_PROTOCOL"
echo "  - Rescue Delay: 7 days"
echo ""
echo "Factory Addresses:"
echo "  - Base: 0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3"
echo "  - Optimism: ${OPTIMISM_FACTORY:-PENDING}"
echo ""
echo "Verification Status:"
echo "  - Base: ✅ https://basescan.org/address/0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3#code"
echo "  - Optimism: https://optimistic.etherscan.io/address/${OPTIMISM_FACTORY:-ADDRESS}"
echo ""
echo "Next steps:"
echo "1. Update deployments/deployment.md with both addresses"
echo "2. Configure Bob resolver with the factory addresses"
echo "3. Test the deployment with cross-chain swaps"
