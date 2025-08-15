#!/bin/bash

# Deploy BMN Protocol to mainnet chains
# Usage: VERSION=v3.0.0 ./scripts/deploy-mainnet.sh

set -e

# Get version from environment or default to v3.0.0
VERSION="${VERSION:-v3.0.0}"

echo "========================================="
echo "BMN Protocol Mainnet Deployment"
echo "Version: $VERSION"
echo "========================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "[ERROR] .env file not found!"
    echo "Please create .env with required keys:"
    echo "  - DEPLOYER_PRIVATE_KEY"
    echo "  - BASE_RPC_URL or OPTIMISM_RPC_URL"
    echo "  - BASESCAN_API_KEY (for Base)"
    echo "  - OPTIMISTIC_ETHERSCAN_API_KEY (for Optimism)"
    exit 1
fi

# Source environment variables
source .env

# Validate required environment variables
if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo "[ERROR] DEPLOYER_PRIVATE_KEY not set in .env"
    exit 1
fi

echo "Step 1: Building contracts..."
echo "------------------------------"
forge build

# Deploy to Base if RPC URL is set
if [ ! -z "$BASE_RPC_URL" ]; then
    echo ""
    echo "Step 2: Deploying to Base mainnet (Chain ID: 8453)..."
    echo "------------------------------------------------------"
    VERSION=$VERSION forge script script/DeployMainnet.s.sol \
        --rpc-url $BASE_RPC_URL \
        --broadcast \
        --verify \
        --etherscan-api-key $BASESCAN_API_KEY \
        -vvv
else
    echo "[SKIP] BASE_RPC_URL not set, skipping Base deployment"
fi

# Deploy to Optimism if RPC URL is set
if [ ! -z "$OPTIMISM_RPC_URL" ]; then
    echo ""
    echo "Step 3: Deploying to Optimism mainnet (Chain ID: 10)..."
    echo "--------------------------------------------------------"
    VERSION=$VERSION forge script script/DeployMainnet.s.sol \
        --rpc-url $OPTIMISM_RPC_URL \
        --broadcast \
        --verify \
        --etherscan-api-key $OPTIMISTIC_ETHERSCAN_API_KEY \
        -vvv
else
    echo "[SKIP] OPTIMISM_RPC_URL not set, skipping Optimism deployment"
fi

echo ""
echo "Step 4: Deployment Summary..."
echo "------------------------------"

# Display deployment info for each chain
for file in deployments/${VERSION}-*.env; do
    if [ -f "$file" ]; then
        echo ""
        echo "Found deployment: $(basename $file)"
        cat "$file" | grep -E "^(FACTORY_ADDRESS|CHAIN_ID)="
    fi
done

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Check contract verification on explorers"
echo "2. Update deployment.md with new addresses"
echo "3. Run tests to verify deployment"
echo ""