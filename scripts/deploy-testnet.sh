#!/bin/bash
# Script to deploy contracts to testnets (Base Sepolia and Etherlink)

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
source .env

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testnet Deployment Script${NC}"
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
        echo "Please fund this address with testnet ETH to continue"
        return 1
    fi
    
    # Deploy contracts
    echo -e "\n${YELLOW}Deploying contracts...${NC}"
    forge script script/TestnetDeploy.s.sol \
        --rpc-url "$rpc_url" \
        --broadcast \
        --verify \
        -vvv
    
    echo -e "${GREEN}Deployment to $chain_name completed!${NC}"
}

# Main deployment flow
main() {
    echo "Deployer address: 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0"
    echo "Bob (Resolver): 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5"
    echo "Alice (User): 0x240E2588e35FB9D3D60B283B45108a49972FFFd8"
    echo ""
    
    # Deploy to Base Sepolia
    if [ "$1" = "base" ] || [ -z "$1" ]; then
        deploy_to_chain "Base Sepolia" "$CHAIN_A_RPC_URL" "84532"
    fi
    
    # Deploy to Etherlink Testnet
    if [ "$1" = "etherlink" ] || [ -z "$1" ]; then
        deploy_to_chain "Etherlink Testnet" "$CHAIN_B_RPC_URL" "128123"
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
    echo "Deploy contracts to testnets"
    echo ""
    echo "Arguments:"
    echo "  base       - Deploy only to Base Sepolia"
    echo "  etherlink  - Deploy only to Etherlink Testnet"
    echo "  (none)     - Deploy to both chains"
    exit 0
fi

main "$@"