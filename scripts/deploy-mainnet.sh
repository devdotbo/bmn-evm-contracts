#!/bin/bash
# Script to deploy contracts to mainnets (Base and Etherlink)

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
source .env

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Mainnet Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to deploy to a specific chain
deploy_to_chain() {
    local chain_name=$1
    local rpc_url=$2
    local chain_id=$3
    
    echo -e "\n${YELLOW}Deploying to $chain_name (Chain ID: $chain_id)${NC}"
    echo "RPC URL: $rpc_url"
    
    # Check if we can connect to the RPC
    echo -n "Checking RPC connection... "
    if cast chain-id --rpc-url "$rpc_url" >/dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}Cannot connect to $rpc_url${NC}"
        return 1
    fi
    
    # Check deployer balance
    echo -n "Checking deployer balance... "
    balance=$(cast balance $DEPLOYER --rpc-url "$rpc_url" 2>/dev/null || echo "0")
    balance_ether=$(cast --from-wei "$balance" 2>/dev/null || echo "0")
    echo "$balance_ether ETH"
    
    if [ "$balance" = "0" ]; then
        echo -e "${RED}WARNING: Deployer has no balance on $chain_name${NC}"
        echo "Deployer address: $DEPLOYER"
        echo "Please fund this address with ETH to continue"
        return 1
    fi
    
    # Deploy contracts
    echo -e "\n${YELLOW}Deploying contracts...${NC}"
    forge script script/MainnetDeploy.s.sol \
        --rpc-url "$rpc_url" \
        --broadcast \
        --verify \
        -vvv
    
    echo -e "${GREEN}Deployment to $chain_name completed!${NC}"
}

# Main deployment flow
main() {
    echo "Deployer address: $DEPLOYER"
    echo "Bob (Resolver): $BOB_RESOLVER"
    echo "Alice (User): $ALICE"
    echo ""
    
    # Deploy to Base Mainnet
    if [ "$1" = "base" ] || [ -z "$1" ]; then
        deploy_to_chain "Base Mainnet" "$CHAIN_A_RPC_URL" "8453"
    fi
    
    # Deploy to Etherlink Mainnet
    if [ "$1" = "etherlink" ] || [ -z "$1" ]; then
        deploy_to_chain "Etherlink Mainnet" "$CHAIN_B_RPC_URL" "42793"
    fi
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Show deployment files
    echo -e "\nDeployment files created:"
    ls -la deployments/*.json 2>/dev/null || echo "No deployment files found"
}

# Parse arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [base|etherlink]"
    echo ""
    echo "Deploy contracts to mainnets"
    echo ""
    echo "Arguments:"
    echo "  base       - Deploy only to Base Mainnet"
    echo "  etherlink  - Deploy only to Etherlink Mainnet"
    echo "  (none)     - Deploy to both chains"
    exit 0
fi

main "$@"