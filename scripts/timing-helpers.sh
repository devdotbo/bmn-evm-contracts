#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to get current timestamp from a chain
get_chain_timestamp() {
    local rpc_url=$1
    local response=$(curl -s -X POST $rpc_url \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}')
    
    local hex_timestamp=$(echo $response | jq -r '.result.timestamp')
    echo $((16#${hex_timestamp:2}))
}

# Function to get block number from a chain
get_block_number() {
    local rpc_url=$1
    local response=$(curl -s -X POST $rpc_url \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')
    
    local hex_block=$(echo $response | jq -r '.result')
    echo $((16#${hex_block:2}))
}

# Function to wait for specific timestamp
wait_for_timestamp() {
    local rpc_url=$1
    local target_timestamp=$2
    local chain_name=$3
    
    echo -e "${YELLOW}Waiting for $chain_name to reach timestamp $target_timestamp...${NC}"
    
    while true; do
        local current=$(get_chain_timestamp $rpc_url)
        if [ $current -ge $target_timestamp ]; then
            echo -e "${GREEN}✓ $chain_name reached target timestamp: $current${NC}"
            break
        fi
        
        local remaining=$((target_timestamp - current))
        printf "\r${BLUE}$chain_name:${NC} Current: %d, Target: %d, Remaining: %d seconds" \
            $current $target_timestamp $remaining
        
        sleep 0.5
    done
    echo ""
}

# Function to mine blocks until timestamp
mine_to_timestamp() {
    local rpc_url=$1
    local target_timestamp=$2
    local chain_name=$3
    
    echo -e "${YELLOW}Mining $chain_name to timestamp $target_timestamp...${NC}"
    
    # Set next block timestamp
    curl -s -X POST $rpc_url \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"anvil_setNextBlockTimestamp\",\"params\":[$target_timestamp],\"id\":1}" > /dev/null
    
    # Mine one block
    curl -s -X POST $rpc_url \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"anvil_mine","params":["0x1"],"id":1}' > /dev/null
    
    local new_timestamp=$(get_chain_timestamp $rpc_url)
    echo -e "${GREEN}✓ $chain_name mined to timestamp: $new_timestamp${NC}"
}

# Function to display timing status
show_timing_status() {
    local test_start_time=$1
    
    echo -e "\n${MAGENTA}=== Timing Status ===${NC}"
    
    # Get timestamps
    local ts_a=$(get_chain_timestamp "http://localhost:8545")
    local ts_b=$(get_chain_timestamp "http://localhost:8546")
    local block_a=$(get_block_number "http://localhost:8545")
    local block_b=$(get_block_number "http://localhost:8546")
    
    # Calculate elapsed time
    local elapsed_a=$((ts_a - test_start_time))
    local elapsed_b=$((ts_b - test_start_time))
    local drift=$((ts_a - ts_b))
    
    echo -e "${BLUE}Chain A:${NC}"
    echo -e "  Timestamp: ${GREEN}$ts_a${NC} ($(date -r $ts_a 2>/dev/null || date -d @$ts_a))"
    echo -e "  Block: ${GREEN}$block_a${NC}"
    echo -e "  Elapsed: ${GREEN}$elapsed_a seconds${NC}"
    
    echo -e "${BLUE}Chain B:${NC}"
    echo -e "  Timestamp: ${GREEN}$ts_b${NC} ($(date -r $ts_b 2>/dev/null || date -d @$ts_b))"
    echo -e "  Block: ${GREEN}$block_b${NC}"
    echo -e "  Elapsed: ${GREEN}$elapsed_b seconds${NC}"
    
    echo -e "${BLUE}Drift:${NC} ${YELLOW}$drift seconds${NC}"
    
    # Check timelock windows
    echo -e "\n${BLUE}Timelock Windows:${NC}"
    echo -e "  Withdrawal: ${GREEN}Active${NC} (started at $test_start_time)"
    
    if [ $elapsed_a -ge 10 ]; then
        echo -e "  Public Withdrawal: ${GREEN}Active${NC} (started at $((test_start_time + 10)))"
    else
        echo -e "  Public Withdrawal: ${YELLOW}Pending${NC} (starts in $((10 - elapsed_a))s)"
    fi
    
    if [ $elapsed_a -ge 30 ]; then
        echo -e "  Cancellation: ${GREEN}Active${NC} (started at $((test_start_time + 30)))"
    else
        echo -e "  Cancellation: ${YELLOW}Pending${NC} (starts in $((30 - elapsed_a))s)"
    fi
    
    if [ $elapsed_a -ge 45 ]; then
        echo -e "  Public Cancellation: ${GREEN}Active${NC} (started at $((test_start_time + 45)))"
    else
        echo -e "  Public Cancellation: ${YELLOW}Pending${NC} (starts in $((45 - elapsed_a))s)"
    fi
    
    echo ""
}

# Export functions for use in other scripts
export -f get_chain_timestamp
export -f get_block_number
export -f wait_for_timestamp
export -f mine_to_timestamp
export -f show_timing_status

# If called directly with arguments
if [ "$1" == "status" ]; then
    show_timing_status ${2:-$(get_chain_timestamp "http://localhost:8545")}
elif [ "$1" == "sync" ]; then
    ./scripts/sync-chain-timestamps.sh
elif [ "$1" == "wait" ]; then
    wait_for_timestamp "http://localhost:8545" $2 "Chain A"
elif [ "$1" == "mine" ]; then
    mine_to_timestamp "http://localhost:8545" $2 "Chain A"
fi