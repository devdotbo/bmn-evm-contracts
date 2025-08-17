# SimplifiedEscrowFactory Deployment Scripts

This directory contains deployment scripts for SimplifiedEscrowFactory, the 1inch-compatible version of the BMN atomic swap protocol.

## Scripts Overview

### Deploy.s.sol
Main deployment script for SimplifiedEscrowFactory with full 1inch integration.

**Features:**
- Deploys SimplifiedEscrowFactory with SimpleSettlement inheritance
- Supports both CREATE3 (deterministic addresses) and direct deployment
- Auto-configures for multiple chains (Mainnet, Optimism, Base, Polygon, Arbitrum, BSC)
- Deploys mock LimitOrderProtocol for testing when needed
- Generates verification commands for Etherscan

**Usage:**
```bash
# Local deployment (Anvil)
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Mainnet deployment (with CREATE3)
source .env && forge script script/Deploy.s.sol --rpc-url $MAINNET_RPC_URL --broadcast

# Verify existing deployment
FACTORY_ADDRESS=0x... forge script script/Deploy.s.sol:Deploy --sig "verify()" --rpc-url $RPC_URL
```

### LocalDeploy.s.sol
Specialized script for local testing with complete test environment setup.

**Features:**
- Deploys factory with mock LimitOrderProtocol
- Creates test tokens (TKA and TKB)
- Mints tokens to test accounts (Alice and Bob)
- Sets up all necessary approvals
- Configures resolver whitelist
- Returns structured deployment data

**Usage:**
```bash
# Deploy complete test environment
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Get deployment info
FACTORY_ADDRESS=0x... forge script script/LocalDeploy.s.sol:LocalDeploy --sig "getDeployment()"
```

### DeployConfig.s.sol
Configuration helper for multi-chain deployments.

**Features:**
- Chain-specific configurations for all major networks
- Environment variable management
- Verification command generation
- Configuration validation

**Usage:**
```bash
# Show all supported chains
forge script script/DeployConfig.s.sol --sig "showAllChains()"
```

## Environment Variables

### Required
- `DEPLOYER_PRIVATE_KEY`: Private key for deployment account

### Optional Configuration
- `LIMIT_ORDER_PROTOCOL`: Override 1inch protocol address
- `OWNER`: Factory owner address (defaults to deployer)
- `RESCUE_DELAY`: Rescue delay in seconds (default: 7 days)
- `ACCESS_TOKEN`: Access token for escrows (default: none)
- `WETH`: WETH address override
- `USE_MOCK_PROTOCOL`: Deploy mock protocol (true/false)
- `USE_CREATE3`: Use CREATE3 for deployment (true/false)

### Chain-Specific RPC URLs
- `MAINNET_RPC_URL`: Ethereum mainnet RPC
- `OPTIMISM_RPC_URL`: Optimism RPC
- `BASE_RPC_URL`: Base RPC
- `POLYGON_RPC_URL`: Polygon RPC
- `ARBITRUM_RPC_URL`: Arbitrum RPC
- `BSC_RPC_URL`: BSC RPC

### Verification API Keys
- `ETHERSCAN_API_KEY`: Mainnet Etherscan
- `OPTIMISM_ETHERSCAN_API_KEY`: Optimistic Etherscan
- `BASESCAN_API_KEY`: Basescan
- `POLYGONSCAN_API_KEY`: Polygonscan
- `ARBISCAN_API_KEY`: Arbiscan
- `BSCSCAN_API_KEY`: BSCscan

## Constructor Parameters

SimplifiedEscrowFactory requires:
1. `limitOrderProtocol`: Address of 1inch SimpleLimitOrderProtocol
2. `owner`: Factory owner who can manage whitelists and pause
3. `rescueDelay`: Delay for rescue operations (e.g., 7 days)
4. `accessToken`: Token for access control (use address(0) if not needed)
5. `weth`: WETH address for the chain

## Test Accounts (Anvil)

- **Deployer**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` (Account 0)
- **Alice (Maker)**: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` (Account 1)
- **Bob (Resolver)**: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` (Account 2)

## Deployment Flow

1. **Local Testing:**
   ```bash
   # Start Anvil
   anvil --hardfork shanghai
   
   # Deploy test environment
   forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast
   
   # Run tests
   forge test --match-contract SimplifiedEscrowFactoryTest -vvv
   ```

2. **Production Deployment:**
   ```bash
   # Set environment variables
   export DEPLOYER_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE
   export BASE_RPC_URL=https://rpc.provider.com/base/YOUR_API_KEY_HERE
   export BASESCAN_API_KEY=YOUR_BASESCAN_API_KEY_HERE
   
   # Deploy to Base
   forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL --broadcast
   
   # Verify on Basescan (command will be shown in output)
   ```

## Key Implementation Features

- **Constructor-based implementation deployment**: Implementations are deployed in the factory constructor to ensure correct FACTORY immutable capture
- **SimpleSettlement inheritance**: Factory inherits from 1inch SimpleSettlement for protocol integration
- **postInteraction() entry point**: Main entry point for 1inch protocol integration
- **No CREATE3 for implementations**: Only the factory itself can use CREATE3 for deterministic address

## Integration Notes

- Resolvers must approve the factory for token transfers before filling orders
- The factory's `postInteraction()` is called by the 1inch protocol after order fills
- Escrow creation happens automatically during the post-interaction callback
- Block timestamps must be read from event blocks for immutables calculation