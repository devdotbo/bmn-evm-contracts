# SimpleLimitOrderProtocol Integration Guide

## Overview

This document describes the integration between the SimpleLimitOrderProtocol (our custom 1inch-style implementation) and the CrossChainEscrowFactory for atomic cross-chain swaps without bridges.

## Architecture

### Components

1. **SimpleLimitOrderProtocol** (`bmn-evm-contracts-limit-order/`)
   - Custom implementation without whitelisting/staking requirements
   - Deployed separately on each chain
   - Handles order creation, validation, and filling
   - Triggers postInteraction callbacks for escrow creation

2. **CrossChainEscrowFactory** (`bmn-evm-contracts/`)
   - Receives postInteraction callbacks from SimpleLimitOrderProtocol
   - Creates deterministic escrow contracts
   - Manages cross-chain atomic swap logic

### Integration Flow

```
1. User creates limit order with SimpleLimitOrderProtocol
   └─> Order includes factory extension data for cross-chain swap

2. Resolver fills order through SimpleLimitOrderProtocol
   └─> Protocol executes token transfers
   └─> Protocol calls postInteraction on CrossChainEscrowFactory

3. Factory creates source escrow with locked tokens
   └─> Deterministic address calculation
   └─> Timelock-based security

4. Resolver creates destination escrow on target chain
   └─> Locks equivalent tokens on destination

5. Atomic swap completion via secret reveal
   └─> Maker withdraws from destination with secret
   └─> Resolver uses revealed secret for source withdrawal
```

## Deployed Addresses

### SimpleLimitOrderProtocol
| Network | Address | Status |
|---------|---------|--------|
| Optimism | `0x44716439C19c2E8BD6E1bCB5556ed4C31dA8cDc7` | ✅ Deployed |
| Base | `0x1c1A74b677A28ff92f4AbF874b3Aa6dE864D3f06` | ✅ Deployed |
| Etherlink | TBD | 🔄 Pending |

### CrossChainEscrowFactory (Current - uses 1inch)
| Network | Address | Limit Order Protocol |
|---------|---------|---------------------|
| Optimism | `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c` | 1inch Official |
| Base | `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1` | 1inch Official |

### CrossChainEscrowFactory (New - with SimpleLimitOrderProtocol)
To be deployed using `script/DeployWithSimpleLimitOrder.s.sol`

## Deployment Instructions

### Prerequisites

1. Ensure SimpleLimitOrderProtocol is deployed on target chains
2. Have deployer account funded with ETH on all chains
3. Set up environment variables in `.env`:
   ```bash
   DEPLOYER_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE
   OPTIMISM_RPC=YOUR_OPTIMISM_RPC_URL_HERE
   BASE_RPC=YOUR_BASE_RPC_URL_HERE
   ```

### Deploy New Factory with SimpleLimitOrderProtocol

#### 1. Deploy on Optimism
```bash
source .env && \
forge script script/DeployWithSimpleLimitOrder.s.sol \
    --rpc-url $OPTIMISM_RPC \
    --broadcast \
    --verify \
    -vvvv
```

#### 2. Deploy on Base
```bash
source .env && \
forge script script/DeployWithSimpleLimitOrder.s.sol \
    --rpc-url $BASE_RPC \
    --broadcast \
    --verify \
    -vvvv
```

### Local Testing

#### 1. Start Multi-Chain Environment
```bash
./scripts/test-limit-order-integration.sh
```

This script will:
- Start two Anvil chains (ports 8545 and 8546)
- Deploy SimpleLimitOrderProtocol on both chains
- Deploy CrossChainEscrowFactory with integration
- Run integration tests

#### 2. Run Integration Tests
```bash
forge test --match-contract SimpleLimitOrderIntegration -vv
```

## Order Structure for Cross-Chain Swaps

When creating orders that trigger escrow creation, include the following in the order extension:

```javascript
const orderExtension = {
    // Factory address for postInteraction
    factory: FACTORY_ADDRESS,
    
    // Cross-chain parameters
    destinationChainId: 10,  // e.g., Optimism
    destinationToken: "0x...",  // Token address on destination
    destinationReceiver: aliceAddress,
    
    // Timelocks configuration
    timelocks: {
        srcWithdrawal: 3600,
        srcPublicWithdrawal: 7200,
        srcCancellation: 10800,
        srcPublicCancellation: 14400,
        dstWithdrawal: 1800,
        dstPublicWithdrawal: 3600,
        dstCancellation: 7200,
        dstPublicCancellation: 10800
    },
    
    // Secret hash for atomic swap
    hashlock: keccak256(secret)
};

// Set POST_INTERACTION flag in makerTraits
const makerTraits = (1n << 255n); // Bit 255 = POST_INTERACTION
```

## Resolver Integration

### Update Resolver Configuration

The resolver needs to be updated to:

1. **Use SimpleLimitOrderProtocol addresses** instead of 1inch
2. **Monitor events** from the new protocol
3. **Create orders** with proper extension data
4. **Handle postInteraction** callbacks

### Resolver Code Changes

```javascript
// Update protocol addresses
const PROTOCOL_ADDRESSES = {
    optimism: "0x44716439C19c2E8BD6E1bCB5556ed4C31dA8cDc7",
    base: "0x1c1A74b677A28ff92f4AbF874b3Aa6dE864D3f06"
};

// Update factory addresses (after new deployment)
const FACTORY_ADDRESSES = {
    optimism: "NEW_FACTORY_ADDRESS",
    base: "NEW_FACTORY_ADDRESS"
};
```

## Testing Checklist

- [ ] SimpleLimitOrderProtocol accepts orders
- [ ] Orders can be filled successfully
- [ ] postInteraction is called on factory
- [ ] Source escrow is created with correct parameters
- [ ] Destination escrow can be created by resolver
- [ ] Secret reveal mechanism works
- [ ] Withdrawals execute correctly
- [ ] Cancellations respect timelocks

## Security Considerations

1. **Factory Authorization**: The factory must accept calls from SimpleLimitOrderProtocol
2. **Signature Validation**: Orders must be properly signed by makers
3. **Timelock Safety**: Ensure timelocks provide adequate protection
4. **Secret Management**: Hashlocks must be unique per swap
5. **Gas Optimization**: Monitor gas costs for the full flow

## Migration Plan

### Phase 1: Testing (Current)
- Deploy to local test environment
- Run integration tests
- Verify all components work together

### Phase 2: Testnet Deployment
- Deploy new factory to Optimism Sepolia
- Deploy new factory to Base Sepolia
- Test with real cross-chain transactions

### Phase 3: Mainnet Migration
- Deploy new factory contracts
- Update resolver configuration
- Gradual migration of order flow
- Monitor for issues

## Troubleshooting

### Common Issues

1. **"Invalid limit order protocol"**
   - Ensure factory is deployed with correct SimpleLimitOrderProtocol address
   - Verify the protocol address matches the chain

2. **"PostInteraction failed"**
   - Check that maker has approved tokens
   - Verify extension data is properly encoded
   - Ensure POST_INTERACTION flag is set

3. **"Escrow creation failed"**
   - Verify safety deposit is pre-funded
   - Check timelocks are valid
   - Ensure hashlock is unique

## Support and Resources

- SimpleLimitOrderProtocol: `/bmn-evm-contracts-limit-order/`
- CrossChainEscrowFactory: `/bmn-evm-contracts/`
- Resolver Implementation: `/bmn-evm-resolver/`
- Test Scripts: `/scripts/test-limit-order-integration.sh`