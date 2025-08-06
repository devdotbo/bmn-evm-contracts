#!/bin/bash

# Deploy CrossChainEscrowFactory v2.1.0 locally with Bob whitelisted

set -e

echo "========================================"
echo "Local Deployment of Factory v2.1.0"
echo "========================================"

# Check if chains are running
if ! nc -z localhost 8545; then
    echo "[ERROR] Chain A not running on port 8545"
    echo "Run: ./scripts/multi-chain-setup.sh"
    exit 1
fi

if ! nc -z localhost 8546; then
    echo "[ERROR] Chain B not running on port 8546"
    echo "Run: ./scripts/multi-chain-setup.sh"
    exit 1
fi

# Default test accounts
DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
BOB_ADDRESS="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

echo ""
echo "[INFO] Deploying to Chain A (port 8545)..."
echo "========================================"

# Deploy to Chain A
forge script script/LocalDeployV2.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key $DEPLOYER_KEY \
    --broadcast \
    -vvv

echo ""
echo "[INFO] Deploying to Chain B (port 8546)..."
echo "========================================"

# Deploy to Chain B
forge script script/LocalDeployV2.s.sol \
    --rpc-url http://localhost:8546 \
    --private-key $DEPLOYER_KEY \
    --broadcast \
    -vvv

echo ""
echo "========================================"
echo "DEPLOYMENT COMPLETE"
echo "========================================"
echo ""
echo "[NEXT STEPS]"
echo "1. Bob ($BOB_ADDRESS) is now whitelisted on both chains"
echo "2. Factory v2.1.0 with security features is deployed"
echo "3. Tokens are minted for test accounts"
echo "4. Ready for cross-chain atomic swaps"
echo ""
echo "[DEPLOYMENT FILES]"
echo "- deployments/local-chain-a-v2.json"
echo "- deployments/local-chain-b-v2.json"
echo ""
echo "[TEST COMMAND]"
echo "Run a test swap: ./scripts/test-live-swap.sh"