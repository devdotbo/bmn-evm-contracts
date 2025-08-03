#!/bin/bash

# BMN V2 Verification Script

echo "=== Verifying BMN Access Token V2 on Basescan ==="

# Contract details
CONTRACT_ADDRESS="0x886857ec119B59F26F0DD2C3234353C0bce2977f"
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0)

echo "Contract: BMNAccessTokenV2"
echo "Address: $CONTRACT_ADDRESS"
echo "Constructor args: $CONSTRUCTOR_ARGS"

# Load environment
source .env

# Verify on Base
echo -e "\nVerifying on Base mainnet..."
forge verify-contract \
    --chain-id 8453 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $CONSTRUCTOR_ARGS \
    --compiler-version "v0.8.23+commit.f704f362" \
    --via-ir \
    $CONTRACT_ADDRESS \
    contracts/BMNAccessTokenV2.sol:BMNAccessTokenV2

echo -e "\nDone! Check verification status at:"
echo "https://basescan.org/address/$CONTRACT_ADDRESS#code"