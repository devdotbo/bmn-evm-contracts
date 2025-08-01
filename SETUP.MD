# Hackathon Setup Guide for Bridge-Me-Not

This guide helps you set up a minimal atomic swap contract system for hackathon use.

## Step 1: Install Dependencies with Forge

Run these commands in your project root:

```bash
# Install required dependencies using forge
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
forge install 1inch/solidity-utils
forge install 1inch/limit-order-protocol
forge install 1inch/limit-order-settlement
forge install dmfxyz/murky
```

## Step 2: Copy Essential Contracts

Create the directory structure and copy contracts from the source repository:

```bash
# Set source path (relative from bridge-me-not to cross-chain-swap)
SOURCE_PATH="../../1inch/cross-chain-swap"

# Create directories
mkdir -p contracts/libraries
mkdir -p contracts/interfaces
mkdir -p contracts/mocks

# Copy core contracts
cp $SOURCE_PATH/contracts/EscrowFactory.sol contracts/
cp $SOURCE_PATH/contracts/BaseEscrowFactory.sol contracts/
cp $SOURCE_PATH/contracts/EscrowSrc.sol contracts/
cp $SOURCE_PATH/contracts/EscrowDst.sol contracts/
cp $SOURCE_PATH/contracts/BaseEscrow.sol contracts/
cp $SOURCE_PATH/contracts/Escrow.sol contracts/
cp $SOURCE_PATH/contracts/EscrowFactoryContext.sol contracts/
cp $SOURCE_PATH/contracts/MerkleStorageInvalidator.sol contracts/

# Copy libraries
cp $SOURCE_PATH/contracts/libraries/ImmutablesLib.sol contracts/libraries/
cp $SOURCE_PATH/contracts/libraries/ProxyHashLib.sol contracts/libraries/
cp $SOURCE_PATH/contracts/libraries/TimelocksLib.sol contracts/libraries/

# Copy all interfaces
cp $SOURCE_PATH/contracts/interfaces/*.sol contracts/interfaces/

# Copy useful mocks
cp $SOURCE_PATH/contracts/mocks/ResolverExample.sol contracts/mocks/
```

## Step 3: Create Configuration Files

### foundry.toml
```toml
[profile.default]
src = 'contracts'
out = 'out'
libs = ['lib']
test = 'test'
optimizer_runs = 1000000
via-ir = true
evm_version = 'shanghai'
solc_version = '0.8.23'

[fmt]
line_length = 140
bracket_spacing = true
```

### remappings.txt
```
@openzeppelin/=lib/openzeppelin-contracts/
openzeppelin-contracts/=lib/openzeppelin-contracts/
solidity-utils/=lib/solidity-utils/
limit-order-protocol/=lib/limit-order-protocol/
limit-order-settlement/=lib/limit-order-settlement/
murky/=lib/murky/
forge-std/=lib/forge-std/src/
```

## Step 4: Create Simple Deployment Script

Create `script/LocalDeploy.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin, LimitOrderProtocol, IWETH } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";

contract LocalDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens
        TokenMock tokenA = new TokenMock("Token A", "TKA");
        TokenMock tokenB = new TokenMock("Token B", "TKB");
        TokenMock accessToken = new TokenMock("Access Token", "ACCESS");
        TokenMock feeToken = new TokenMock("Fee Token", "FEE");

        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
        console.log("Access Token:", address(accessToken));
        console.log("Fee Token:", address(feeToken));

        // Deploy Limit Order Protocol
        LimitOrderProtocol lop = new LimitOrderProtocol(IWETH(address(0)));
        console.log("Limit Order Protocol:", address(lop));

        // Deploy Escrow Factory
        EscrowFactory factory = new EscrowFactory(
            address(lop),
            feeToken,
            accessToken,
            deployer, // owner
            604800,   // 7 days rescue delay
            604800    // 7 days rescue delay
        );
        console.log("Escrow Factory:", address(factory));

        // Mint tokens to test accounts
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account 1
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;   // Anvil account 2

        tokenA.mint(alice, 1000 ether);
        tokenB.mint(bob, 1000 ether);
        accessToken.mint(alice, 1);
        accessToken.mint(bob, 1);
        feeToken.mint(bob, 100 ether);

        console.log("Setup complete!");
        console.log("Alice:", alice);
        console.log("Bob (Resolver):", bob);

        vm.stopBroadcast();
    }
}
```

## Step 5: Create Test Helper

Create `test/CrossChainHelper.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";

contract CrossChainHelper is Test {
    // Helper to build order data
    function buildOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount,
        address receiver
    ) public pure returns (IOrderMixin.Order memory) {
        // Simplified order creation
        // Add your order building logic here
    }

    // Helper to create timelocks
    function createTimelocks() public view returns (uint256) {
        // Create timelocks with current timestamp
        // Return encoded timelocks
    }
}
```

## Step 6: Multi-Chain Setup Script

Create `scripts/multi-chain-setup.sh`:

```bash
#!/bin/bash

# Start Chain A (Source)
echo "Starting Chain A on port 8545..."
anvil --port 8545 --chain-id 1337 > chain-a.log 2>&1 &
CHAIN_A_PID=$!

# Start Chain B (Destination)
echo "Starting Chain B on port 8546..."
anvil --port 8546 --chain-id 1338 > chain-b.log 2>&1 &
CHAIN_B_PID=$!

sleep 2

# Load environment variables (create .env file based on .env.example)
source .env

# Deploy on Chain A
echo "Deploying on Chain A..."
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Deploy on Chain B
echo "Deploying on Chain B..."
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8546 --broadcast --private-key $DEPLOYER_PRIVATE_KEY

echo "Setup complete!"
echo "Chain A PID: $CHAIN_A_PID"
echo "Chain B PID: $CHAIN_B_PID"
echo "Press Ctrl+C to stop both chains"

# Wait for interrupt
wait
```

## Step 7: Simple Resolver Script

Create `scripts/resolver.js`:

```javascript
const { ethers } = require('ethers');

// Configuration
const CHAIN_A_RPC = 'http://localhost:8545';
const CHAIN_B_RPC = 'http://localhost:8546';

const RESOLVER_KEY = '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a'; // Anvil account 2

async function main() {
    // Connect to both chains
    const providerA = new ethers.JsonRpcProvider(CHAIN_A_RPC);
    const providerB = new ethers.JsonRpcProvider(CHAIN_B_RPC);

    const resolverA = new ethers.Wallet(RESOLVER_KEY, providerA);
    const resolverB = new ethers.Wallet(RESOLVER_KEY, providerB);

    console.log('Resolver monitoring both chains...');
    console.log('Resolver address:', resolverA.address);

    // Monitor Chain A for orders
    // When order found, execute on Chain B
    // Monitor for secret reveal
    // Complete swap

    // Add your resolver logic here
}

main().catch(console.error);
```

## Quick Start Commands

```bash
# 1. Make scripts executable
chmod +x scripts/multi-chain-setup.sh

# 2. Start both chains and deploy
./scripts/multi-chain-setup.sh

# 3. Run resolver (in another terminal)
node scripts/resolver.js
```

## Next Steps

1. Implement order creation logic
2. Add resolver monitoring logic
3. Create demo script showing full flow
4. Add your bridge-specific features

## Tips for Hackathon

- Keep timelocks short (minutes, not days) for demos
- Pre-fund accounts with tokens
- Have a clear demo script ready
- Focus on core functionality first
- Add UI/additional features if time permits

Good luck with your hackathon!
