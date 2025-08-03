#!/bin/bash
set -e

# MAINNET DEPLOYMENT SCRIPT WITH SAFETY CHECKS
# This script deploys the fixed EscrowFactory to Base and Etherlink mainnets

source .env

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "====================================="
echo "   MAINNET DEPLOYMENT SCRIPT"
echo "====================================="
echo ""

# Safety confirmation
echo -e "${RED}⚠️  WARNING: This will deploy to MAINNET!${NC}"
echo -e "${RED}This action is IRREVERSIBLE and will cost real ETH.${NC}"
echo ""
read -p "Type 'DEPLOY TO MAINNET' to continue: " confirmation
if [ "$confirmation" != "DEPLOY TO MAINNET" ]; then
    echo "Deployment cancelled."
    exit 1
fi

# Pre-deployment checks
echo -e "\n${YELLOW}Running pre-deployment checks...${NC}"

# Check deployer address
DEPLOYER_ADDRESS=$(cast wallet address --private-key $DEPLOYER_PRIVATE_KEY)
echo "Deployer address: $DEPLOYER_ADDRESS"

# Function to check balance
check_balance() {
    local chain_name=$1
    local rpc_url=$2
    local min_balance=$3
    
    echo -e "\n${BLUE}Checking $chain_name...${NC}"
    
    # Check ETH balance
    balance_wei=$(cast balance $DEPLOYER_ADDRESS --rpc-url "$rpc_url")
    balance_eth=$(cast --from-wei $balance_wei)
    echo "ETH Balance: $balance_eth ETH"
    
    # Check if balance is sufficient (in wei)
    min_balance_wei=$(cast --to-wei $min_balance)
    if [ "$balance_wei" -lt "$min_balance_wei" ]; then
        echo -e "${RED}✗ Insufficient ETH balance on $chain_name. Need at least $min_balance ETH${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Sufficient ETH balance${NC}"
    fi
    
    # Check block number (connectivity test)
    block=$(cast block-number --rpc-url "$rpc_url" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ RPC connection successful (block: $block)${NC}"
    else
        echo -e "${RED}✗ RPC connection failed${NC}"
        return 1
    fi
    
    return 0
}

# Check both chains
all_checks_passed=true
check_balance "Base Mainnet" "$CHAIN_A_RPC_URL" "0.01" || all_checks_passed=false
check_balance "Etherlink Mainnet" "$CHAIN_B_RPC_URL" "0.1" || all_checks_passed=false

if [ "$all_checks_passed" = false ]; then
    echo -e "\n${RED}Pre-deployment checks failed. Please resolve issues before continuing.${NC}"
    exit 1
fi

# Show deployment parameters
echo -e "\n${YELLOW}Deployment Parameters:${NC}"
echo "Base Mainnet RPC: $CHAIN_A_RPC_URL"
echo "Etherlink Mainnet RPC: $CHAIN_B_RPC_URL"
echo "Tokens to use:"
echo "  - Base: TKA at $CHAIN_A_TOKEN" 
echo "  - Etherlink: TKB at $CHAIN_B_TOKEN"
echo "Access Token: $MAINNET_ACCESS_TOKEN"
echo "Rescue Delay: 86400 seconds (1 day)"
echo "Deployed At Offset: 300 seconds (5 minutes)"

# Final confirmation
echo -e "\n${YELLOW}Final deployment details:${NC}"
echo "This will deploy:"
echo "1. EscrowFactory on Base Mainnet"
echo "2. EscrowFactory on Etherlink Mainnet"
echo "Both factories will use the CREATE2 fix (Clones.predictDeterministicAddress)"
echo ""
read -p "Proceed with deployment? (yes/no): " final_confirm
if [ "$final_confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 1
fi

# Create deployment script
cat > script/MainnetDeploy.s.sol << EOF
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MainnetDeploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address accessToken = vm.envAddress("MAINNET_ACCESS_TOKEN");
        
        vm.startBroadcast(deployerKey);
        
        EscrowFactory factory = new EscrowFactory(
            address(0), // No limit order protocol needed for mainnet
            IERC20(address(0)), // Will be set per-chain
            accessToken,
            86400,  // rescueDelay: 1 day
            300     // deployedAtOffset: 5 minutes
        );
        
        console.log("=== MAINNET DEPLOYMENT ===");
        console.log("Factory deployed at:", address(factory));
        console.log("Src Implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("Dst Implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        console.log("Access Token:", address(factory.accessToken()));
        console.log("=======================");
        
        vm.stopBroadcast();
    }
}
EOF

# Deploy to Base Mainnet
echo -e "\n${YELLOW}Deploying to Base Mainnet...${NC}"
BASE_DEPLOY_OUTPUT=$(forge script script/MainnetDeploy.s.sol \
    --rpc-url "$CHAIN_A_RPC_URL" \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --verify \
    --etherscan-api-key $BASE_ETHERSCAN_API_KEY \
    -vvv 2>&1)

# Extract Base factory address
BASE_FACTORY=$(echo "$BASE_DEPLOY_OUTPUT" | grep "Factory deployed at:" | tail -1 | awk '{print $4}')
if [ -z "$BASE_FACTORY" ]; then
    echo -e "${RED}Failed to deploy on Base Mainnet${NC}"
    echo "$BASE_DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ Base Mainnet factory deployed at: $BASE_FACTORY${NC}"

# Deploy to Etherlink Mainnet
echo -e "\n${YELLOW}Deploying to Etherlink Mainnet...${NC}"
ETHERLINK_DEPLOY_OUTPUT=$(forge script script/MainnetDeploy.s.sol \
    --rpc-url "$CHAIN_B_RPC_URL" \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --legacy \
    -vvv 2>&1)

# Extract Etherlink factory address
ETHERLINK_FACTORY=$(echo "$ETHERLINK_DEPLOY_OUTPUT" | grep "Factory deployed at:" | tail -1 | awk '{print $4}')
if [ -z "$ETHERLINK_FACTORY" ]; then
    echo -e "${RED}Failed to deploy on Etherlink Mainnet${NC}"
    echo "$ETHERLINK_DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ Etherlink Mainnet factory deployed at: $ETHERLINK_FACTORY${NC}"

# Save deployment info
TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S_UTC")
cat > deployments/mainnet-deployment-$TIMESTAMP.json << EOF
{
  "timestamp": "$TIMESTAMP",
  "deployer": "$DEPLOYER_ADDRESS",
  "base_mainnet": {
    "factory": "$BASE_FACTORY",
    "chainId": 8453,
    "rpc": "$CHAIN_A_RPC_URL"
  },
  "etherlink_mainnet": {
    "factory": "$ETHERLINK_FACTORY", 
    "chainId": 42793,
    "rpc": "$CHAIN_B_RPC_URL"
  },
  "configuration": {
    "accessToken": "$MAINNET_ACCESS_TOKEN",
    "rescueDelay": 86400,
    "deployedAtOffset": 300
  }
}
EOF

# Update main deployment file
cp deployments/mainnet-deployment-$TIMESTAMP.json deployments/mainnet-latest.json

echo -e "\n${GREEN}===== DEPLOYMENT SUCCESSFUL =====${NC}"
echo -e "${GREEN}Base Mainnet Factory: $BASE_FACTORY${NC}"
echo -e "${GREEN}Etherlink Mainnet Factory: $ETHERLINK_FACTORY${NC}"
echo -e "${GREEN}Deployment info saved to: deployments/mainnet-deployment-$TIMESTAMP.json${NC}"

# Cleanup
rm -f script/MainnetDeploy.s.sol

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Verify contracts on Etherscan (Base should auto-verify)"
echo "2. Update resolver with new factory addresses"
echo "3. Run end-to-end test on mainnet"
echo "4. Monitor for 24 hours before announcing"