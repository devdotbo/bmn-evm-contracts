# Cross-Chain Atomic Swap Solution - 1inch Style

## Problem Statement
Cross-chain atomic swaps face a critical challenge: CREATE2 address prediction fails when factories use `block.timestamp` during deployment, causing address mismatches between predicted and actual escrow addresses.

## Our Solution: 1inch-Style Resolver Pattern

Instead of trying to predict addresses, we adopted the 1inch Fusion resolver pattern:

### Key Components

1. **CrossChainResolver.sol** - Pre-deployed resolver on both chains
   - Manages entire swap lifecycle
   - No address prediction needed
   - Event-driven architecture
   - Stores swap data in mappings

2. **Benefits**
   - ✅ No immutables validation issues
   - ✅ Clean separation of concerns
   - ✅ Easy swap tracking via swap IDs
   - ✅ Event-based communication
   - ✅ Proven pattern from 1inch Fusion

### How It Works

```solidity
// 1. Alice initiates swap on source chain
resolver.initiateSwap(hashlock, bob, token, amount, dstChainId, timelocks);
// Emits: SwapInitiated event with swapId

// 2. Resolver creates destination escrow
resolver.createDestinationEscrow(swapId, alice, bob, token, amount, ...);
// Emits: EscrowCreated event

// 3. Bob reveals secret and withdraws
resolver.withdraw(swapId, secret, false); // destination
// Emits: SwapCompleted event

// 4. Alice uses revealed secret to withdraw
resolver.withdraw(swapId, secret, true); // source
```

### Architecture Comparison

**Traditional Approach (problematic)**:
```
Alice → Factory.createSrcEscrow() → Escrow @ predicted address ❌
         ↓
   block.timestamp changes
         ↓
   Actual address ≠ Predicted address
```

**1inch-Style Resolver (our solution)**:
```
Alice → Resolver.initiateSwap() → Escrow @ tracked address ✅
         ↓
   Resolver stores mapping
         ↓
   No prediction needed!
```

### Key Innovation

By following 1inch's pattern, we avoid the core issue entirely:
- **No address prediction** = No timestamp mismatch
- **Central resolver** = Clean state management
- **Event-driven** = Easy cross-chain coordination

### Implementation Details

The resolver:
1. Receives tokens from users
2. Deploys escrows via factory
3. Tracks escrow addresses in mappings
4. Handles withdrawals with stored data
5. Emits events for off-chain monitoring

### Security Features

- Owner-only functions for critical operations
- Swap ID validation prevents replay attacks
- Secret validation ensures atomicity
- Event emission for transparency

### Deployment

```bash
# Deploy on Base
forge script script/DeployResolver.s.sol --rpc-url $BASE_RPC_URL --broadcast

# Deploy on Etherlink  
forge script script/DeployResolver.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast
```

### Future Improvements

1. Multi-signature support for resolver operations
2. Fee mechanism for resolver incentives
3. Integration with existing 1inch infrastructure
4. Support for partial fills

## Conclusion

By adopting the proven 1inch Fusion resolver pattern, we eliminate the address prediction problem entirely, creating a more robust and maintainable cross-chain atomic swap solution.