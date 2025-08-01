#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Usage function
show_usage() {
    echo -e "${BLUE}Test Single Step - Debug Individual Actions${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    echo "Usage: $0 <action> [rpc-url]"
    echo ""
    echo "Available actions:"
    echo "  create-order       - Create order on Chain A"
    echo "  create-src-escrow  - Create source escrow on Chain A"
    echo "  create-dst-escrow  - Create destination escrow on Chain B"
    echo "  withdraw-src       - Withdraw from source escrow"
    echo "  withdraw-dst       - Withdraw from destination escrow"
    echo "  check-balances     - Check current balances"
    echo ""
    echo "Default RPC URLs:"
    echo "  Chain A: http://localhost:8545"
    echo "  Chain B: http://localhost:8546"
    echo ""
    echo "Examples:"
    echo "  $0 create-order"
    echo "  $0 check-balances http://localhost:8545"
    echo "  $0 create-dst-escrow http://localhost:8546"
    echo ""
    echo "Environment variables:"
    echo "  VERBOSE=true       - Show full output"
}

# Check arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

ACTION="$1"
RPC_URL="$2"

# Set default RPC URL based on action
if [ -z "$RPC_URL" ]; then
    case "$ACTION" in
        create-order|create-src-escrow|withdraw-src)
            RPC_URL="http://localhost:8545"
            ;;
        create-dst-escrow|withdraw-dst)
            RPC_URL="http://localhost:8546"
            ;;
        check-balances)
            RPC_URL="http://localhost:8545"
            ;;
        *)
            echo -e "${RED}Unknown action: $ACTION${NC}"
            show_usage
            exit 1
            ;;
    esac
fi

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

# Determine chain name for display
CHAIN_NAME="Chain A"
if [[ "$RPC_URL" == *"8546"* ]]; then
    CHAIN_NAME="Chain B"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Single Step: $ACTION${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "RPC URL: $RPC_URL ($CHAIN_NAME)"
echo -e "Verbose: ${VERBOSE:-false}"
echo ""

# Check if chain is running
PORT=$(echo "$RPC_URL" | grep -o '[0-9]*$')
if ! nc -z localhost "$PORT"; then
    echo -e "${RED}❌ Chain is not running on port $PORT!${NC}"
    echo -e "${YELLOW}Fix: Run './scripts/multi-chain-setup.sh' or 'mprocs'${NC}"
    exit 1
fi

# Show balances before action (except for check-balances)
if [ "$ACTION" != "check-balances" ]; then
    echo -e "${YELLOW}Balances before $ACTION:${NC}"
    ACTION=check-balances forge script script/LiveTestChains.s.sol \
        --rpc-url "$RPC_URL" 2>&1 | grep -E "(Alice|Bob|Token)" || echo -e "${RED}Failed to check balances${NC}"
    echo ""
fi

# Run the specific action
echo -e "${BLUE}Running: $ACTION${NC}"
OUTPUT=$(ACTION="$ACTION" forge script script/LiveTestChains.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --slow \
    -vvv 2>&1)
EXIT_CODE=$?

# Show output based on verbose setting and exit code
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ $ACTION completed successfully${NC}"
    if [ "${VERBOSE:-false}" = "true" ]; then
        echo -e "\n${YELLOW}Full output:${NC}"
        echo "$OUTPUT"
    else
        # Filter known warnings
        echo "$OUTPUT" | grep -v "Warning: Multi chain deployment is still under development" \
            | grep -v "Error: IO error: not a terminal" \
            | grep -v "Warning: EIP-3855" \
            | grep -v "contains a transaction to .* which does not contain any code"
    fi
else
    echo -e "${RED}❌ $ACTION FAILED with exit code $EXIT_CODE${NC}"
    echo -e "\n${YELLOW}Full error output:${NC}"
    echo "$OUTPUT"
    echo -e "${RED}===========================================${NC}"
fi

# Show balances after action (except for check-balances)
if [ "$ACTION" != "check-balances" ]; then
    echo -e "\n${YELLOW}Balances after $ACTION:${NC}"
    ACTION=check-balances forge script script/LiveTestChains.s.sol \
        --rpc-url "$RPC_URL" 2>&1 | grep -E "(Alice|Bob|Token)" || echo -e "${RED}Failed to check balances${NC}"
fi

# Show state file if it exists and was potentially modified
if [ -f "deployments/test-state.json" ] && [ "$ACTION" != "check-balances" ]; then
    echo -e "\n${YELLOW}Current state file:${NC}"
    if command -v jq >/dev/null 2>&1; then
        jq . deployments/test-state.json 2>/dev/null || cat deployments/test-state.json
    else
        cat deployments/test-state.json
    fi
fi

echo -e "\n${BLUE}========================================${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Single step test completed successfully${NC}"
else
    echo -e "${RED}❌ Single step test failed${NC}"
fi
echo -e "${BLUE}========================================${NC}"

exit $EXIT_CODE