# Simple Solution: Resolver Should Read Block Timestamp from Events

## The Non-Issue

After security audit, we realized the "problem" has a simple solution that requires NO contract changes.

## Current Implementation (v2.3, v3.0.0, v3.0.1, v3.0.2)

The factory already:
1. Uses `block.timestamp` when creating escrows (line 247 of SimplifiedEscrowFactory.sol)
2. Emits events when escrows are created
3. These events are emitted in the same block as the escrow creation

## The Solution for Resolvers

```javascript
// When resolver sees SrcEscrowCreated or PostInteractionEscrowCreated event
async function calculateImmutables(event, provider) {
    // Step 1: Get the block where the event was emitted
    const block = await provider.getBlock(event.blockNumber);
    
    // Step 2: Use that block's timestamp - this is EXACTLY what the factory used
    const deployedAt = block.timestamp;
    
    // Step 3: Build immutables with this timestamp
    const packedTimelocks = (deployedAt << 224) |
                            (0 << 0) |  // srcWithdrawal offset
                            (60 << 32) | // srcPublicWithdrawal offset
                            ((srcCancellationTimestamp - deployedAt) << 64) |
                            // ... etc
    
    // Step 4: Create immutables struct
    const immutables = {
        orderHash: event.orderHash,
        hashlock: event.hashlock,
        maker: event.maker,
        taker: event.taker,
        token: event.token,
        amount: event.amount,
        safetyDeposit: safetyDeposit,
        timelocks: packedTimelocks
    };
    
    return immutables;
}
```

## Why This Works

1. **Deterministic**: The block timestamp is immutable once mined
2. **Accessible**: Events include blockNumber, resolvers can query block data
3. **Exact Match**: This gives the EXACT timestamp the factory used
4. **No Protocol Changes**: Works with all deployed versions

## Implementation for Resolver Team

```typescript
// TypeScript example for resolver
class EscrowResolver {
    async onSrcEscrowCreated(event: SrcEscrowCreatedEvent) {
        // Get block timestamp
        const block = await this.provider.getBlock(event.blockNumber);
        const deployedAt = block.timestamp;
        
        // Parse order data to get cancellation/withdrawal times
        const { srcCancellationTimestamp, dstWithdrawalTimestamp } = this.parseOrderData(event);
        
        // Build immutables exactly as factory does
        const immutables = this.buildImmutables(
            event,
            deployedAt,  // Use block timestamp, not predicted time
            srcCancellationTimestamp,
            dstWithdrawalTimestamp
        );
        
        // Now can withdraw using these immutables
        await this.withdrawFromEscrow(event.escrow, immutables);
    }
    
    private buildImmutables(
        event: any,
        deployedAt: number,
        srcCancellation: number,
        dstWithdrawal: number
    ): Immutables {
        // Pack timelocks exactly as SimplifiedEscrowFactory does
        let packedTimelocks = BigInt(deployedAt) << 224n;
        packedTimelocks |= BigInt(0) << 0n;  // srcWithdrawal
        packedTimelocks |= BigInt(60) << 32n; // srcPublicWithdrawal
        packedTimelocks |= BigInt(srcCancellation - deployedAt) << 64n;
        packedTimelocks |= BigInt(srcCancellation - deployedAt + 60) << 96n;
        packedTimelocks |= BigInt(dstWithdrawal - deployedAt) << 128n;
        packedTimelocks |= BigInt(dstWithdrawal - deployedAt + 60) << 160n;
        packedTimelocks |= BigInt(srcCancellation - deployedAt) << 192n;
        
        return {
            orderHash: event.orderHash,
            hashlock: event.hashlock,
            maker: event.maker,
            taker: event.taker,
            token: event.token,
            amount: event.amount,
            safetyDeposit: event.safetyDeposit,
            timelocks: packedTimelocks
        };
    }
}
```

## Conclusion

**NO CONTRACT CHANGES NEEDED**

The "InvalidImmutables" error occurs because resolvers are trying to predict `block.timestamp` instead of reading it from the event's block. The solution is purely on the resolver side:

1. Listen for escrow creation events
2. Read the block timestamp from the event's block
3. Use that exact timestamp to calculate immutables
4. Withdraw successfully

## Benefits of This Approach

✅ No protocol upgrades needed  
✅ Works with all deployed versions (v2.3, v3.0.x)  
✅ No security risks  
✅ Simple resolver-side fix  
✅ Deterministic and reliable  

## Recommendation

1. **Do NOT deploy v3.0.3** - It has security vulnerabilities
2. **Do NOT deploy v3.0.4** - It's unnecessary complexity
3. **Keep using current contracts** - They work correctly
4. **Update resolver code** - To read block.timestamp from events

The protocol is working as designed. The resolver just needs to use the blockchain's own timestamp data.