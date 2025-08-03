#!/bin/bash
# Test script using 1inch's same-transaction deployment pattern

set -e  # Exit on error

echo "=========================================="
echo "Testing Improved Pattern (1inch approach)"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if anvil instances are running
check_chains() {
    if ! nc -z localhost 8545 2>/dev/null; then
        echo -e "${RED}Error: Chain A (localhost:8545) is not running${NC}"
        echo "Please run: mprocs"
        exit 1
    fi
    
    if ! nc -z localhost 8546 2>/dev/null; then
        echo -e "${RED}Error: Chain B (localhost:8546) is not running${NC}"
        echo "Please run: mprocs"
        exit 1
    fi
    
    echo -e "${GREEN}[OK] Both chains are running${NC}"
}

# Run a forge script command
run_step() {
    local action=$1
    local chain=$2
    local description=$3
    
    echo -e "\n${YELLOW}Step: $description${NC}"
    echo "Running: ACTION=$action on chain $chain"
    
    ACTION=$action forge script script/LiveTestChainsImproved.s.sol \
        --rpc-url http://localhost:$chain \
        --broadcast \
        -vv 2>&1 | grep -E "(Source escrow|Destination escrow|Actual escrow|Expected escrow|Addresses match|Alice received|Bob received|SUCCESS|Escrow address:|Escrow token balance:|balance before:|balance after:|Calling as|right after deployment)" || true
}

# Main test flow
main() {
    echo "Checking chain connectivity..."
    check_chains
    
    echo -e "\n${GREEN}Starting improved cross-chain swap test...${NC}"
    
    # Clean up old state file
    rm -f deployments/test-state-improved.json
    
    # Check initial balances
    echo -e "\n${YELLOW}Initial balances on Chain A:${NC}"
    ACTION=check-balances forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8545 2>&1 | grep -A 10 "Current Balances" || true
    
    echo -e "\n${YELLOW}Initial balances on Chain B:${NC}"
    ACTION=check-balances forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8546 2>&1 | grep -A 10 "Current Balances" || true
    
    # Execute swap steps
    run_step "create-src-escrow" "8545" "Creating source escrow with improved pattern"
    sleep 2
    
    run_step "create-dst-escrow" "8546" "Creating destination escrow"
    sleep 2
    
    run_step "withdraw-dst" "8546" "Alice withdraws from destination (reveals secret)"
    sleep 2
    
    run_step "withdraw-src" "8545" "Bob withdraws from source (uses revealed secret)"
    
    # Check final balances
    echo -e "\n${YELLOW}Final balances on Chain A:${NC}"
    ACTION=check-balances forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8545 2>&1 | grep -A 10 "Current Balances" || true
    
    echo -e "\n${YELLOW}Final balances on Chain B:${NC}"
    ACTION=check-balances forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8546 2>&1 | grep -A 10 "Current Balances" || true
    
    echo -e "\n${GREEN}SUCCESS: Test completed!${NC}"
    echo ""
    echo "Expected results:"
    echo "- Alice: Lost 10 TKA, gained 10 TKB"
    echo "- Bob: Gained 10 TKA, lost 10 TKB"
}

main "$@"