#!/bin/bash

# Parse the destination escrow address from the latest broadcast file

BROADCAST_FILE="broadcast/LiveTestChains.s.sol/1338/run-latest.json"

if [ ! -f "$BROADCAST_FILE" ]; then
    echo "Error: Broadcast file not found: $BROADCAST_FILE"
    exit 1
fi

# Extract the escrow address from the DstEscrowCreated event data
# The first 32 bytes (64 hex chars) after 0x contain the address (padded to 32 bytes)
DST_ESCROW=$(cat "$BROADCAST_FILE" | jq -r '.receipts[1].logs[1].data' | cut -c 27-66 | sed 's/^/0x/')

if [ -z "$DST_ESCROW" ] || [ "$DST_ESCROW" = "0x" ]; then
    echo "Error: Failed to extract destination escrow address"
    exit 1
fi

echo "$DST_ESCROW"