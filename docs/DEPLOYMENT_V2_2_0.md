# SimplifiedEscrowFactory v2.2.0 Deployment Guide

## Overview

Version 2.2.0 introduces PostInteraction interface support, enabling atomic integration with 1inch SimpleLimitOrderProtocol. This allows escrows to be created automatically when limit orders are filled.

## Key Features

### PostInteraction Integration
- Implements `IPostInteraction` interface from 1inch protocol
- Enables atomic escrow creation during order fills
- Gas-optimized for ~105k gas per postInteraction call
- Automatic token transfer from taker to escrow

### Security Features (Retained from v2.1.0)
- Resolver whitelisting for controlled access
- Emergency pause mechanism
- Owner-controlled configuration
- Optional maker whitelisting

## Deployment Addresses

### CREATE3 Factory
- **Address**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` (Base & Optimism)
- **Purpose**: Ensures deterministic addresses across chains

### Expected Addresses (All Chains)

```
EscrowSrc Implementation: [Calculated from CREATE3]
EscrowDst Implementation: [Calculated from CREATE3]
SimplifiedEscrowFactory v2.2.0: [Calculated from CREATE3]
```

The factory address will be identical on Base and Optimism due to CREATE3.

## Deployment Process

### 1. Prerequisites

Create a `.env` file with:
```bash
# Deployer private key (must have ETH on both chains)
DEPLOYER_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE

# RPC URLs
BASE_RPC_URL=https://base-mainnet.infura.io/v3/YOUR_INFURA_KEY_HERE
OPTIMISM_RPC_URL=https://optimism-mainnet.infura.io/v3/YOUR_OPTIMISM_KEY_HERE

# Optional: Initial resolvers to whitelist (comma-separated)
INITIAL_RESOLVERS=0xResolver1,0xResolver2,0xResolver3
```

### 2. Run Deployment

```bash
# Deploy to both Base and Optimism
./scripts/deploy-v2.2-mainnet.sh

# Or deploy individually
# Base
source .env && forge script script/DeployV2_2_Mainnet.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --verify

# Optimism
source .env && forge script script/DeployV2_2_Mainnet.s.sol \
    --rpc-url $OPTIMISM_RPC_URL \
    --broadcast \
    --verify
```

### 3. Verify Deployment

The script automatically verifies:
- Contract sizes
- Implementation addresses
- Factory configuration
- Owner address
- Resolver whitelist status

## Post-Deployment Steps

### 1. Transfer Ownership
```solidity
// Transfer to multisig
factory.transferOwnership(MULTISIG_ADDRESS);
```

### 2. Whitelist Resolvers
```solidity
// Add production resolvers
factory.whitelistResolver(RESOLVER_ADDRESS);
```

### 3. Configure 1inch Integration

The factory can be used as a PostInteraction extension:

```solidity
// In 1inch order creation
Order memory order = Order({
    // ... order parameters ...
    postInteraction: address(factory),
    // ... other parameters ...
});
```

### 4. Update Resolver Infrastructure

Resolvers must:
1. Update factory address to v2.2.0
2. Approve factory for token transfers
3. Support PostInteraction flow

## PostInteraction Flow

1. **Order Fill**: 1inch protocol fills limit order
2. **Token Transfer**: Protocol transfers tokens from maker to taker
3. **PostInteraction Call**: Protocol calls `factory.postInteraction()`
4. **Escrow Creation**: Factory creates source escrow and transfers tokens
5. **Event Emission**: `PostInteractionEscrowCreated` event emitted

## Gas Costs

- PostInteraction escrow creation: ~105,000 gas
- Standard escrow creation: ~95,000 gas
- Additional overhead: ~10,000 gas for PostInteraction logic

## Security Considerations

### Resolver Requirements
- Must be whitelisted before creating escrows
- Must approve factory for token transfers
- Should monitor `PostInteractionEscrowCreated` events

### Emergency Procedures
```solidity
// Pause protocol (owner only)
factory.setEmergencyPause(true);

// Resume protocol
factory.setEmergencyPause(false);
```

## Migration from v2.1.0

### For Factory Users
1. Update factory address to v2.2.0
2. Re-approve factory for token transfers
3. No changes to escrow interaction logic

### For Resolvers
1. Get whitelisted on new factory
2. Update monitoring for new events
3. Support PostInteraction flow (optional)

### For 1inch Integration
1. Use factory address as postInteraction
2. Ensure resolver is ready for atomic flow
3. Test with small amounts first

## Testing

### Local Testing
```bash
# Run PostInteraction tests
forge test --match-contract PostInteractionTest -vvv
```

### Mainnet Testing
1. Create small test order with postInteraction
2. Verify escrow creation
3. Complete full swap flow
4. Check gas usage

## Monitoring

Key events to monitor:
- `PostInteractionEscrowCreated`: New escrows via 1inch
- `SrcEscrowCreated`: Standard escrow creation
- `ResolverWhitelisted`: New resolver additions
- `EmergencyPause`: Protocol pause events

## Support

For issues or questions:
- Review test files: `test/PostInteractionTest.sol`
- Check implementation: `contracts/SimplifiedEscrowFactory.sol`
- Consult documentation: `docs/POSTINTERACTION_IMPLEMENTATION.md`