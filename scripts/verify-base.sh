#!/bin/bash

# Base Chain Verification Script
# Verifies smart contracts on Base mainnet

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Base Chain Contract Verification ===${NC}"
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Check for Basescan API key
if [ -z "$BASESCAN_API_KEY" ]; then
    echo -e "${YELLOW}Warning: BASESCAN_API_KEY not found in .env${NC}"
    echo -e "${YELLOW}Add the following to your .env file:${NC}"
    echo "BASESCAN_API_KEY=YOUR_API_KEY_HERE"
    echo ""
    echo "Get your API key from: https://basescan.org/myapikey"
    exit 1
fi

# Base mainnet RPC URL
BASE_RPC_URL="https://mainnet.base.org"
CHAIN_ID="8453"

echo "Starting verification process..."
echo ""

# Function to verify a contract
verify_contract() {
    local contract_name=$1
    local contract_address=$2
    local constructor_args=$3
    
    echo -e "${YELLOW}Verifying ${contract_name} at ${contract_address}...${NC}"
    
    forge verify-contract \
        --chain-id ${CHAIN_ID} \
        --rpc-url ${BASE_RPC_URL} \
        --etherscan-api-key ${BASESCAN_API_KEY} \
        --verifier-url https://api.basescan.org/api \
        ${contract_address} \
        ${contract_name} \
        ${constructor_args} \
        --watch
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${contract_name} verified successfully${NC}"
    else
        echo -e "${RED}✗ ${contract_name} verification failed${NC}"
    fi
    echo ""
}

# 1. BMN Token is external (deployed via CREATE3 in separate repo)
echo -e "${GREEN}1. BMN Token (External)${NC}"
echo -e "BMN Token is deployed externally at: 0xe666570DDa40948c6Ba9294440ffD28ab59C8325"
echo -e "See https://basescan.org/address/0xe666570DDa40948c6Ba9294440ffD28ab59C8325#code"
echo ""

# 2. Verify EscrowFactory
echo -e "${GREEN}2. EscrowFactory${NC}"
# First, let's encode the constructor args
FACTORY_ARGS=$(cast abi-encode "constructor(address,address,address,address,uint32,uint32)" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000" \
    "0xe666570DDa40948c6Ba9294440ffD28ab59C8325" \
    "0x5f29827e25dc174a6A51C99e6811Bbd7581285b0" \
    86400 \
    86400)

verify_contract \
    "contracts/EscrowFactory.sol:EscrowFactory" \
    "0x068aABdFa6B8c442CD32945A9A147B45ad7146d2" \
    "--constructor-args ${FACTORY_ARGS}"

# 3. Verify EscrowSrc Implementation
echo -e "${GREEN}3. EscrowSrc Implementation${NC}"
ESCROW_ARGS=$(cast abi-encode "constructor(uint32,address)" \
    86400 \
    "0xe666570DDa40948c6Ba9294440ffD28ab59C8325")

verify_contract \
    "contracts/EscrowSrc.sol:EscrowSrc" \
    "0x8f92DA1E1b537003569b7293B8063E6e79f27FC6" \
    "--constructor-args ${ESCROW_ARGS}"

# 4. Verify EscrowDst Implementation
echo -e "${GREEN}4. EscrowDst Implementation${NC}"
verify_contract \
    "contracts/EscrowDst.sol:EscrowDst" \
    "0xFd3114ef8B537003569b7293B8063E6e79f27FC6" \
    "--constructor-args ${ESCROW_ARGS}"

echo -e "${GREEN}=== Verification Complete ===${NC}"
echo ""
echo "Check verification status at:"
echo "- BMN Token (External): https://basescan.org/address/0xe666570DDa40948c6Ba9294440ffD28ab59C8325#code"
echo "- EscrowFactory: https://basescan.org/address/0x068aABdFa6B8c442CD32945A9A147B45ad7146d2#code"
echo "- EscrowSrc: https://basescan.org/address/0x8f92DA1E1b537003569b7293B8063E6e79f27FC6#code"
echo "- EscrowDst: https://basescan.org/address/0xFd3114ef8B537003569b7293B8063E6e79f27FC6#code"