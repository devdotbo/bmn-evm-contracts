#!/bin/bash
# Script to check balances on testnets

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
source .env

# Account addresses
DEPLOYER="0x5f29827e25dc174a6A51C99e6811Bbd7581285b0"
BOB_RESOLVER="0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5"
ALICE="0x240E2588e35FB9D3D60B283B45108a49972FFFd8"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testnet Balance Check${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to check balance on a chain
check_balance() {
    local chain_name=$1
    local rpc_url=$2
    local address=$3
    local account_name=$4
    
    # Get ETH balance
    balance_wei=$(cast balance "$address" --rpc-url "$rpc_url" 2>/dev/null || echo "0")
    balance_eth=$(cast --from-wei "$balance_wei" 2>/dev/null || echo "0")
    
    echo -e "${BLUE}$account_name${NC} ($address):"
    echo "  ETH: $balance_eth"
    
    # If deployment file exists, check token balances
    local deployment_file=""
    if [[ "$chain_name" == "Base Sepolia" ]]; then
        deployment_file="deployments/baseSepolia.json"
    elif [[ "$chain_name" == "Etherlink Testnet" ]]; then
        deployment_file="deployments/etherlinkTestnet.json"
    fi
    
    if [ -f "$deployment_file" ]; then
        # Extract token addresses
        tokenA=$(jq -r '.contracts.tokenA' "$deployment_file" 2>/dev/null || echo "")
        tokenB=$(jq -r '.contracts.tokenB' "$deployment_file" 2>/dev/null || echo "")
        
        if [ -n "$tokenA" ] && [ "$tokenA" != "null" ]; then
            balance_a=$(cast call --block-number latest "$tokenA" "balanceOf(address)" "$address" --rpc-url "$rpc_url" 2>/dev/null || echo "0x0")
            balance_a_dec=$(cast --to-dec "$balance_a" 2>/dev/null || echo "0")
            balance_a_eth=$(cast --from-wei "$balance_a_dec" 2>/dev/null || echo "0")
            echo "  Token A: $balance_a_eth TKA"
        fi
        
        if [ -n "$tokenB" ] && [ "$tokenB" != "null" ]; then
            balance_b=$(cast call --block-number latest "$tokenB" "balanceOf(address)" "$address" --rpc-url "$rpc_url" 2>/dev/null || echo "0x0")
            balance_b_dec=$(cast --to-dec "$balance_b" 2>/dev/null || echo "0")
            balance_b_eth=$(cast --from-wei "$balance_b_dec" 2>/dev/null || echo "0")
            echo "  Token B: $balance_b_eth TKB"
        fi
    fi
}

# Function to check all balances on a chain
check_chain_balances() {
    local chain_name=$1
    local rpc_url=$2
    
    echo -e "\n${YELLOW}=== $chain_name ===${NC}"
    
    # Check if we can connect
    if ! cast chain-id --rpc-url "$rpc_url" >/dev/null 2>&1; then
        echo -e "${RED}Cannot connect to $rpc_url${NC}"
        return
    fi
    
    check_balance "$chain_name" "$rpc_url" "$DEPLOYER" "Deployer"
    check_balance "$chain_name" "$rpc_url" "$BOB_RESOLVER" "Bob (Resolver)"
    check_balance "$chain_name" "$rpc_url" "$ALICE" "Alice (User)"
}

# Main function
main() {
    # Check Base Sepolia
    if [ "$1" = "base" ] || [ -z "$1" ]; then
        check_chain_balances "Base Sepolia" "$CHAIN_A_RPC_URL"
    fi
    
    # Check Etherlink Testnet
    if [ "$1" = "etherlink" ] || [ -z "$1" ]; then
        check_chain_balances "Etherlink Testnet" "$CHAIN_B_RPC_URL"
    fi
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Faucet Links:${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Base Sepolia Faucet: https://www.coinbase.com/faucets/base-sepolia-faucet"
    echo "Etherlink Testnet Faucet: https://faucet.etherlink.com/"
    echo ""
    echo "Fund these addresses:"
    echo "- Deployer: $DEPLOYER"
    echo "- Bob (Resolver): $BOB_RESOLVER"
    echo "- Alice (User): $ALICE"
}

# Parse arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [base|etherlink]"
    echo ""
    echo "Check account balances on testnets"
    echo ""
    echo "Arguments:"
    echo "  base       - Check only Base Sepolia"
    echo "  etherlink  - Check only Etherlink Testnet"
    echo "  (none)     - Check both chains"
    exit 0
fi

main "$@"