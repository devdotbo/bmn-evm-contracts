#!/bin/bash

# Deploy SimplifiedEscrowFactory v2.2.0 with PostInteraction to mainnet
# This script deploys to Base and Optimism using CREATE3 for deterministic addresses

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}SimplifiedEscrowFactory v2.2.0 Mainnet Deployment${NC}"
echo -e "${BLUE}================================================${NC}"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create a .env file with:"
    echo "  DEPLOYER_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE"
    echo "  BASE_RPC_URL=https://base-mainnet.infura.io/v3/YOUR_INFURA_KEY_HERE"
    echo "  OPTIMISM_RPC_URL=https://optimism-mainnet.infura.io/v3/YOUR_INFURA_KEY_HERE"
    echo "  INITIAL_RESOLVERS=address1,address2,address3 (optional)"
    exit 1
fi

# Source environment variables
source .env

# Validate required environment variables
if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo -e "${RED}Error: DEPLOYER_PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$BASE_RPC_URL" ]; then
    echo -e "${RED}Error: BASE_RPC_URL not set in .env${NC}"
    exit 1
fi

if [ -z "$OPTIMISM_RPC_URL" ]; then
    echo -e "${RED}Error: OPTIMISM_RPC_URL not set in .env${NC}"
    exit 1
fi

# Function to deploy to a specific chain
deploy_to_chain() {
    local CHAIN_NAME=$1
    local RPC_URL=$2
    local CHAIN_ID=$3
    
    echo -e "\n${YELLOW}Deploying to $CHAIN_NAME (Chain ID: $CHAIN_ID)...${NC}"
    
    # Run deployment script
    forge script script/DeployV2_2_Mainnet.s.sol \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --verify \
        --slow \
        -vvv
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully deployed to $CHAIN_NAME${NC}"
    else
        echo -e "${RED}✗ Failed to deploy to $CHAIN_NAME${NC}"
        return 1
    fi
}

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Deploy to Base
echo -e "\n${BLUE}[1/2] Deploying to Base Mainnet${NC}"
deploy_to_chain "Base" "$BASE_RPC_URL" "8453"

# Deploy to Optimism
echo -e "\n${BLUE}[2/2] Deploying to Optimism Mainnet${NC}"
deploy_to_chain "Optimism" "$OPTIMISM_RPC_URL" "10"

# Show deployment summary
echo -e "\n${BLUE}================================================${NC}"
echo -e "${BLUE}Deployment Summary${NC}"
echo -e "${BLUE}================================================${NC}"

# Read deployment files and extract factory address
if [ -f "deployments/v2.2.0-mainnet-8453.env" ]; then
    echo -e "\n${GREEN}Base Deployment:${NC}"
    grep "SIMPLIFIED_ESCROW_FACTORY=" deployments/v2.2.0-mainnet-8453.env
fi

if [ -f "deployments/v2.2.0-mainnet-10.env" ]; then
    echo -e "\n${GREEN}Optimism Deployment:${NC}"
    grep "SIMPLIFIED_ESCROW_FACTORY=" deployments/v2.2.0-mainnet-10.env
fi

# Calculate deterministic factory address
FACTORY_ADDRESS=$(cast create2 \
    --deployer 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d \
    --salt $(cast keccak "BMN-SimplifiedEscrowFactory-v2.2.0-PostInteraction") \
    --init-code-hash $(cast keccak $(forge inspect SimplifiedEscrowFactory bytecode)) \
    2>/dev/null | grep "Address:" | awk '{print $2}' || echo "Calculate manually")

echo -e "\n${YELLOW}Expected Factory Address (all chains): $FACTORY_ADDRESS${NC}"

echo -e "\n${BLUE}================================================${NC}"
echo -e "${BLUE}Post-Deployment Checklist${NC}"
echo -e "${BLUE}================================================${NC}"
echo "[ ] 1. Verify contracts on Etherscan/Basescan"
echo "[ ] 2. Transfer ownership to multisig wallet"
echo "[ ] 3. Whitelist production resolvers"
echo "[ ] 4. Configure 1inch SimpleLimitOrderProtocol"
echo "[ ] 5. Update resolver infrastructure to use new factory"
echo "[ ] 6. Test PostInteraction with small amounts"
echo "[ ] 7. Monitor initial transactions"
echo "[ ] 8. Update documentation with new addresses"

echo -e "\n${GREEN}Deployment script completed!${NC}"