# Hackathon Deployment Guide - CrossChain Resolver

## Quick Start (Deploy in 5 minutes)

### Prerequisites
1. `.env` file with `DEPLOYER_PRIVATE_KEY`
2. ETH on Base and Etherlink mainnets for gas
3. BMN tokens on both chains (contract: `0x9c32618CEeC96B9dc0B7c0976C4b4cf2eE452988`)

### Deploy to Both Chains
```bash
# Run the automated deployment script
./scripts/deploy-resolver-hackathon.sh
```

This will:
1. Deploy TestEscrowFactory on each chain
2. Deploy CrossChainResolverV2 on each chain
3. Save deployment addresses to `deployments/` directory

### Manual Deployment (if script fails)

#### Deploy to Base Mainnet
```bash
forge script script/DeployResolverMainnet.s.sol \
  --rpc-url https://mainnet.base.org \
  --broadcast \
  --verify \
  -vvv
```

#### Deploy to Etherlink Mainnet
```bash
forge script script/DeployResolverMainnet.s.sol \
  --rpc-url https://node.mainnet.etherlink.com \
  --broadcast \
  --verify \
  -vvv
```

## Testing the Deployment

### 1. Test Swap Creation (on source chain)
```bash
RESOLVER_ADDRESS=<your-resolver-address> \
forge script script/TestCrossChainResolver.s.sol \
  --rpc-url <source-chain-rpc> \
  --broadcast
```

### 2. Complete Swap (on destination chain)
Use the output from step 1 to call `createDestinationEscrow()` on the destination chain.

## Contract Addresses

### BMN Token (same on both chains)
- Base: `0x9c32618CEeC96B9dc0B7c0976C4b4cf2eE452988`
- Etherlink: `0x9c32618CEeC96B9dc0B7c0976C4b4cf2eE452988`

### Deployed Contracts (after running deployment)
Check `deployments/mainnet-Base-resolver.env` and `deployments/mainnet-Etherlink-resolver.env`

## Architecture Overview

```
CrossChainResolverV2
    └── Uses TestEscrowFactory
         ├── Creates source escrows directly (bypasses limit order protocol)
         └── Creates destination escrows normally
```

## Key Differences from Production

1. **TestEscrowFactory**: Allows direct source escrow creation without limit order protocol
2. **Simplified Access Control**: Uses basic owner pattern instead of complex ACL
3. **Mock Tokens**: Fee and access tokens are simple mocks for demo purposes

## Common Issues

### "Factory not found"
Deploy TestEscrowFactory first or set FACTORY_ADDRESS in .env

### "Insufficient balance"
Fund deployer address with ETH and BMN tokens

### "Invalid chain ID"
Ensure you're deploying to Base (8453) or Etherlink (42793)

## Demo Flow

1. **Alice** (on Base) initiates swap:
   - Locks 100 BMN tokens
   - Creates hashlock from secret
   - Specifies Bob as taker on Etherlink

2. **Resolver** (on Etherlink):
   - Sees the swap event
   - Creates destination escrow
   - Locks 100 BMN tokens for Alice

3. **Bob** (on Etherlink):
   - Withdraws using secret
   - Secret is revealed on-chain

4. **Alice** (on Base):
   - Uses revealed secret
   - Withdraws Bob's tokens

## Verification Commands

After deployment, verify contracts:

```bash
# Verify on Base
forge verify-contract <FACTORY_ADDRESS> \
  contracts/test/TestEscrowFactory.sol:TestEscrowFactory \
  --chain base

forge verify-contract <RESOLVER_ADDRESS> \
  contracts/CrossChainResolverV2.sol:CrossChainResolverV2 \
  --chain base

# Verify on Etherlink (if supported)
# Similar commands with --chain etherlink
```