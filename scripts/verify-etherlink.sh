#!/bin/bash

# Etherlink Chain Verification Script
# Verifies smart contracts on Etherlink mainnet

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Etherlink Chain Contract Verification ===${NC}"
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Etherlink mainnet details
ETHERLINK_RPC_URL="https://node.mainnet.etherlink.com"
CHAIN_ID="42793"

echo -e "${YELLOW}Note: Etherlink verification process${NC}"
echo ""

# Check if Etherlink has an API-based verification service
echo -e "${BLUE}Checking Etherlink explorer capabilities...${NC}"
echo ""

# Function to generate verification info
generate_verification_info() {
    local contract_name=$1
    local contract_address=$2
    local constructor_args=$3
    
    echo -e "${GREEN}${contract_name}:${NC}"
    echo "  Address: ${contract_address}"
    echo "  Constructor Arguments: ${constructor_args}"
    echo ""
}

# Generate flattened source files for manual verification
echo -e "${YELLOW}Generating flattened source files...${NC}"

# Create verification directory
mkdir -p verification/etherlink

# Flatten contracts
echo "Flattening BMNAccessTokenV2..."
forge flatten contracts/BMNAccessTokenV2.sol > verification/etherlink/BMNAccessTokenV2_flattened.sol

echo "Flattening EscrowFactory..."
forge flatten contracts/EscrowFactory.sol > verification/etherlink/EscrowFactory_flattened.sol

echo "Flattening EscrowSrc..."
forge flatten contracts/EscrowSrc.sol > verification/etherlink/EscrowSrc_flattened.sol

echo "Flattening EscrowDst..."
forge flatten contracts/EscrowDst.sol > verification/etherlink/EscrowDst_flattened.sol

echo -e "${GREEN}✓ Flattened files created in verification/etherlink/${NC}"
echo ""

# Generate constructor arguments
echo -e "${YELLOW}Generating constructor arguments...${NC}"
echo ""

# Run the verification script to get encoded args
forge script script/VerifyContracts.s.sol -vvv > verification/etherlink/constructor_args.txt

# Generate verification info for each contract
echo -e "${GREEN}=== Contract Verification Information ===${NC}"
echo ""

# 1. BMNAccessTokenV2
BMNV2_ARGS="0x0000000000000000000000005f29827e25dc174a6A51C99e6811Bbd7581285b0"
generate_verification_info \
    "BMNAccessTokenV2" \
    "0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e" \
    "${BMNV2_ARGS}"

# 2. EscrowFactory
FACTORY_ARGS=$(cast abi-encode "constructor(address,address,address,address,uint32,uint32)" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e" \
    "0x5f29827e25dc174a6A51C99e6811Bbd7581285b0" \
    86400 \
    86400)
generate_verification_info \
    "EscrowFactory" \
    "0x068aABdFa6B8c442CD32945A9A147B45ad7146d2" \
    "${FACTORY_ARGS}"

# 3. EscrowSrc
ESCROW_ARGS=$(cast abi-encode "constructor(uint32,address)" \
    86400 \
    "0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e")
generate_verification_info \
    "EscrowSrc" \
    "0x8f92DA1E1b537003569b7293B8063E6e79f27FC6" \
    "${ESCROW_ARGS}"

# 4. EscrowDst
generate_verification_info \
    "EscrowDst" \
    "0xFd3114ef8B537003569b7293B8063E6e79f27FC6" \
    "${ESCROW_ARGS}"

# Save constructor args to files
echo -e "${YELLOW}Saving constructor arguments to files...${NC}"
echo "${BMNV2_ARGS}" > verification/etherlink/BMNAccessTokenV2_constructor_args.txt
echo "${FACTORY_ARGS}" > verification/etherlink/EscrowFactory_constructor_args.txt
echo "${ESCROW_ARGS}" > verification/etherlink/EscrowSrc_constructor_args.txt
echo "${ESCROW_ARGS}" > verification/etherlink/EscrowDst_constructor_args.txt

echo -e "${GREEN}✓ Constructor arguments saved${NC}"
echo ""

# Check if Etherlink explorer supports API verification
echo -e "${BLUE}=== Manual Verification Steps ===${NC}"
echo ""
echo "Etherlink Explorer: https://explorer.etherlink.com/"
echo ""
echo "For each contract:"
echo "1. Navigate to the contract address on the explorer"
echo "2. Click on 'Contract' tab"
echo "3. Click 'Verify and Publish'"
echo "4. Select the following settings:"
echo "   - Compiler Type: Solidity (Single file)"
echo "   - Compiler Version: v0.8.23+commit.f704f362"
echo "   - Open Source License: MIT"
echo ""
echo "5. Paste the flattened source code from:"
echo "   verification/etherlink/<Contract>_flattened.sol"
echo ""
echo "6. Set Optimization:"
echo "   - Enabled: Yes"
echo "   - Runs: 1000000"
echo "   - Via-IR: Yes"
echo ""
echo "7. Paste constructor arguments from:"
echo "   verification/etherlink/<Contract>_constructor_args.txt"
echo ""
echo "8. Complete any CAPTCHA and submit"
echo ""

# Try automated verification if Etherlink supports it
echo -e "${YELLOW}Attempting automated verification...${NC}"
echo ""

# Check if Etherlink has Etherscan-compatible API
if command -v curl &> /dev/null; then
    echo "Checking for Etherscan-compatible API..."
    
    # Try common API endpoints
    API_ENDPOINTS=(
        "https://api.explorer.etherlink.com/api"
        "https://explorer.etherlink.com/api"
        "https://api.etherlink.com"
    )
    
    for endpoint in "${API_ENDPOINTS[@]}"; do
        echo -n "Trying ${endpoint}... "
        if curl -s --max-time 5 "${endpoint}?module=contract&action=getabi&address=0x0000000000000000000000000000000000000000" > /dev/null 2>&1; then
            echo -e "${GREEN}Found!${NC}"
            echo ""
            echo "You may be able to use forge verify-contract with:"
            echo "--verifier-url ${endpoint}"
            break
        else
            echo -e "${RED}Not available${NC}"
        fi
    done
fi

echo ""
echo -e "${GREEN}=== Verification Files Created ===${NC}"
echo ""
echo "All files saved in: verification/etherlink/"
echo ""
echo "Contract addresses on Etherlink:"
echo "- BMNAccessTokenV2: https://explorer.etherlink.com/address/0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e"
echo "- EscrowFactory: https://explorer.etherlink.com/address/0x068aABdFa6B8c442CD32945A9A147B45ad7146d2"
echo "- EscrowSrc: https://explorer.etherlink.com/address/0x8f92DA1E1b537003569b7293B8063E6e79f27FC6"
echo "- EscrowDst: https://explorer.etherlink.com/address/0xFd3114ef8B537003569b7293B8063E6e79f27FC6"