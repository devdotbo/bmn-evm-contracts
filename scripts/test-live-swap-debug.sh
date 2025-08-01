#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DEBUG: Live Cross-Chain Atomic Swap${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to check balances
check_balances() {
    local chain_name="$1"
    local rpc_url="$2"
    local chain_letter="$3"
    
    echo -e "\n${YELLOW}=== Balances on $chain_name ===${NC}"
    ACTION=check-balances forge script script/LiveTestChains.s.sol \
        --rpc-url "$rpc_url" 2>&1 | grep -E "(Alice|Bob|Token)" || echo -e "${RED}Failed to check balances${NC}"
}

# Function to run step with full error reporting
run_step() {
    local step_name="$1"
    local action="$2"
    local rpc_url="$3"
    
    echo -e "\n${BLUE}$step_name${NC}"
    echo -e "${YELLOW}Running: ACTION=$action forge script script/LiveTestChains.s.sol --rpc-url $rpc_url --broadcast --slow -vvv${NC}"
    
    # Run without error suppression to see what's actually happening
    ACTION="$action" forge script script/LiveTestChains.s.sol \
        --rpc-url "$rpc_url" \
        --broadcast \
        --slow \
        -vvv
    
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}❌ STEP FAILED with exit code $exit_code${NC}"
        echo -e "${RED}This is why balances aren't changing!${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Step completed successfully${NC}"
        return 0
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
echo -e "\n${BLUE}Checking chain connectivity...${NC}"
if ! nc -z localhost 8545; then
    echo -e "${RED}Error: Chain A (port 8545) is not running!${NC}"
    exit 1
fi
if ! nc -z localhost 8546; then
    echo -e "${RED}Error: Chain B (port 8546) is not running!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Both chains are running${NC}"

# Check if deployments exist
if [ ! -f "deployments/chainA.json" ] || [ ! -f "deployments/chainB.json" ]; then
    echo -e "${RED}Error: Deployment files not found!${NC}"
    echo "Please run ./scripts/multi-chain-setup.sh to deploy contracts"
    exit 1
fi
echo -e "${GREEN}✅ Deployment files found${NC}"

# Show initial balances
echo -e "\n${BLUE}=== INITIAL BALANCES ===${NC}"
check_balances "Chain A" "http://localhost:8545" "A"
check_balances "Chain B" "http://localhost:8546" "B"

# Clean up previous test state
echo -e "\n${BLUE}Cleaning up previous test state...${NC}"
rm -f deployments/test-state.json
echo -e "${GREEN}✅ Test state cleared${NC}"

# Step 1: Create order on Chain A
if ! run_step "Step 1: Creating order on Chain A..." "create-order" "http://localhost:8545"; then
    exit 1
fi

# Verify state file was created
if [ ! -f "deployments/test-state.json" ]; then
    echo -e "${RED}❌ State file was not created! Order creation failed.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ State file created successfully${NC}"
echo -e "${YELLOW}State file contents:${NC}"
cat deployments/test-state.json | jq . 2>/dev/null || cat deployments/test-state.json

# Step 2: Create source escrow on Chain A
if ! run_step "Step 2: Creating source escrow on Chain A..." "create-src-escrow" "http://localhost:8545"; then
    exit 1
fi

# Check balances after source escrow creation
echo -e "\n${BLUE}=== BALANCES AFTER SOURCE ESCROW CREATION ===${NC}"
check_balances "Chain A" "http://localhost:8545" "A"

# Step 3: Create destination escrow on Chain B
if ! run_step "Step 3: Creating destination escrow on Chain B..." "create-dst-escrow" "http://localhost:8546"; then
    exit 1
fi

# Check balances after destination escrow creation
echo -e "\n${BLUE}=== BALANCES AFTER DESTINATION ESCROW CREATION ===${NC}"
check_balances "Chain B" "http://localhost:8546" "B"

# Step 4: Withdraw from source escrow on Chain A
if ! run_step "Step 4: Withdrawing from source escrow on Chain A..." "withdraw-src" "http://localhost:8545"; then
    exit 1
fi

# Check balances after source withdrawal
echo -e "\n${BLUE}=== BALANCES AFTER SOURCE WITHDRAWAL ===${NC}"
check_balances "Chain A" "http://localhost:8545" "A"

# Step 5: Withdraw from destination escrow on Chain B
if ! run_step "Step 5: Withdrawing from destination escrow on Chain B..." "withdraw-dst" "http://localhost:8546"; then
    exit 1
fi

# Check final balances
echo -e "\n${BLUE}=== FINAL BALANCES ===${NC}"
check_balances "Chain A" "http://localhost:8545" "A"
check_balances "Chain B" "http://localhost:8546" "B"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ DEBUG: Cross-chain atomic swap test completed!${NC}"
echo -e "${GREEN}========================================${NC}"

# Show expected vs actual results
echo -e "\n${BLUE}Expected Results:${NC}"
echo -e "  Alice should have: 990 TKA on Chain A, 110 TKB on Chain B"
echo -e "  Bob should have: 510 TKA on Chain A, 990 TKB on Chain B"
echo -e "\n${YELLOW}Compare the final balances above with these expected values.${NC}"