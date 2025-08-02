#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# RPC URLs
RPC_A="http://localhost:8545"
RPC_B="http://localhost:8546"

echo -e "${BLUE}Chain Timestamp Synchronization${NC}"
echo "================================"

# Function to get current timestamp from a chain
get_timestamp() {
    local rpc_url=$1
    local response=$(curl -s -X POST $rpc_url \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}')
    
    # Extract timestamp (hex) and convert to decimal
    local hex_timestamp=$(echo $response | jq -r '.result.timestamp')
    echo $((16#${hex_timestamp:2}))
}

# Function to set timestamp on a chain
set_timestamp() {
    local rpc_url=$1
    local timestamp=$2
    
    curl -s -X POST $rpc_url \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"anvil_setNextBlockTimestamp\",\"params\":[$timestamp],\"id\":1}" > /dev/null
    
    # Mine a block to apply the timestamp
    curl -s -X POST $rpc_url \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"anvil_mine","params":["0x1"],"id":1}' > /dev/null
}

# Check if chains are running
if ! nc -z localhost 8545 2>/dev/null; then
    echo -e "${RED}Error: Chain A (port 8545) is not running${NC}"
    exit 1
fi

if ! nc -z localhost 8546 2>/dev/null; then
    echo -e "${RED}Error: Chain B (port 8546) is not running${NC}"
    exit 1
fi

# Get current timestamps
echo -e "${YELLOW}Getting current timestamps...${NC}"
TIMESTAMP_A=$(get_timestamp $RPC_A)
TIMESTAMP_B=$(get_timestamp $RPC_B)

echo -e "Chain A timestamp: ${GREEN}$TIMESTAMP_A${NC} ($(date -r $TIMESTAMP_A 2>/dev/null || date -d @$TIMESTAMP_A))"
echo -e "Chain B timestamp: ${GREEN}$TIMESTAMP_B${NC} ($(date -r $TIMESTAMP_B 2>/dev/null || date -d @$TIMESTAMP_B))"

# Calculate difference
DIFF=$((TIMESTAMP_A - TIMESTAMP_B))
ABS_DIFF=${DIFF#-}

echo -e "Timestamp difference: ${YELLOW}$ABS_DIFF seconds${NC}"

# Synchronize if difference is more than 2 seconds
if [ $ABS_DIFF -gt 2 ]; then
    echo -e "${YELLOW}Synchronizing timestamps...${NC}"
    
    # Use the higher timestamp as the target
    if [ $TIMESTAMP_A -gt $TIMESTAMP_B ]; then
        TARGET_TIMESTAMP=$TIMESTAMP_A
        echo -e "Setting Chain B to match Chain A: ${GREEN}$TARGET_TIMESTAMP${NC}"
        set_timestamp $RPC_B $TARGET_TIMESTAMP
    else
        TARGET_TIMESTAMP=$TIMESTAMP_B
        echo -e "Setting Chain A to match Chain B: ${GREEN}$TARGET_TIMESTAMP${NC}"
        set_timestamp $RPC_A $TARGET_TIMESTAMP
    fi
    
    # Verify synchronization
    sleep 1
    NEW_TIMESTAMP_A=$(get_timestamp $RPC_A)
    NEW_TIMESTAMP_B=$(get_timestamp $RPC_B)
    NEW_DIFF=$((NEW_TIMESTAMP_A - NEW_TIMESTAMP_B))
    NEW_ABS_DIFF=${NEW_DIFF#-}
    
    if [ $NEW_ABS_DIFF -le 2 ]; then
        echo -e "${GREEN}✓ Chains synchronized successfully!${NC}"
        echo -e "New difference: ${GREEN}$NEW_ABS_DIFF seconds${NC}"
    else
        echo -e "${RED}✗ Synchronization failed${NC}"
        echo -e "Difference still: ${RED}$NEW_ABS_DIFF seconds${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Chains are already synchronized${NC}"
fi

echo ""
echo -e "${BLUE}Timestamp Monitor Mode${NC}"
echo "Press Ctrl+C to exit"
echo ""

# Continuous monitoring mode
while true; do
    TIMESTAMP_A=$(get_timestamp $RPC_A)
    TIMESTAMP_B=$(get_timestamp $RPC_B)
    DIFF=$((TIMESTAMP_A - TIMESTAMP_B))
    
    # Clear line and print status
    printf "\r${BLUE}Chain A:${NC} %d | ${BLUE}Chain B:${NC} %d | ${BLUE}Diff:${NC} %+d seconds" \
        $TIMESTAMP_A $TIMESTAMP_B $DIFF
    
    # Alert if drift exceeds threshold
    ABS_DIFF=${DIFF#-}
    if [ $ABS_DIFF -gt 5 ]; then
        printf " ${RED}[DRIFT WARNING]${NC}"
    fi
    
    sleep 1
done