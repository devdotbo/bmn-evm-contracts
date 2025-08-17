#!/bin/bash

# Verify SimplifiedEscrowFactory contracts on Base and Optimism explorers
# Usage: ./scripts/verify-mainnet.sh

set -e

echo "========================================="
echo "Contract Verification Script"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hardcoded configuration (same as deploy script)
LIMIT_ORDER_PROTOCOL="0x119c71D3BbAC22029622cbaEc24854d3D32D2828"
RESCUE_DELAY=604800  # 7 days
ACCESS_TOKEN="0x0000000000000000000000000000000000000000"  # No access token

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}[ERROR] .env file not found!${NC}"
    exit 1
fi

# Source environment variables
source .env

# Validate required environment variables
if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo -e "${RED}[ERROR] DEPLOYER_PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo -e "${RED}[ERROR] ETHERSCAN_API_KEY not set in .env${NC}"
    exit 1
fi

# Get deployer address (which is the owner)
DEPLOYER_ADDRESS=$(cast wallet address $DEPLOYER_PRIVATE_KEY)
OWNER=$DEPLOYER_ADDRESS

echo "Configuration:"
echo "  Owner: $OWNER"
echo "  Limit Order Protocol: $LIMIT_ORDER_PROTOCOL"
echo "  Rescue Delay: $RESCUE_DELAY seconds"
echo ""

# Function to get constructor arguments
get_constructor_args() {
    local CHAIN_ID=$1
    
    # WETH addresses
    local WETH
    if [ "$CHAIN_ID" = "8453" ]; then
        # Base
        WETH="0x4200000000000000000000000000000000000006"
    elif [ "$CHAIN_ID" = "10" ]; then
        # Optimism
        WETH="0x4200000000000000000000000000000000000006"
    fi
    
    # Encode constructor arguments
    cast abi-encode "constructor(address,address,uint32,address,address)" \
        $LIMIT_ORDER_PROTOCOL \
        $OWNER \
        $RESCUE_DELAY \
        $ACCESS_TOKEN \
        $WETH
}

# Verify Base deployment
if [ -f "deployments/base-mainnet.env" ]; then
    echo -e "${YELLOW}Verifying Base deployment...${NC}"
    echo "------------------------------"
    
    source deployments/base-mainnet.env
    
    if [ ! -z "$BASE_FACTORY" ]; then
        echo "Factory address: $BASE_FACTORY"
        
        # Get constructor arguments
        CONSTRUCTOR_ARGS=$(get_constructor_args 8453)
        echo "Constructor args: $CONSTRUCTOR_ARGS"
        echo ""
        
        # Verify factory
        echo "Verifying SimplifiedEscrowFactory on Base..."
        forge verify-contract \
            --chain base \
            --watch \
            $BASE_FACTORY \
            contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory \
            --constructor-args $CONSTRUCTOR_ARGS \
            --verifier etherscan \
            --etherscan-api-key $ETHERSCAN_API_KEY \
            --compiler-version v0.8.23+commit.f704f362 \
            --num-of-optimizations 1000000
        
        echo -e "${GREEN}Base verification submitted!${NC}"
        echo "Check status at: https://basescan.org/address/$BASE_FACTORY#code"
        echo ""
        
        # Also try to verify implementation contracts if we can find them
        echo "Attempting to verify implementation contracts..."
        
        # Get implementation addresses from factory
        SRC_IMPL=$(cast call $BASE_FACTORY "ESCROW_SRC_IMPLEMENTATION()(address)" --rpc-url https://mainnet.base.org)
        DST_IMPL=$(cast call $BASE_FACTORY "ESCROW_DST_IMPLEMENTATION()(address)" --rpc-url https://mainnet.base.org)
        
        if [ ! -z "$SRC_IMPL" ] && [ "$SRC_IMPL" != "0x0000000000000000000000000000000000000000" ]; then
            echo "Verifying EscrowSrc implementation at $SRC_IMPL..."
            forge verify-contract \
                --chain base \
                $SRC_IMPL \
                contracts/EscrowSrc.sol:EscrowSrc \
                --verifier etherscan \
                --etherscan-api-key $ETHERSCAN_API_KEY \
                --compiler-version v0.8.23+commit.f704f362 \
                --num-of-optimizations 1000000 || echo "EscrowSrc verification may have failed or already verified"
        fi
        
        if [ ! -z "$DST_IMPL" ] && [ "$DST_IMPL" != "0x0000000000000000000000000000000000000000" ]; then
            echo "Verifying EscrowDst implementation at $DST_IMPL..."
            forge verify-contract \
                --chain base \
                $DST_IMPL \
                contracts/EscrowDst.sol:EscrowDst \
                --verifier etherscan \
                --etherscan-api-key $ETHERSCAN_API_KEY \
                --compiler-version v0.8.23+commit.f704f362 \
                --num-of-optimizations 1000000 || echo "EscrowDst verification may have failed or already verified"
        fi
    else
        echo -e "${RED}[ERROR] BASE_FACTORY not found in deployments/base-mainnet.env${NC}"
    fi
else
    echo -e "${YELLOW}[SKIP] Base verification - deployment file not found${NC}"
fi

# Verify Optimism deployment
if [ -f "deployments/optimism-mainnet.env" ]; then
    echo ""
    echo -e "${YELLOW}Verifying Optimism deployment...${NC}"
    echo "------------------------------"
    
    source deployments/optimism-mainnet.env
    
    if [ ! -z "$OPTIMISM_FACTORY" ]; then
        echo "Factory address: $OPTIMISM_FACTORY"
        
        # Get constructor arguments
        CONSTRUCTOR_ARGS=$(get_constructor_args 10)
        echo "Constructor args: $CONSTRUCTOR_ARGS"
        echo ""
        
        # Verify factory
        echo "Verifying SimplifiedEscrowFactory on Optimism..."
        forge verify-contract \
            --chain optimism \
            --watch \
            $OPTIMISM_FACTORY \
            contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory \
            --constructor-args $CONSTRUCTOR_ARGS \
            --verifier etherscan \
            --etherscan-api-key $ETHERSCAN_API_KEY \
            --compiler-version v0.8.23+commit.f704f362 \
            --num-of-optimizations 1000000
        
        echo -e "${GREEN}Optimism verification submitted!${NC}"
        echo "Check status at: https://optimistic.etherscan.io/address/$OPTIMISM_FACTORY#code"
        echo ""
        
        # Also try to verify implementation contracts
        echo "Attempting to verify implementation contracts..."
        
        # Get implementation addresses from factory
        SRC_IMPL=$(cast call $OPTIMISM_FACTORY "ESCROW_SRC_IMPLEMENTATION()(address)" --rpc-url https://mainnet.optimism.io)
        DST_IMPL=$(cast call $OPTIMISM_FACTORY "ESCROW_DST_IMPLEMENTATION()(address)" --rpc-url https://mainnet.optimism.io)
        
        if [ ! -z "$SRC_IMPL" ] && [ "$SRC_IMPL" != "0x0000000000000000000000000000000000000000" ]; then
            echo "Verifying EscrowSrc implementation at $SRC_IMPL..."
            forge verify-contract \
                --chain optimism \
                $SRC_IMPL \
                contracts/EscrowSrc.sol:EscrowSrc \
                --verifier etherscan \
                --etherscan-api-key $ETHERSCAN_API_KEY \
                --compiler-version v0.8.23+commit.f704f362 \
                --num-of-optimizations 1000000 || echo "EscrowSrc verification may have failed or already verified"
        fi
        
        if [ ! -z "$DST_IMPL" ] && [ "$DST_IMPL" != "0x0000000000000000000000000000000000000000" ]; then
            echo "Verifying EscrowDst implementation at $DST_IMPL..."
            forge verify-contract \
                --chain optimism \
                $DST_IMPL \
                contracts/EscrowDst.sol:EscrowDst \
                --verifier etherscan \
                --etherscan-api-key $ETHERSCAN_API_KEY \
                --compiler-version v0.8.23+commit.f704f362 \
                --num-of-optimizations 1000000 || echo "EscrowDst verification may have failed or already verified"
        fi
    else
        echo -e "${RED}[ERROR] OPTIMISM_FACTORY not found in deployments/optimism-mainnet.env${NC}"
    fi
else
    echo -e "${YELLOW}[SKIP] Optimism verification - deployment file not found${NC}"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Verification Complete!${NC}"
echo "========================================="
echo ""
echo "Note: Verification may take a few minutes to complete on the explorers."
echo "Check the URLs above to see the verification status."
echo ""
echo "If verification fails, you may need to manually verify on the explorers with:"
echo "  - Compiler: v0.8.23+commit.f704f362"
echo "  - Optimization: Yes, 1000000 runs"
echo "  - EVM Version: cancun"