#!/bin/bash
set -e

# Simple script to verify CREATE2 fix locally
source .env

echo "=== CREATE2 Fix Verification ==="
echo "Testing that predicted addresses match deployed addresses"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Start clean Anvil instance
echo "Starting Anvil..."
pkill -f anvil || true
anvil --block-time 1 --hardfork shanghai > /dev/null 2>&1 &
ANVIL_PID=$!
sleep 2

# Deploy contracts
echo "Deploying contracts..."
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key $DEPLOYER_PRIVATE_KEY > deploy.log 2>&1

# Extract factory address
FACTORY=$(grep "TestEscrowFactory deployed at:" deploy.log | awk '{print $NF}')
echo "Factory deployed at: $FACTORY"

# Test addresses using cast
echo -e "\nTesting address prediction..."

# Create test calldata for addressOfEscrowSrc
# Function selector: addressOfEscrowSrc(IBaseEscrow.Immutables)
SELECTOR="0x5e88e91f"

# Build immutables struct (simplified test data)
# orderHash: 0x0000...0000 (32 bytes)
# hashlock: keccak256("test") = 0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658
# maker: 0x0000000000000000000000000000000000000001
# taker: 0x0000000000000000000000000000000000000002  
# token: 0x0000000000000000000000000000000000000003
# amount: 1000000000000000000 (1 ether)
# safetyDeposit: 100000000000000 (0.0001 ether)
# timelocks: 0x0000... (simplified)

# Construct calldata
CALLDATA="${SELECTOR}0000000000000000000000000000000000000000000000000000000000000020"
CALLDATA="${CALLDATA}0000000000000000000000000000000000000000000000000000000000000000" # orderHash
CALLDATA="${CALLDATA}9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658" # hashlock
CALLDATA="${CALLDATA}0000000000000000000000000000000000000000000000000000000000000001" # maker
CALLDATA="${CALLDATA}0000000000000000000000000000000000000000000000000000000000000002" # taker
CALLDATA="${CALLDATA}0000000000000000000000000000000000000000000000000000000000000003" # token
CALLDATA="${CALLDATA}0000000000000000000000000000000000000000000000000de0b6b3a7640000" # amount
CALLDATA="${CALLDATA}00000000000000000000000000000000000000000000000000005af3107a4000" # safetyDeposit
CALLDATA="${CALLDATA}0000000000000000000000000000000000000000000000000000000000000000" # timelocks

# Call addressOfEscrowSrc
echo "Calling addressOfEscrowSrc..."
PREDICTED_SRC=$(cast call $FACTORY $CALLDATA --rpc-url http://localhost:8545)
echo "Predicted source escrow: $PREDICTED_SRC"

# Now test actual deployment through a simplified script
cat > script/VerifyCreate2.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { Timelocks } from "../contracts/libraries/TimelocksLib.sol";

contract VerifyCreate2 is Script {
    using AddressLib for Address;
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address factory = vm.envAddress("FACTORY_ADDRESS");
        
        // Same test data as shell script
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: keccak256("test"),
            maker: Address.wrap(uint160(0x0000000000000000000000000000000000000001)),
            taker: Address.wrap(uint160(0x0000000000000000000000000000000000000002)),
            token: Address.wrap(uint160(0x0000000000000000000000000000000000000003)),
            amount: 1 ether,
            safetyDeposit: 0.0001 ether,
            timelocks: Timelocks.wrap(0)
        });
        
        // Get predicted addresses
        address predictedSrc = TestEscrowFactory(factory).addressOfEscrowSrc(immutables);
        address predictedDst = TestEscrowFactory(factory).addressOfEscrowDst(immutables);
        
        console.log("Predicted source escrow:", predictedSrc);
        console.log("Predicted dest escrow:", predictedDst);
        
        // Deploy and check
        vm.startBroadcast(deployerKey);
        
        // Pre-fund for safety deposit
        payable(predictedSrc).transfer(0.0001 ether);
        
        // Deploy source escrow (using test factory method)
        address deployedSrc = TestEscrowFactory(factory).createSrcEscrowForTesting(immutables, 0);
        
        console.log("Deployed source escrow:", deployedSrc);
        console.log("Match?", deployedSrc == predictedSrc);
        
        vm.stopBroadcast();
    }
}
EOF

# Run verification
echo -e "\nRunning deployment verification..."
FACTORY_ADDRESS=$FACTORY forge script script/VerifyCreate2.s.sol --rpc-url http://localhost:8545 --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvv > verify.log 2>&1

# Check results
if grep -q "Match? true" verify.log; then
    echo -e "${GREEN}✓ SUCCESS: Address prediction matches deployment!${NC}"
    echo "The CREATE2 fix is working correctly."
else
    echo -e "${RED}✗ FAILURE: Address mismatch detected!${NC}"
    echo "Check verify.log for details."
fi

# Cleanup
kill $ANVIL_PID 2>/dev/null || true
rm -f deploy.log verify.log script/VerifyCreate2.s.sol

echo -e "\nVerification complete."