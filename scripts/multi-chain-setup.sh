#!/bin/bash

# Start Chain A (Source)
echo "Starting Chain A on port 8545..."
anvil --port 8545 --chain-id 1337 > chain-a.log 2>&1 &
CHAIN_A_PID=$!

# Start Chain B (Destination)
echo "Starting Chain B on port 8546..."
anvil --port 8546 --chain-id 1338 > chain-b.log 2>&1 &
CHAIN_B_PID=$!

sleep 2

# Deploy on Chain A
echo "Deploying on Chain A..."
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy on Chain B
echo "Deploying on Chain B..."
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8546 --broadcast

echo "Setup complete!"
echo "Chain A PID: $CHAIN_A_PID"
echo "Chain B PID: $CHAIN_B_PID"
echo "Press Ctrl+C to stop both chains"

# Wait for interrupt
wait