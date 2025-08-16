# BMN Protocol Deployments

## Current Production Deployment (v3.0.2)

**SimplifiedEscrowFactory v3.0.2**: `0xAbF126d74d6A438a028F33756C0dC21063F72E96`
- **Base (Chain ID 8453)**: `0xAbF126d74d6A438a028F33756C0dC21063F72E96`
- **Optimism (Chain ID 10)**: `0xAbF126d74d6A438a028F33756C0dC21063F72E96`
- **Deployment Date**: August 16, 2025
- **Deployed via**: CREATE3 (same address on both chains)

### Features
- Fixed FACTORY immutable bug from v3.0.1
- PostInteraction support for 1inch integration
- Resolver whitelist with bypass option
- Emergency pause mechanism
- EIP-712 signed actions

### BMN Token
- **Address**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (all chains)

## Important: Resolver Integration Instructions

### How to Calculate Immutables for Withdrawals

When resolvers need to withdraw from escrows, they MUST use the exact `block.timestamp` from when the escrow was created:

```javascript
// Step 1: Listen for escrow creation event
const filter = factory.filters.PostInteractionEscrowCreated();
factory.on(filter, async (escrow, hashlock, sender, taker, amount, event) => {
    
    // Step 2: Get the block where the escrow was created
    const block = await provider.getBlock(event.blockNumber);
    const deployedAt = block.timestamp; // THIS is the exact timestamp the factory used
    
    // Step 3: Build immutables using this exact timestamp
    const packedTimelocks = buildTimelocks(deployedAt, srcCancellation, dstWithdrawal);
    
    // Step 4: Create immutables struct
    const immutables = {
        orderHash: orderHash,
        hashlock: hashlock,
        maker: makerAddress,
        taker: takerAddress,
        token: tokenAddress,
        amount: amount,
        safetyDeposit: safetyDeposit,
        timelocks: packedTimelocks
    };
    
    // Step 5: Use these immutables for withdrawal
    await escrow.withdraw(immutables, secret);
});
```

### Building Timelocks Correctly

```javascript
function buildTimelocks(deployedAt, srcCancellationTimestamp, dstWithdrawalTimestamp) {
    // Pack timelocks exactly as SimplifiedEscrowFactory does (line 247)
    let packed = BigInt(deployedAt) << 224n;                                    // deployedAt
    packed |= BigInt(0) << 0n;                                                  // srcWithdrawal: 0 offset
    packed |= BigInt(60) << 32n;                                                // srcPublicWithdrawal: 60s offset
    packed |= BigInt(srcCancellationTimestamp - deployedAt) << 64n;            // srcCancellation offset
    packed |= BigInt(srcCancellationTimestamp - deployedAt + 60) << 96n;       // srcPublicCancellation offset
    packed |= BigInt(dstWithdrawalTimestamp - deployedAt) << 128n;             // dstWithdrawal offset
    packed |= BigInt(dstWithdrawalTimestamp - deployedAt + 60) << 160n;        // dstPublicWithdrawal offset
    packed |= BigInt(srcCancellationTimestamp - deployedAt) << 192n;           // dstCancellation (aligned with src)
    
    return packed;
}
```

### Common Mistakes to Avoid

❌ **WRONG**: Trying to predict `block.timestamp`
```javascript
const deployedAt = Math.floor(Date.now() / 1000); // DON'T DO THIS
```

✅ **CORRECT**: Reading actual `block.timestamp` from event
```javascript
const block = await provider.getBlock(event.blockNumber);
const deployedAt = block.timestamp; // DO THIS
```

## Contract Verification

All contracts are verified on:
- [Basescan](https://basescan.org/address/0xAbF126d74d6A438a028F33756C0dC21063F72E96)
- [Optimistic Etherscan](https://optimistic.etherscan.io/address/0xAbF126d74d6A438a028F33756C0dC21063F72E96)

## Previous Deployments

See `deployments/archive/` directory for historical deployments.

## Technical Details

### Architecture
- Uses Clone proxy pattern for gas-efficient escrow deployment
- CREATE3 for cross-chain deterministic addresses
- EIP-712 for secure off-chain signature validation

### Key Contracts
- **SimplifiedEscrowFactory**: Main factory contract
- **EscrowSrc**: Source chain escrow implementation
- **EscrowDst**: Destination chain escrow implementation
- **BMNToken**: Access token for resolver participation

### Security Features
- Resolver whitelist (with bypass option for permissionless mode)
- Emergency pause mechanism
- Rescue delay for stuck funds recovery
- Time-based access controls for withdrawals/cancellations

## Support

For integration support or questions:
- Review the technical documentation in `/docs`
- Check example integrations in `/test`
- Contact the development team