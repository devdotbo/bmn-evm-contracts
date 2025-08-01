#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Bridge-Me-Not Account Funding${NC}"
echo "============================="

# Default accounts
ALICE="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
BOB="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Function to check if port is in use
check_port() {
    lsof -i :$1 > /dev/null 2>&1
    return $?
}

# Check if chains are running
if ! check_port 8545 || ! check_port 8546; then
    echo -e "${RED}Error: Chains are not running!${NC}"
    echo "Please run ./scripts/multi-chain-setup.sh first"
    exit 1
fi

# Check if deployments exist
if [ ! -f "deployments/chainA.json" ] || [ ! -f "deployments/chainB.json" ]; then
    echo -e "${RED}Error: Deployment files not found!${NC}"
    echo "Please run ./scripts/multi-chain-setup.sh to deploy contracts"
    exit 1
fi

# Parse command line arguments
FUND_ETH=false
FUND_TOKENS=false
AMOUNT_ETH="10"
AMOUNT_TOKENS="100"

if [ $# -eq 0 ]; then
    FUND_ETH=true
    FUND_TOKENS=true
else
    while [[ $# -gt 0 ]]; do
        case $1 in
            --eth)
                FUND_ETH=true
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    AMOUNT_ETH=$2
                    shift
                fi
                ;;
            --tokens)
                FUND_TOKENS=true
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    AMOUNT_TOKENS=$2
                    shift
                fi
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --eth [amount]    Fund ETH (default: 10 ETH)"
                echo "  --tokens [amount] Fund tokens (default: 100 tokens)"
                echo "  --help            Show this help"
                echo ""
                echo "If no options provided, funds both ETH and tokens with defaults"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
        shift
    done
fi

# Get token addresses
TOKEN_A_CHAIN_A=$(cat deployments/chainA.json | grep -o '"tokenA": "[^"]*"' | cut -d'"' -f4)
TOKEN_B_CHAIN_B=$(cat deployments/chainB.json | grep -o '"tokenB": "[^"]*"' | cut -d'"' -f4)

# Fund ETH
if [ "$FUND_ETH" = true ]; then
    echo -e "\n${BLUE}Funding ETH...${NC}"
    
    # Fund on Chain A
    echo -e "Chain A (Alice): Sending ${AMOUNT_ETH} ETH..."
    cast send $ALICE --value "${AMOUNT_ETH}ether" --private-key $DEPLOYER_KEY --rpc-url http://localhost:8545 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Funded Alice with ${AMOUNT_ETH} ETH on Chain A${NC}"
    else
        echo -e "${RED}✗ Failed to fund Alice on Chain A${NC}"
    fi
    
    echo -e "Chain A (Bob): Sending ${AMOUNT_ETH} ETH..."
    cast send $BOB --value "${AMOUNT_ETH}ether" --private-key $DEPLOYER_KEY --rpc-url http://localhost:8545 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Funded Bob with ${AMOUNT_ETH} ETH on Chain A${NC}"
    else
        echo -e "${RED}✗ Failed to fund Bob on Chain A${NC}"
    fi
    
    # Fund on Chain B
    echo -e "Chain B (Alice): Sending ${AMOUNT_ETH} ETH..."
    cast send $ALICE --value "${AMOUNT_ETH}ether" --private-key $DEPLOYER_KEY --rpc-url http://localhost:8546 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Funded Alice with ${AMOUNT_ETH} ETH on Chain B${NC}"
    else
        echo -e "${RED}✗ Failed to fund Alice on Chain B${NC}"
    fi
    
    echo -e "Chain B (Bob): Sending ${AMOUNT_ETH} ETH..."
    cast send $BOB --value "${AMOUNT_ETH}ether" --private-key $DEPLOYER_KEY --rpc-url http://localhost:8546 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Funded Bob with ${AMOUNT_ETH} ETH on Chain B${NC}"
    else
        echo -e "${RED}✗ Failed to fund Bob on Chain B${NC}"
    fi
fi

# Fund Tokens
if [ "$FUND_TOKENS" = true ]; then
    echo -e "\n${BLUE}Funding Tokens...${NC}"
    
    # Mint Token A on Chain A
    echo -e "Chain A: Minting ${AMOUNT_TOKENS} TKA to Alice..."
    MINT_SIG="mint(address,uint256)"
    AMOUNT_WEI=$(cast to-wei $AMOUNT_TOKENS)
    
    cast send $TOKEN_A_CHAIN_A "$MINT_SIG" $ALICE $AMOUNT_WEI \
        --private-key $DEPLOYER_KEY --rpc-url http://localhost:8545 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Minted ${AMOUNT_TOKENS} TKA to Alice on Chain A${NC}"
    else
        echo -e "${RED}✗ Failed to mint TKA to Alice${NC}"
    fi
    
    cast send $TOKEN_A_CHAIN_A "$MINT_SIG" $BOB $AMOUNT_WEI \
        --private-key $DEPLOYER_KEY --rpc-url http://localhost:8545 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Minted ${AMOUNT_TOKENS} TKA to Bob on Chain A${NC}"
    else
        echo -e "${RED}✗ Failed to mint TKA to Bob${NC}"
    fi
    
    # Mint Token B on Chain B
    echo -e "Chain B: Minting ${AMOUNT_TOKENS} TKB to Bob..."
    cast send $TOKEN_B_CHAIN_B "$MINT_SIG" $BOB $AMOUNT_WEI \
        --private-key $DEPLOYER_KEY --rpc-url http://localhost:8546 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Minted ${AMOUNT_TOKENS} TKB to Bob on Chain B${NC}"
    else
        echo -e "${RED}✗ Failed to mint TKB to Bob${NC}"
    fi
fi

echo -e "\n${GREEN}Funding complete!${NC}"
echo -e "Run ${BLUE}./scripts/check-deployment.sh${NC} to see updated balances"