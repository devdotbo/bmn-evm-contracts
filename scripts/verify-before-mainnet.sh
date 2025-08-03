#!/bin/bash
set -e

# Pre-mainnet verification script
# This ensures our CREATE2 fix will work correctly before deploying to mainnet

source .env

echo "=== Pre-Mainnet Verification ==="
echo "This script verifies the CREATE2 fix is ready for mainnet"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Track overall status
ALL_TESTS_PASSED=true

# 1. Verify local test passes
echo -e "${YELLOW}1. Running local verification...${NC}"
if [ -f "./scripts/quick-create2-test.sh" ]; then
    ./scripts/quick-create2-test.sh > /tmp/local-test.log 2>&1
    if grep -q "FIX IS WORKING!" /tmp/local-test.log; then
        echo -e "${GREEN}✓ Local CREATE2 test passed${NC}"
    else
        echo -e "${RED}✗ Local CREATE2 test failed${NC}"
        ALL_TESTS_PASSED=false
    fi
else
    echo -e "${RED}✗ Local test script not found${NC}"
    ALL_TESTS_PASSED=false
fi

# 2. Check contract compilation
echo -e "\n${YELLOW}2. Verifying contract compilation...${NC}"
forge build > /tmp/build.log 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Contracts compile successfully${NC}"
else
    echo -e "${RED}✗ Contract compilation failed${NC}"
    ALL_TESTS_PASSED=false
fi

# 3. Run forge tests
echo -e "\n${YELLOW}3. Running forge tests...${NC}"
forge test > /tmp/test.log 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ All tests pass${NC}"
else
    echo -e "${RED}✗ Some tests failed${NC}"
    cat /tmp/test.log | grep -A5 "FAIL"
    ALL_TESTS_PASSED=false
fi

# 4. Check git status
echo -e "\n${YELLOW}4. Checking git status...${NC}"
if [ -z "$(git status --porcelain)" ]; then
    echo -e "${GREEN}✓ Working directory clean${NC}"
else
    echo -e "${YELLOW}⚠ Uncommitted changes detected:${NC}"
    git status --short
fi

# 5. Verify deployment parameters
echo -e "\n${YELLOW}5. Verifying deployment parameters...${NC}"
PARAMS_VALID=true

if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo -e "${RED}✗ DEPLOYER_PRIVATE_KEY not set${NC}"
    PARAMS_VALID=false
    ALL_TESTS_PASSED=false
fi

if [ -z "$MAINNET_ACCESS_TOKEN" ]; then
    echo -e "${RED}✗ MAINNET_ACCESS_TOKEN not set${NC}"
    PARAMS_VALID=false
    ALL_TESTS_PASSED=false
fi

if [ -z "$CHAIN_A_RPC_URL" ] || [ -z "$CHAIN_B_RPC_URL" ]; then
    echo -e "${RED}✗ RPC URLs not configured${NC}"
    PARAMS_VALID=false
    ALL_TESTS_PASSED=false
fi

if [ "$PARAMS_VALID" = true ]; then
    echo -e "${GREEN}✓ All deployment parameters configured${NC}"
fi

# 6. Check BaseEscrowFactory has the fix
echo -e "\n${YELLOW}6. Verifying CREATE2 fix in BaseEscrowFactory...${NC}"
if grep -q "Clones.predictDeterministicAddress" contracts/BaseEscrowFactory.sol; then
    echo -e "${GREEN}✓ BaseEscrowFactory uses Clones.predictDeterministicAddress${NC}"
    
    # Check both functions are updated
    SRC_UPDATED=$(grep -A2 "addressOfEscrowSrc" contracts/BaseEscrowFactory.sol | grep -c "Clones.predictDeterministicAddress")
    DST_UPDATED=$(grep -A2 "addressOfEscrowDst" contracts/BaseEscrowFactory.sol | grep -c "Clones.predictDeterministicAddress")
    
    if [ "$SRC_UPDATED" -eq 1 ] && [ "$DST_UPDATED" -eq 1 ]; then
        echo -e "${GREEN}✓ Both addressOfEscrowSrc and addressOfEscrowDst are updated${NC}"
    else
        echo -e "${RED}✗ Not all address functions are updated${NC}"
        ALL_TESTS_PASSED=false
    fi
else
    echo -e "${RED}✗ CREATE2 fix not found in BaseEscrowFactory${NC}"
    ALL_TESTS_PASSED=false
fi

# 7. Summary
echo -e "\n${YELLOW}=== VERIFICATION SUMMARY ===${NC}"
if [ "$ALL_TESTS_PASSED" = true ]; then
    echo -e "${GREEN}✅ All checks passed! Ready for mainnet deployment.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run fork tests: ./scripts/test-fork-simple.sh"
    echo "2. Deploy to testnets first: ./scripts/deploy-fixed-testnets.sh"
    echo "3. Test on testnets for 24-48 hours"
    echo "4. Deploy to mainnet: ./scripts/deploy-mainnet-with-checks.sh"
else
    echo -e "${RED}❌ Some checks failed. Please fix issues before mainnet deployment.${NC}"
    exit 1
fi