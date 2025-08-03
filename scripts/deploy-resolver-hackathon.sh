#!/bin/bash

# Hackathon deployment script for CrossChainResolverV2
# Deploys to Base and Etherlink mainnets

set -e

echo "=== BMN CrossChain Resolver Deployment for Hackathon ==="
echo "This script will deploy the resolver infrastructure to Base and Etherlink mainnets"
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found!"
    echo "Please create .env with DEPLOYER_PRIVATE_KEY"
    exit 1
fi

# Check if DEPLOYER_PRIVATE_KEY is set
if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo "Error: DEPLOYER_PRIVATE_KEY not set in .env!"
    exit 1
fi

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Function to deploy to a specific chain
deploy_to_chain() {
    local CHAIN_NAME=$1
    local RPC_URL=$2
    local CHAIN_ID=$3
    
    echo ""
    echo "=== Deploying to $CHAIN_NAME (Chain ID: $CHAIN_ID) ==="
    echo "RPC URL: $RPC_URL"
    
    # Check chain connectivity
    echo "Checking chain connectivity..."
    CURRENT_CHAIN_ID=$(cast chain-id --rpc-url $RPC_URL 2>/dev/null || echo "0")
    
    if [ "$CURRENT_CHAIN_ID" != "$CHAIN_ID" ]; then
        echo "Error: Expected chain ID $CHAIN_ID but got $CURRENT_CHAIN_ID"
        echo "Please check your RPC URL"
        return 1
    fi
    
    # Get deployer balance
    DEPLOYER_ADDRESS=$(cast wallet address $DEPLOYER_PRIVATE_KEY)
    BALANCE=$(cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL --ether || echo "0")
    echo "Deployer address: $DEPLOYER_ADDRESS"
    echo "Deployer balance: $BALANCE ETH"
    
    if [ "$BALANCE" == "0" ]; then
        echo "Warning: Deployer has no balance on $CHAIN_NAME!"
        echo "Please fund the deployer address before continuing."
        read -p "Press Enter to continue anyway, or Ctrl+C to cancel..."
    fi
    
    # Deploy contracts
    echo "Deploying contracts..."
    forge script script/DeployResolverMainnet.s.sol \
        --rpc-url $RPC_URL \
        --broadcast \
        --verify \
        --etherscan-api-key ${ETHERSCAN_API_KEY:-"dummy"} \
        -vvv \
        --slow \
        --legacy \
        2>&1 | tee deployments/${CHAIN_NAME}-deployment.log
    
    echo "Deployment to $CHAIN_NAME completed!"
}

# Deploy to Base Mainnet
echo ""
echo "Step 1: Deploy to Base Mainnet"
read -p "Deploy to Base? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    BASE_RPC=${BASE_RPC_URL:-"https://mainnet.base.org"}
    deploy_to_chain "Base" "$BASE_RPC" "8453"
else
    echo "Skipping Base deployment"
fi

# Deploy to Etherlink Mainnet
echo ""
echo "Step 2: Deploy to Etherlink Mainnet"
read -p "Deploy to Etherlink? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ETHERLINK_RPC=${ETHERLINK_RPC_URL:-"https://node.mainnet.etherlink.com"}
    deploy_to_chain "Etherlink" "$ETHERLINK_RPC" "42793"
else
    echo "Skipping Etherlink deployment"
fi

# Summary
echo ""
echo "=== Deployment Summary ==="
echo "Check the deployment files in the deployments/ directory:"
ls -la deployments/mainnet-*.env 2>/dev/null || echo "No deployment files found"

echo ""
echo "=== Next Steps ==="
echo "1. Verify the contracts on block explorers"
echo "2. Fund the resolver with BMN tokens on both chains"
echo "3. Test the cross-chain swap functionality"
echo ""
echo "To test a swap:"
echo "- On source chain: Call initiateSwap() with BMN tokens"
echo "- On destination chain: Call createDestinationEscrow() as resolver"
echo "- Use withdraw() to complete the swap with the secret"