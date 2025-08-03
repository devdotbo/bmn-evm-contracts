#!/bin/bash
set -e

# Simple fork test using cast commands
source .env

echo "=== Simple Fork Test for CREATE2 Fix ==="
echo "This test deploys a new factory on forked mainnet and verifies address predictions"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_fork() {
    local chain_name=$1
    local rpc_url=$2
    local token_address=$3
    
    echo -e "\n${YELLOW}Testing on $chain_name fork...${NC}"
    echo "RPC URL: $rpc_url"
    
    # Get latest block
    BLOCK=$(cast block-number --rpc-url "$rpc_url")
    echo "Fork block: $BLOCK"
    
    # Start Anvil fork
    echo "Starting Anvil fork..."
    pkill -f "anvil.*8547" || true
    anvil --fork-url "$rpc_url" --fork-block-number "$BLOCK" --port 8547 --hardfork shanghai > /dev/null 2>&1 &
    ANVIL_PID=$!
    sleep 3
    
    # Deploy factory using simple script
    cat > script/SimpleForkDeploy.s.sol << EOF
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleForkDeploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        vm.startBroadcast(deployerKey);
        
        // Deploy factory with fix
        TestEscrowFactory factory = new TestEscrowFactory(
            address(0),
            IERC20($token_address),
            IERC20($token_address),
            deployer,
            86400,
            86400
        );
        
        console.log("FACTORY_DEPLOYED:", address(factory));
        console.log("SRC_IMPL:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("DST_IMPL:", factory.ESCROW_DST_IMPLEMENTATION());
        
        vm.stopBroadcast();
    }
}
EOF
    
    # Deploy and capture addresses
    echo "Deploying factory..."
    DEPLOY_OUTPUT=$(forge script script/SimpleForkDeploy.s.sol --rpc-url http://localhost:8547 --broadcast --private-key $DEPLOYER_PRIVATE_KEY 2>&1)
    
    FACTORY=$(echo "$DEPLOY_OUTPUT" | grep "FACTORY_DEPLOYED:" | awk '{print $2}')
    SRC_IMPL=$(echo "$DEPLOY_OUTPUT" | grep "SRC_IMPL:" | awk '{print $2}')
    DST_IMPL=$(echo "$DEPLOY_OUTPUT" | grep "DST_IMPL:" | awk '{print $2}')
    
    echo "Factory: $FACTORY"
    echo "Src Implementation: $SRC_IMPL"
    echo "Dst Implementation: $DST_IMPL"
    
    # Test address prediction using cast
    echo -e "\n${YELLOW}Testing address predictions...${NC}"
    
    # Prepare test data
    # Function selector for addressOfEscrowSrc: 0x5e88e91f
    # Create simple immutables struct
    IMMUTABLES="0x"
    IMMUTABLES="${IMMUTABLES}0000000000000000000000000000000000000000000000000000000000000000" # orderHash
    IMMUTABLES="${IMMUTABLES}$(cast keccak "test_secret")" # hashlock (remove 0x prefix)
    IMMUTABLES="${IMMUTABLES}000000000000000000000000$(echo $DEPLOYER_ADDRESS | cut -c 3-)" # maker
    IMMUTABLES="${IMMUTABLES}0000000000000000000000000000000000000000000000000000000000000123" # taker
    IMMUTABLES="${IMMUTABLES}000000000000000000000000$(echo $token_address | cut -c 3-)" # token
    IMMUTABLES="${IMMUTABLES}0000000000000000000000000000000000000000000000000de0b6b3a7640000" # amount (1 ether)
    IMMUTABLES="${IMMUTABLES}00000000000000000000000000000000000000000000000000038d7ea4c68000" # safetyDeposit (0.001 ether)
    IMMUTABLES="${IMMUTABLES}0000000000000000000000000000000000000000000000000000000000000000" # timelocks
    
    # Get salt for manual calculation
    SALT=$(cast keccak "$IMMUTABLES")
    echo "Salt: $SALT"
    
    # Call addressOfEscrowSrc
    CALLDATA="0x5e88e91f0000000000000000000000000000000000000000000000000000000000000020${IMMUTABLES:2}"
    PREDICTED_SRC=$(cast call $FACTORY "$CALLDATA" --rpc-url http://localhost:8547)
    echo "Predicted Src (from factory): $PREDICTED_SRC"
    
    # Calculate using Clones formula
    # predictDeterministicAddress calculates: keccak256(0x3d602d80600a3d3981f3363d3d373d3d3d363d73 + implementation + salt + 0x5af43d82803e903d91602b57fd5bf3)
    CLONES_PREFIX="3d602d80600a3d3981f3363d3d373d3d3d363d73"
    CLONES_SUFFIX="5af43d82803e903d91602b57fd5bf3"
    CLONES_BYTECODE="0x${CLONES_PREFIX}${SRC_IMPL:2}${SALT:2}${CLONES_SUFFIX}"
    CLONES_HASH=$(cast keccak "$CLONES_BYTECODE")
    
    # Calculate CREATE2 address: keccak256(0xff + factory + salt + bytecode_hash)[12:]
    CREATE2_INPUT="0xff${FACTORY:2}${SALT:2}${CLONES_HASH:2}"
    CREATE2_HASH=$(cast keccak "$CREATE2_INPUT")
    MANUAL_PREDICTED="0x${CREATE2_HASH:26}"
    
    echo "Predicted Src (manual calc): $MANUAL_PREDICTED"
    
    # Compare
    if [ "${PREDICTED_SRC,,}" = "${MANUAL_PREDICTED,,}" ]; then
        echo -e "${GREEN}✓ Address predictions match! The CREATE2 fix is working.${NC}"
        RESULT="SUCCESS"
    else
        echo -e "${RED}✗ Address mismatch! Factory: $PREDICTED_SRC, Manual: $MANUAL_PREDICTED${NC}"
        RESULT="FAILURE"
    fi
    
    # Cleanup
    kill $ANVIL_PID 2>/dev/null || true
    rm -f script/SimpleForkDeploy.s.sol
    
    echo -e "\n${YELLOW}$chain_name test complete: $RESULT${NC}"
}

# Get deployer address
DEPLOYER_ADDRESS=$(cast wallet address --private-key $DEPLOYER_PRIVATE_KEY)
echo "Deployer: $DEPLOYER_ADDRESS"

# Test on Base mainnet
test_fork "Base Mainnet" "$CHAIN_A_RPC_URL" "0x8DBB1c08A147e9bd46fC378A3a7C4C3E8f5d9B20"

# Test on Etherlink mainnet  
test_fork "Etherlink Mainnet" "$CHAIN_B_RPC_URL" "0xf87D02ac4b4787166179B582b8b0793e5191B050"

echo -e "\n${GREEN}All fork tests complete!${NC}"