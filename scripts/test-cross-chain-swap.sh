#!/bin/bash
# Unified test script for cross-chain swaps with network parameter

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
source .env

# Parse network parameter
NETWORK=${1:-""}

if [ -z "$NETWORK" ]; then
    echo -e "${RED}Error: Network parameter required${NC}"
    echo ""
    echo "Usage: $0 <network> [action]"
    echo ""
    echo "Networks:"
    echo "  local     - Local Anvil chains"
    echo "  testnet   - Base Sepolia + Etherlink Testnet"
    echo "  mainnet   - Base Mainnet + Etherlink Mainnet"
    echo ""
    echo "Actions (optional):"
    echo "  create-order"
    echo "  create-src-escrow"
    echo "  create-dst-escrow"
    echo "  withdraw-dst"
    echo "  withdraw-src"
    echo "  check-balances"
    echo "  full (default) - Run full test sequence"
    exit 1
fi

ACTION=${2:-"full"}

# Set deployment files and RPC URLs based on network
case $NETWORK in
    "local")
        CHAIN_A_DEPLOYMENT="deployments/chainA.json"
        CHAIN_B_DEPLOYMENT="deployments/chainB.json"
        CHAIN_A_RPC="http://localhost:8545"
        CHAIN_B_RPC="http://localhost:8546"
        SCRIPT="script/LiveTestChains.s.sol"
        STATE_FILE="deployments/test-state.json"
        ;;
    "testnet")
        CHAIN_A_DEPLOYMENT="deployments/baseSepolia.json"
        CHAIN_B_DEPLOYMENT="deployments/etherlinkTestnet.json"
        CHAIN_A_RPC="$CHAIN_A_RPC_URL"  # From .env
        CHAIN_B_RPC="$CHAIN_B_RPC_URL"  # From .env
        SCRIPT="script/LiveTestMainnet.s.sol"  # Reuse mainnet script
        STATE_FILE="deployments/testnet-test-state.json"
        ;;
    "mainnet")
        CHAIN_A_DEPLOYMENT="deployments/baseMainnet.json"
        CHAIN_B_DEPLOYMENT="deployments/etherlinkMainnet.json"
        CHAIN_A_RPC="$CHAIN_A_RPC_URL"  # From .env
        CHAIN_B_RPC="$CHAIN_B_RPC_URL"  # From .env
        SCRIPT="script/LiveTestMainnet.s.sol"
        STATE_FILE="deployments/mainnet-test-state.json"
        ;;
    *)
        echo -e "${RED}Unknown network: $NETWORK${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cross-Chain Swap Test - $NETWORK${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if deployment files exist
if [ ! -f "$CHAIN_A_DEPLOYMENT" ] || [ ! -f "$CHAIN_B_DEPLOYMENT" ]; then
    echo -e "${RED}Error: Deployment files not found${NC}"
    echo "Chain A deployment: $CHAIN_A_DEPLOYMENT"
    echo "Chain B deployment: $CHAIN_B_DEPLOYMENT"
    echo "Please run deployment first"
    exit 1
fi

# Function to run a specific action
run_action() {
    local action=$1
    local rpc_url=$2
    
    echo -e "${YELLOW}Running action: $action${NC}"
    
    ACTION=$action forge script $SCRIPT \
        --rpc-url "$rpc_url" \
        --broadcast \
        -vvv \
        --sig "run()"
}

# Function to check balances
check_balances() {
    echo -e "${YELLOW}Checking balances...${NC}"
    
    ACTION=check-balances forge script $SCRIPT \
        --rpc-url "$CHAIN_A_RPC" \
        --sig "run()"
}

# Main execution
if [ "$ACTION" = "full" ]; then
    echo "Running full cross-chain swap test sequence..."
    echo ""
    
    # Show initial balances
    check_balances
    echo ""
    
    # Step 1: Create order
    echo -e "${BLUE}Step 1: Creating order on Chain A${NC}"
    run_action "create-order" "$CHAIN_A_RPC"
    echo ""
    
    # Step 2: Create source escrow
    echo -e "${BLUE}Step 2: Creating source escrow on Chain A${NC}"
    run_action "create-src-escrow" "$CHAIN_A_RPC"
    echo ""
    
    # Step 3: Create destination escrow
    echo -e "${BLUE}Step 3: Creating destination escrow on Chain B${NC}"
    run_action "create-dst-escrow" "$CHAIN_B_RPC"
    echo ""
    
    # Step 4: Withdraw from destination (Alice reveals secret)
    echo -e "${BLUE}Step 4: Withdrawing from destination escrow (Alice reveals secret)${NC}"
    run_action "withdraw-dst" "$CHAIN_B_RPC"
    echo ""
    
    # Step 5: Withdraw from source (Bob uses revealed secret)
    echo -e "${BLUE}Step 5: Withdrawing from source escrow (Bob uses revealed secret)${NC}"
    run_action "withdraw-src" "$CHAIN_A_RPC"
    echo ""
    
    # Show final balances
    echo -e "${BLUE}Final balances:${NC}"
    check_balances
    
else
    # Run specific action
    case $ACTION in
        "create-order"|"create-src-escrow"|"withdraw-src")
            run_action "$ACTION" "$CHAIN_A_RPC"
            ;;
        "create-dst-escrow"|"withdraw-dst")
            run_action "$ACTION" "$CHAIN_B_RPC"
            ;;
        "check-balances")
            check_balances
            ;;
        *)
            echo -e "${RED}Unknown action: $ACTION${NC}"
            exit 1
            ;;
    esac
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"