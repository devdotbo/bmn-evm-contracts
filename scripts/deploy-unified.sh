#!/bin/bash
# Unified deployment script for all networks (testnet and mainnet)

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
source .env

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Unified Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to get RPC URL based on network name
get_rpc_url() {
    local network=$1
    case $network in
        "base-sepolia")
            echo "https://lb.drpc.org/base-sepolia/***REMOVED***-gy0cAAR8LUYEklbR4ac"
            ;;
        "base")
            echo "$CHAIN_A_RPC_URL"
            ;;
        "etherlink-testnet")
            echo "https://rpc.ankr.com/etherlink_testnet/35d1fcc2f4af5eb2f0770fc52924942699d99ff26b9d1ee25d5f711e172cd4f5"
            ;;
        "etherlink")
            echo "$CHAIN_B_RPC_URL"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to get chain ID from network name
get_chain_id() {
    local network=$1
    case $network in
        "base-sepolia")
            echo "84532"
            ;;
        "base")
            echo "8453"
            ;;
        "etherlink-testnet")
            echo "128123"
            ;;
        "etherlink")
            echo "42793"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to deploy to a specific network
deploy_to_network() {
    local network=$1
    local rpc_url=$(get_rpc_url "$network")
    local chain_id=$(get_chain_id "$network")
    
    if [ -z "$rpc_url" ] || [ -z "$chain_id" ]; then
        echo -e "${RED}Unknown network: $network${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}Deploying to $network (Chain ID: $chain_id)${NC}"
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
        echo -e "${RED}WARNING: Deployer has no balance on $network${NC}"
        echo "Deployer address: $DEPLOYER"
        echo "Please fund this address with ETH to continue"
        return 1
    fi
    
    # Deploy contracts with appropriate verification
    echo -e "\n${YELLOW}Deploying contracts...${NC}"
    
    # Check if this is Etherlink (use Blockscout) or other chains (use Etherscan)
    if [[ "$network" == "etherlink" || "$network" == "etherlink-testnet" ]]; then
        # Etherlink uses Blockscout
        forge script script/UnifiedDeploy.s.sol \
            --rpc-url "$rpc_url" \
            --broadcast \
            --verify \
            --verifier blockscout \
            --verifier-url "$(get_verifier_url "$network")" \
            -vvv \
            --slow  # Add slow flag to help with nonce issues
    else
        # Other chains use Etherscan
        export ETHERSCAN_VERIFICATION_INTERVAL=5  # 5 seconds instead of 15
        export ETHERSCAN_VERIFICATION_RETRIES=3   # Fewer retries
        
        forge script script/UnifiedDeploy.s.sol \
            --rpc-url "$rpc_url" \
            --broadcast \
            --verify \
            --verifier-url "$(get_verifier_url "$network")" \
            --etherscan-api-key "$ETHERSCAN_API_KEY" \
            -vvv \
            --slow  # Add slow flag to help with nonce issues
    fi
    
    echo -e "${GREEN}Deployment to $network completed!${NC}"
}

# Function to get verifier URL for network
get_verifier_url() {
    local network=$1
    case $network in
        "base-sepolia")
            echo "https://api-sepolia.basescan.org/api"
            ;;
        "base")
            echo "https://api.basescan.org/api"
            ;;
        "etherlink-testnet")
            echo "https://testnet.explorer.etherlink.com/api/"
            ;;
        "etherlink")
            echo "https://explorer.etherlink.com/api/"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Main deployment flow
main() {
    local network=$1
    
    echo "Deployer address: $DEPLOYER"
    echo "Bob (Resolver): $BOB_RESOLVER"
    echo "Alice (User): $ALICE"
    echo ""
    
    if [ -z "$network" ]; then
        echo -e "${RED}Error: Network name required${NC}"
        echo ""
        echo "Usage: $0 <network>"
        echo ""
        echo "Available networks:"
        echo "  base-sepolia      - Base Sepolia testnet"
        echo "  base              - Base mainnet"
        echo "  etherlink-testnet - Etherlink testnet"
        echo "  etherlink         - Etherlink mainnet"
        exit 1
    fi
    
    deploy_to_network "$network"
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Show deployment files
    echo -e "\nDeployment files:"
    ls -la deployments/*.json 2>/dev/null || echo "No deployment files found"
}

# Parse arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 <network>"
    echo ""
    echo "Deploy contracts to specified network"
    echo ""
    echo "Available networks:"
    echo "  base-sepolia      - Base Sepolia testnet"
    echo "  base              - Base mainnet"
    echo "  etherlink-testnet - Etherlink testnet"
    echo "  etherlink         - Etherlink mainnet"
    exit 0
fi

main "$@"