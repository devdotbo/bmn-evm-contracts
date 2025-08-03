#!/bin/bash
set -e

echo "Deploying fixed factories to testnets..."

# Set testnet RPC URLs
BASE_SEPOLIA_RPC="https://lb.drpc.org/base-sepolia/$DRPC_API_KEY"
ETHERLINK_TESTNET_RPC="https://node.ghostnet.etherlink.com"

# Deploy to Base Sepolia
echo -e "\n1. Deploying to Base Sepolia..."
echo "RPC URL: $BASE_SEPOLIA_RPC"

# Only verify if API key is present
if [ -n "$BASESCAN_API_KEY" ]; then
    DEPLOYMENT_NAME=baseSepolia DEPLOY_TEST_FACTORY=true forge script script/DeployFixed.s.sol \
        --rpc-url $BASE_SEPOLIA_RPC \
        --broadcast \
        --verify \
        --etherscan-api-key $BASESCAN_API_KEY \
        -vvv
else
    echo "No Basescan API key found, deploying without verification..."
    DEPLOYMENT_NAME=baseSepolia DEPLOY_TEST_FACTORY=true forge script script/DeployFixed.s.sol \
        --rpc-url $BASE_SEPOLIA_RPC \
        --broadcast \
        -vvv
fi

# Deploy to Etherlink testnet  
echo -e "\n2. Deploying to Etherlink testnet..."
echo "RPC URL: $ETHERLINK_TESTNET_RPC"
DEPLOYMENT_NAME=etherlinkTestnet DEPLOY_TEST_FACTORY=true forge script script/DeployFixed.s.sol \
    --rpc-url $ETHERLINK_TESTNET_RPC \
    --broadcast \
    -vvv

echo -e "\nFixed factory deployment complete!"