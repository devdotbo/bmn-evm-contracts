# Demo: 1inch-Style Cross-Chain Atomic Swap

## The Problem We Solved

During the hackathon, we discovered that CREATE2 address prediction fails when:
```solidity
// Factory uses block.timestamp
timelocks = timelocks.setDeployedAt(block.timestamp);
// This timestamp differs from script execution time!
```

Result: `InvalidImmutables()` errors when trying to withdraw.

## Our Solution: 1inch Fusion Pattern

### Step 1: Pre-deploy Resolver on Both Chains

```solidity
contract CrossChainResolver {
    // Manages swaps without address prediction
    mapping(bytes32 => SwapData) public swaps;
    mapping(address => bytes32) public escrowToSwapId;
}
```

### Step 2: Initiate Swap (No Address Prediction!)

```solidity
// Alice initiates on Base
bytes32 swapId = resolver.initiateSwap(
    hashlock,
    bob,          // taker
    BMN_TOKEN,
    10 ether,
    42793,        // Etherlink chain ID
    timelocks
);

// Event: SwapInitiated(swapId, alice, bob, 8453, 42793, 10 ether)
```

### Step 3: Create Destination Escrow

```solidity
// Resolver on Etherlink creates destination
resolver.createDestinationEscrow(
    swapId,
    alice,        // maker becomes taker on dst
    bob,          // taker becomes maker on dst
    BMN_TOKEN,
    10 ether,
    hashlock,
    timelocks,
    srcTimestamp
);

// Event: EscrowCreated(swapId, 0xbd00..., false)
```

### Step 4: Complete Swap

```solidity
// Bob withdraws on destination (reveals secret)
resolver.withdraw(swapId, secret, false);
// Event: SwapCompleted(swapId, secret)

// Alice withdraws on source (uses revealed secret)
resolver.withdraw(swapId, secret, true);
// Event: SwapCompleted(swapId, secret)
```

## Key Benefits

1. **No Address Prediction** - Resolver tracks addresses in mappings
2. **Event-Driven** - Easy to monitor and automate
3. **Clean Architecture** - Follows proven 1inch pattern
4. **No Timestamp Issues** - Resolver handles deployment timing

## Comparison with Failed Approach

### ❌ Old Way (Failed)
```
Predicted: 0x123E3050719EAD96862a370C0a00CABc1BD7aB4c
Actual:    0xBd0069d96c4bb6f7eE9352518CA5b4465b5Bc32A
Result:    InvalidImmutables() - STUCK!
```

### ✅ New Way (1inch-Style)
```
swapId: 0xabc123...
Escrow stored in: swaps[swapId].dstEscrow
Result: Clean withdrawal - SUCCESS!
```

## Real Mainnet Test Results

During our testing:
- Source escrow: `0xD36aAb77Ae4647F0085838c3a4a1eD08cD4e6B8A` (Base)
- Destination escrow: `0xBd0069d96c4bb6f7eE9352518CA5b4465b5Bc32A` (Etherlink)
- Issue: Address mismatch due to timestamp differences
- Solution: 1inch-style resolver eliminates this problem

## Code Architecture

```
CrossChainResolver
├── initiateSwap()      // Start swap, deploy source escrow
├── createDestinationEscrow()  // Deploy destination escrow
├── registerEscrow()    // Track deployed addresses
├── withdraw()          // Complete swap with secret
└── Events              // For cross-chain coordination
```

## Conclusion

By following 1inch's proven Fusion resolver pattern, we transformed a blocking issue into an elegant solution. No more address prediction problems - just clean, event-driven cross-chain swaps!