#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
VERBOSE=${VERBOSE:-false}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Live Cross-Chain Atomic Swap${NC}"
echo -e "${BLUE}========================================${NC}"
if [ "$VERBOSE" = "true" ]; then
    echo -e "${YELLOW}Running in VERBOSE mode - all output will be shown${NC}"
fi

# Function to check balances on a specific chain
check_chain_balances() {
    local chain_name="$1"
    local rpc_url="$2"
    local prefix="$3"
    
    echo -e "${prefix}${YELLOW}$chain_name balances:${NC}"
    ACTION=check-balances forge script script/LiveTestChains.s.sol \
        --rpc-url "$rpc_url" 2>&1 | grep -E "(Alice|Bob|Token)" || echo -e "${RED}Failed to check $chain_name balances${NC}"
}

# Function to run forge script with proper error handling
run_forge_step() {
    local step_name="$1"
    local action="$2"  
    local rpc_url="$3"
    local show_balances="$4"  # optional: "before-after" to show balance changes
    
    echo -e "\n${BLUE}$step_name${NC}"
    
    # Show balances before if requested
    if [ "$show_balances" = "before-after" ]; then
        echo -e "\n${YELLOW}Balances before $step_name:${NC}"
        check_chain_balances "Chain A" "http://localhost:8545" "  "
        check_chain_balances "Chain B" "http://localhost:8546" "  "
    fi
    
    # Run the command and capture output
    local output
    output=$(ACTION="$action" forge script script/LiveTestChains.s.sol \
        --rpc-url "$rpc_url" \
        --broadcast \
        --slow \
        -vvv 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Success - filter output for readability unless verbose
        if [ "$VERBOSE" = "true" ]; then
            echo "$output"
        else
            echo "$output" | grep -v "Warning: Multi chain deployment is still under development" \
                | grep -v "Error: IO error: not a terminal" \
                | grep -v "Warning: EIP-3855" \
                | grep -v "contains a transaction to .* which does not contain any code"
        fi
        echo -e "${GREEN}✅ $step_name completed successfully${NC}"
        
        # Show balances after if requested
        if [ "$show_balances" = "before-after" ]; then
            echo -e "\n${YELLOW}Balances after $step_name:${NC}"
            check_chain_balances "Chain A" "http://localhost:8545" "  "
            check_chain_balances "Chain B" "http://localhost:8546" "  "
        fi
        
        return 0
    else
        # Failure - always show full output to help debug
        echo -e "${RED}❌ $step_name FAILED with exit code $exit_code${NC}"
        echo -e "${YELLOW}Full error output:${NC}"
        echo "$output"
        echo -e "${RED}===========================================${NC}"
        return $exit_code
    fi
}

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

# Check if chains are running
if ! nc -z localhost 8545 || ! nc -z localhost 8546; then
    echo -e "${RED}Error: Chains are not running!${NC}"
    echo "Please run ./scripts/multi-chain-setup.sh first"
    exit 1
fi

# Check if deployments exist
if [ ! -f "deployments/chainA.json" ] || [ ! -f "deployments/chainB.json" ]; then
    echo -e "${RED}Error: Deployment files not found!${NC}"
    echo "Please run ./scripts/multi-chain-setup.sh to deploy contracts"
    exit 1
fi

# Show initial balances
echo -e "\n${BLUE}=== INITIAL BALANCES ===${NC}"
check_chain_balances "Chain A" "http://localhost:8545" ""
check_chain_balances "Chain B" "http://localhost:8546" ""

# Clean up previous test state
echo -e "\n${BLUE}Cleaning up previous test state...${NC}"
rm -f deployments/test-state.json

# Step 1: Create order on Chain A
if ! run_forge_step "Step 1: Creating order on Chain A" "create-order" "http://localhost:8545"; then
    exit 1
fi

if [ ! -f "deployments/test-state.json" ]; then
    echo -e "${RED}❌ Failed to create order - state file missing!${NC}"
    exit 1
fi

# Step 2: Create source escrow on Chain A (Alice locks tokens)
if ! run_forge_step "Step 2: Creating source escrow on Chain A" "create-src-escrow" "http://localhost:8545" "before-after"; then
    exit 1
fi

# Step 3: Create destination escrow on Chain B (Bob locks tokens)
if ! run_forge_step "Step 3: Creating destination escrow on Chain B" "create-dst-escrow" "http://localhost:8546" "before-after"; then
    exit 1
fi

# Step 4: Withdraw from source escrow on Chain A (Bob gets Alice's tokens)
if ! run_forge_step "Step 4: Withdrawing from source escrow on Chain A" "withdraw-src" "http://localhost:8545" "before-after"; then
    exit 1
fi

# Step 5: Withdraw from destination escrow on Chain B (Alice gets Bob's tokens)
if ! run_forge_step "Step 5: Withdrawing from destination escrow on Chain B" "withdraw-dst" "http://localhost:8546" "before-after"; then
    exit 1
fi

# Check final balances
echo -e "\n${BLUE}=== FINAL BALANCES ===${NC}"
check_chain_balances "Chain A" "http://localhost:8545" ""
check_chain_balances "Chain B" "http://localhost:8546" ""

echo -e "\n${GREEN}✓ Live cross-chain atomic swap test completed!${NC}"
echo -e "${GREEN}Check the balances above to verify the swap was successful.${NC}"
echo -e "\n${BLUE}Expected results:${NC}"
echo -e "  Alice should have: 990 TKA on Chain A, 110 TKB on Chain B"
echo -e "  Bob should have: 510 TKA on Chain A, 990 TKB on Chain B"
echo -e "\n${YELLOW}Usage:${NC}"
echo -e "  Normal mode: ./scripts/test-live-swap.sh"
echo -e "  Verbose mode: VERBOSE=true ./scripts/test-live-swap.sh"