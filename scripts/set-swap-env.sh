#!/bin/bash

# Set environment variables for the swap from the test run
# Usage: source ./scripts/set-swap-env.sh

echo "Setting swap environment variables..."

# From the test run output
export SWAP_ID=0x9bd1f92fdaa220a9f77ba021590c24a601f8e9b48c43c05c0a6f710b1de9552c
export SECRET=0x1a0ff4cb885a06c95aa7951dff21b154b71e55ad064b34bd5f1377966ba7ace5
export HASHLOCK=0xe6f4bcb088e7708f146c0afc4e42d5f61b49db23f4023ea87d806596f5a24e23

# Set resolver key (you need to set this in your .env file)
export RESOLVER_PRIVATE_KEY=${RESOLVER_PRIVATE_KEY:-$DEPLOYER_PRIVATE_KEY}

echo "Swap environment variables set:"
echo "SWAP_ID: $SWAP_ID"
echo "SECRET: $SECRET"
echo "HASHLOCK: $HASHLOCK"
echo ""
echo "Now you can run:"
echo "1. On Etherlink: forge script script/CompleteResolverSwap.s.sol --rpc-url \$ETHERLINK_RPC_URL --broadcast"
echo "2. On Base: forge script script/CompleteResolverSwap.s.sol --rpc-url \$BASE_RPC_URL --broadcast"