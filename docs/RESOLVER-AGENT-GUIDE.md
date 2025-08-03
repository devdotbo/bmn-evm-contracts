# Resolver Agent Guide

This guide provides essential information for resolver agents operating the BMN cross-chain atomic swap protocol.

## Overview

The BMN protocol enables trustless cross-chain atomic swaps between Base and Etherlink mainnet chains. As a resolver, you facilitate these swaps by providing liquidity and executing the protocol steps.

## Current Deployment Status

### Production Deployment (CrossChainEscrowFactory)
- **Factory Address**: `0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa` (same on both chains)
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (18 decimals)
- **Status**: Deployed via CREATE2 for deterministic addresses
- **Limitation**: Requires 1inch Limit Order Protocol integration for source escrow creation

### Test Deployment (TestEscrowFactory)
- **Purpose**: Simplified testing without limit order protocol
- **Script**: `scripts/run-mainnet-test.sh`
- **Warning**: Only for testing - bypasses security checks

## Working Test Scripts

### Main Test Script: `run-mainnet-test.sh`

This is the primary script for testing atomic swaps on mainnet:

```bash
# Phase 1: Deploy test infrastructure
./scripts/run-mainnet-test.sh deploy

# Phase 2: Execute atomic swap
./scripts/run-mainnet-test.sh swap

# Phase 3: Check balances
./scripts/run-mainnet-test.sh check
```

### Supporting Scripts
- `script/PrepareMainnetTest.s.sol` - Deploys TestEscrowFactory
- `script/LiveTestMainnet.s.sol` - Executes atomic swap steps

### Balance Checking
```bash
./scripts/check-mainnet-balances.sh
```

## Atomic Swap Flow

### Step 1: Order Creation
Alice creates an order with:
- Source token: BMN on Base
- Destination token: BMN on Etherlink
- Amount: 10 BMN
- Hashlock: Generated from secret

### Step 2: Source Escrow Creation
- Alice locks 10 BMN in source escrow on Base
- Escrow is timelocked with specific withdrawal windows
- Safety deposit required (0.00001 ETH)

### Step 3: Destination Escrow Creation
- Bob (resolver) deploys destination escrow on Etherlink
- Locks 10 BMN for Alice
- Uses same hashlock as source escrow

### Step 4: Destination Withdrawal
- Alice withdraws from destination escrow
- This reveals the secret on-chain
- Alice receives 10 BMN on Etherlink

### Step 5: Source Withdrawal
- Bob uses revealed secret to withdraw from source
- Bob receives 10 BMN on Base
- Atomic swap completes

## Timelock Configuration

Production timelocks (in seconds):
- **Source Withdrawal**: 0-300s (5 min) - Taker only
- **Source Public Withdrawal**: 300-600s (5-10 min) - Anyone
- **Source Cancellation**: 600-900s (10-15 min) - Maker only
- **Source Public Cancellation**: 900s+ (15 min+) - Anyone
- **Destination**: Similar structure with offsets

## Environment Setup

Required environment variables:
```bash
# Private keys
DEPLOYER_PRIVATE_KEY=
ALICE_PRIVATE_KEY=
RESOLVER_PRIVATE_KEY=

# RPC endpoints
BASE_RPC_URL=https://mainnet.base.org
ETHERLINK_RPC_URL=https://node.mainnet.etherlink.com

# Chain mappings (for compatibility)
CHAIN_A_RPC_URL=$BASE_RPC_URL
CHAIN_B_RPC_URL=$ETHERLINK_RPC_URL
```

## Test Accounts

Standard test accounts (funded for testing):
- **Alice**: Creates orders, provides source liquidity
- **Bob**: Acts as resolver, provides destination liquidity

## Safety Deposits

- Required to prevent griefing attacks
- Amount: 0.00001 ETH (~$0.03-0.04)
- Returned after successful swap
- In production, resolver typically covers both deposits

## Known Issues and Solutions

### Issue: "Creating source escrow" fails
**Cause**: Script references deleted `TestCrossChainSwap.s.sol`
**Solution**: Use `run-mainnet-test.sh` instead

### Issue: Factory address mismatch
**Cause**: Using old deployment addresses
**Solution**: Use current addresses listed above

### Issue: Decimal calculation errors
**Cause**: BMN has 18 decimals, not 6
**Solution**: All scripts updated to use correct decimals

## Deprecated Scripts

Do not use these scripts (they reference deleted contracts):
- `test-mainnet-swap.sh`
- `test-crosschain-swap.sh`

## Integration with bmn-evm-resolver

The TypeScript resolver implementation (`../bmn-evm-resolver`) monitors orders and executes swaps automatically. When updating contracts:

1. Build contracts: `forge build`
2. Copy ABIs to resolver:
   ```bash
   cp out/TestEscrowFactory.sol/TestEscrowFactory.json ../bmn-evm-resolver/abis/
   cp out/EscrowSrc.sol/EscrowSrc.json ../bmn-evm-resolver/abis/
   cp out/EscrowDst.sol/EscrowDst.json ../bmn-evm-resolver/abis/
   ```
3. Update resolver configuration with new addresses

## Security Considerations

1. **TestEscrowFactory** is for testing only - it bypasses critical security checks
2. Always verify hashlock matches across both escrows
3. Monitor timelock windows to avoid missing withdrawal periods
4. Ensure sufficient gas on both chains for all transactions
5. Never expose private keys in scripts or logs

## Monitoring and Debugging

### Check deployment status
```bash
cat deployments/baseMainnetTest.json
cat deployments/etherlinkMainnetTest.json
```

### Verify escrow state
Use `cast call` to check escrow contract state:
```bash
# Check if secret is revealed
cast call <escrow_address> "secretRevealed()(bool)" --rpc-url $BASE_RPC_URL

# Check escrow balances
cast call <escrow_address> "token()(address)" --rpc-url $BASE_RPC_URL
```

### Transaction debugging
Use `-vvvv` flag with forge scripts for detailed output:
```bash
ACTION=create-src-escrow forge script script/LiveTestMainnet.s.sol --rpc-url $BASE_RPC_URL --broadcast -vvvv
```

## Next Steps

1. For production: Implement 1inch Limit Order Protocol integration
2. For testing: Continue using TestEscrowFactory via `run-mainnet-test.sh`
3. Monitor successful swaps via balance changes
4. Report issues in the project repository