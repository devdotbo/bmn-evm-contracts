#!/bin/bash
# Script to verify deployed contracts on block explorers

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
source .env

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Contract Verification Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to verify contracts on a chain
verify_chain() {
    local chain_name=$1
    local deployment_file=$2
    local verifier_url=$3
    local chain_id=$4
    
    echo -e "\n${YELLOW}=== Verifying on $chain_name ===${NC}"
    
    if [ ! -f "$deployment_file" ]; then
        echo -e "${RED}Deployment file not found: $deployment_file${NC}"
        return
    fi
    
    # Extract contract addresses
    FACTORY=$(jq -r '.contracts.factory' "$deployment_file" 2>/dev/null || echo "")
    LOP=$(jq -r '.contracts.limitOrderProtocol' "$deployment_file" 2>/dev/null || echo "")
    TOKEN_A=$(jq -r '.contracts.tokenA' "$deployment_file" 2>/dev/null || echo "")
    TOKEN_B=$(jq -r '.contracts.tokenB' "$deployment_file" 2>/dev/null || echo "")
    ACCESS_TOKEN=$(jq -r '.contracts.accessToken' "$deployment_file" 2>/dev/null || echo "")
    FEE_TOKEN=$(jq -r '.contracts.feeToken' "$deployment_file" 2>/dev/null || echo "")
    
    echo "Contracts to verify:"
    echo "  Factory: $FACTORY"
    echo "  LimitOrderProtocol: $LOP"
    echo "  Token A: $TOKEN_A"
    echo "  Token B: $TOKEN_B"
    echo "  Access Token: $ACCESS_TOKEN"
    echo "  Fee Token: $FEE_TOKEN"
    
    # Verify each contract
    echo -e "\n${BLUE}Verifying EscrowFactory...${NC}"
    forge verify-contract \
        --chain-id "$chain_id" \
        --etherscan-api-key "$ETHERSCAN_API_KEY" \
        --verifier-url "$verifier_url" \
        "$FACTORY" \
        contracts/EscrowFactory.sol:EscrowFactory \
        --constructor-args $(cast abi-encode "constructor(address,address,address,address,uint32,uint32)" "$LOP" "$FEE_TOKEN" "$ACCESS_TOKEN" "$DEPLOYER" 604800 604800) \
        2>/dev/null || echo "Factory verification may have already been verified or failed"
    
    echo -e "\n${BLUE}Verifying LimitOrderProtocol...${NC}"
    forge verify-contract \
        --chain-id "$chain_id" \
        --etherscan-api-key "$ETHERSCAN_API_KEY" \
        --verifier-url "$verifier_url" \
        "$LOP" \
        limit-order-protocol/contracts/LimitOrderProtocol.sol:LimitOrderProtocol \
        --constructor-args $(cast abi-encode "constructor(address)" "0x0000000000000000000000000000000000000000") \
        2>/dev/null || echo "LOP verification may have already been verified or failed"
    
    # Verify tokens (they all have the same constructor pattern)
    verify_token() {
        local token_address=$1
        local token_name=$2
        local token_symbol=$3
        
        echo -e "\n${BLUE}Verifying $token_name...${NC}"
        forge verify-contract \
            --chain-id "$chain_id" \
            --etherscan-api-key "$ETHERSCAN_API_KEY" \
            --verifier-url "$verifier_url" \
            "$token_address" \
            solidity-utils/contracts/mocks/TokenMock.sol:TokenMock \
            --constructor-args $(cast abi-encode "constructor(string,string)" "$token_name" "$token_symbol") \
            2>/dev/null || echo "$token_name verification may have already been verified or failed"
    }
    
    verify_token "$TOKEN_A" "Token A" "TKA"
    verify_token "$TOKEN_B" "Token B" "TKB"
    verify_token "$ACCESS_TOKEN" "Access Token" "ACCESS"
    verify_token "$FEE_TOKEN" "Fee Token" "FEE"
}

# Main function
main() {
    # Verify Base Sepolia
    if [ "$1" = "base" ] || [ -z "$1" ]; then
        verify_chain "Base Sepolia" "deployments/baseSepolia.json" "https://api-sepolia.basescan.org/api" "84532"
    fi
    
    # Verify Etherlink Testnet
    if [ "$1" = "etherlink" ] || [ -z "$1" ]; then
        # Note: Etherlink may not have Etherscan-compatible API yet
        echo -e "\n${YELLOW}Etherlink Testnet verification may not be available yet${NC}"
        # verify_chain "Etherlink Testnet" "deployments/etherlinkTestnet.json" "https://api.etherlink.com/api" "128123"
    fi
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Verification Complete${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Parse arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [base|etherlink]"
    echo ""
    echo "Verify deployed contracts on block explorers"
    echo ""
    echo "Arguments:"
    echo "  base       - Verify only Base Sepolia contracts"
    echo "  etherlink  - Verify only Etherlink Testnet contracts"
    echo "  (none)     - Verify contracts on both chains"
    exit 0
fi

main "$@"