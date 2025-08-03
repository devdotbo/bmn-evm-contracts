#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Mainnet Cross-Chain Atomic Swap Test ===${NC}"
echo -e "${YELLOW}Safety deposit: 0.00001 ETH (~$0.03-0.04)${NC}"
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Map RPC URLs to expected names
export BASE_RPC_URL="${CHAIN_A_RPC_URL}"
export ETHERLINK_RPC_URL="${CHAIN_B_RPC_URL}"

# Check required environment variables
required_vars=("DEPLOYER_PRIVATE_KEY" "ALICE_PRIVATE_KEY" "RESOLVER_PRIVATE_KEY" "BASE_RPC_URL" "ETHERLINK_RPC_URL")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: $var is not set${NC}"
        exit 1
    fi
done

# Function to run command with description
run_step() {
    local description=$1
    local command=$2
    echo -e "${GREEN}>>> $description${NC}"
    echo -e "${YELLOW}Command: $command${NC}"
    eval $command
    echo ""
}

# Phase selection
if [ "$1" == "deploy" ]; then
    echo -e "${GREEN}Phase 1: Deploying Test Infrastructure${NC}"
    
    run_step "Step 1.1: Deploy on Base" \
        "ACTION=deploy-base forge script script/PrepareMainnetTest.s.sol --rpc-url \$BASE_RPC_URL --broadcast -vvv"
    
    run_step "Step 1.2: Deploy on Etherlink" \
        "ACTION=deploy-etherlink forge script script/PrepareMainnetTest.s.sol --rpc-url \$ETHERLINK_RPC_URL --broadcast -vvv"
    
    run_step "Step 1.3: Fund accounts on Base" \
        "ACTION=fund-accounts forge script script/PrepareMainnetTest.s.sol --rpc-url \$BASE_RPC_URL --broadcast -vvv"
    
    run_step "Step 1.4: Fund accounts on Etherlink" \
        "ACTION=fund-accounts forge script script/PrepareMainnetTest.s.sol --rpc-url \$ETHERLINK_RPC_URL --broadcast -vvv"
    
    run_step "Step 1.5: Verify setup on Base" \
        "ACTION=check-setup forge script script/PrepareMainnetTest.s.sol --rpc-url \$BASE_RPC_URL"
    
    run_step "Step 1.6: Verify setup on Etherlink" \
        "ACTION=check-setup forge script script/PrepareMainnetTest.s.sol --rpc-url \$ETHERLINK_RPC_URL"
    
elif [ "$1" == "swap" ]; then
    echo -e "${GREEN}Phase 2: Executing Cross-Chain Swap${NC}"
    echo -e "${YELLOW}Note: This must complete within 15 minutes!${NC}"
    echo ""
    
    run_step "Step 2.1: Create order (Alice on Base)" \
        "ACTION=create-order forge script script/LiveTestMainnet.s.sol --rpc-url \$BASE_RPC_URL --broadcast -vvv"
    
    run_step "Step 2.2: Create source escrow (Alice locks 10 TKA on Base)" \
        "ACTION=create-src-escrow forge script script/LiveTestMainnet.s.sol --rpc-url \$BASE_RPC_URL --broadcast -vvv"
    
    run_step "Step 2.3: Create destination escrow (Bob locks 10 TKB on Etherlink)" \
        "ACTION=create-dst-escrow forge script script/LiveTestMainnet.s.sol --rpc-url \$ETHERLINK_RPC_URL --broadcast -vvv"
    
    echo -e "${YELLOW}Waiting 5 seconds before withdrawals...${NC}"
    sleep 5
    
    run_step "Step 2.4: Withdraw from destination (Alice gets 10 TKB, reveals secret)" \
        "ACTION=withdraw-dst forge script script/LiveTestMainnet.s.sol --rpc-url \$ETHERLINK_RPC_URL --broadcast -vvv"
    
    run_step "Step 2.5: Withdraw from source (Bob gets 10 TKA using secret)" \
        "ACTION=withdraw-src forge script script/LiveTestMainnet.s.sol --rpc-url \$BASE_RPC_URL --broadcast -vvv"
    
    run_step "Step 2.6: Check final balances" \
        "ACTION=check-balances forge script script/LiveTestMainnet.s.sol --rpc-url \$BASE_RPC_URL"
    
    echo -e "${GREEN}✓ Swap completed successfully!${NC}"
    
elif [ "$1" == "check" ]; then
    echo -e "${GREEN}Checking current state${NC}"
    
    run_step "Check Base setup" \
        "ACTION=check-setup forge script script/PrepareMainnetTest.s.sol --rpc-url \$BASE_RPC_URL"
    
    run_step "Check Etherlink setup" \
        "ACTION=check-setup forge script script/PrepareMainnetTest.s.sol --rpc-url \$ETHERLINK_RPC_URL"
    
    run_step "Check swap balances" \
        "ACTION=check-balances forge script script/LiveTestMainnet.s.sol --rpc-url \$BASE_RPC_URL"
    
else
    echo "Usage: $0 [deploy|swap|check]"
    echo ""
    echo "  deploy - Deploy test infrastructure on both chains"
    echo "  swap   - Execute the cross-chain atomic swap"
    echo "  check  - Check current state and balances"
    echo ""
    echo "Required environment variables:"
    echo "  DEPLOYER_PRIVATE_KEY, ALICE_PRIVATE_KEY, RESOLVER_PRIVATE_KEY"
    echo "  BASE_RPC_URL, ETHERLINK_RPC_URL"
fi