# Factory Event Enhancement Upgrade - Deployment Guide

## Overview

This guide details the deployment process for the CrossChainEscrowFactory upgrade that adds direct escrow address emission to events, eliminating the need for Ponder to use the factory pattern on Etherlink.

## Pre-Deployment Checklist

### 1. Environment Setup

Ensure your `.env` file contains:
```bash
# Deployer private key (must have funds on both chains)
DEPLOYER_PRIVATE_KEY=<your-private-key>

# RPC URLs
BASE_RPC_URL=https://mainnet.base.org
ETHERLINK_RPC_URL=https://node.mainnet.etherlink.com

# Optional: Etherscan API keys for verification
BASESCAN_API_KEY=<your-basescan-key>
```

### 2. Verify Prerequisites

```bash
# Check deployer balance on both chains
source .env && cast balance $DEPLOYER_ADDRESS --rpc-url $BASE_RPC_URL
source .env && cast balance $DEPLOYER_ADDRESS --rpc-url $ETHERLINK_RPC_URL

# Verify CREATE3 factory exists
source .env && cast code 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d --rpc-url $BASE_RPC_URL
source .env && cast code 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d --rpc-url $ETHERLINK_RPC_URL

# Verify existing implementations
source .env && cast code 0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535 --rpc-url $BASE_RPC_URL
source .env && cast code 0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b --rpc-url $BASE_RPC_URL
```

## Deployment Process

### Step 1: Deploy to Base Mainnet

```bash
# Run deployment script for Base
source .env && forge script script/DeployFactoryUpgrade.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $BASESCAN_API_KEY \
    -vvvv
```

Expected output:
```
Deploying Factory Event Enhancement Upgrade
==========================================
Deployer: 0x...
Chain ID: 8453
Deploying to: Base

[OK] Upgraded CrossChainEscrowFactory deployed at: 0x...
```

### Step 2: Verify Base Deployment

1. Check deployment file:
```bash
cat deployments/factory-upgrade-base-latest.env
```

2. Verify on Basescan:
```bash
# The script should auto-verify, but if needed:
source deployments/factory-upgrade-base-latest.env
forge verify-contract $UPGRADED_FACTORY \
    CrossChainEscrowFactory \
    --chain-id 8453 \
    --etherscan-api-key $BASESCAN_API_KEY \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address)" \
        0x1111111254EEB25477B68fb85Ed929f73A960582 \
        $FEE_TOKEN \
        $ACCESS_TOKEN \
        $DEPLOYER \
        0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535 \
        0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b)
```

### Step 3: Deploy to Etherlink Mainnet

```bash
# Run deployment script for Etherlink
source .env && forge script script/DeployFactoryUpgrade.s.sol \
    --rpc-url $ETHERLINK_RPC_URL \
    --broadcast \
    --slow \
    -vvvv
```

Note: Etherlink doesn't support Etherscan verification yet, so we skip the `--verify` flag.

### Step 4: Verify Etherlink Deployment

1. Check deployment file:
```bash
cat deployments/factory-upgrade-etherlink-latest.env
```

2. Manually verify contract deployment:
```bash
source deployments/factory-upgrade-etherlink-latest.env
cast code $UPGRADED_FACTORY --rpc-url $ETHERLINK_RPC_URL
```

## Post-Deployment Verification

### 1. Test Event Emission

Create a test script to verify events are emitted correctly:

```bash
# Create test order on the new factory
cast send $UPGRADED_FACTORY \
    "createSrcEscrow(...)" \
    --rpc-url $BASE_RPC_URL \
    --private-key $TEST_PRIVATE_KEY
```

### 2. Check Event Logs

```bash
# Get recent events from the factory
cast logs \
    --address $UPGRADED_FACTORY \
    --from-block latest \
    --rpc-url $BASE_RPC_URL
```

### 3. Verify Event Format

The new events should include the escrow address as the first indexed parameter:
- `SrcEscrowCreated(address indexed escrow, ...)`
- `DstEscrowCreated(address indexed escrow, ...)`

## Indexer Migration

### 1. Update Ponder Configuration

Update your Ponder config to use the new factory addresses:

```typescript
// ponder.config.ts
export const config = {
  contracts: [
    {
      name: "CrossChainEscrowFactory",
      network: "base",
      address: "0x<new-factory-address>",
      startBlock: <deployment-block>,
      abi: updatedFactoryABI,
    },
    {
      name: "CrossChainEscrowFactory", 
      network: "etherlink",
      address: "0x<new-factory-address>",
      startBlock: <deployment-block>,
      abi: updatedFactoryABI,
    }
  ]
}
```

### 2. Update Event Handlers

Modify event handlers to use the escrow address directly:

```typescript
// Before: Calculate CREATE2 address
const escrowAddress = calculateCreate2Address(event.args.srcImmutables);

// After: Use emitted address
const escrowAddress = event.args.escrow;
```

### 3. Dual-Mode Support

For transition period, support both event formats:

```typescript
function handleEscrowCreated(event: any) {
  let escrowAddress: string;
  
  // New format with address
  if (event.args.escrow) {
    escrowAddress = event.args.escrow;
  } 
  // Legacy format - calculate
  else if (event.args.srcImmutables) {
    escrowAddress = calculateCreate2Address(event.args.srcImmutables);
  }
  
  // Process escrow...
}
```

## Monitoring

### 1. Gas Usage

Monitor the gas impact of the upgrade:

```bash
# Compare gas usage before/after
cast estimate $UPGRADED_FACTORY "createSrcEscrow(...)" --rpc-url $BASE_RPC_URL
```

Expected increase: ~2,100 gas (<1% of total transaction cost)

### 2. Event Processing

Monitor indexer performance:
- Event processing speed on Etherlink
- Reduced RPC calls for factory pattern
- Successful escrow address resolution

### 3. Error Tracking

Watch for any errors in:
- Event emission
- Indexer processing
- Cross-chain consistency

## Rollback Plan

If issues occur, the indexer can immediately revert to using the old factory:

1. Update Ponder config to point to old factory address
2. Restart indexer from last known good block
3. Resume using CREATE2 calculation for escrow addresses

The protocol remains fully functional during any rollback.

## Success Metrics

- [OK] Both chains deployed successfully
- [OK] Events emit escrow addresses in first parameter
- [OK] Indexer processes new events without factory pattern
- [OK] Gas increase within expected range (<1%)
- [OK] No disruption to existing protocol operations
- [OK] Etherlink indexing performance improved

## Deployed Addresses

After successful deployment, update this section:

### Base Mainnet
- Upgraded Factory: `0x...` (Block: ...)
- Deployment TX: `0x...`

### Etherlink Mainnet  
- Upgraded Factory: `0x...` (Block: ...)
- Deployment TX: `0x...`

## Next Steps

1. Update resolver to use new factory address
2. Migrate indexer to new event format
3. Monitor for 7 days before removing legacy support
4. Update all documentation with new addresses