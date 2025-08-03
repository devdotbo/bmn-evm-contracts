#!/bin/bash

# Check verification status of contracts on Base and Etherlink

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Contract Verification Status ===${NC}"
echo ""

# Contract addresses
BMN_ACCESS_TOKEN_V2="0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e"
ESCROW_FACTORY="0x068aABdFa6B8c442CD32945A9A147B45ad7146d2"
ESCROW_SRC_IMPL="0x8f92DA1E1b537003569b7293B8063E6e79f27FC6"
ESCROW_DST_IMPL="0xFd3114ef8B537003569b7293B8063E6e79f27FC6"

# Function to check if contract is verified on Base
check_base_verification() {
    local address=$1
    local name=$2
    
    echo -n "  ${name}: "
    
    # Check if contract has verified source code on Basescan
    # This is a simple check - you might need to adjust based on actual API response
    if curl -s "https://basescan.org/address/${address}#code" | grep -q "Contract Source Code Verified" 2>/dev/null; then
        echo -e "${GREEN}✓ Verified${NC}"
        return 0
    else
        echo -e "${RED}✗ Not verified${NC}"
        return 1
    fi
}

# Function to check if contract is verified on Etherlink
check_etherlink_verification() {
    local address=$1
    local name=$2
    
    echo -n "  ${name}: "
    
    # Etherlink doesn't have API, so we just provide the URL
    echo -e "${YELLOW}Check manually${NC}"
    echo "    URL: https://explorer.etherlink.com/address/${address}"
}

echo -e "${BLUE}Base Chain:${NC}"
echo ""
check_base_verification "${BMN_ACCESS_TOKEN_V2}" "BMNAccessTokenV2"
check_base_verification "${ESCROW_FACTORY}" "EscrowFactory"
check_base_verification "${ESCROW_SRC_IMPL}" "EscrowSrc"
check_base_verification "${ESCROW_DST_IMPL}" "EscrowDst"

echo ""
echo -e "${BLUE}Etherlink Chain:${NC}"
echo ""
check_etherlink_verification "${BMN_ACCESS_TOKEN_V2}" "BMNAccessTokenV2"
check_etherlink_verification "${ESCROW_FACTORY}" "EscrowFactory"
check_etherlink_verification "${ESCROW_SRC_IMPL}" "EscrowSrc"
check_etherlink_verification "${ESCROW_DST_IMPL}" "EscrowDst"

echo ""
echo -e "${GREEN}=== Quick Actions ===${NC}"
echo ""
echo "To verify on Base:"
echo "  1. Add BASESCAN_API_KEY to .env"
echo "  2. Run: ./scripts/verify-base.sh"
echo ""
echo "To verify on Etherlink:"
echo "  1. Run: ./scripts/verify-etherlink.sh"
echo "  2. Follow manual verification steps"
echo ""
echo "For detailed instructions, see: VERIFICATION.md"