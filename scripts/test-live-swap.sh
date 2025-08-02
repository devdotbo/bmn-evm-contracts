#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
VERBOSE=${VERBOSE:-false}

# Source timing helpers
source scripts/timing-helpers.sh

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
echo -e "\n${BLUE}Checking prerequisites...${NC}"
if ! nc -z localhost 8545; then
    echo -e "${RED}❌ Chain A (port 8545) is not running!${NC}"
    echo -e "${YELLOW}Fix: Run './scripts/multi-chain-setup.sh' or 'mprocs'${NC}"
    exit 1
fi
if ! nc -z localhost 8546; then
    echo -e "${RED}❌ Chain B (port 8546) is not running!${NC}"
    echo -e "${YELLOW}Fix: Run './scripts/multi-chain-setup.sh' or 'mprocs'${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Both chains are running${NC}"

# Check if deployments exist
if [ ! -f "deployments/chainA.json" ]; then
    echo -e "${RED}❌ Chain A deployment file not found!${NC}"
    echo -e "${YELLOW}Fix: Run './scripts/deploy-both-chains.sh'${NC}"
    exit 1
fi
if [ ! -f "deployments/chainB.json" ]; then
    echo -e "${RED}❌ Chain B deployment file not found!${NC}"
    echo -e "${YELLOW}Fix: Run './scripts/deploy-both-chains.sh'${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Deployment files found${NC}"

# Check if .env file exists and has required variables
if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo -e "${RED}❌ DEPLOYER_PRIVATE_KEY not set!${NC}"
    echo -e "${YELLOW}Fix: Create .env file with DEPLOYER_PRIVATE_KEY${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Environment variables configured${NC}"

# Synchronize chain timestamps before starting
echo -e "\n${BLUE}Synchronizing chain timestamps...${NC}"
./scripts/sync-chain-timestamps.sh >/dev/null 2>&1 &
SYNC_PID=$!
sleep 2
kill $SYNC_PID 2>/dev/null

# Record test start time
TEST_START_TIME=$(get_chain_timestamp "http://localhost:8545")
echo -e "${GREEN}✅ Test starting at timestamp: $TEST_START_TIME${NC}"

# Show initial balances
echo -e "\n${BLUE}=== INITIAL BALANCES ===${NC}"
check_chain_balances "Chain A" "http://localhost:8545" ""
check_chain_balances "Chain B" "http://localhost:8546" ""

# Show initial timing status
show_timing_status $TEST_START_TIME

# Clean up previous test state
echo -e "\n${BLUE}Cleaning up previous test state...${NC}"
rm -f deployments/test-state.json

# Step 1: Create order on Chain A
echo -e "\n${MAGENTA}=== PHASE 1: Order Creation ===${NC}"
show_timing_status $TEST_START_TIME
if ! run_forge_step "Step 1: Creating order on Chain A" "create-order" "http://localhost:8545"; then
    exit 1
fi

if [ ! -f "deployments/test-state.json" ]; then
    echo -e "${RED}❌ Failed to create order - state file missing!${NC}"
    echo -e "${YELLOW}This usually means the order creation transaction failed.${NC}"
    echo -e "${YELLOW}Try running: VERBOSE=true ./scripts/test-live-swap.sh to see full output${NC}"
    exit 1
fi

# Validate state file content
echo -e "${GREEN}✅ State file created, validating content...${NC}"
if command -v jq >/dev/null 2>&1; then
    # Validate JSON and check required fields
    if ! jq . deployments/test-state.json >/dev/null 2>&1; then
        echo -e "${RED}❌ State file contains invalid JSON${NC}"
        exit 1
    fi
    
    # Check for required fields
    for field in secret hashlock orderHash timestamp; do
        if ! jq -e ".$field" deployments/test-state.json >/dev/null 2>&1; then
            echo -e "${RED}❌ State file missing required field: $field${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}✅ State file validation passed${NC}"
else
    echo -e "${YELLOW}⚠ jq not found, skipping detailed state file validation${NC}"
    cat deployments/test-state.json
fi

# Step 2: Create source escrow on Chain A (Alice locks tokens)
echo -e "\n${MAGENTA}=== PHASE 2: Escrow Creation ===${NC}"
show_timing_status $TEST_START_TIME
if ! run_forge_step "Step 2: Creating source escrow on Chain A" "create-src-escrow" "http://localhost:8545" "before-after"; then
    exit 1
fi

# Step 3: Create destination escrow on Chain B (Bob locks tokens)
if ! run_forge_step "Step 3: Creating destination escrow on Chain B" "create-dst-escrow" "http://localhost:8546" "before-after"; then
    exit 1
fi

# Step 4: Withdraw from source escrow on Chain A (Bob gets Alice's tokens)
echo -e "\n${MAGENTA}=== PHASE 3: Secret Reveal & Withdrawal ===${NC}"
show_timing_status $TEST_START_TIME
echo -e "${YELLOW}Note: Withdrawals should complete within the withdrawal window (0-30s)${NC}"
if ! run_forge_step "Step 4: Withdrawing from source escrow on Chain A" "withdraw-src" "http://localhost:8545" "before-after"; then
    exit 1
fi

# Step 5: Withdraw from destination escrow on Chain B (Alice gets Bob's tokens)
if ! run_forge_step "Step 5: Withdrawing from destination escrow on Chain B" "withdraw-dst" "http://localhost:8546" "before-after"; then
    exit 1
fi

# Check final balances
echo -e "\n${BLUE}=== FINAL BALANCES ===${NC}"
show_timing_status $TEST_START_TIME
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
echo -e "  Debug version: ./scripts/test-live-swap-debug.sh"

echo -e "\n${BLUE}Troubleshooting:${NC}"
echo -e "  If balances don't change:"
echo -e "    1. Check that you're running the right script (test-live-swap.sh, not test-live-chains.sh)"
echo -e "    2. Run with VERBOSE=true to see full transaction output"
echo -e "    3. Check that both chains are running: nc -z localhost 8545 && nc -z localhost 8546"
echo -e "    4. Verify deployments exist: ls -la deployments/"
echo -e "    5. Check initial balances with: ./scripts/check-deployment.sh"
echo -e "  If transactions fail:"
echo -e "    1. Ensure accounts have sufficient ETH for gas"
echo -e "    2. Check .env file has correct DEPLOYER_PRIVATE_KEY"
echo -e "    3. Restart chains if needed: pkill anvil && ./scripts/multi-chain-setup.sh"